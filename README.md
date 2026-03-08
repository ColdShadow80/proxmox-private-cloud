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
│   └── 09-summary.sh
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
