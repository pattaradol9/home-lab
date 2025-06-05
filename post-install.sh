#!/bin/bash
set -euo pipefail

echo "=== Disable Swap ==="
if swapon --summary | grep -q '^'; then
  swapoff -a
  sed -i.bak '/ swap / s/^/#/' /etc/fstab
  echo "✅ Swap disabled and /etc/fstab updated."
else
  echo "ℹ️ Swap already disabled."
fi

echo "=== Update & Install Base Packages ==="
apt update
apt upgrade -y
apt install -y \
  build-essential \
  curl \
  wget \
  git \
  unzip \
  zip \
  jq \
  nano \
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
  mkdir -p /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
    | tee /etc/apt/sources.list.d/docker.list > /dev/null
  apt update
  apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
else
  echo "ℹ️ Docker already installed."
fi

usermod -aG docker $USER || true

echo "=== Install Go (latest: 1.24.3) ==="
GO_VERSION="1.24.3"
if ! go version 2>/dev/null | grep -q "go$GO_VERSION"; then
  curl -LO "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz"
  rm -rf /usr/local/go
  tar -C /usr/local -xzf "go${GO_VERSION}.linux-amd64.tar.gz"
  echo 'export PATH=$PATH:/usr/local/go/bin' > /etc/profile.d/go.sh
  chmod +x /etc/profile.d/go.sh
  rm "go${GO_VERSION}.linux-amd64.tar.gz"
else
  echo "ℹ️ Go $GO_VERSION already installed."
fi

echo "=== Install Node.js (LTS: 22.16.0) ==="
NODE_VERSION="22.16.0"
if ! command -v node >/dev/null || ! node -v | grep -q "v${NODE_VERSION}"; then
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
  apt install -y nodejs
else
  echo "ℹ️ Node.js v${NODE_VERSION} already installed."
fi

echo "=== Enable SSH & Docker ==="
systemctl enable ssh
systemctl enable docker
systemctl start ssh
systemctl start docker

echo "🎉 All done! You may reboot now to apply everything."
