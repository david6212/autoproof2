// SEC-23, SEC-26, SEC-27, SEC-28 — executed against the rules.
//
// SEC-23: one account could bury the operator inbox under unlimited rows.
// Now each report's id is exactly subject__reporter, for a subject that
// exists, and one waiting report per person per subject is all there is.
// It also fixes what the old `review_reports` check broke: the client's
// duplicate test was a `get` that only the operator was allowed to make.
//
// SEC-26: the fuel price-sorting collection-group query could never be
// permitted. Renamed to `prices`, with a recursive rule for that name only.
//
// SEC-27 / SEC-28: a professional's public profile could not be deleted by
// anybody, and could not be edited by its owner.
//
// Run: cd test/rules && npm test

import { readFileSync } from 'node:fs';
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from '@firebase/rules-unit-testing';
import {
  doc, setDoc, getDoc, updateDoc, deleteDoc, getDocs, writeBatch,
  collectionGroup, query, where, Timestamp, serverTimestamp,
} from 'firebase/firestore';

const ME = 'reporterMe';
const OTHER = 'reporterOther';
const NOW = Timestamp.fromMillis(Date.UTC(2026, 8, 1));

const results = [];
function record(name, ok, detail = '') {
  results.push({ name, ok, detail });
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}${detail ? ` — ${detail}` : ''}`);
}
async function allowed(name, run, setup = seed) {
  await setup();
  try { await assertSucceeds(run()); record(name, true); }
  catch (e) { record(name, false, `refused — ${e.message}`); }
}
async function refused(name, run, setup = seed) {
  await setup();
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

async function seed(extra = async () => {}) {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users', ME), { name: 'x' });
    await setDoc(doc(db, 'cars', 'car1'), { sellerId: OTHER, status: 'active', createdAt: NOW });
    await setDoc(doc(db, 'cars/car1/notes/note1'), { authorUid: OTHER, authorName: 'רון', tags: [] });
    await setDoc(doc(db, 'places', 'place1'), { source: 'community', ratingCount: 1, ratingSum: 4, isHidden: false });
    await setDoc(doc(db, 'places/place1/reviews', OTHER), { rating: 4, authorName: 'רון', authorUid: OTHER });
    await setDoc(doc(db, 'fuel_reports/st1/prices', OTHER), { uid: OTHER, agorot: 700, at: Timestamp.now() });
    await setDoc(doc(db, 'escort_pros', ME), {
      displayName: 'דוד', town: 'חיפה', areas: [], priceIls: 300, about: '',
      yearsExperience: 5, declaresInsurance: true, certStatus: 'none', createdAt: NOW,
    });
    await setDoc(doc(db, 'pro_applications', ME), {
      reporterUid: ME, proId: ME, note: 'דוד', handledAt: null, createdAt: NOW,
    });
    await extra(db);
  });
}
const mine = () => env.authenticatedContext(ME).firestore();

const noteReport = (id, carId = 'car1', noteId = 'note1') => {
  const db = mine();
  return setDoc(doc(db, 'note_reports', id), {
    carId, noteId, reporterUid: ME, handledAt: null, createdAt: serverTimestamp(),
  });
};
const correction = (id, kind = 'listing_report', carId = 'car1', note = 'x') =>
  setDoc(doc(mine(), 'data_corrections', id), {
    kind, carId, reporterUid: ME, note, handledAt: null, createdAt: serverTimestamp(),
  });
const reviewReport = (id) =>
  setDoc(doc(mine(), 'review_reports', id), {
    placeId: 'place1', reviewUid: OTHER, reporterUid: ME, note: '',
    handledAt: null, createdAt: serverTimestamp(),
  });

// ------------------------------------------------------------ SEC-23 --------

await allowed('a note report under its exact id is filed', () =>
  noteReport(`car1__note1__${ME}`));
await refused('a second one while the first waits is refused', () =>
  noteReport(`car1__note1__${ME}`),
  () => seed(async (db) => setDoc(doc(db, 'note_reports', `car1__note1__${ME}`),
    { carId: 'car1', noteId: 'note1', reporterUid: ME, handledAt: null, createdAt: NOW })));
await refused('an auto-id, the old flood, is refused', () =>
  noteReport('aZ9randomAutoId123'));
await refused('a padded prefix ending in my uid is refused', () =>
  noteReport(`zzz__car1__note1__${ME}`));
await refused('a report about a note that does not exist is refused', () =>
  noteReport(`car1__ghost__${ME}`, 'car1', 'ghost'));
await allowed('once answered, the same report may be filed again', () =>
  noteReport(`car1__note1__${ME}`),
  () => seed(async (db) => setDoc(doc(db, 'note_reports', `car1__note1__${ME}`),
    { carId: 'car1', noteId: 'note1', reporterUid: ME, handledAt: NOW, createdAt: NOW })));

await allowed('a correction under its exact id is filed', () =>
  correction(`listing_report__car1__${ME}`));
await refused('a correction about a listing that does not exist', () =>
  correction(`listing_report__nocar__${ME}`, 'listing_report', 'nocar'));
await refused('a correction of an unknown kind', () =>
  correction(`spam__car1__${ME}`, 'spam'));
await refused('a correction with an essay attached', () =>
  correction(`listing_report__car1__${ME}`, 'listing_report', 'car1', 'x'.repeat(1001)));

await allowed('a review report under its exact id is filed', () =>
  reviewReport(`place1__${OTHER}__${ME}`));
await refused('the old unanchored shape is refused', () =>
  reviewReport(`place1__${OTHER}__extra__${ME}`));

await allowed('a reporter may check their own report exists — the duplicate test', () =>
  getDoc(doc(mine(), 'review_reports', `place1__${OTHER}__${ME}`)));
await refused('but not somebody else\'s', () =>
  getDoc(doc(mine(), 'review_reports', `place1__${ME}__${OTHER}`)));
await refused('and nobody but the operator lists the inbox', () =>
  getDocs(query(collectionGroup(mine(), 'note_reports'))));

// ------------------------------------------------------------ SEC-26 --------

await allowed('the price-sorting collection group works, signed out', () =>
  getDocs(query(collectionGroup(env.unauthenticatedContext().firestore(), 'prices'),
    where('at', '>', Timestamp.fromMillis(Date.now() - 86400000)))));
await allowed('a driver reports a price, naming themselves', () =>
  setDoc(doc(mine(), 'fuel_reports/st1/prices', ME), { uid: ME, agorot: 690, at: serverTimestamp() }));
await refused('a price filed under somebody else\'s uid field', () =>
  setDoc(doc(mine(), 'fuel_reports/st1/prices', ME), { uid: OTHER, agorot: 690, at: serverTimestamp() }));
await refused('the old `reports` name takes no more writes', () =>
  setDoc(doc(mine(), 'fuel_reports/st1/reports', ME), { agorot: 690, at: serverTimestamp() }));

// ------------------------------------------------------- SEC-27 / SEC-28 ----

await allowed('a professional edits their profile without resetting its age', () =>
  setDoc(doc(mine(), 'escort_pros', ME), { priceIls: 350, about: 'עשר שנים במוסך' }, { merge: true }));
await refused('a fresh createdAt on an edit is still refused', () =>
  setDoc(doc(mine(), 'escort_pros', ME), { priceIls: 350, createdAt: serverTimestamp() }, { merge: true }));
await refused('a waiting application cannot be overwritten', () =>
  setDoc(doc(mine(), 'pro_applications', ME), {
    reporterUid: ME, proId: ME, note: 'x', handledAt: null, createdAt: serverTimestamp(),
  }));
await allowed('an answered application may be filed again', () =>
  setDoc(doc(mine(), 'pro_applications', ME), {
    reporterUid: ME, proId: ME, note: 'x', handledAt: null, createdAt: serverTimestamp(),
  }),
  () => seed(async (db) => updateDoc(doc(db, 'pro_applications', ME), { handledAt: NOW })));
await allowed('an applicant may check their own application', () =>
  getDoc(doc(mine(), 'pro_applications', ME)));

await refused('a live account cannot delete its public profile', () =>
  deleteDoc(doc(mine(), 'escort_pros', ME)));
await allowed('but leaving takes the profile and the application with it', async () => {
  const db = mine();
  await deleteDoc(doc(db, 'users', ME));
  await deleteDoc(doc(db, 'escort_pros', ME));
  await deleteDoc(doc(db, 'pro_applications', ME));
});
await refused('nobody else can delete it, even while erasing themselves', async () => {
  const db = env.authenticatedContext(OTHER).firestore();
  await deleteDoc(doc(db, 'escort_pros', ME));
});

await env.cleanup();
const failed = results.filter((r) => !r.ok);
console.log(`\n${results.length - failed.length}/${results.length} passed`);
process.exit(failed.length === 0 ? 0 : 1);
