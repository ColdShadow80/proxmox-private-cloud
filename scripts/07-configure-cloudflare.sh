CTID=$(cat /tmp/homelab_ctid)

pct exec $CTID -- bash -c "
docker run -d \
 --name cloudflared \
 --restart unless-stopped \
 cloudflare/cloudflared:latest tunnel --no-autoupdate run
"
