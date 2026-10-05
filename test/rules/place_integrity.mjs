// SEC-01 and SEC-02, executed rather than string-matched.
//
// SEC-01: a garage's score could be driven anywhere by one account. The rule
// asked only that the caller's review EXIST after the write — so one honest
// review, then N bare `+1 / +5` updates, each passing every clause. And the
// review document could be written on its own, so create-5 / edit-to-1 /
// delete left +4 in the sum with the count unchanged.
//
// SEC-02: hiding needed a report in the caller's own name, which the caller
// writes. Two writes removed any garage from the directory, permanently. The
// three-reporter threshold existed only in the client.
//
// What it pins, in both directions:
//
//   1. Every client path still goes through: a new review, an edit, a
//      withdrawal, withdrawing a review the operator hid, the operator hiding
//      one, and the first, second and third report — the third one hiding.
//
//   2. Every way to move the score or the directory without the matching
//      document is refused.
//
// Run: cd test/rules && npm test

import { readFileSync } from 'node:fs';
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from '@firebase/rules-unit-testing';
import {
  doc, setDoc, updateDoc, deleteDoc, writeBatch, Timestamp, serverTimestamp,
} from 'firebase/firestore';

const ME = 'reviewer-me';
const OTHER = 'reviewer-other';
const P = 'p1';

const results = [];
function record(name, ok, detail = '') {
  results.push({ name, ok, detail });
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}${detail ? ` — ${detail}` : ''}`);
}

async function allowed(name, run, setup = seed) {
  await setup();
  try {
    await assertSucceeds(run());
    record(name, true);
  } catch (e) {
    record(name, false, `refused — ${e.message}`);
  }
}

async function refused(name, run, setup = seed) {
  await setup();
  try {
    await assertFails(run());
    record(name, true);
  } catch (e) {
    record(name, false, `went through — ${e.message}`);
  }
}

const env = await initializeTestEnvironment({
  projectId: 'bonnetcheck-rules-test',
  firestore: {
    rules: readFileSync('../../firestore.rules', 'utf8'),
    host: '127.0.0.1',
    port: 8080,
  },
});

const NOW = Timestamp.fromMillis(Date.UTC(2026, 8, 1));

function review(rating, extra = {}) {
  return {
    rating,
    text: 'טיפול טוב',
    serviceType: '',
    vehicleModel: '',
    serviceRecordIds: [],
    authorName: 'דוד',
    createdAt: NOW,
    ...extra,
  };
}

// One place, one review by somebody else (4 stars), no reports.
async function seed({ mine = null, reports = [], hiddenMine = false } = {}) {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const count = 1 + (mine && !hiddenMine ? 1 : 0);
    const sum = 4 + (mine && !hiddenMine ? mine : 0);
    await setDoc(doc(db, 'places', P), {
      source: 'community',
      category: 'garage_mechanical',
      name: 'מוסך הבדיקה',
      addedByUid: OTHER,
      ratingCount: count,
      ratingSum: sum,
      ratingAvg: sum / count,
      isHidden: false,
      reportCount: reports.length,
    });
    await setDoc(doc(db, 'places', P, 'reviews', OTHER), review(4));
    if (mine) {
      await setDoc(doc(db, 'places', P, 'reviews', ME),
        review(mine, hiddenMine ? { hiddenByOperator: true } : {}));
    }
    for (const uid of reports) {
      await setDoc(doc(db, 'places', P, 'reports', uid),
        { reason: 'not_exists', reporterUid: uid, createdAt: NOW });
    }
  });
}
const withMyReview = (rating, hidden = false) => () =>
  seed({ mine: rating, hiddenMine: hidden });
const withReports = (...uids) => () => seed({ reports: uids });

const as = (uid) => env.authenticatedContext(uid).firestore();
const operator = () => env.authenticatedContext('op', {
  email: 'davidmalede@gmail.com',
  email_verified: true,
}).firestore();

// Mirrors `PlaceRepository.saveReview` / `deleteReview` / `reportDoesNotExist`.
function saveReview(db, rating, count, sum) {
  const b = writeBatch(db);
  b.set(doc(db, 'places', P, 'reviews', ME), review(rating));
  b.update(doc(db, 'places', P), {
    ratingCount: count, ratingSum: sum, ratingAvg: sum / count,
    lastReviewAt: serverTimestamp(),
  });
  return b.commit();
}
function deleteReview(db, count, sum) {
  const b = writeBatch(db);
  b.delete(doc(db, 'places', P, 'reviews', ME));
  b.update(doc(db, 'places', P), {
    ratingCount: count, ratingSum: sum, ratingAvg: count ? sum / count : 0,
  });
  return b.commit();
}
function report(db, uid, newCount) {
  const b = writeBatch(db);
  b.set(doc(db, 'places', P, 'reports', uid),
    { reason: 'not_exists', reporterUid: uid, createdAt: serverTimestamp() });
  b.update(doc(db, 'places', P), {
    reportCount: newCount,
    ...(newCount >= 3 ? { isHidden: true } : {}),
  });
  return b.commit();
}

// ------------------------------------------------ SEC-01, honest paths ------

await allowed('a new review adds one and exactly its rating', () =>
  saveReview(as(ME), 5, 2, 9));

await allowed('an edit keeps the count and moves the sum by new − old', () =>
  saveReview(as(ME), 2, 2, 6), withMyReview(5));

await allowed('a withdrawal takes one and exactly its rating back out', () =>
  deleteReview(as(ME), 1, 4), withMyReview(5));

await allowed('a review the operator hid is withdrawn on its own', () =>
  deleteDoc(doc(as(ME), 'places', P, 'reviews', ME)), withMyReview(5, true));

await allowed('the operator hides a review and takes its rating out', () => {
  const db = operator();
  const b = writeBatch(db);
  b.update(doc(db, 'places', P, 'reviews', ME),
    { hiddenByOperator: true, hiddenAt: serverTimestamp() });
  b.update(doc(db, 'places', P), { ratingCount: 1, ratingSum: 4, ratingAvg: 4 });
  return b.commit();
}, withMyReview(5));

// ------------------------------------------------- SEC-01, forgeries --------

await refused('the 26/09 loop: an existing review, then a bare +1/+5', () =>
  updateDoc(doc(as(ME), 'places', P), { ratingCount: 3, ratingSum: 14 }),
  withMyReview(5));

await refused('holding the count and dragging the sum down', () =>
  updateDoc(doc(as(ME), 'places', P), { ratingSum: 4 }), withMyReview(5));

await refused('a new 1-star review that adds 5 to the sum', () =>
  saveReview(as(ME), 1, 2, 9));

await refused('a new review that adds two to the count', () =>
  saveReview(as(ME), 5, 3, 9));

await refused('an aggregate move with no review at all', () =>
  updateDoc(doc(as(ME), 'places', P), { ratingCount: 2, ratingSum: 9 }));

await refused('a review written on its own, leaving the score behind', () =>
  setDoc(doc(as(ME), 'places', P, 'reviews', ME), review(5)));

await refused('an edit 5 → 1 with the sum left where it was', () =>
  setDoc(doc(as(ME), 'places', P, 'reviews', ME), review(1)), withMyReview(5));

await refused('a review deleted on its own, so it can be added again', () =>
  deleteDoc(doc(as(ME), 'places', P, 'reviews', ME)), withMyReview(5));

await refused('withdrawing a review but taking 5 out for a 2', () =>
  deleteReview(as(ME), 1, 1), withMyReview(2));

await refused('withdrawing a hidden review and taking its rating out twice', () =>
  deleteReview(as(ME), 0, 0), withMyReview(5, true));

// ------------------------------------------------ SEC-02, honest paths ------

await allowed('the first report counts one and does not hide', () =>
  report(as(ME), ME, 1));

await allowed('the third distinct reporter hides the place', () =>
  report(as(ME), ME, 3), withReports('a', 'b'));

// ------------------------------------------------- SEC-02, forgeries --------

await refused('the 26/09 pair: my own report, then isHidden', () =>
  updateDoc(doc(as(ME), 'places', P), { isHidden: true }), withReports(ME));

await refused('a single report that claims to be the third', () =>
  report(as(ME), ME, 3));

await refused('the counter raised again on a report already filed', () =>
  updateDoc(doc(as(ME), 'places', P), { reportCount: 2 }), withReports(ME));

await refused('a report filed without moving the counter', () =>
  setDoc(doc(as(ME), 'places', P, 'reports', ME),
    { reason: 'not_exists', reporterUid: ME, createdAt: NOW }));

await refused('hiding at two reports', () => {
  const db = as(ME);
  const b = writeBatch(db);
  b.set(doc(db, 'places', P, 'reports', ME),
    { reason: 'not_exists', reporterUid: ME, createdAt: NOW });
  b.update(doc(db, 'places', P), { reportCount: 2, isHidden: true });
  return b.commit();
}, withReports('a'));

await refused('a place created with reports already on it', () =>
  setDoc(doc(as(ME), 'places', 'p-new'), {
    source: 'community',
    category: 'garage_mechanical',
    name: 'חדש',
    addedByUid: ME,
    ratingCount: 0,
    ratingSum: 0,
    isHidden: false,
    reportCount: 3,
  }));

await env.cleanup();

const failed = results.filter((r) => !r.ok);
console.log(`\n${results.length - failed.length}/${results.length} passed`);
process.exit(failed.length === 0 ? 0 : 1);
