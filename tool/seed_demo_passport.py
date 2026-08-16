# Seeds one demo vehicle passport with a real-looking service history, and
# links it to the Mazda CX-5 demo listing.
#
# Why: the passport is built but invisible. The garage is private, so nobody
# sees it until they add their own car — and the buyer-facing half (the service
# timeline on a listing, the "תיק מתועד" badge) never appears at all. This makes
# the headline feature demonstrable to anyone who opens the app.
#
# Admin REST writes bypass security rules, which is the only way to create a
# vehicle owned by `demo-seller`.
import io
import json
import urllib.request

PROJECT = "autoproof-8d827"
BASE = "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents" % PROJECT

CAR_ID = "9J8Wnc5kHEF8tF106IxQ"   # Mazda CX-5, plate 4659255, demo-seller
VEHICLE_ID = "demo-vehicle-mazda"
OWNER = "demo-seller"
PLATE = "4659255"

with io.open(r"C:\Users\DAVID\.config\configstore\firebase-tools.json",
             encoding="utf-8") as fh:
    TOKEN = json.load(fh)["tokens"]["access_token"]


def request(method, path, body=None, params=""):
    url = BASE + path + params
    data = json.dumps(body).encode("utf-8") if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Authorization", "Bearer " + TOKEN)
    req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        print(method, path, "->", e.code, e.read().decode("utf-8")[:400])
        raise


def s(x):
    return {"stringValue": x}


def i(x):
    return {"integerValue": str(x)}


def b(x):
    return {"booleanValue": x}


def ts(x):
    return {"timestampValue": x}


# Four services, Feb 2025 -> Apr 2026. Three records over six months is the
# badge rule; four over fourteen months clears it comfortably and looks like
# somebody actually logging as they go, which is the behaviour the badge is
# meant to reward.
SERVICES = [
    ("s1", "routine",   "טיפול 60,000",   "2025-02-10T09:00:00Z", 61000, 1150, "מוסך אבי ובניו"),
    ("s2", "tires",     "החלפת 4 צמיגים", "2025-06-22T09:00:00Z", 72500, 1800, "צמיגי הצפון"),
    ("s3", "brakes",    "רפידות קדמיות",  "2025-11-05T09:00:00Z", 83000,  950, "מוסך אבי ובניו"),
    ("s4", "routine",   "טיפול 90,000",   "2026-04-18T09:00:00Z", 91000, 1320, "מוסך אבי ובניו"),
]

FIRST = SERVICES[0][3]
LAST = SERVICES[-1][3]
SPAN_MONTHS = 14   # Feb 2025 -> Apr 2026

vehicle = {
    "fields": {
        "plate": s(PLATE),
        "ownerId": s(OWNER),
        "nickname": s(""),
        "currentKm": i(92000),
        "acquiredVia": s("manual"),
        "isListed": b(True),
        "activeCarId": s(CAR_ID),
        "serviceCount": i(len(SERVICES)),
        "firstServiceAt": ts(FIRST),
        "lastServiceAt": ts(LAST),
        "openRecallCount": i(0),
        "createdAt": ts("2024-09-01T09:00:00Z"),
        "purchaseDate": ts("2024-09-01T09:00:00Z"),
        "govSnapshot": {
            "mapValue": {
                "fields": {
                    "make": s("מאזדה"),
                    "model": s("CX-5"),
                    "year": i(2017),
                    "color": s("אפור מטלי"),
                    "fuelType": s("בנזין"),
                }
            }
        },
    }
}

print("writing vehicle...")
request("PATCH", "/vehicles/" + VEHICLE_ID, vehicle)

print("writing %d service records..." % len(SERVICES))
for sid, stype, title, date, km, cost, garage in SERVICES:
    request("PATCH", "/vehicles/%s/services/%s" % (VEHICLE_ID, sid), {
        "fields": {
            "type": s(stype),
            "title": s(title),
            "date": ts(date),
            "km": i(km),
            "cost": i(cost),
            "garageName": s(garage),
            "addedByOwnerId": s(OWNER),
            "createdAt": ts(date),
        }
    })

print("linking the listing to the passport...")
mask = ("?updateMask.fieldPaths=vehicleId"
        "&updateMask.fieldPaths=hasDocumentedHistory"
        "&updateMask.fieldPaths=serviceCount"
        "&updateMask.fieldPaths=historySpanMonths")
request("PATCH", "/cars/" + CAR_ID, {
    "fields": {
        "vehicleId": s(VEHICLE_ID),
        "hasDocumentedHistory": b(True),
        "serviceCount": i(len(SERVICES)),
        "historySpanMonths": i(SPAN_MONTHS),
    }
}, params=mask)

print("done")
