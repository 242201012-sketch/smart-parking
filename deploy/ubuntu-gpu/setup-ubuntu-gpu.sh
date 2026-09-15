#!/usr/bin/env bash
# SmartParking — GPU'lu Ubuntu üretim sunucusu kurulumu
#
# Kullanım (sudo):
#   sudo ./setup-ubuntu-gpu.sh
#
# Bu betik aşağıdakileri kurar ve yapılandırır:
#   - Ubuntu güncellemeleri ve temel paketler (curl, git, make, build-essential)
#   - NVIDIA sürücü deposu + driver kurulumu
#   - Docker Engine (stable) + Compose plugin
#   - nvidia-container-toolkit ve varsayılan GPU runtime
#   - docker compose gpu yığınını başlatma (opsiyonel)

set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Bu betik sudo ile çalıştırılmalıdır." >&2
  exit 1
fi

echo "[1/6] Sistem güncelleniyor..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y
apt-get install -y --no-install-recommends \
  curl ca-certificates gnupg lsb-release git make build-essential

echo "[2/6] NVIDIA sürücüsü kuruluyor..."
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
  | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
# NVIDIA driver deposu
apt-get install -y --no-install-recommends ubuntu-drivers-common
ubuntu-drivers install

echo "[3/6] Docker Engine kuruluyor..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
codename="$(lsb_release -cs)"
cat > /etc/apt/sources.list.d/docker.list <<EOF
deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu ${codename} stable
EOF
apt-get update -y
apt-get install -y --no-install-recommends docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker

echo "[4/6] nvidia-container-toolkit kuruluyor..."
cat > /etc/apt/sources.list.d/nvidia-container-toolkit.list <<EOF
deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://nvidia.github.io/libnvidia-container/stable/deb/\$(ARCH) /
EOF
apt-get update -y
apt-get install -y --no-install-recommends nvidia-container-toolkit
nvidia-ctk runtime configure --runtime=docker
systemctl restart docker

echo "[5/6] GPU doğrulanıyor..."
docker run --rm --gpus all nvidia/cuda:12.6.3-base-ubuntu24.04 nvidia-smi -L || \
  echo "UYARI: GPU testi başarısız — NVIDIA sürücüsü yüklendikten sonra yeniden başlatma gerekebilir."

echo "[6/6] Tamamlandı."
echo "Yeniden başlatma önerilir: sudo reboot"
echo "Ardından çalıştırın: sudo docker compose -f deploy/ubuntu-gpu/docker-compose.gpu.yml up -d --build"