Install setup

```bash

bash -c "$(curl -fsSL https://raw.githubusercontent.com/ColdShadow80/proxmox-private-cloud/main/bootstrap.sh)"

```


07-configure-cloudflare.sh

script will:

Ask the user for their domain (or use a free Cloudflare Tunnel domain if none is provided).
Create a Cloudflare tunnel (if not already created).
Generate a config.yml with mappings for Dockhand, Traefik, and the dashboard.
Run the tunnel container.
Save the chosen domain to /opt/gitops/cloudflared-domain.txt so the user can check it anytime.

```bash

bash -c "$(curl -fsSL https://raw.githubusercontent.com/ColdShadow80/proxmox-private-cloud/main/scripts/07a-cloudflared-setup.sh)"
```
