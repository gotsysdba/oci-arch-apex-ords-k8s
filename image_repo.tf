variable "container_repositories" {
  description = "List of required Container Repositories"
  type        = list(any)
  default = [
    "operator",
    "cert-manager-cainjector",
    "cert-manager-controller",
    "cert-manager-webhook",
    "controller",
    "kube-webhook-certgen",
    "metrics-server",
    "sqlcl",
    "ords",
  ]
}

resource "oci_identity_auth_token" "identity_auth_token" {
  count       = var.byo_auth_token == "" ? 1 : 0
  description = format("%s-auth-token", local.label_prefix)
  user_id     = local.user_ocid
  provider    = oci.home_region
}

resource "oci_artifacts_container_repository" "artifacts_container_repository" {
  for_each       = toset(var.container_repositories)
  compartment_id = local.compartment_ocid
  display_name   = lower(format("%s/%s", local.label_prefix, each.value))
  is_immutable   = false
  is_public      = true
}
