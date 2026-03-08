#!/usr/bin/env bash
set -e

echo "------------------------------"
echo "Installing Docker on LXC..."
echo "------------------------------"

# Install Docker prerequisites
apt-get update
apt-get install -y ca-certificates curl gnupg lsb-release

# Add Docker's official GPG key
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Set up the repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Configure Docker to use standard paths (container rootfs is already on ZFS)
DOCKER_ROOT="/var/lib/docker"
mkdir -p "$DOCKER_ROOT"

# Configure Docker daemon.json
DOCKER_CONFIG="/etc/docker/daemon.json"
cat > "$DOCKER_CONFIG" <<EOF
{
  "storage-driver": "overlay2"
}
EOF

# Restart Docker to apply changes
systemctl enable docker
systemctl restart docker

echo "✅ Docker installed and configured"
