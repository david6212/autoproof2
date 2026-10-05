// The counters a "תיק מתועד" badge is computed from, executed rather than
// string-matched.
//
// Until 05/10 `vehicles/{id}` let its owner raise `serviceCount` by one per
// write with nothing behind it, and move `firstServiceAt` anywhere. Three bare
// updates and a back-dated first service made a documented passport out of
// nothing, and SEC-06's listing check then confirmed the forgery, because it
// compares the listing to exactly these counters.
//
// What it pins, in both directions:
//
//   1. Every honest path still goes through: the first record on an empty
//      passport, a record older than the latest (dates hold), an ordinary
//      edit, a fresh passport, and a buyer claiming a car with a handover
//      code.
//
//   2. Every way to move the counters without a record is refused: a bare
//      increment, a replay of a record that already existed, naming a record
//      that is never written, dates that the record does not imply, a
//      back-dated first service with no increment at all, and a passport
//      created with a history already on it.
//
// Run: cd test/rules && npm test

import { readFileSync } from 'node:fs';
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from '@firebase/rules-unit-testing';
import { doc, setDoc, updateDoc, writeBatch, Timestamp } from 'firebase/firestore';

const ME = 'owner-me';
const BUYER = 'buyer-them';
const VEHICLE = 'v1';
const EMPTY = 'v-empty';

const day = (y, m, d) => Timestamp.fromMillis(Date.UTC(y, m, d));
const FIRST = day(2026, 0, 10);
const LAST = day(2026, 5, 10);

const results = [];
function record(name, ok, detail = '') {
  results.push({ name, ok, detail });
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}${detail ? ` — ${detail}` : ''}`);
}

async function allowed(name, run) {
  await seed();
  try {
    await assertSucceeds(run());
    record(name, true);
  } catch (e) {
    record(name, false, `refused — ${e.message}`);
  }
}

async function refused(name, run) {
  await seed();
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

function service(date) {
  return {
    addedByOwnerId: ME,
    type: 'routine',
    title: 'טיפול',
    date,
    km: 50000,
    cost: 800,
    createdAt: date,
  };
}

async function seed() {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    // Two real records, five months apart: not yet documented.
    await setDoc(doc(db, 'vehicles', VEHICLE), {
      ownerId: ME,
      plate: '12345678',
      serviceCount: 2,
      firstServiceAt: FIRST,
      lastServiceAt: LAST,
      lastServiceId: 's2',
      currentKm: 50000,
      isListed: false,
      activeCarId: null,
      createdAt: FIRST,
    });
    await setDoc(doc(db, 'vehicles', VEHICLE, 'services', 's1'), service(FIRST));
    await setDoc(doc(db, 'vehicles', VEHICLE, 'services', 's2'), service(LAST));
    await setDoc(doc(db, 'vehicles', EMPTY), {
      ownerId: ME,
      plate: '87654321',
      serviceCount: 0,
      firstServiceAt: null,
      lastServiceAt: null,
      currentKm: 0,
      isListed: false,
      activeCarId: null,
      createdAt: FIRST,
    });
    await setDoc(doc(db, 'transfers', 'CODE1'), {
      vehicleId: VEHICLE,
      fromUserId: ME,
      status: 'pending',
      createdAt: FIRST,
      expiresAt: Timestamp.fromMillis(Date.now() + 86400000),
    });
  });
}

const mine = () => env.authenticatedContext(ME).firestore();

// Mirrors `ServiceRepository.addService`: the record and the counters in one
// batch, `lastServiceAt` only when it advances.
function addService(db, vehicleId, id, date, counters) {
  const batch = writeBatch(db);
  batch.set(doc(db, 'vehicles', vehicleId, 'services', id), service(date));
  batch.update(doc(db, 'vehicles', vehicleId), counters);
  return batch.commit();
}

// ------------------------------------------------------- honest paths -------

await allowed('the first record on an empty passport sets both dates', () =>
  addService(mine(), EMPTY, 'n1', day(2026, 2, 1), {
    serviceCount: 1,
    lastServiceId: 'n1',
    firstServiceAt: day(2026, 2, 1),
    lastServiceAt: day(2026, 2, 1),
  }));

await allowed('a newer record advances lastServiceAt', () =>
  addService(mine(), VEHICLE, 's3', day(2026, 8, 1), {
    serviceCount: 3,
    lastServiceId: 's3',
    lastServiceAt: day(2026, 8, 1),
  }));

await allowed('an older record leaves both dates where they were', () =>
  addService(mine(), VEHICLE, 's3', day(2026, 3, 1), {
    serviceCount: 3,
    lastServiceId: 's3',
  }));

await allowed('an ordinary edit with the count held', () =>
  updateDoc(doc(mine(), 'vehicles', VEHICLE), { nickname: 'הלבנה' }));

await allowed('a fresh passport with no history', () =>
  setDoc(doc(mine(), 'vehicles', 'v-new'), {
    ownerId: ME,
    plate: '11122233',
    serviceCount: 0,
    firstServiceAt: null,
    lastServiceAt: null,
    createdAt: FIRST,
  }));

await allowed('a buyer claims the car with a handover code', () =>
  updateDoc(doc(env.authenticatedContext(BUYER).firestore(), 'vehicles', VEHICLE), {
    ownerId: BUYER,
    previousOwnerId: ME,
    claimedVia: 'CODE1',
    acquiredVia: 'bonnetcheck',
    transferredAt: Timestamp.now(),
    isListed: false,
    activeCarId: null,
  }));

// ------------------------------------------------------------- forgeries ----

await refused('a bare increment with no record beside it', () =>
  updateDoc(doc(mine(), 'vehicles', VEHICLE), { serviceCount: 3 }));

await refused('an increment that replays a record which already existed', () =>
  updateDoc(doc(mine(), 'vehicles', VEHICLE), {
    serviceCount: 3,
    lastServiceId: 's1',
  }));

await refused('an increment naming a record that is never written', () =>
  updateDoc(doc(mine(), 'vehicles', VEHICLE), {
    serviceCount: 3,
    lastServiceId: 'ghost',
  }));

await refused('a real record, but lastServiceAt later than the record says', () =>
  addService(mine(), VEHICLE, 's3', day(2026, 3, 1), {
    serviceCount: 3,
    lastServiceId: 's3',
    lastServiceAt: day(2026, 11, 1),
  }));

await refused('a real record, but firstServiceAt back-dated beside it', () =>
  addService(mine(), VEHICLE, 's3', day(2026, 8, 1), {
    serviceCount: 3,
    lastServiceId: 's3',
    lastServiceAt: day(2026, 8, 1),
    firstServiceAt: day(2024, 0, 1),
  }));

await refused('back-dating firstServiceAt with the count held', () =>
  updateDoc(doc(mine(), 'vehicles', VEHICLE), { firstServiceAt: day(2024, 0, 1) }));

await refused('a passport created with a history already on it', () =>
  setDoc(doc(mine(), 'vehicles', 'v-new'), {
    ownerId: ME,
    plate: '11122233',
    serviceCount: 0,
    firstServiceAt: day(2024, 0, 1),
    lastServiceAt: day(2026, 0, 1),
    createdAt: FIRST,
  }));

await env.cleanup();

const failed = results.filter((r) => !r.ok);
console.log(`\n${results.length - failed.length}/${results.length} passed`);
process.exit(failed.length === 0 ? 0 : 1);
