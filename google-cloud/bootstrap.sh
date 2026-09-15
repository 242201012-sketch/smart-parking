#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="${1:-}"
REGION="${2:-europe-west3}"
REPOSITORY="smartparking"
SQL_INSTANCE="smartparking-db"
DB_NAME="smartparking"
DB_USER="smartparking_api"
RUNTIME_SA_NAME="smartparking-runtime"

if [[ -z "$PROJECT_ID" ]]; then
  echo "Kullanım: ./google-cloud/bootstrap.sh GOOGLE_CLOUD_PROJECT_ID [REGION]" >&2
  exit 2
fi

for command in gcloud openssl; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "$command bulunamadı." >&2
    exit 2
  fi
done

ACTIVE_ACCOUNT="$(gcloud auth list --filter=status:ACTIVE --format='value(account)' | head -n 1)"
if [[ -z "$ACTIVE_ACCOUNT" ]]; then
  echo "Önce gcloud auth login çalıştırın." >&2
  exit 2
fi

gcloud config set project "$PROJECT_ID"
gcloud services enable \
  artifactregistry.googleapis.com \
  cloudbuild.googleapis.com \
  cloudresourcemanager.googleapis.com \
  firebase.googleapis.com \
  fcm.googleapis.com \
  identitytoolkit.googleapis.com \
  maps-android-backend.googleapis.com \
  run.googleapis.com \
  secretmanager.googleapis.com \
  sqladmin.googleapis.com

if ! gcloud artifacts repositories describe "$REPOSITORY" --location="$REGION" >/dev/null 2>&1; then
  gcloud artifacts repositories create "$REPOSITORY" \
    --location="$REGION" \
    --repository-format=docker \
    --description="SmartParking API images"
fi

RUNTIME_SA="$RUNTIME_SA_NAME@$PROJECT_ID.iam.gserviceaccount.com"
if ! gcloud iam service-accounts describe "$RUNTIME_SA" >/dev/null 2>&1; then
  gcloud iam service-accounts create "$RUNTIME_SA_NAME" \
    --display-name="SmartParking Cloud Run runtime"
fi

for role in roles/cloudsql.client roles/secretmanager.secretAccessor roles/firebasecloudmessaging.admin; do
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:$RUNTIME_SA" \
    --role="$role" \
    --condition=None >/dev/null
done

if ! gcloud sql instances describe "$SQL_INSTANCE" >/dev/null 2>&1; then
  gcloud sql instances create "$SQL_INSTANCE" \
    --database-version=POSTGRES_16 \
    --region="$REGION" \
    --tier=db-f1-micro \
    --storage-size=10 \
    --storage-type=SSD \
    --storage-auto-increase
fi

if ! gcloud sql databases describe "$DB_NAME" --instance="$SQL_INSTANCE" >/dev/null 2>&1; then
  gcloud sql databases create "$DB_NAME" --instance="$SQL_INSTANCE"
fi

secret_exists() {
  gcloud secrets describe "$1" >/dev/null 2>&1
}

read_secret() {
  gcloud secrets versions access latest --secret="$1"
}

upsert_secret() {
  local name="$1"
  local value="$2"
  if secret_exists "$name"; then
    local current
    current="$(read_secret "$name")"
    if [[ "$current" != "$value" ]]; then
      printf '%s' "$value" | gcloud secrets versions add "$name" --data-file=- >/dev/null
    fi
  else
    printf '%s' "$value" | gcloud secrets create "$name" \
      --replication-policy=automatic \
      --data-file=- >/dev/null
  fi
}

CONNECTION_NAME="$(gcloud sql instances describe "$SQL_INSTANCE" --format='value(connectionName)')"
if gcloud sql users list --instance="$SQL_INSTANCE" --filter="name=$DB_USER" --format='value(name)' | grep -qx "$DB_USER" \
  && secret_exists smartparking-db-connection; then
  DB_CONNECTION="$(read_secret smartparking-db-connection)"
else
  DB_PASSWORD="$(openssl rand -base64 36 | tr -d '\n')"
  if gcloud sql users list --instance="$SQL_INSTANCE" --filter="name=$DB_USER" --format='value(name)' | grep -qx "$DB_USER"; then
    gcloud sql users set-password "$DB_USER" --instance="$SQL_INSTANCE" --password="$DB_PASSWORD"
  else
    gcloud sql users create "$DB_USER" --instance="$SQL_INSTANCE" --password="$DB_PASSWORD"
  fi
  DB_CONNECTION="Host=/cloudsql/$CONNECTION_NAME;Port=5432;Database=$DB_NAME;Username=$DB_USER;Password=$DB_PASSWORD;SSL Mode=Disable;Timeout=15;Keepalive=30;Pooling=true;Maximum Pool Size=20;Minimum Pool Size=0;Connection Idle Lifetime=300"
fi

if secret_exists smartparking-admin-email && secret_exists smartparking-admin-password; then
  ADMIN_EMAIL="$(read_secret smartparking-admin-email)"
  ADMIN_PASSWORD="$(read_secret smartparking-admin-password)"
else
  read -r -p "İlk yönetici e-posta adresi: " ADMIN_EMAIL
  read -r -s -p "İlk yönetici parolası (en az 12 karakter): " ADMIN_PASSWORD
  echo
fi
if [[ -z "$ADMIN_EMAIL" || ${#ADMIN_PASSWORD} -lt 12 ]]; then
  echo "Geçerli bir yönetici e-postası ve en az 12 karakterlik parola gereklidir." >&2
  exit 2
fi

if secret_exists smartparking-iyzico-api-key && secret_exists smartparking-iyzico-secret-key; then
  IYZICO_API_KEY="$(read_secret smartparking-iyzico-api-key)"
  IYZICO_SECRET_KEY="$(read_secret smartparking-iyzico-secret-key)"
else
  read -r -p "iyzico Sandbox API anahtarı: " IYZICO_API_KEY
  read -r -s -p "iyzico Sandbox gizli anahtarı: " IYZICO_SECRET_KEY
  echo
fi
if [[ -z "$IYZICO_API_KEY" || -z "$IYZICO_SECRET_KEY" ]]; then
  echo "iyzico Sandbox API ve gizli anahtarı zorunludur." >&2
  exit 2
fi

JWT_KEY="$(secret_exists smartparking-jwt-key && read_secret smartparking-jwt-key || openssl rand -base64 48 | tr -d '\n')"
SENSOR_KEY="$(secret_exists smartparking-sensor-key && read_secret smartparking-sensor-key || openssl rand -hex 32)"
CAMERA_KEY="$(secret_exists smartparking-camera-key && read_secret smartparking-camera-key || openssl rand -hex 32)"

upsert_secret smartparking-db-connection "$DB_CONNECTION"
upsert_secret smartparking-jwt-key "$JWT_KEY"
upsert_secret smartparking-sensor-key "$SENSOR_KEY"
upsert_secret smartparking-camera-key "$CAMERA_KEY"
upsert_secret smartparking-admin-email "$ADMIN_EMAIL"
upsert_secret smartparking-admin-password "$ADMIN_PASSWORD"
upsert_secret smartparking-iyzico-api-key "$IYZICO_API_KEY"
upsert_secret smartparking-iyzico-secret-key "$IYZICO_SECRET_KEY"

PROJECT_NUMBER="$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')"
BUILD_SA="$(gcloud builds get-default-service-account | tr -d '[:space:]')"
if [[ -z "$BUILD_SA" ]]; then
  echo "Cloud Build varsayılan servis hesabı belirlenemedi (proje: $PROJECT_NUMBER)." >&2
  exit 2
fi
for role in roles/cloudbuild.builds.builder roles/run.admin roles/artifactregistry.writer roles/logging.logWriter; do
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:$BUILD_SA" \
    --role="$role" \
    --condition=None >/dev/null
done
gcloud iam service-accounts add-iam-policy-binding "$RUNTIME_SA" \
  --member="serviceAccount:$BUILD_SA" \
  --role=roles/iam.serviceAccountUser \
  --condition=None >/dev/null

echo "Altyapı hazır. Firebase Console adımlarını tamamladıktan sonra:"
echo "gcloud builds submit --config=cloudbuild.yaml ."
