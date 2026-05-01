# Gemini CLI Context for this Cluster Trait Repository

This file provides framework-level context for Gemini CLI when operating in this Cluster Trait Repository (CTR). It pairs with `CLAUDE.md` in the same directory, which holds the per-trait specifics. Both files are loaded together — `.gemini/settings.json` in this trait sets `context.fileName: ["GEMINI.md", "CLAUDE.md"]` so Gemini CLI concatenates both into the model context.

The parent project's `CLAUDE.md` at the repo root contains additional cross-trait rules. Read it too.

---

## 1. Context: What is a Cluster Trait Repository (CTR)?

A Cluster Trait Repository is a convention-based packaging of YAML configuration used in GitOps deployments.

- **Core Purpose:** A CTR equips a cluster with specific capabilities or functionality (the "trait") by providing opinionated configurations, controllers, and operators. It changes the fundamental nature of the cluster.
- **Scope Limitation:** A CTR *enables* functionality but does *not* instantiate the final application or specific resource. For example, a database CTR provides the database operator, CRDs, and foundational setup, but leaves the creation of specific database instances to separate application packages.
- **Mechanism:** Relies heavily on Kustomize to compose `base/` manifests with opinionated `overlays/`.

## 2. Gemini's Role and Objectives

Gemini CLI is an active participant in the lifecycle of this CTR. Its primary responsibilities:

- **Configuration Management:** Clean, minimize, and revise YAML configurations. Ensure YAML is valid, readable, and adheres to GitOps best practices. Remove redundant or default values to keep manifests lean.
- **Automation:** Automate routine tasks such as scaffolding new components, updating references, and formatting code.
- **Testing & Validation:** Validate the configuration (e.g., verifying `kustomize build` outputs) and help define testing strategies for the trait.
- **Upgrades & Maintenance:** Upgrade upstream dependencies (Helm charts or raw manifests in `base/`), resolve structural changes, migrate to newer Kubernetes API versions.
- **Releasing:** Support the release lifecycle by helping generate changelogs, bump versions, and prepare final manifest packages in `manifests/`.
- **Security:** Review configurations for security misconfigurations (RBAC scoping, security contexts, no privileged defaults) and help harden the trait.

## 3. Architectural Conventions & Hydration

- **Directory Structure:**
  - `base/` — Raw, upstream, or foundational manifests (un-opinionated). Generic — no storageClass, no endpoints, no demo references.
  - `overlays/` — Opinionated configurations (e.g., `overlays/default/`). The core trait logic resides here. **Policy lives in the overlay, not the base.**
  - `specs/` — Architectural decisions, infrastructure requirements, and operational T-codes (Spec-Kit V1.2).
  - `manifests/` — Hydration target directory.
    - `manifests/config/<overlay>/<overlay>-generated.yaml` — for ConfigSync to read.
    - `manifests/packages/pkg-<overlay>.yaml` — bundled package form. (Note: some upstream traits use singular `package/`; this repo and most peers use plural `packages/`. Match what `generate.sh` writes.)
- **Hydration Mechanism (`generate.sh`):**
  - Uses `kustomize build` (with `--enable-helm` if the kustomization references `helmCharts`).
  - Iterates `overlays/*/kustomization.yaml`, writes both `<overlay>-generated.yaml` and `pkg-<overlay>.yaml`.
  - Validates output with `nomos vet --source-format=unstructured --no-api-server-check` if `nomos` is installed locally.
  - **Partial build:** `./generate.sh <overlay_name>` rebuilds just that overlay.
  - **Always run after editing `base/` or `overlays/`** so `manifests/` stays in sync.

## 4. Execution Guidelines for Gemini

- **Spec-Kit Consultation:** Always consult the most recent `SPEC-##` file in `/specs` before suggesting code changes or infrastructure deployments. Spec-Kit specs take precedence over general best practices when they conflict.
- **Declarative Focus:** All modifications must result in valid, declarative Kubernetes manifests.
- **Hydration Lifecycle:** Always run `./generate.sh` after manifest changes. Commit source + hydrated output together.
- **Don't manually edit `manifests/` files.** They're hydration output. `./generate.sh` rewrites them. If you find yourself wanting to hand-tweak generated YAML, the patch belongs in an overlay.
- **Surgical YAML edits — keep manifests lean.** Remove redundant or default values when touching configs. If a field is at its schema default, drop it.
- **Embrace eventual consistency (GitOps mindset).** The cluster reconciles toward the manifest. Don't chase imperative state mid-debug. If you have to imperatively poke something during debug, capture it as a manifest update *before* considering the work done.
- **No imperative commands except for build and debug.** All final KRM lives in `base/` or `overlays/**`. Never `kubectl apply -f` something that should have been a kustomize patch.
- **Security pass on every config change.** RBAC scoping (no `cluster-admin` where namespace-scoped works), `securityContext` (`runAsNonRoot: true`, `readOnlyRootFilesystem: true`, `capabilities: { drop: [ALL] }`), no privileged defaults, no host-network/host-PID.
- **Ask for clarification on ambiguous architecture.** When an upgrade or configuration change involves a non-obvious architectural call (CRD migration shape, dependency graph, multi-trait interop), surface the ambiguity and the candidate options. Don't pick silently.
- **No raw `Secret` objects.** Credentials flow through `external-secrets.io` exclusively (`ExternalSecret` + `ClusterSecretStore`).

## 5. Documentation & Tracking

- **CHANGELOG.md** — additive, reverse-chronological. Update at the end of every significant session or milestone. Capture architectural decisions and major friction encountered, not just file changes.
- **PROGRESS.md** — living checklist of features past, current, and future. Update as tasks are identified, started, or completed. PROGRESS.md is the trait's roadmap source-of-truth; CHANGELOG.md is the trait's session log.

## 6. Spec-Kit V1.2 Standard

This project uses the **Spec-Kit V1.2 standard** for technical and architectural documentation.

- **Scope:** Architectural decisions, infrastructure requirements, and operational T-codes are documented in `/specs`.
- **T-codes:** standardized operations — T01 init, T02 overlay config, T03 creation via `generate.sh`, T04 audit, T05 update, T06 deletion.
- **Adherence:** All changes must align with the specifications defined in `SPEC-##` files. Specs take precedence over general best practices when they conflict.

---

**Per-trait specifics live in `CLAUDE.md`** in this same directory. Both files are loaded into context simultaneously when Gemini CLI is configured per `.gemini/settings.json` in this repo.
