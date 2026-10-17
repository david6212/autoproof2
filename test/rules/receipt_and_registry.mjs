// SEC-30 and SEC-21, executed against the rules.
//
// SEC-30: attaching a receipt to a record nobody had edited was refused —
// the update rule demanded an `editedAt` stamp — and because the image and
// the flag were two writes, the image stayed behind with nothing pointing at
// it. Now one batch, and a `hasReceipt`-only write needs no edit stamp.
//
// SEC-21: the registry snapshot on a listing was frozen after publication,
// which killed the seller's refresh button. Now it may change only beside a
// check date that IS the server's clock.
//
// Run: cd test/rules && npm test

import { readFileSync } from 'node:fs';
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from '@firebase/rules-unit-testing';
import {
  doc, setDoc, updateDoc, writeBatch, Timestamp, serverTimestamp,
} from 'firebase/firestore';

const ME = 'owner-me';
const NOW = Timestamp.fromMillis(Date.UTC(2026, 8, 1));

const results = [];
function record(name, ok, detail = '') {
  results.push({ name, ok, detail });
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}${detail ? ` — ${detail}` : ''}`);
}
async function allowed(name, run) {
  await seed();
  try { await assertSucceeds(run()); record(name, true); }
  catch (e) { record(name, false, `refused — ${e.message}`); }
}
async function refused(name, run) {
  await seed();
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

async function seed() {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'vehicles', 'v1'), {
      ownerId: ME, serviceCount: 1, isListed: false, createdAt: NOW,
    });
    // Written by addService: no `editedAt`, on purpose.
    await setDoc(doc(db, 'vehicles/v1/services/s1'), {
      addedByOwnerId: ME, date: NOW, createdAt: NOW, km: 50000, title: 'טיפול',
    });
    await setDoc(doc(db, 'cars', 'c1'), {
      sellerId: ME, status: 'active', createdAt: NOW, price: 50000,
      govSnapshot: { year: 2015 }, govCheckedAt: NOW,
      serviceCount: 0, hasDocumentedHistory: false,
    });
  });
}
const mine = () => env.authenticatedContext(ME).firestore();

// ------------------------------------------------------------ SEC-30 --------

// Mirrors `ServiceRepository.setReceipt`.
await allowed('a receipt attaches to a record that was never edited', () => {
  const db = mine();
  const b = writeBatch(db);
  b.set(doc(db, 'vehicles/v1/services/s1/file/blob'), { bytes: 'x', width: 1, height: 1 });
  b.update(doc(db, 'vehicles/v1/services/s1'), { hasReceipt: true });
  return b.commit();
});

await refused('an edit of what the record SAYS still needs the stamp', () =>
  updateDoc(doc(mine(), 'vehicles/v1/services/s1'), { km: 999 }));

await refused('nor can the content ride along with the receipt flag', () =>
  updateDoc(doc(mine(), 'vehicles/v1/services/s1'), { hasReceipt: true, km: 999 }));

await refused('and the flag cannot be used to un-attach without a stamp', () =>
  updateDoc(doc(mine(), 'vehicles/v1/services/s1'), { hasReceipt: false }));

await refused('a stranger cannot attach one', () => {
  const db = env.authenticatedContext('stranger').firestore();
  const b = writeBatch(db);
  b.set(doc(db, 'vehicles/v1/services/s1/file/blob'), { bytes: 'x' });
  b.update(doc(db, 'vehicles/v1/services/s1'), { hasReceipt: true });
  return b.commit();
});

// ------------------------------------------------------------ SEC-21 --------

// Mirrors `CarRepository.refreshGovSnapshot`.
await allowed('the seller refreshes the registry answer, stamped by the server', () =>
  updateDoc(doc(mine(), 'cars', 'c1'), {
    govSnapshot: { year: 2015, testValidUntil: '2027-01-01' },
    govCheckedAt: serverTimestamp(),
  }));

await refused('a new answer with the old date is refused', () =>
  updateDoc(doc(mine(), 'cars', 'c1'), { govSnapshot: { year: 2019 } }));

await refused('a new answer with a date the phone chose is refused', () =>
  updateDoc(doc(mine(), 'cars', 'c1'), {
    govSnapshot: { year: 2019 },
    govCheckedAt: Timestamp.fromMillis(Date.now() + 86400000),
  }));

await refused('nor may the date be moved on its own to look fresh', () =>
  updateDoc(doc(mine(), 'cars', 'c1'), {
    govCheckedAt: Timestamp.fromMillis(Date.now() - 1000),
  }));

await allowed('a price edit, touching neither, still goes through', () =>
  updateDoc(doc(mine(), 'cars', 'c1'), { price: 48000 }));

await env.cleanup();
const failed = results.filter((r) => !r.ok);
console.log(`\n${results.length - failed.length}/${results.length} passed`);
process.exit(failed.length === 0 ? 0 : 1);
