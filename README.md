# Proxmox Private Cloud Homelab

Fully automated **GitOps-powered homelab** running on **Proxmox VE** with Docker, reverse proxy, SSO, monitoring, and self-healing containers.  
Supports **Cloudflare Tunnel** for secure external access.

This project allows deploying a **10+ service homelab** in ~4 minutes using optional GitOps automation.

---

## 🚀 Quick Start – Run First

From your **Proxmox host**, run the main bootstrap script:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/ColdShadow80/proxmox-private-cloud/main/bootstrap.sh)"
```

Optional: pin a branch/tag/commit for all fetched scripts:

```bash
REPO_REF=main bash -c "$(curl -fsSL https://raw.githubusercontent.com/ColdShadow80/proxmox-private-cloud/main/bootstrap.sh)"
```

**What the bootstrap does:**
- Creates an LXC container with Docker
- Clones this repo to `/opt/gitops` inside the container
- Deploys services from `stacks/homelab-stack.yml` (auto-copies from `.example` if needed)
- Prompts for optional network config, Cloudflare tunnel, and dashboard

Optional Cloudflare Tunnel setup (after the bootstrap):

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/ColdShadow80/proxmox-private-cloud/main/scripts/07a-cloudflared-setup.sh)"
```

When prompted, enter your domain/subdomain (e.g., homelab.example.com).
If left empty, a free .trycloudflare.com subdomain will be assigned.
After completion, the script prints service URLs:

```arduino
Dockhand: https://dockhand.<your-domain>
Traefik: https://traefik.<your-domain>
Dashboard: https://dashboard.<your-domain>
```

The chosen domain is stored in:

```bash
/opt/gitops/cloudflared-domain.txt
```

## 🎯 Install Only One Service (Existing Setup)

If you already have a container and Docker running, you do **not** need to rerun `bootstrap.sh`.

### Update scripts first (recommended)

If your container was created earlier, it may not have the newest scripts yet.

```bash
cd /opt/gitops
git pull origin main
```

If `git pull` is blocked by local changes, fetch only one script:

```bash
cd /opt/gitops
git fetch origin main
git checkout origin/main -- scripts/11-install-homarr.sh
```

### Option A: Deploy one service from the GitOps stack

Inside your homelab container:

```bash
cd /opt/gitops/stacks
docker compose -f homelab-stack.yml up -d <service-name>
```

To see all valid `<service-name>` values:

```bash
docker compose -f /opt/gitops/stacks/homelab-stack.yml config --services
```

Examples:

```bash
docker compose -f /opt/gitops/stacks/homelab-stack.yml up -d grafana
docker compose -f /opt/gitops/stacks/homelab-stack.yml up -d nextcloud
docker compose -f /opt/gitops/stacks/homelab-stack.yml up -d prometheus
```

### Option B: Run one optional installer script only

Inside your homelab container:

```bash
cd /opt/gitops
bash scripts/10-install-uptime-kuma.sh
bash scripts/11-install-homarr.sh
bash scripts/12-install-immich.sh
```

Run only the one you want. These scripts are safe to re-run and will reuse existing app directories.

From the Proxmox host (without entering the container shell), run one script with:

```bash
pct exec <CTID> -- bash /opt/gitops/scripts/11-install-homarr.sh
```

Replace `11-install-homarr.sh` with `10-install-uptime-kuma.sh` or `12-install-immich.sh` as needed.

### Quick reference (pick one)

| Service | Install method | Name to use | Default URL |
| ------- | -------------- | ----------- | ----------- |
| Dockhand | Option A (stack) | `dockhand` | `http://<container-ip>:3000` |
| Traefik Dashboard | Option A (stack) | `traefik` | `http://<container-ip>:8080` |
| Authentik | Option A (stack) | `authentik` | `http://<container-ip>:8000` |
| Nextcloud | Option A (stack) | `nextcloud` | `http://<container-ip>:8081` |
| Immich (stack variant) | Option A (stack) | `immich` | `http://<container-ip>:8082` |
| Uptime Kuma (stack variant) | Option A (stack) | `uptime-kuma` | `http://<container-ip>:3001` |
| Gitea | Option A (stack) | `gitea` | `http://<container-ip>:3002` |
| Grafana | Option A (stack) | `grafana` | `http://<container-ip>:3003` |
| Prometheus | Option A (stack) | `prometheus` | `http://<container-ip>:9090` |
| Homarr | Option B (script) | `scripts/11-install-homarr.sh` | `http://<container-ip>:7575` |
| Uptime Kuma (dedicated installer) | Option B (script) | `scripts/10-install-uptime-kuma.sh` | `http://<container-ip>:3001` |
| Immich (dedicated installer) | Option B (script) | `scripts/12-install-immich.sh` | `http://<container-ip>:2283` |

## 🧱 Architecture

```css
Internet
   │
   ▼
Cloudflare
   │
   ▼
Cloudflare Tunnel (Cloudflared container)
   │
   ▼
Traefik Reverse Proxy
   │
   ▼
Authentik SSO
   │
   ├── Dockhand
   ├── Nextcloud
   ├── Immich
   ├── Grafana
   ├── Prometheus
   ├── Uptime Kuma
   ├── Gitea
   ├── Redis
   └── Dashboard
```

Infrastructure layer:

```css
Proxmox VE
   │
   └── LXC Container
        │
        └── Docker + GitOps Stack

```

## 🧰 Services Deployed
| Service           | Purpose                     |
| ----------------- | --------------------------- |
| Dockhand          | Docker management UI        |
| Traefik           | Reverse proxy               |
| Authentik         | Single Sign-On              |
| Cloudflare Tunnel | Secure remote access        |
| Watchtower        | Automatic container updates |
| Uptime Kuma       | Uptime monitoring           |
| Nextcloud         | Self-hosted cloud           |
| Immich            | Photo management            |
| Grafana           | Metrics dashboard           |
| Prometheus        | Metrics collection          |
| Gitea             | Git server                  |
| Redis             | Cache / backend             |
| Dashboard         | Homelab overview dashboard  |

## 📂 Repository Structure

```php
proxmox-private-cloud/
│
├── bootstrap.sh               # Main orchestrator
├── README.md                  # Documentation
├── scripts/                   # Automation scripts
│   ├── 01-detect-ctid.sh
│   ├── 02-create-zfs.sh
│   ├── 03-create-lxc.sh
│   ├── 04-configure-network.sh
│   ├── 05-install-docker.sh
│   ├── 06-deploy-gitops.sh
│   ├── 07-configure-cloudflare.sh
│   ├── 07a-cloudflared-setup.sh  # Optional user domain tunnel setup
│   ├── 08-deploy-dashboard.sh
│   ├── 09-summary.sh
│   ├── 10-install-uptime-kuma.sh
│   ├── 11-install-homarr.sh
│   └── 12-install-immich.sh
└── stacks/
    ├── homelab-stack.yml          # Your customized service stack
    └── homelab-stack.yml.example  # Template with example services
```

**Customizing Your Stack:**
Before first run, copy the example and customize your services:
```bash
cp stacks/homelab-stack.yml.example stacks/homelab-stack.yml
# Edit homelab-stack.yml to enable/disable services
```

The bootstrap script will use `homelab-stack.yml` if present, or automatically copy from `.example` if not.

## 🔐 Security Best Practices

**Important:** Never commit sensitive information to this repository.

- `stacks/homelab-stack.yml` is gitignored - customize it locally without committing passwords/tokens
- Use `.example` files for templates, never put real credentials in them
- Keep Cloudflare tunnel credentials (`*-tunnel.json`) local
- Store secrets in environment variables or separate `.env` files (also gitignored)
- The default LXC password `changeme` should be changed immediately after container creation

**Files automatically ignored by `.gitignore`:**
- `*.env`, `.env.*` - Environment variable files
- `*-credentials.json`, `*-tunnel.json` - Authentication files
- `stacks/homelab-stack.yml` - Your customized service stack
- SSL certificates and private keys

📖 **See [SECURITY.md](SECURITY.md) for comprehensive security guidelines.**

**Pre-commit security check:**
```bash
bash scripts/security-check.sh
```
This script scans staged files for potential sensitive data before committing.

## 🔧 How Each Script Works
### bootstrap.sh

Orchestrates the complete deployment in 9 steps:
1. ZFS pool selection and dataset creation
2. CTID detection (prompts for starting container ID)
3. LXC container creation (prompts for Debian version and template storage)
4. Network configuration (optional static IP)
5. Docker installation inside the container
6. GitOps stack deployment
7. Cloudflare Tunnel setup (optional)
8. Dashboard deployment
9. Deployment summary

Interactive prompts allow customization at each stage.

```bash
REPO_REF=main bash -c "$(curl -fsSL https://raw.githubusercontent.com/ColdShadow80/proxmox-private-cloud/main/bootstrap.sh)"
```

### 01-detect-ctid.sh

Detects the next free CTID in Proxmox and saves it to /tmp/homelab_ctid.

```bash
NEXTID=$(pvesh get /cluster/nextid)
echo $NEXTID > /tmp/homelab_ctid
```

### 02-create-zfs.sh

Creates a ZFS dataset for Docker volumes (rpool/docker).

```bash
POOL=rpool
DATASET=docker
zfs create $POOL/$DATASET
```

### 03-create-lxc.sh

Creates an LXC container with nested virtualization enabled and resources assigned.
Prompts for Debian major version (default: 12) and automatically selects the latest matching Proxmox template.
For template storage: aborts if none exist, auto-uses it if only one exists, or prompts selection when multiple are available (30-second timeout, then defaults to the storage with most free space).
Container rootfs is created on a Proxmox storage that supports rootdir content, using `storage:size` syntax (default size: 50G, override with `ROOTFS_SIZE_GB`).

```bash
pct create $CTID local:vztmpl/debian-12-standard_12.3-1_amd64.tar.gz \
 --hostname docker-host \
 --cores 4 --memory 8192 \
 --rootfs local-lvm:50 \
 --features nesting=1,keyctl=1 \
 --net0 name=eth0,bridge=vmbr0,ip=dhcp
pct start $CTID
```

### 04-configure-network.sh

Assigns static IP and gateway for the LXC.

```bash
pct set $CTID --net0 name=eth0,bridge=vmbr0,ip=192.168.1.50/24,gw=192.168.1.1
```

### 05-install-docker.sh

Installs Docker Engine and Docker Compose plugin inside the LXC container, enables Docker on boot.
Uses standard container paths (/var/lib/docker).

```bash
apt update
apt install -y curl git
curl -fsSL https://get.docker.com | sh
apt install -y docker-compose-plugin
systemctl enable docker
```

### 06-deploy-gitops.sh

Clones the repository into /opt/gitops (inside container) and deploys services from stacks/homelab-stack.yml using Docker Compose.
By default uses the proxmox-private-cloud repository. Override with `GITOPS_REPO` environment variable.

```bash
git clone https://github.com/ColdShadow80/proxmox-private-cloud.git /opt/gitops
cd /opt/gitops/stacks
docker compose -f homelab-stack.yml up -d
```

### 07-configure-cloudflare.sh

Runs Cloudflared container to maintain a secure outbound tunnel.
Does not assign hostnames — base for optional 07a.

```bash
docker run -d \
 --name cloudflared \
 --restart unless-stopped \
 cloudflare/cloudflared:latest tunnel --no-autoupdate run
```

### 07a-cloudflared-setup.sh (optional)

Continues from 07 without repeating work.

Prompts for user domain (or uses free .trycloudflare.com).

Generates config.yml mapping:

dockhand.<domain> → Dockhand

traefik.<domain> → Traefik

dashboard.<domain> → Dashboard

Saves domain in /opt/gitops/cloudflared-domain.txt.

Starts/restarts Cloudflared container.

```bash
# Example run
bash scripts/07a-cloudflared-setup.sh
```

### 08-deploy-dashboard.sh

Deploys a custom dashboard if `DASHBOARD_REPO` environment variable is set.
Otherwise skips dashboard deployment (optional step).

```bash
# Only runs if DASHBOARD_REPO is configured
docker run -d \
 --name homelab-dashboard \
 -p 9000:80 \
 -v /opt/dashboard:/usr/share/nginx/html \
 nginx:latest
```

### 09-summary.sh

Prints all accessible service URLs, using the saved domain if Cloudflare tunnel is configured.

```bash
cat /opt/gitops/cloudflared-domain.txt
echo "Dockhand: https://dockhand.<domain>"
echo "Traefik: https://traefik.<domain>"
echo "Dashboard: https://dashboard.<domain>"
```

### 11-install-homarr.sh

Installs Homarr with Docker socket integration and enables automatic app discovery.

- Deploys Homarr at `http://<container-ip>:7575`
- Creates `/opt/apps/homarr/homarr-autosync.sh`
- Schedules recurring scans in `/etc/cron.d/homarr-autosync` (every 15 minutes)
- Runs an initial sync after deployment

To enable automatic app creation in Homarr:

1. Open Homarr and generate an API key in **Admin → API keys**.
2. Set the key in `/opt/apps/homarr/.env`:

```bash
HOMARR_API_KEY=your_api_key_here
```

3. Re-run sync immediately (optional):

```bash
/opt/apps/homarr/homarr-autosync.sh
```

By default, the sync job adds running Docker containers with published ports as Homarr apps and skips containers already present.

🌐 Cloudflare Tunnel Explained

- Cloudflared container maintains a secure outbound tunnel to Cloudflare.

- Maps internal LXC services to public hostnames/subdomains.

- No router port forwarding required.

- TLS is automatically provided by Cloudflare.

- Users can choose:

  - Own domain (e.g., example.com)

  - Free .trycloudflare.com subdomain

### Example URLs after setup:

```bash
Dockhand: https://dockhand.homelab.example.com
Traefik: https://traefik.homelab.example.com
Dashboard: https://dashboard.homelab.example.com

```

## 🔁 GitOps / Updates

- Containers auto-update via Watchtower.

- Infrastructure updates via git pull and docker compose up -d.

- Optional services can be added via stacks/apps/ overrides.

## 💾 Backup Strategy

1. Proxmox scheduled backups

2. ZFS snapshots for Docker volumes

3. Optional offsite backups using Restic or similar

## 🔐 Security Recommendations

- Use Authentik SSO for all services.

- Enable TLS/HTTPS with Traefik.

- Restrict access to dashboards and Docker management.

- Configure firewall or VPN if exposing services publicly.

## 📜 License

MIT License

## 🤝 Contributing

- Pull requests welcome.

- Add new services, dashboards, or GitOps enhancements.
