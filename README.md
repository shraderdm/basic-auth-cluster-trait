# basic-auth-cluster-trait

HTTP Basic Auth gatekeeper in front of public demo services that lack their own auth (the healthcare review UI, kagent UI, future vertical demos). Langfuse has its own auth and does NOT go through this; Langfuse gets its own HTTPRoute directly.

Not production-grade auth. A stopgap for shrader.cloud public demo exposure.

## What it ships

| Resource | Purpose |
|---|---|
| `basic-auth-system` namespace | Houses the shared gatekeeper |
| `ExternalSecret basic-auth-htpasswd-es` | Syncs `basic-auth-shrader-demo` from GSM → K8s Secret `basic-auth-htpasswd` |
| `ConfigMap basic-auth-nginx-config` | Multi-server-block nginx.conf, one block per public hostname |
| `Deployment basic-auth-gatekeeper` (replicas: 2) | nginx-unprivileged, mounts the ConfigMap + Secret |
| `Service basic-auth-gatekeeper` | ClusterIP:80, the target of every public HTTPRoute |

## Architecture

```
browser ── https://healthcare.shrader.cloud/ ──►
  cloud-gateway (kgateway, 443 TLS) ──►
    HTTPRoute in healthcare-demo namespace ──►
      basic-auth-gatekeeper.basic-auth-system:80 ──►
        nginx server block `server_name healthcare.shrader.cloud` ──►
          auth_basic check against /etc/nginx/htpasswd/auth ──►
            proxy_pass http://healthcare-review-ui.healthcare-demo:80
```

Adding a new public service means:

1. Deploy the app Service in its namespace (normal app-trait work).
2. Add a new `server { listen 8080; server_name <fqdn>; ... }` block to `base/configmap.yaml`.
3. Add an HTTPRoute in the app's namespace that `backendRefs` this trait's `basic-auth-gatekeeper` Service.
4. Re-hydrate this trait (`./generate.sh default`), commit, push. ConfigSync picks it up.

## Credential rotation

See `dependencies/README.md`.

## Installation

Consumed via RootSync. Example:

```yaml
apiVersion: configsync.gke.io/v1beta1
kind: RootSync
metadata:
  name: basic-auth-trait-sync
  namespace: config-management-system
spec:
  sourceFormat: unstructured
  git:
    repo: https://github.com/shraderdm/basic-auth-cluster-trait.git
    branch: main
    dir: manifests/config/default
    auth: none
```

## Why not oauth2-proxy / Envoy ExtAuth

- oauth2-proxy in htpasswd mode is ~300MB and does far more than needed.
- Envoy ExtAuth would require a gRPC auth service. More moving parts for no benefit at this scale.
- nginx `auth_basic` is 5 lines of config. Every engineer can reason about it.

If/when the demo needs real auth (SSO, OAuth, MFA), swap this trait for a proper `oauth2-proxy-cluster-trait` or an IAP-integrated cluster-trait in an org-attached project.
