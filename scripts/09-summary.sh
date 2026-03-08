#!/usr/bin/env bash
set -e

IP=""

# Try to detect container IP from Proxmox host context
if command -v pct >/dev/null 2>&1 && [ -n "${CTID:-}" ]; then
	IP=$(pct exec "$CTID" -- hostname -I 2>/dev/null | awk '{print $1}')
elif command -v hostname >/dev/null 2>&1; then
	# Fallback when running inside container
	IP=$(hostname -I 2>/dev/null | awk '{print $1}')
fi

if [ -z "$IP" ]; then
	IP="<container-ip>"
fi

echo ""
echo "Deployment Finished"
echo ""
echo "Container CTID: ${CTID:-unknown}"
echo "Container IP:   $IP"
echo ""
echo "Dockhand:          http://$IP:3000"
echo "Traefik Dashboard: http://$IP:8080"
echo "Uptime Kuma:       http://$IP:3001"
echo "Gitea:             http://$IP:3002"
echo "Grafana:           http://$IP:3003"
echo "Prometheus:        http://$IP:9090"
echo ""
echo "If these URLs are unreachable from your laptop:"
echo "- Ensure laptop is on the same LAN/VLAN as the container IP"
echo "- Confirm container network mode/IP (DHCP vs static)"
echo "- Check Proxmox/LXC firewall rules"
