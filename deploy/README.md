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
docker compose logs -f cordane  # watch it boot
```

Open `https://<your EXTERNAL_URL>` and sign in with GitHub — **the first account
to sign in becomes the admin**.

### What you must set in `.env`

| Var | What |
|-----|------|
| `EXTERNAL_URL` / `CONTROL_HOST` | your hub URL / hostname |
| `PROXY_DOMAIN` | wildcard preview base (blank = path-based, see below) |
| `CF_API_TOKEN` | Cloudflare token, `Zone:DNS:Edit` — for the wildcard cert |
| `CORDANE_SECRET_KEY` | `openssl rand -base64 32` — **back up out-of-band** |
| `CORDANE_GITHUB_CLIENT_ID/SECRET` | GitHub OAuth app (sign-in) |

### DNS

Point these at the VPS IP (on Cloudflare: **DNS-only / grey cloud** — Caddy
terminates TLS itself; proxying would break the streaming connections):

| Type | Name | Value |
|------|------|-------|
| A | `cordane.app` (apex/hub) | `<VPS IP>` |
| A | `*.cordane.app` (previews) | `<VPS IP>` |

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

## Simple mode (no DNS token, no wildcard)

Don't want to create a DNS API token? Serve a single hostname with HTTP-01 TLS
and path-based previews:

1. In `.env`, leave `PROXY_DOMAIN` and `CF_API_TOKEN` blank.
2. In `docker-compose.yml`, mount `./Caddyfile.pathbased` instead of `./Caddyfile`.

App previews are then at `/w/{worker}/{app}/` (fine for simple/trusted apps;
apps using absolute URLs/websockets may break — see the top-level README).

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
