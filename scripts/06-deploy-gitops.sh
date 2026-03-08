CTID=$(cat /tmp/homelab_ctid)

pct exec $CTID -- bash -c "
mkdir -p /opt/gitops
cd /opt/gitops
git clone https://github.com/YOURUSER/proxmox-private-cloud.git
cd proxmox-private-cloud/stacks
docker compose -f homelab-stack.yml up -d
"
