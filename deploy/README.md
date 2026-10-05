# Self-hosting cordane with Docker Compose

Run the whole control plane — hub, wildcard TLS, and continuous backups — on one
VPS with two containers. Prebuilt images are pulled from GHCR, so you need
**nothing installed but Docker**.

```
deploy/
  docker-compose.yml     # the stack: caddy + cordane
  .env.example           # all config — copy to .env
  Caddyfile              # wildcard TLS + reverse proxy (default)
  Caddyfile.pathbased    # simpler no-DNS-token variant
  caddy.Dockerfile       # build Caddy with a DNS plugin (only if rebuilding)
```

## What it runs

- **caddy** — terminates TLS and reverse-proxies to cordane. Gets **free
  auto-renewing wildcard certs** (`cordane.app` + `*.cordane.app`) via the ACME
  **DNS-01** challenge. Publishes ports 80/443.
- **cordane** — the Go control plane. SQLite lives on the `cordane_data` volume;
  when object-store creds are set it runs under **litestream** (restore-on-boot +
  continuous WAL replication). Not exposed to the host.

Single node by design: the hub holds each worker's tunnel in memory, so there's
no clustering and a deploy is a clean restart. Scale by adding workers (the heavy
compute lives there), not hub replicas.

## Quick start

```sh
# 1. a small VPS (1–2 vCPU), Docker + compose installed, ports 80/443 open
# 2. grab this folder (or the repo) onto the box, then:
cp .env.example .env
nano .env                       # fill in the values below
openssl rand -base64 32         # → paste as CORDANE_SECRET_KEY (back it up!)

docker compose up -d
docker compose logs -f          # both containers — TLS/cert errors show in caddy's log
```

Open `https://<your EXTERNAL_URL>` and sign in with GitHub — **the first account
to sign in becomes the admin**.

### What you must set in `.env`

| Var | What |
|-----|------|
| `EXTERNAL_URL` / `CONTROL_HOST` | your hub URL / hostname |
| `PROXY_DOMAIN` | wildcard mode only — preview base (blank in simple mode) |
| `CF_API_TOKEN` | wildcard mode only — Cloudflare token, `Zone:DNS:Edit` |
| `CORDANE_SECRET_KEY` | `openssl rand -base64 32` — **back up out-of-band** |
| `CORDANE_GITHUB_CLIENT_ID/SECRET` | GitHub OAuth app (sign-in) |

### DNS

Point these at the VPS IP (on Cloudflare: **DNS-only / grey cloud** — Caddy
terminates TLS itself; proxying would break the streaming connections):

| Type | Name | Value |
|------|------|-------|
| A | `cordane.app` (apex/hub) | `<VPS IP>` |
| A | `*.cordane.app` (previews — wildcard mode only) | `<VPS IP>` |

### GitHub OAuth

Create an OAuth App (GitHub → Settings → Developer settings → OAuth Apps) with
callback URL `${EXTERNAL_URL}/api/v1/auth/github/callback`, and put the client
id/secret in `.env`.

## Backups (recommended)

Uncomment and fill the `LITESTREAM_*` block in `.env` with any S3-compatible
bucket (Cloudflare R2 is free-egress). cordane then restores from the replica on
a fresh box automatically and streams the WAL out continuously (seconds of RPO).
Leave them blank to run with no backups (data lives only on the `cordane_data`
volume). **Back up `CORDANE_SECRET_KEY` separately** — it is *not* in the
litestream replica.

## Simple mode and wildcard mode

**Simple mode is the default** for a new install: `.env.example` sets
`CADDYFILE=Caddyfile.pathbased`. One hostname, an HTTP-01 certificate, no DNS
API token, and app previews at `/w/{worker}/{app}/` on the hub's origin — fine
for simple or trusted apps; apps that use absolute URLs or websockets may break.

**Wildcard mode** gives every preview its own origin (`myapp--worker.<domain>`),
which is both safer and compatible with any web app. To switch, in `.env`:

```sh
CADDYFILE=Caddyfile          # the wildcard Caddyfile
PROXY_DOMAIN=cordane.example.com
CF_API_TOKEN=…               # Cloudflare, Zone:DNS:Edit (other providers: below)
```

add the `*.` DNS record above, and `docker compose up -d`. (An `.env` from before
`CADDYFILE` existed has no such line and keeps the wildcard file it was set up
with.)

## Keep the worker running

`cordane worker join` enrolls a machine and then keeps running as the worker in
that terminal. To keep it up across logouts and reboots, run `cordane worker run`
as a service. On Linux, a systemd user unit at
`~/.config/systemd/user/cordane-worker.service`:

```ini
[Unit]
Description=Cordane worker
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=/usr/local/bin/cordane worker run --dir %h/.cordane/worker
WorkingDirectory=%h
# Headless agents are started by the worker, so it needs the PATH your shell
# has — wherever claude / codex / opencode / pi and gh live.
Environment=PATH=%h/.local/bin:/usr/local/bin:/usr/bin:/bin
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
```

```sh
systemctl --user daemon-reload && systemctl --user enable --now cordane-worker
loginctl enable-linger "$USER"   # start at boot, without a login
```

Use the path `install.sh` printed if it isn't `/usr/local/bin`. Restarting the
worker ends its terminals (`cordane worker upgrade` keeps them); a hub restart
doesn't. On macOS, a launchd agent running the same command does the job.

## Updating

```sh
docker compose pull && docker compose up -d
```

A brief blip while cordane restarts; workers auto-reconnect.

The compose file pins **`:stable`** — the released build, moved deliberately
once a version has proven itself on our managed fleet. `:latest` tracks every
change and is not meant for production. For full control, pin a commit SHA
(`ghcr.io/cordane/cordane:<sha>`); to roll back, pin the previous SHA and
`up -d` again.

The hub tells you when there's something to pull: an admin sees an **"A newer
Cordane is available"** banner under **Settings → Version** once a newer build is
published (it checks in with cordane.ai daily; it never touches your box — you
run the two commands above yourself). To turn the check off on an air-gapped or
privacy-conscious box, set `CORDANE_UPDATE_CHECK=off` in `.env`.

## A DNS provider other than Cloudflare

The default `Caddyfile` gets its wildcard certificate through Cloudflare's DNS
API. For any other provider, rebuild the Caddy image with that provider's plugin
(the full list is at [caddy-dns](https://github.com/caddy-dns)) — everything you
need is in this folder:

```sh
docker build -f caddy.Dockerfile \
  --build-arg DNS_MODULE=github.com/caddy-dns/route53 \
  -t my-caddy:local .
```

Then point the `caddy` service's `image:` at `my-caddy:local`, swap the
`dns cloudflare …` line in `Caddyfile` for your provider's directive, and set
whatever credentials that plugin expects instead of `CF_API_TOKEN`.

Don't want to deal with DNS APIs at all? Use **simple mode** above — HTTP-01
TLS, no token, no wildcard.

> The `cordane` app image is not built from this repository — this repo holds the
> deployment configuration, and the application itself is distributed only as the
> prebuilt image (see [`NOTICE`](../NOTICE)). Build args and image internals are
> documented here only where you need them to deploy.

## Operations

```sh
docker compose logs -f cordane     # app logs (incl. litestream)
docker compose logs -f caddy       # TLS / proxy logs
docker compose restart cordane     # manual restart
docker compose down                # stop (volumes kept)
```
