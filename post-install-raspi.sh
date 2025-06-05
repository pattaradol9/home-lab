#!/bin/bash
set -euo pipefail

echo "=== Disable Swap ==="
if swapon --summary | grep -q '^'; then
  sudo swapoff -a
  sudo sed -i.bak '/ swap / s/^/#/' /etc/fstab
  echo "✅ Swap disabled and /etc/fstab updated."
else
  echo "ℹ️ Swap already disabled."
fi

echo "=== Update & Install Base Packages ==="
sudo apt update
sudo apt upgrade -y
sudo apt install -y \
  build-essential \
  curl \
  wget \
  git \
  unzip \
  zip \
  jq \
  software-properties-common \
  ca-certificates \
  gnupg \
  lsb-release \
  apt-transport-https \
  net-tools \
  iproute2 \
  dnsutils \
  tmux \
  htop \
  bash-completion \
  openssh-server \
  sudo \
  vim \
  lsof \
  tree \
  make \
  iptables \
  iputils-ping

echo "=== Install Docker ==="
if ! command -v docker >/dev/null; then
  echo "Installing Docker..."
  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt update
  sudo apt install -y docker-ce docker-ce-cli containerd.io
else
  echo "ℹ️ Docker already installed."
fi

sudo usermod -aG docker $USER || true

echo "=== Install Go (1.24.3 for ARM64) ==="
GO_VERSION="1.24.3"
GO_TAR="go${GO_VERSION}.linux-arm64.tar.gz"
if ! go version 2>/dev/null | grep -q "go$GO_VERSION"; then
  curl -LO "https://go.dev/dl/${GO_TAR}"
  sudo rm -rf /usr/local/go
  sudo tar -C /usr/local -xzf "${GO_TAR}"
  echo 'export PATH=$PATH:/usr/local/go/bin' > ~/.profile.d/go.sh
  chmod +x ~/.profile.d/go.sh
  rm "${GO_TAR}"
else
  echo "ℹ️ Go $GO_VERSION already installed."
fi

echo "=== Install Node.js (22.16.0 for ARM64) ==="
NODE_VERSION="22.16.0"
if ! command -v node >/dev/null || ! node -v | grep -q "v${NODE_VERSION}"; then
  curl -fsSL https://deb.nodesource.com/setup_22.x | sudo bash -
  sudo apt install -y nodejs
else
  echo "ℹ️ Node.js v${NODE_VERSION} already installed."
fi

echo "=== Enable SSH & Docker ==="
sudo systemctl enable ssh
sudo systemctl enable docker
sudo systemctl start ssh
sudo systemctl start docker

echo "=== Configure Static IP using dhcpcd ==="
INTERFACE=$(ip route | awk '/default/ { print $5; exit }')
echo "🖧 Detected interface: $INTERFACE"

while [[ -z "${STATIC_IP:-}" ]]; do
  read -rp "📥 Enter static IP address (e.g., 192.168.0.103): " STATIC_IP
done

while [[ -z "${GATEWAY:-}" ]]; do
  read -rp "📥 Enter gateway (e.g., 192.168.0.1): " GATEWAY
done

while [[ -z "${NAMESERVERS:-}" ]]; do
  read -rp "📥 Enter nameservers (comma-separated, e.g., 1.1.1.1,8.8.8.8): " NAMESERVERS
done

# แก้ไข /etc/dhcpcd.conf
sudo sed -i "/^interface $INTERFACE/,/^$/d" /etc/dhcpcd.conf
cat <<EOF | sudo tee -a /etc/dhcpcd.conf > /dev/null

interface $INTERFACE
static ip_address=$STATIC_IP/24
static routers=$GATEWAY
static domain_name_servers=${NAMESERVERS//,/ }
EOF

echo "✅ Static IP applied to /etc/dhcpcd.conf"
echo "🔁 Restarting dhcpcd..."
sudo systemctl restart dhcpcd

echo "🎉 Raspberry Pi post-install complete. Please reboot to apply all changes."
