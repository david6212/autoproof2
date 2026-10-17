// SEC-25: the 24-month retention promise, kept by the rules and not only by
// the app.
//
// Until 10/2026 `cars/{id}` was `allow read: if true`, so a direct REST read
// served every listing ever published — photos, description, seller uid —
// while the app hid the expired ones. Now the rules refuse a listing older
// than 730 days to everyone but its seller, and the feed query carries a
// matching bound so the rules can admit it.
//
// Run: cd test/rules && npm test

import { readFileSync } from 'node:fs';
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from '@firebase/rules-unit-testing';
import {
  doc, setDoc, getDoc, getDocs, collection, query, where, Timestamp,
} from 'firebase/firestore';

const SELLER = 'seller-1';
const DAY = 86400000;
const now = () => Date.now();

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

await env.clearFirestore();
await env.withSecurityRulesDisabled(async (ctx) => {
  const db = ctx.firestore();
  const listing = (ageDays) => ({
    sellerId: SELLER, status: 'active', price: 50000,
    createdAt: Timestamp.fromMillis(now() - ageDays * DAY),
    serviceCount: 0, hasDocumentedHistory: false,
  });
  await setDoc(doc(db, 'cars', 'fresh'), listing(10));
  await setDoc(doc(db, 'cars', 'old'), listing(800));
});

const guest = env.unauthenticatedContext().firestore();
const stranger = env.authenticatedContext('stranger').firestore();
const seller = env.authenticatedContext(SELLER).firestore();

// Mirrors `CarRepository.streamActiveCars` — 725 days, inside the rules' 730.
const feed = (db) => getDocs(query(collection(db, 'cars'),
  where('status', '==', 'active'),
  where('createdAt', '>', Timestamp.fromMillis(now() - 725 * DAY))));

await allowed('a guest opens a current listing', () => getDoc(doc(guest, 'cars', 'fresh')));
await refused('a guest cannot open one older than 24 months', () => getDoc(doc(guest, 'cars', 'old')));
await refused('nor can a signed-in stranger', () => getDoc(doc(stranger, 'cars', 'old')));
await allowed('its seller still can', () => getDoc(doc(seller, 'cars', 'old')));

await allowed('the feed query, bounded like the app\'s, works for a guest', () => feed(guest));
await refused('an unbounded list of every listing is refused', () =>
  getDocs(query(collection(guest, 'cars'), where('status', '==', 'active'))));
await allowed('the seller\'s own query finds their expired listing too', async () => {
  const snap = await getDocs(query(collection(seller, 'cars'), where('sellerId', '==', SELLER)));
  if (snap.size !== 2) throw new Error(`expected 2, got ${snap.size}`);
});

const draft = (createdAt) => ({
  sellerId: SELLER, status: 'active', price: 1, createdAt,
  serviceCount: 0, hasDocumentedHistory: false,
});
await allowed('a listing published today', () =>
  setDoc(doc(seller, 'cars', 'new1'), draft(Timestamp.now())));
await refused('a listing dated next year — it would never expire', () =>
  setDoc(doc(seller, 'cars', 'new2'), draft(Timestamp.fromMillis(now() + 365 * DAY))));
await refused('a listing back-dated three years', () =>
  setDoc(doc(seller, 'cars', 'new3'), draft(Timestamp.fromMillis(now() - 1100 * DAY))));

await env.cleanup();
const failed = results.filter((r) => !r.ok);
console.log(`\n${results.length - failed.length}/${results.length} passed`);
process.exit(failed.length === 0 ? 0 : 1);
