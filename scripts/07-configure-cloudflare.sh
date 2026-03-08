#!/usr/bin/env bash
set -e

echo "------------------------------"
echo "Configuring Cloudflare Tunnel..."
echo "------------------------------"

run_cloudflared() {
	if ! command -v docker >/dev/null 2>&1; then
		echo "ERROR: Docker is not installed in this environment."
		exit 1
	fi

	if docker ps -a --format '{{.Names}}' | grep -qx 'cloudflared'; then
		echo "cloudflared container already exists. Restarting..."
		docker restart cloudflared >/dev/null
	else
		docker run -d \
			--name cloudflared \
			--restart unless-stopped \
			cloudflare/cloudflared:latest tunnel --no-autoupdate run >/dev/null
	fi

	echo "✅ Cloudflare Tunnel container is running."
}

# Host mode: execute inside CTID if pct + CTID file exist
if command -v pct >/dev/null 2>&1 && [ -f /tmp/homelab_ctid ]; then
	CTID=$(cat /tmp/homelab_ctid)
	echo "Running Cloudflare setup inside container $CTID..."
	pct exec "$CTID" -- bash -c 'docker ps -a --format "{{.Names}}" | grep -qx cloudflared && docker restart cloudflared >/dev/null || docker run -d --name cloudflared --restart unless-stopped cloudflare/cloudflared:latest tunnel --no-autoupdate run >/dev/null'
	echo "✅ Cloudflare Tunnel container is running in CTID $CTID."
else
	# Container mode: run directly
	run_cloudflared
fi
