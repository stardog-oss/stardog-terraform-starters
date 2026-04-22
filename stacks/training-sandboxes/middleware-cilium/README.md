# Middleware Cilium

This example mirrors the existing training-sandboxes `middleware-envoy` layer, but targets Cilium Gateway API instead of Envoy Gateway.

It:
- reads the per-student AKS details from the infra remote state
- refreshes per-student kubeconfigs
- installs Gateway API CRDs
- installs or upgrades cert-manager with Gateway API support enabled
- enables Gateway API on an existing Cilium Helm release
- creates a shared `GatewayClass` and one `Gateway` per student cluster

Important prerequisite: the target AKS clusters must already run Cilium. This example does not migrate a non-Cilium cluster to Cilium.
