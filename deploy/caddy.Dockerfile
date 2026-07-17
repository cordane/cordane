# syntax=docker/dockerfile:1
#
# Caddy with a DNS-provider plugin, for free auto-renewing WILDCARD TLS via the
# ACME DNS-01 challenge (required for *.<proxy-domain> app previews — HTTP-01
# cannot validate a wildcard). The official caddy image ships no DNS plugins, so
# we build one. Published by CI to ghcr.io/cordane/caddy (Cloudflare by default).
#
# Different DNS provider? Rebuild with your module (see the caddy-dns org):
#   docker build -f caddy.Dockerfile \
#     --build-arg DNS_MODULE=github.com/caddy-dns/route53 \
#     -t ghcr.io/cordane/caddy:route53 .
ARG DNS_MODULE=github.com/caddy-dns/cloudflare

FROM caddy:2-builder AS builder
ARG DNS_MODULE
RUN xcaddy build --with ${DNS_MODULE}

FROM caddy:2-alpine
COPY --from=builder /usr/bin/caddy /usr/bin/caddy
