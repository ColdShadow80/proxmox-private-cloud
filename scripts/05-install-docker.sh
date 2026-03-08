#!/usr/bin/env bash
set -e

# Ensure ZFS_POOL is defined
if [ -z "$ZFS_POOL" ]; then
    echo "ERROR: ZFS_POOL not defined. Run 02-create-zfs.sh first."
    exit 1
fi

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

# Ensure Docker uses the ZFS dataset for volumes
DOCKER_ROOT="$ZFS_POOL/docker"
mkdir -p "$DOCKER_ROOT"

# Configure Docker daemon.json
DOCKER_CONFIG="/etc/docker/daemon.json"
cat > "$DOCKER_CONFIG" <<EOF
{
  "data-root": "$DOCKER_ROOT",
  "storage-driver": "overlay2"
}
EOF

# Restart Docker to apply changes
systemctl enable docker
systemctl restart docker

echo "✅ Docker installed. Data-root set to $DOCKER_ROOT"
