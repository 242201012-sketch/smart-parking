const args = Object.fromEntries(
  process.argv.slice(2).map((item) => {
    const [key, ...value] = item.replace(/^--/, "").split("=");
    return [key, value.join("=")];
  }),
);

const api = (args.api || process.env.SMARTPARKING_API_URL || "").replace(/\/$/, "");
const deviceId = args.device || process.env.SMARTPARKING_DEVICE_ID;
const sensorKey = args.key || process.env.SMARTPARKING_SENSOR_KEY;
const parkingLotCode = args.lot || "AMASYA-MERKEZ";
const spaceCode = args.space || "P08";
const occupied = (args.occupied || "true").toLowerCase() === "true";
const sequence = Number(args.sequence || Date.now());

if (!api || !deviceId || !sensorKey) {
  console.error(
    "Kullanım: node simulator.mjs --api=https://... --device=AMASYA-GATEWAY-01 --key=... --lot=AMASYA-MERKEZ --space=P08 --occupied=true",
  );
  process.exit(1);
}

const response = await fetch(`${api}/api/sensors/readings`, {
  method: "POST",
  headers: {
    "Content-Type": "application/json",
    "X-Device-Id": deviceId,
    "X-Sensor-Key": sensorKey,
  },
  body: JSON.stringify({
    parkingLotCode,
    spaceCode,
    isOccupied: occupied,
    sequence,
    observedAt: new Date().toISOString(),
    batteryPercent: 92,
    firmwareVersion: "simulator-1.0.0",
    metadata: { source: "node-simulator" },
  }),
});

const body = await response.text();
console.log(`${response.status} ${response.statusText}`);
console.log(body);
if (!response.ok) process.exitCode = 1;
