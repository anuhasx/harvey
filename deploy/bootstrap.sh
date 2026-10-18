#!/usr/bin/env bash
# One-time VPS setup for Harvey. Run as root on a fresh Ubuntu/Debian box:
#
#   sudo bash bootstrap.sh "<public key of the CI deploy key>"
#
# Creates the `harvey` user, installs Python 3.11+ and Chromium's system
# libraries, installs the systemd unit, and lets the harvey user restart
# only that one service (that's all the CI deploy needs sudo for).
set -euo pipefail

DEPLOY_PUBKEY="${1:?usage: bootstrap.sh \"ssh-ed25519 AAAA... github-deploy\"}"
APP_USER=harvey
APP_DIR=/www/wwwroot/harvey

apt-get update
apt-get install -y --no-install-recommends \
    python3 python3-venv python3-pip rsync git curl ca-certificates sudo

# Harvey needs Python >= 3.11 (Ubuntu 22.04 ships 3.10).
PY=python3
if ! python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 11) else 1)'; then
    apt-get install -y software-properties-common
    add-apt-repository -y ppa:deadsnakes/ppa
    apt-get update
    apt-get install -y python3.12 python3.12-venv
    PY=python3.12
fi
echo "$PY" > /etc/harvey-python

id -u "$APP_USER" >/dev/null 2>&1 || useradd --create-home --shell /bin/bash "$APP_USER"
install -d -o "$APP_USER" -g "$APP_USER" "$APP_DIR" "$APP_DIR/data"

# CI deploy key
install -d -m 700 -o "$APP_USER" -g "$APP_USER" /home/$APP_USER/.ssh
touch /home/$APP_USER/.ssh/authorized_keys
grep -qxF "$DEPLOY_PUBKEY" /home/$APP_USER/.ssh/authorized_keys \
    || echo "$DEPLOY_PUBKEY" >> /home/$APP_USER/.ssh/authorized_keys
chown "$APP_USER:$APP_USER" /home/$APP_USER/.ssh/authorized_keys
chmod 600 /home/$APP_USER/.ssh/authorized_keys

# Chromium system libraries for Playwright (needs root, so done here once).
TMPVENV=$(mktemp -d)
"$PY" -m venv "$TMPVENV"
"$TMPVENV/bin/pip" install -q 'playwright>=1.40,<2'
"$TMPVENV/bin/playwright" install-deps chromium
rm -rf "$TMPVENV"

# Claude Code CLI for the harvey user (log in afterwards: see deploy/README.md).
sudo -u "$APP_USER" -H bash -c 'curl -fsSL https://claude.ai/install.sh | sh' || true

# Service + narrow sudo rule for the deploy.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# One unit per market instance; each has its own folder, config and database.
SERVICES="harvey harvey-italy"
RULES=""
for svc in $SERVICES; do
    install -m 644 "$SCRIPT_DIR/$svc.service" /etc/systemd/system/$svc.service
    install -d -o "$APP_USER" -g "$APP_USER" "$(dirname "$APP_DIR")/$svc" "$(dirname "$APP_DIR")/$svc/data"
    # Listed one by one: a wildcard would also match "harvey sshd".
    RULES="$RULES${RULES:+, }/usr/bin/systemctl restart $svc, /usr/bin/systemctl is-active $svc, /usr/bin/systemctl status $svc *"
done
cat > /etc/sudoers.d/harvey-deploy <<SUDO
$APP_USER ALL=(root) NOPASSWD: $RULES
SUDO
chmod 440 /etc/sudoers.d/harvey-deploy
visudo -cf /etc/sudoers.d/harvey-deploy
systemctl daemon-reload
systemctl enable $SERVICES

echo
echo "Bootstrap done. Next: push to main (or run the Deploy workflow), then"
echo "log in to Claude and add .env / harvey.local.yaml — see deploy/README.md."
