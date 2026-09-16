# -*- coding: utf-8 -*-
import sqlite3, json, uuid, datetime, socket, urllib.request, urllib.error

BASE = "http://127.0.0.1:58278"
DB_FILE = r"C:\dev\smartparking\SmartParking.API\smartparking-development.db"
SENSOR_KEY = "SmartParking_Development_Sensor_Key_Change_Me"
CAMERA_KEY = "SmartParking_Development_Camera_Key_Change_Me"

db = sqlite3.connect(DB_FILE)
db.row_factory = sqlite3.Row
cur = db.cursor()

def hdr_dev():
    d = cur.execute("SELECT * FROM SensorDevices WHERE IsDeleted=0 ORDER BY CreatedAt DESC LIMIT 1").fetchone()
    return d

def first_space(lot_id):
    return cur.execute(
        "SELECT * FROM ParkingSpaces WHERE ParkingLotId=? AND IsDeleted=0 ORDER BY Code LIMIT 1", (lot_id,)
    ).fetchone()

def first_camera():
    return cur.execute("SELECT * FROM Cameras WHERE IsDeleted=0 ORDER BY CreatedAt DESC LIMIT 1").fetchone()

def first_lot():
    return cur.execute("SELECT * FROM ParkingLots WHERE IsActive=1 ORDER BY CreatedAt LIMIT 1").fetchone()

def post(path, payload, extra_hdr):
    body = json.dumps(payload).encode("utf-8")
    hdr = {"Content-Type": "application/json", "Accept": "application/json"}
    hdr.update(extra_hdr)
    req = urllib.request.Request(BASE + path, data=body, headers=hdr, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=15) as r:
            return r.status, r.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode("utf-8", "replace")
    except Exception as e:
        return -1, str(e)

def mongo_counts():
    try:
        import pymongo
        c = pymongo.MongoClient("mongodb://127.0.0.1:27017", serverSelectionTimeoutMS=2000)
        d = c["smartparking-telemetry"]
        return d["SensorReadings"].count_documents({}), d["AnprEvents"].count_documents({})
    except Exception as e:
        return ("MONGO-ERR:" + str(e), )

dev = hdr_dev()
lot = first_lot()
space = None
cam = first_camera()

print("=== SQLite bulgu ===")
print("SENSOR DEVICE:", None if dev is None else dict(dev))
print()
if dev is None:
    print("HATA: SensorDevices tablosu bos"); raise SystemExit(1)
lot_id = dev["ParkingLotId"]
space = first_space(lot_id)
print("LOT (dev in lot):", lot_id)
print("SPACE (ilk):", None if space is None else dict(space))
print()
cam_lot_id = None
for cand in [lot["Id"] if lot else None, lot_id]:
    if cand:
        c2 = cur.execute("SELECT * FROM Cameras WHERE ParkingLotId=? AND IsDeleted=0 ORDER BY CreatedAt DESC LIMIT 1", (cand,)).fetchone()
        if c2 is not None:
            cam = c2; cam_lot_id = cand; break
print("CAMERA:", None if cam is None else dict(cam))

# --- hedef degerler ---
device_id = dev["DeviceId"]
seq = 785673
space_code = space["Code"]
space_id = space["Id"]
evt_id = "E2E-ANPR-FINAL-" + str(uuid.uuid4().hex[:10])
lot_guid = cam_lot_id if cam_lot_id else lot_id
cam_id = cam["DeviceId"] if cam else "E2E-CAM-001"
now = datetime.datetime.now(datetime.timezone.utc)

print()
print("=== 1) SENSOR READING (seq=%s, spaceCode=%s) ===" % (seq, space_code))
st, body = post("/api/sensors/readings", {
    "spaceCode": space_code,
    "sequence": seq,
    "isOccupied": True,
    "observedAt": now.isoformat(),
    "batteryPercent": 83,
    "vehiclePlate": "34E2EFINAL",
    "metadata": {"e2e": "final"},
}, {"X-Device-Id": device_id, "X-Sensor-Key": SENSOR_KEY})
print("Status:", st)
print("Body:", body[:400])
print()

print("=== 2) ANPR WEBHOOK (eventId=%s) ===" % evt_id)
st2, body2 = post("/api/cameras/anpr-events", {
    "eventId": evt_id,
    "parkingLotId": lot_guid,
    "cameraId": cam_id,
    "plateNumber": "34E2EFINAL",
    "direction": "entry",
    "confidence": 0.965,
    "observedAt": now.isoformat(),
}, {"X-Camera-Key": CAMERA_KEY})
print("Status:", st2)
print("Body:", body2[:400])
print()

print("=== 3) 12 sn bekle -> Mongo telemetry artisi ===")
import time
time.sleep(12)
m = mongo_counts()
print("Mongo:", m)
