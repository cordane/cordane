# Security policy

Cordane's security model in one paragraph: workers on your machines dial **out**
to the hub over a single TLS WebSocket — nothing listens inbound on your
hardware. The hub authenticates users via GitHub OAuth behind an admin-managed
allowlist; app previews are auth-gated by default with an explicit per-app
public toggle; agent/ticket previews are always team-only. Secrets (app and
profile env vars) are encrypted at rest with AES-256-GCM.

## Reporting a vulnerability

Please email **contact@cordane.ai** with a description and reproduction steps.
We aim to acknowledge reports within 48 hours. Please do not open public issues
for security reports.

Machine-readable contact: [`https://cordane.ai/.well-known/security.txt`](https://cordane.ai/.well-known/security.txt) (RFC 9116).
