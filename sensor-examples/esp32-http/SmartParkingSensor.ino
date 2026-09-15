#include <ArduinoJson.h>
#include <HTTPClient.h>
#include <Preferences.h>
#include <WiFi.h>
#include <WiFiClientSecure.h>

// Bu değerleri cihazın güvenli kurulum/NVS sürecinden okuyacak şekilde değiştirin.
const char* WIFI_SSID = "WIFI_ADI";
const char* WIFI_PASSWORD = "WIFI_PAROLASI";
const char* API_URL = "https://SIZIN-SERVISINIZ.onrender.com/api/sensors/readings";
const char* DEVICE_ID = "AMASYA-GATEWAY-01";
const char* SENSOR_KEY = "RENDER_SENSOR_INGEST_KEY";
const char* PARKING_LOT_CODE = "AMASYA-MERKEZ";
const char* SPACE_CODE = "P08";

// Render sertifikasının güven zincirindeki kök CA PEM metnini buraya ekleyin.
// Boş/yanlış CA ile TLS bağlantısı bilinçli olarak başarısız olur.
const char* ROOT_CA = R"EOF(
-----BEGIN CERTIFICATE-----
KOK_CA_PEM_BURAYA
-----END CERTIFICATE-----
)EOF";

constexpr int TRIGGER_PIN = 5;
constexpr int ECHO_PIN = 18;
constexpr float OCCUPIED_THRESHOLD_CM = 28.0;
constexpr unsigned long SAMPLE_INTERVAL_MS = 1500;
constexpr unsigned long HEARTBEAT_INTERVAL_MS = 60000;

Preferences preferences;
bool stableOccupied = false;
bool candidateOccupied = false;
int candidateCount = 0;
unsigned long lastSampleAt = 0;
unsigned long lastHeartbeatAt = 0;
uint64_t sequenceNumber = 0;

float readDistanceCm() {
  digitalWrite(TRIGGER_PIN, LOW);
  delayMicroseconds(2);
  digitalWrite(TRIGGER_PIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIGGER_PIN, LOW);
  const unsigned long duration = pulseIn(ECHO_PIN, HIGH, 30000);
  if (duration == 0) return -1;
  return duration * 0.0343f / 2.0f;
}

bool sendReading(bool occupied, float distanceCm) {
  if (WiFi.status() != WL_CONNECTED) return false;

  WiFiClientSecure client;
  client.setCACert(ROOT_CA);
  HTTPClient http;
  if (!http.begin(client, API_URL)) return false;
  http.addHeader("Content-Type", "application/json");
  http.addHeader("X-Device-Id", DEVICE_ID);
  http.addHeader("X-Sensor-Key", SENSOR_KEY);

  JsonDocument document;
  document["parkingLotCode"] = PARKING_LOT_CODE;
  document["spaceCode"] = SPACE_CODE;
  document["isOccupied"] = occupied;
  document["sequence"] = sequenceNumber;
  document["firmwareVersion"] = "esp32-ultrasonic-1.0.0";
  document["metadata"]["distanceCm"] = distanceCm;
  String body;
  serializeJson(document, body);

  const int status = http.POST(body);
  http.end();
  return status == 200 || status == 202;
}

void connectWifi() {
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  const unsigned long deadline = millis() + 20000;
  while (WiFi.status() != WL_CONNECTED && millis() < deadline) delay(250);
}

void setup() {
  Serial.begin(115200);
  pinMode(TRIGGER_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);
  preferences.begin("smartparking", false);
  sequenceNumber = preferences.getULong64("sequence", 0);
  connectWifi();
}

void loop() {
  if (WiFi.status() != WL_CONNECTED) connectWifi();
  const unsigned long now = millis();
  if (now - lastSampleAt < SAMPLE_INTERVAL_MS) return;
  lastSampleAt = now;

  const float distanceCm = readDistanceCm();
  if (distanceCm < 0) return;
  const bool measuredOccupied = distanceCm <= OCCUPIED_THRESHOLD_CM;
  if (measuredOccupied != candidateOccupied) {
    candidateOccupied = measuredOccupied;
    candidateCount = 1;
  } else {
    candidateCount++;
  }

  const bool heartbeatDue = now - lastHeartbeatAt >= HEARTBEAT_INTERVAL_MS;
  const bool stateChanged = candidateCount >= 3 && candidateOccupied != stableOccupied;
  if (!stateChanged && !heartbeatDue) return;

  sequenceNumber++;
  // Başarısız istekte aynı sequence korunur; sonraki loop idempotent retry yapar.
  if (sendReading(stateChanged ? candidateOccupied : stableOccupied, distanceCm)) {
    if (stateChanged) stableOccupied = candidateOccupied;
    preferences.putULong64("sequence", sequenceNumber);
    lastHeartbeatAt = now;
  } else {
    sequenceNumber--;
    delay(2000);
  }
}
