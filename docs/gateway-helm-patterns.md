# Helm Gateway & Certificate Patterns

## Why This Matters
- Stardog deployments can reuse a shared Envoy Gateway or create their own.
- Cert-manager automation may live in Terraform or inside the Helm chart.
- Pick the model that matches your platform’s security boundaries.

---

## Pattern #1 – Certificate Outside, Routes Inside
- **Profiles:** `profile-01h~azure-envoy-gateway-shared`
- **How it works:** Terraform (or another platform IaC) installs cert-manager, ACME Issuer, Certificates, and the shared Gateway listeners. Each Stardog release only renders `HTTPRoute`/`TCPRoute` resources that attach via `parentRefs`.
- **Benefits:**
  - Centralized TLS secrets and ACME accounts; no elevated permissions for app teams.
  - A single Let’s Encrypt certificate (e.g., `profile-01e.sd-testlab.com`) serves both HTTPS and BI TCP (`TLS` listener on port 5806).
  - Shared Gateway enforces consistent listeners (`http`, `https`, `bi-tcp`) and DNS coverage (`sparql.*`, `bi.*`, `launchpad.*`).
- **Watchouts:**
  - Helm values must set `gateway.http.createGateway=false` and `gateway.http.tls.enabled=false`; TLS policies come entirely from the platform.
  - Terraform must keep the Issuer + Certificate manifests up to date (`envs/.../ingress.tf` handles this in our repo).

---

## Pattern #2 – Everything Outside the Chart
- **Profiles:** `profile-01g~azure-envoy-gateway-platform`
- **How it works:** Routes, Gateways, Certificates, and LoadBalancers are all defined in a central IaC repo. App Helm charts expose Services only.
- **Benefits:**
  - Strong separation of duties and auditability; ideal for regulated environments or strict GitOps flows.
  - Zero Kubernetes RBAC surface granted to app releases.
- **Trade-offs:**
  - Slower iteration—every hostname/path change requires a platform pull request.
  - Helm values never reference `gateway.*`, so documentation must explain how traffic arrives at the Service.

---

## Pattern #3 – Route + Certificate Inside the Chart
- **Profiles:** `profile-01e~azure-envoy-gateway`
- **How it works:** Set `gateway.http.createGateway=true`, enable `gateway.http.tls`, and optionally `gateway.tcpBi.tls`. The chart renders the Gateway, listeners, Certificates, and routes in one release.
- **Benefits:**
  - Self-contained; easy to reason about, great for isolated dev/test clusters or single-tenant environments.
  - Lets teams experiment with new Gateway features (redirects, launchpad proxy, BI TCPRoute) without waiting on platform changes.
- **Trade-offs:**
  - Multiple releases may each create their own Gateway + LoadBalancer, consuming IPs and duplicating certificates.
  - Requires the Helm release to have `cluster-admin`-like permissions to install CRDs, Gateways, and Secrets.

---

## Pattern #4 – Gateway Outside, Certs + Routes Inside
- **Profiles:** `profile-01f~azure-envoy-gateway-central`
- **How it works:** Terraform owns the shared Gateway and listeners, while the Helm chart renders `HTTPRoute`/`TCPRoute` plus cert-manager `Issuer`/`Certificate` resources for that release.
- **Benefits:**
  - Shared Gateway reduces IP/LB sprawl while keeping app-managed TLS.
  - App teams can rotate certs independently without platform PRs.
- **Trade-offs:**
  - Requires cert-manager permissions in the app namespace.
  - Platform and app teams must coordinate on listener names and TLS secret locations.

---

## Choosing the Right Pattern
| Question | Preferred Pattern |
| --- | --- |
| Do you operate a shared Envoy Gateway managed by Terraform? | **Pattern #1** |
| Do security teams manage every external listener and cert? | **Pattern #2** |
| Are you deploying to isolated clusters or need app-level autonomy? | **Pattern #3** |
| Do you want a shared Gateway but app-owned certificates? | **Pattern #4** |

> Tip: Regardless of pattern, remember that Gateway listeners own the external port. Only one listener (shared or chart-managed) can terminate TLS for a given IP:port combination.

---

## Hands-On Checklist (Pattern #1)
1. Confirm Terraform applied the ACME Issuer & Certificate (`null_resource.envoy_acme_issuer` / `envoy_certificate`).
2. In `values.stardog.yaml`, set:
   - `gateway.http.domain`, `createGateway=false`, `tls.enabled=false`
   - `gateway.tcpBi.parentRefs` → shared `bi-tcp` listener (no TLS block)
3. Enable Launchpad redirect if needed:
   - `gateway.http.redirect.enabled=true`
4. Deploy Helm; verify routes attach via `kubectl get httproute`.
5. Validate TLS with `openssl s_client -connect bi.<domain>:5806`.

---

## Key Takeaways
- Certificates and routes can live in different layers; just ensure ownership is clear.
- The Stardog chart happily acts as a “route only” consumer when a shared Gateway handles TLS.
- For BI TCP TLS, either rely on the shared listener (Pattern #1/#2) or opt into `createGateway=true` (Pattern #3).
- Document your chosen pattern so every environment (profile-01e, profile-01c, etc.) stays consistent.
