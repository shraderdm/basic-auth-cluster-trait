# Dependencies — basic-auth-cluster-trait

This trait depends on **exactly one** other cluster-trait:

| Dependency | Why |
|---|---|
| `external-secrets-anthos` | Provides the `gcp-secret-store` ClusterSecretStore that this trait's ExternalSecret pulls the htpasswd from. |

It has **no dependency** on `gateway-api-cluster-trait` by itself — the HTTPRoutes that route traffic through the gatekeeper live in the consuming app-traits / cluster-traits, not here. Install order: external-secrets → basic-auth → (anything that consumes it).

## GSM secret prereq

Before this trait's ExternalSecret can sync, a GSM secret named
`demo-basic-auth-htpasswd` must exist in project `david-learning-2026` (or
whatever project the `gcp-secret-store` ClusterSecretStore points at). Content
is a single-line htpasswd blob, e.g. `admin:$apr1$...$...`.

Create (or rotate) with:

```bash
printf 'admin:' > /tmp/ht
printf 'YOUR_PASSWORD' | openssl passwd -apr1 -stdin >> /tmp/ht
gcloud secrets versions add demo-basic-auth-htpasswd \
  --project=david-learning-2026 --data-file=/tmp/ht
rm /tmp/ht
kubectl annotate externalsecret -n basic-auth-system basic-auth-htpasswd-es \
  force-sync=$(date +%s) --overwrite
kubectl -n basic-auth-system rollout restart deploy/basic-auth-gatekeeper
```
