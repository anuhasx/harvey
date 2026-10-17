# Deploying Harvey to a VPS

Every push to `main` that passes the `tests` workflow is deployed to the VPS
(`161.97.118.140`) by `.github/workflows/deploy.yml`. You can also run it by
hand: Actions → deploy → Run workflow.

Server-only files are never overwritten by a deploy: `.env`,
`harvey.local.yaml`, `data/` (database, Gmail token) and the skills generated
by `harvey train`.

## One-time setup

**1. Make a deploy key** (on your PC):

    ssh-keygen -t ed25519 -f harvey_deploy -N "" -C github-deploy

**2. Bootstrap the VPS** (as root):

    scp deploy/bootstrap.sh deploy/harvey.service harvey_deploy.pub root@161.97.118.140:/root/
    ssh root@161.97.118.140 'bash /root/bootstrap.sh "$(cat /root/harvey_deploy.pub)"'

**3. Add GitHub secrets** (repo → Settings → Secrets and variables → Actions):

| Secret | Value |
|---|---|
| `VPS_SSH_KEY` | contents of `harvey_deploy` (the private key) |
| `VPS_KNOWN_HOSTS` | output of `ssh-keyscan 161.97.118.140` (recommended) |

Then delete `harvey_deploy` from your PC, or keep it somewhere safe.

**4. First deploy:** Actions → deploy → Run workflow.

**5. Configure Harvey on the server** (as root, then as harvey):

    scp .env harvey.local.yaml root@161.97.118.140:/www/wwwroot/harvey/
    ssh root@161.97.118.140 'chown harvey:harvey /www/wwwroot/harvey/{.env,harvey.local.yaml}'
    ssh root@161.97.118.140
    su - harvey
    claude login            # open the URL on your PC, paste the code back
    claude -p "say hi"
    exit
    systemctl restart harvey

Gmail: run `harvey gmail auth` on your PC, then copy `data/gmail_token.json`
to `/www/wwwroot/harvey/data/` (owned by harvey).

## Day to day

    journalctl -u harvey -f                         # live logs
    ssh -L 5555:localhost:5555 root@161.97.118.140  # then, on the server:
    su - harvey -c 'cd harvey && .venv/bin/harvey dashboard'

Open http://localhost:5555 on your PC. Don't open port 5555 in the firewall —
the dashboard has no login.
