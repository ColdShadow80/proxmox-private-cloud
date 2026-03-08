CTID=$(cat /tmp/homelab_ctid)

pct exec $CTID -- bash -c "
apt update
apt install -y curl git
curl -fsSL https://get.docker.com | sh
apt install -y docker-compose-plugin
systemctl enable docker
"
