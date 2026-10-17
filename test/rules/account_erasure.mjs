// "Delete my account", executed against the rules.
//
// `account_deletion_reach_test.dart` runs the real Dart code against an
// in-memory database that has no rules. This is the other half: every step of
// the same sequence, in the same order, against the real ruleset — because a
// step the rules refuse leaves the account half-deleted, and the policy says
// it is gone.
//
// It also pins the two privacy rules that came with it (SEC-18, SEC-19): a
// world-readable note or review may carry "מיכל ש." and never "מיכל שפירא",
// and the collection-group reads that deletion needs let an account list its
// OWN traces and nobody else's.
//
// Run: cd test/rules && npm test

import { readFileSync } from 'node:fs';
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from '@firebase/rules-unit-testing';
import {
  doc, setDoc, deleteDoc, getDocs, writeBatch, collectionGroup, query, where,
  Timestamp, serverTimestamp,
} from 'firebase/firestore';

const ME = 'me-uid';
const OTHER = 'other-uid';
const NOW = Timestamp.fromMillis(Date.UTC(2026, 8, 1));

const results = [];
function record(name, ok, detail = '') {
  results.push({ name, ok, detail });
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}${detail ? ` — ${detail}` : ''}`);
}
async function allowed(name, run) {
  try { await assertSucceeds(run()); record(name, true); }
  catch (e) { record(name, false, `refused — ${e.message}`); }
}
async function refused(name, run) {
  try { await assertFails(run()); record(name, true); }
  catch (e) { record(name, false, `went through — ${e.message}`); }
}

const env = await initializeTestEnvironment({
  projectId: 'bonnetcheck-rules-test',
  firestore: {
    rules: readFileSync('../../firestore.rules', 'utf8'),
    host: '127.0.0.1',
    port: 8080,
  },
});

const review = (uid, rating, name = 'רון') => ({
  rating, text: '', serviceType: '', vehicleModel: '', serviceRecordIds: [],
  authorName: name, authorUid: uid, createdAt: NOW,
});

async function seed() {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users', ME), { name: 'דוד' });
    await setDoc(doc(db, 'vehicles', 'v1'), {
      ownerId: ME, serviceCount: 1, isListed: false, createdAt: NOW,
    });
    await setDoc(doc(db, 'vehicles/v1/services/s1'), {
      addedByOwnerId: ME, date: NOW, createdAt: NOW, km: 1, title: 'x',
    });
    await setDoc(doc(db, 'vehicles/v1/services/s1/file/blob'), { bytes: 'x' });
    await setDoc(doc(db, 'cars', 'theirs'), { sellerId: OTHER, status: 'active', createdAt: NOW });
    await setDoc(doc(db, 'cars/theirs/notes/n-mine'), { authorUid: ME, authorName: 'דוד מ.', tags: [] });
    await setDoc(doc(db, 'cars/theirs/notes/n-theirs'), { authorUid: OTHER, authorName: 'רון', tags: [] });
    await setDoc(doc(db, 'cars/theirs/buyer_likes', ME), { uid: ME, likedAt: NOW });
    await setDoc(doc(db, 'cars/theirs/journeys', ME), { uid: ME, stage: 2 });
    await setDoc(doc(db, 'places', 'p1'), {
      source: 'community', addedByUid: OTHER, isHidden: false,
      ratingCount: 2, ratingSum: 8, reportCount: 1,
    });
    await setDoc(doc(db, 'places/p1/reviews', ME), review(ME, 5, 'דוד מ.'));
    await setDoc(doc(db, 'places/p1/reviews', OTHER), review(OTHER, 3));
    await setDoc(doc(db, 'places/p1/reports', ME), { reporterUid: ME, reason: 'x' });
  });
}

// ------------------------------------------- the sequence, as written -------
await seed();
const mine = env.authenticatedContext(ME).firestore();

// Before erasure starts, a report is still permanent.
await refused('a report cannot be withdrawn by a live account', () =>
  deleteDoc(doc(mine, 'places/p1/reports', ME)));

await allowed('1. the profile document goes first', () =>
  deleteDoc(doc(mine, 'users', ME)));

await allowed('3. the invoice image under a service record (SEC-17)', () =>
  deleteDoc(doc(mine, 'vehicles/v1/services/s1/file/blob')));
await allowed('3. then the service record itself', () =>
  deleteDoc(doc(mine, 'vehicles/v1/services/s1')));
await allowed('3. then the passport', () =>
  deleteDoc(doc(mine, 'vehicles', 'v1')));

async function deleteMineIn(group, field) {
  const snap = await getDocs(query(collectionGroup(mine, group), where(field, '==', ME)));
  if (snap.empty) throw new Error(`found nothing in ${group}`);
  for (const d of snap.docs) await deleteDoc(d.ref);
}
await allowed('5. my note on their listing, found by collection group', () =>
  deleteMineIn('notes', 'authorUid'));
await allowed('5. my like on their listing', () =>
  deleteMineIn('buyer_likes', 'uid'));
await allowed('5. my journey on their listing', () =>
  deleteMineIn('journeys', 'uid'));
await allowed('5. my "does not exist" report, while erasing', () =>
  deleteMineIn('reports', 'reporterUid'));
await allowed('5. my review, with its rating taken out', async () => {
  const snap = await getDocs(query(collectionGroup(mine, 'reviews'), where('authorUid', '==', ME)));
  if (snap.empty) throw new Error('found nothing in reviews');
  for (const d of snap.docs) {
    const b = writeBatch(mine);
    b.delete(d.ref);
    b.update(d.ref.parent.parent, { ratingCount: 1, ratingSum: 3, ratingAvg: 3 });
    await b.commit();
  }
});

// ------------------------------------------- what it may NOT reach -----------
await seed();
const nosy = env.authenticatedContext(ME).firestore();
await refused('nobody lists another account\'s notes by collection group', () =>
  getDocs(query(collectionGroup(nosy, 'notes'), where('authorUid', '==', OTHER))));
await refused('nor their reviews', () =>
  getDocs(query(collectionGroup(nosy, 'reviews'), where('authorUid', '==', OTHER))));
await refused('nor an unfiltered collection group of reports', () =>
  getDocs(collectionGroup(nosy, 'reports')));
await refused('a signed-out caller lists nothing by collection group', () =>
  getDocs(query(collectionGroup(env.unauthenticatedContext().firestore(), 'notes'),
    where('authorUid', '==', ME))));

// ------------------------------------------- SEC-18 / SEC-19: the name -------
await seed();
const writer = env.authenticatedContext(ME).firestore();
await allowed('a note signed "מיכל ש." is accepted', () =>
  setDoc(doc(writer, 'cars/theirs/notes/n-new'), { authorUid: ME, authorName: 'מיכל ש.', tags: [] }));
await refused('a note signed with a full name is refused', () =>
  setDoc(doc(writer, 'cars/theirs/notes/n-new2'), { authorUid: ME, authorName: 'מיכל שפירא', tags: [] }));
await refused('a note with no name at all is refused', () =>
  setDoc(doc(writer, 'cars/theirs/notes/n-new3'), { authorUid: ME, tags: [] }));

async function saveReview(name, authorUid = ME) {
  const b = writeBatch(writer);
  b.set(doc(writer, 'places/p1/reviews', ME), { ...review(ME, 4, name), authorUid });
  b.update(doc(writer, 'places', 'p1'), {
    ratingCount: 2, ratingSum: 7, ratingAvg: 3.5, lastReviewAt: serverTimestamp(),
  });
  return b.commit();
}
await allowed('a review edit signed "דוד מ." is accepted', () => saveReview('דוד מ.'));
await seed();
await refused('a review signed with a full name is refused', () => saveReview('דוד מלדה'));
await seed();
await refused('a review whose authorUid names somebody else is refused', () =>
  saveReview('דוד מ.', OTHER));

await env.cleanup();
const failed = results.filter((r) => !r.ok);
console.log(`\n${results.length - failed.length}/${results.length} passed`);
process.exit(failed.length === 0 ? 0 : 1);
