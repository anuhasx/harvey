#!/usr/bin/env bash
# Runs ON the VPS as the harvey user, called by .github/workflows/deploy.yml
# after the code has been rsynced into place. Idempotent.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

PY=$(cat /etc/harvey-python 2>/dev/null || echo python3)
[ -x .venv/bin/python ] || "$PY" -m venv .venv
.venv/bin/pip install -q --upgrade pip
.venv/bin/pip install -q -e .
.venv/bin/python -m playwright install chromium
mkdir -p data

if [ ! -f .env ] || [ ! -f harvey.local.yaml ]; then
    echo "::warning::.env or harvey.local.yaml missing on the VPS — Harvey will run unconfigured until you add them."
fi

sudo /usr/bin/systemctl restart harvey
sleep 5
if sudo /usr/bin/systemctl is-active harvey; then
    echo "Harvey restarted on $(cat .deployed-sha 2>/dev/null || echo unknown)"
else
    sudo /usr/bin/systemctl status harvey --no-pager -n 40 || true
    exit 1
fi
