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

## Markets and dashboards

| Market | Folder | Agent service | Dashboard |
|---|---|---|---|
| Sri Lanka | `/www/wwwroot/harvey` | `harvey` | https://harvey.tryso.lk (port 5555) |
| Italy (lead list only, email off) | `/www/wwwroot/harvey-italy` | `harvey-italy` | https://harvey-italy.tryso.lk (port 5556) |

Each market has its own `.env`, `harvey.local.yaml`, `skills/product_knowledge.md`
and `data/`. A deploy updates the code in both and restarts the agent and its
dashboard.

The dashboards run as `harvey-dashboard` / `harvey-italy-dashboard`, bound to
127.0.0.1 only. nginx (`deploy/nginx/*.conf`, installed in
`/www/server/panel/vhost/nginx/`) publishes them over HTTPS behind a password,
because the dashboard has no login of its own and can edit `.env` and send email.

**Add or change a dashboard login** (as root; it prompts for the password, so
it never lands in your shell history):

    printf "admin:$(openssl passwd -apr1)
" >> /www/server/nginx/conf/harvey.htpasswd

The same login works for both dashboards. To remove a user, delete its line
from that file. No nginx reload needed.

## Day to day

    journalctl -u harvey -f           # Sri Lanka agent logs
    journalctl -u harvey-italy -f     # Italy agent logs
    systemctl restart harvey          # restart an agent

Don't open ports 5555/5556 in the firewall — reach the dashboards through
the HTTPS sites above.
