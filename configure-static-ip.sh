#!/bin/bash
set -euo pipefail

echo "=== Configure Static IP Address ==="

# ตรวจหา interface หลักจาก default route
INTERFACE=$(ip route | awk '/default/ { print $5; exit }')
echo "🖧 Detected interface: $INTERFACE"

# รับค่า IP address
while [[ -z "${STATIC_IP:-}" ]]; do
  read -rp "📥 Enter static IP address (e.g., 192.168.0.103 or 192.168.0.103/24): " STATIC_IP
done

# ถ้าไม่ได้ใส่ /mask → เติม /24 ให้
if [[ "$STATIC_IP" != */* ]]; then
  STATIC_IP="$STATIC_IP/24"
fi

# รับค่า gateway
while [[ -z "${GATEWAY:-}" ]]; do
  read -rp "📥 Enter gateway (e.g., 192.168.0.1): " GATEWAY
done

# รับค่า nameservers
while [[ -z "${NAMESERVERS:-}" ]]; do
  read -rp "📥 Enter nameservers (comma-separated, e.g., 1.1.1.1,8.8.8.8): " NAMESERVERS
done

NETPLAN_CONFIG="/etc/netplan/01-netcfg.yaml"

# เตือนถ้าไฟล์มีอยู่แล้ว
if [ -f "$NETPLAN_CONFIG" ]; then
  echo "⚠️ Netplan config already exists at $NETPLAN_CONFIG"
  read -rp "❓ Overwrite existing config? (y/N): " OVERWRITE
  if [[ ! "$OVERWRITE" =~ ^[Yy]$ ]]; then
    echo "❌ Canceled by user."
    exit 0
  fi
fi

# เขียนไฟล์ Netplan
cat <<EOF | sudo tee "$NETPLAN_CONFIG" > /dev/null
network:
  version: 2
  renderer: networkd
  ethernets:
    $INTERFACE:
      addresses:
        - $STATIC_IP
      nameservers:
        addresses: [${NAMESERVERS//,/ }]
      routes:
        - to: default
          via: $GATEWAY
EOF

# ปรับ permission ให้ netplan ไม่เตือน
sudo chmod 600 "$NETPLAN_CONFIG"

echo "✅ Netplan config written to $NETPLAN_CONFIG"
echo "🌀 Applying netplan..."
sudo netplan apply

echo "🎉 Static IP configured successfully!"
