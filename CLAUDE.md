# CLAUDE.md — basic-auth-cluster-trait

Per-trait flavor of the parent `CLAUDE.md` at `/Users/davidshrader/GDC-cluster-traits/`. Read both.

## What this trait is

HTTP Basic Auth gatekeeper that sits between the shared `cloud-gateway` and any public demo service that doesn't have its own auth. One shared nginx Deployment + Service in `basic-auth-system` namespace; nginx server blocks do host-based upstream routing to the right app namespace.

Consumed today by:
- `healthcare.shrader.cloud` → healthcare-review-ui in healthcare-demo
- `kagent.shrader.cloud` → kagent UI in kagent

NOT consumed by Langfuse (it has its own NextAuth login).

## Hard rules

- **Creds come from GSM, never hardcoded.** The `basic-auth-shrader-demo` GSM secret holds the htpasswd blob. The ExternalSecret syncs it into `basic-auth-htpasswd` in this namespace.
- **Deprecated creds stay in GSM history.** Never delete old versions of the GSM secret; just add a new version and force-sync.
- **One gatekeeper Pod set for all demos.** Don't split into per-app gatekeepers unless we hit a concrete scale or timeout problem. The host-based routing pattern is cleaner to reason about as a demo primitive.
- **HTTPRoutes live WITH the app, not in this trait.** An HTTPRoute pointing `healthcare.shrader.cloud` at this Service should be part of `healthcare-app-trait`, not this trait. Keeps ownership aligned with the thing the route targets.

## Where things live

- `base/namespace.yaml` — `basic-auth-system` namespace
- `base/external-secrets.yaml` — ExternalSecret + target Secret template
- `base/configmap.yaml` — nginx.conf with one server block per public hostname
- `base/gatekeeper.yaml` — Deployment + Service (nginx-unprivileged, runs as UID 101, read-only root filesystem)
- `overlays/default/` — passthrough today; overlay patches for alternate hostnames / timeouts would go here

## Adding a new public subdomain

1. Edit `base/configmap.yaml`, add a new `server { listen 8080; server_name <fqdn>; ... }` block. Copy an existing block, swap the `server_name` and the `proxy_pass` upstream.
2. Add the HTTPRoute in the consuming app-trait (not here).
3. `./generate.sh default`, commit, push.

## Port mapping

- Container port 8080 = HTTP (auth-gated)
- Container port 8081 = /healthz (NO auth, for k8s probes)
- Service port 80 → targetPort http (8080)

nginx-unprivileged can't bind <1024, so we listen on 8080 in-container and expose as 80 on the Service.

## Why two replicas

Not for HA load. For the demo shape — if one replica crashes during a stage demo, the other serves. Cost is trivial (25m CPU, 32Mi memory each).

## Relevant vault notes (PKM load step — see `[[unpinned vault notes are dormant memory — CLAUDE.md is how you activate them]]`)

- `[[demo-specific routing belongs in its own cluster-trait — never pollute upstream ones]]` — why this trait is separate from kagent/langfuse traits
- `[[IAP and oauth2-proxy are deferred in the cluster-trait world — basic auth is enough]]` — why basic-auth, not a richer auth layer
- `[[ConfigSync RootSyncs fight over implicit namespace ownership]]` — why the ReferenceGrant for cross-namespace routes lives HERE (this trait owns `basic-auth-system`), not in `demo-public-routes-cluster-trait`
- `[[the canonical demo image registry is shraderdm slash agent-demos]]` — registry rules (nginx is upstream though, not from our registry)
- `[[back to cluster-trait plus app-trait for the demo reel — easy-deploy abandoned]]` — the packaging model this trait fits into
