// SEC-20, executed rather than string-matched.
//
// The Dart suite cannot see this class of bug: its rules tests read
// `firestore.rules` as text (SEC-24), so all 943 of them stayed green while a
// deployed rule made the product's signature feature impossible. This is the
// first test in the repo that actually runs the rules.
//
// What it pins, in both directions:
//
//   1. An owner whose car is listed CAN log a service record. The real
//      `addService` batch writes the record, the passport's counters and the
//      listing's denormalised copy together, and `claimsMatchThePassport` has
//      to read the passport as it will be AFTER that batch. With `get()` it
//      read the state before, so the listing always claimed one more service
//      than the passport showed, the listing write was denied, and — a batch
//      being atomic — the service record died with it.
//
//   2. The listing's claims still cannot be forged. Writing the listing's
//      `serviceCount` up with no matching service record beside it is refused.
//      That is the guarantee SEC-06 was written for, and the fix for SEC-20
//      must not spend it.
//
// Run: cd test/rules && npm test

import { readFileSync } from 'node:fs';
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from '@firebase/rules-unit-testing';
import { doc, setDoc, writeBatch, Timestamp } from 'firebase/firestore';

const ME = 'owner-me';
const VEHICLE = 'v1';
const CAR = 'c1';

// Two services, five months apart: a real passport that is NOT yet documented
// (three records spanning six months is the bar), so the third record below is
// the one that matters.
const FIRST = Timestamp.fromMillis(Date.UTC(2026, 0, 10));
const LAST = Timestamp.fromMillis(Date.UTC(2026, 5, 10));
const NEW_SERVICE = Timestamp.fromMillis(Date.UTC(2026, 8, 20));

// `documentedByRecord`: >= 3 records AND >= 15552000000 ms (180 days) between
// the first and the last. Jan → Sep clears it, so the third record flips the
// badge — which is exactly the write the old rule could not admit.
const SPAN_MS = NEW_SERVICE.toMillis() - FIRST.toMillis();
const WILL_BE_DOCUMENTED = SPAN_MS >= 15552000000;

const results = [];
function record(name, ok, detail = '') {
  results.push({ name, ok, detail });
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}${detail ? ` — ${detail}` : ''}`);
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
    await setDoc(doc(db, 'vehicles', VEHICLE), {
      ownerId: ME,
      plate: '12345678',
      serviceCount: 2,
      firstServiceAt: FIRST,
      lastServiceAt: LAST,
      historySpanMonths: 5,
      currentKm: 90000,
      isListed: true,
      activeCarId: CAR,
      createdAt: FIRST,
    });
    await setDoc(doc(db, 'cars', CAR), {
      sellerId: ME,
      vehicleId: VEHICLE,
      status: 'active',
      km: 90000,
      price: 98000,
      createdAt: FIRST,
      serviceCount: 2,
      historySpanMonths: 5,
      hasDocumentedHistory: false,
    });
  });
}

// ---------------------------------------------------------------- the batch --
// Mirrors `ServiceRepository.addService` field for field.
function addServiceBatch(db) {
  const batch = writeBatch(db);
  batch.set(doc(db, 'vehicles', VEHICLE, 'services', 's3'), {
    addedByOwnerId: ME,
    type: 'routine',
    title: 'טיפול 90,000',
    date: NEW_SERVICE,
    km: 96000,
    cost: 1200,
    createdAt: NEW_SERVICE,
  });
  batch.update(doc(db, 'vehicles', VEHICLE), {
    serviceCount: 3,
    lastServiceId: 's3',
    lastServiceAt: NEW_SERVICE,
    currentKm: 96000,
  });
  batch.update(doc(db, 'cars', CAR), {
    vehicleId: VEHICLE,
    serviceCount: 3,
    historySpanMonths: Math.floor(SPAN_MS / 86400000 / 30),
    hasDocumentedHistory: WILL_BE_DOCUMENTED,
  });
  return batch.commit();
}

await seed();
const mine = env.authenticatedContext(ME).firestore();

try {
  await assertSucceeds(addServiceBatch(mine));
  record('an owner with a listed car can log a service record', true);
} catch (e) {
  record('an owner with a listed car can log a service record', false,
    `this is SEC-20 — ${e.message}`);
}

// ------------------------------------------- and the guarantee still holds --
await seed();
const forger = env.authenticatedContext(ME).firestore();

try {
  await assertFails(
    // The listing half alone: claim a third service, write no service record.
    (async () => {
      const batch = writeBatch(forger);
      batch.update(doc(forger, 'cars', CAR), {
        serviceCount: 3,
        hasDocumentedHistory: true,
      });
      return batch.commit();
    })(),
  );
  record('a listing cannot claim a service the passport does not have', true);
} catch (e) {
  record('a listing cannot claim a service the passport does not have', false,
    `SEC-06 regressed — ${e.message}`);
}

// A seller may still edit a listed car without touching the claims at all —
// `claimsUnchanged`. If this broke, every price edit on a documented car would
// be refused and the fix would have traded one outage for another.
await seed();
try {
  await assertSucceeds(
    (async () => {
      const batch = writeBatch(mine);
      batch.update(doc(mine, 'cars', CAR), { price: 95000 });
      return batch.commit();
    })(),
  );
  record('a price edit on a listed car still goes through', true);
} catch (e) {
  record('a price edit on a listed car still goes through', false, e.message);
}

await env.cleanup();

const failed = results.filter((r) => !r.ok);
console.log(`\n${results.length - failed.length}/${results.length} passed`);
process.exit(failed.length === 0 ? 0 : 1);
