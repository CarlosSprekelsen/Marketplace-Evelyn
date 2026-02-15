#!/usr/bin/env bash
set -euo pipefail

# ─── VPS Initial Setup Script ───
# Run as root on a fresh Ubuntu 22.04 VPS
# Usage: sudo bash setup-vps.sh

DEPLOY_USER="marketplace"

echo "=== Creating deploy user ==="
if ! id "$DEPLOY_USER" &>/dev/null; then
  adduser --disabled-password --gecos "" "$DEPLOY_USER"
  usermod -aG sudo "$DEPLOY_USER"
  echo "$DEPLOY_USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$DEPLOY_USER
  echo "User $DEPLOY_USER created."
else
  echo "User $DEPLOY_USER already exists."
fi

echo "=== Installing Docker ==="
if ! command -v docker &>/dev/null; then
  apt-get update
  apt-get install -y ca-certificates curl gnupg
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" > /etc/apt/sources.list.d/docker.list
  apt-get update
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  usermod -aG docker "$DEPLOY_USER"
  echo "Docker installed."
else
  echo "Docker already installed."
fi

echo "=== Installing Nginx ==="
if ! command -v nginx &>/dev/null; then
  apt-get install -y nginx
  systemctl enable nginx
  echo "Nginx installed."
else
  echo "Nginx already installed."
fi

echo "=== Installing Certbot ==="
if ! command -v certbot &>/dev/null; then
  apt-get install -y certbot python3-certbot-nginx
  echo "Certbot installed."
else
  echo "Certbot already installed."
fi

echo "=== Configuring UFW Firewall ==="
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable
echo "UFW configured (22, 80, 443)."

echo "=== Installing and configuring fail2ban ==="
if ! command -v fail2ban-client &>/dev/null; then
  apt-get install -y fail2ban
fi

cat > /etc/fail2ban/jail.local <<'JAIL'
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 5
bantime = 3600
findtime = 600
JAIL

systemctl enable fail2ban
systemctl restart fail2ban
echo "fail2ban configured."

echo "=== SSH Hardening ==="
SSHD_CONFIG="/etc/ssh/sshd_config"
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' "$SSHD_CONFIG"
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' "$SSHD_CONFIG"
sed -i 's/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' "$SSHD_CONFIG"
systemctl reload sshd
echo "SSH hardened (password auth disabled, root login disabled)."

echo ""
echo "=== Setup Complete ==="
echo "1. Copy your SSH key: ssh-copy-id $DEPLOY_USER@<server-ip>"
echo "2. Log in as $DEPLOY_USER and clone the repo"
echo "3. Copy .env.production.example to .env.production and fill in secrets"
echo "4. Run deploy.sh"
