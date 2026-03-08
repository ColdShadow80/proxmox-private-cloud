# Security Policy

## Reporting Security Issues

If you discover a security vulnerability, please email the repository owner directly rather than opening a public issue.

## Best Practices

### Never Commit Sensitive Data

This repository uses `.gitignore` to prevent accidental commits of sensitive files. However, you should always verify before pushing:

**Blocked by .gitignore:**
- Environment files: `*.env`, `.env.*`
- Credentials: `*-credentials.json`, `*-tunnel.json`
- Private keys: `*.key`, `*.pem`, `*.p12`
- Customized stack file: `stacks/homelab-stack.yml`
- SSL certificates (except examples)

### Password Management

**Default Passwords:**
- LXC container default password is `changeme` - **change immediately** after creation:
  ```bash
  pct exec <CTID> -- passwd
  ```

**Service Credentials:**
- Use strong, unique passwords for each service
- Store credentials in `.env` files (excluded from commits)
- Use secrets management tools like:
  - Docker Secrets
  - HashiCorp Vault
  - Bitwarden/1Password for team sharing

### Cloudflare Tunnel Security

**Tunnel credentials are sensitive!**
- `*-tunnel.json` files contain authentication tokens
- These files are gitignored automatically
- Store backups securely, not in version control
- Rotate credentials if accidentally exposed

### Docker Compose Security

When customizing `stacks/homelab-stack.yml`:
- **Never** hardcode passwords in the compose file
- Use environment variables:
  ```yaml
  environment:
    - MYSQL_ROOT_PASSWORD=${MYSQL_PASSWORD}
  ```
- Create a `.env` file (gitignored) for sensitive values:
  ```bash
  MYSQL_PASSWORD=your-secure-password
  ```

### Network Security

- Keep Proxmox host firewall enabled
- Use VLANs to isolate container networks
- Enable Cloudflare Tunnel for secure external access (no port forwarding)
- Use Traefik with SSL/TLS for internal services
- Configure Authentik SSO to centralize authentication

### Container Security

- Regularly update containers with Watchtower (included in stack)
- Run containers as non-root users when possible
- Limit container capabilities and resources
- Review logs regularly for suspicious activity

### SSH/Access Security

- Use SSH keys, not passwords, for Proxmox access
- Disable root SSH login on production systems
- Use 2FA for critical services (Authentik, Proxmox)
- Regularly audit user access and permissions

## What's Safe to Commit

✅ **Safe:**
- Template files (`.example` suffix)
- Scripts without hardcoded credentials
- Documentation
- Docker Compose files with environment variable placeholders

❌ **Never commit:**
- Actual passwords, API keys, tokens
- Private SSL certificates
- Cloudflare tunnel credentials
- Production `.env` files
- Database backups with user data
- Personal customization files

## Checking Before You Push

Always run before pushing:
```bash
git status
git diff
```

Look for:
- Files that should be ignored
- Hardcoded passwords or tokens
- API keys or credentials
- Personal information

## If You Accidentally Commit Secrets

1. **Immediately rotate/revoke the exposed credentials**
2. Remove from Git history:
   ```bash
   git filter-branch --force --index-filter \
     "git rm --cached --ignore-unmatch path/to/sensitive/file" \
     --prune-empty --tag-name-filter cat -- --all
   ```
3. Force push (⚠️ coordinate with team first):
   ```bash
   git push --force --all
   ```
4. Contact GitHub support to clear cached views

## Secure Deployment Checklist

- [ ] Changed default LXC password
- [ ] Created `.env` file for service passwords (not committed)
- [ ] Configured Cloudflare Tunnel credentials securely
- [ ] Enabled SSL/TLS for all public services
- [ ] Set up Authentik SSO
- [ ] Configured firewall rules
- [ ] Enabled automatic updates (Watchtower)
- [ ] Backed up important data to secure location
- [ ] Reviewed and customized `homelab-stack.yml` without committing
- [ ] Documented recovery procedures offline

## Additional Resources

- [OWASP Docker Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html)
- [Docker Security Best Practices](https://docs.docker.com/engine/security/)
- [Proxmox Security Guide](https://pve.proxmox.com/wiki/Security)
