CTID=$(cat /tmp/homelab_ctid)

pct exec $CTID -- bash -c "
docker run -d \
  --name homelab-dashboard \
  -p 9000:80 \
  -v /opt/gitops/dashboard:/usr/share/nginx/html \
  nginx:latest
"
