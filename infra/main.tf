data "digitalocean_kubernetes_versions" "available" {}

locals {
  requested_kubernetes_version       = trimspace(var.kubernetes_version)
  available_kubernetes_version_slugs = toset(data.digitalocean_kubernetes_versions.available.valid_versions)
  effective_kubernetes_version = (
    local.requested_kubernetes_version != "" && contains(local.available_kubernetes_version_slugs, local.requested_kubernetes_version)
  ) ? local.requested_kubernetes_version : data.digitalocean_kubernetes_versions.available.latest_version
}

resource "digitalocean_kubernetes_cluster" "main" {
  name          = var.cluster_name
  region        = var.region
  version       = local.effective_kubernetes_version
  auto_upgrade  = true
  surge_upgrade = true

  node_pool {
    name       = var.node_pool_name
    size       = var.node_size
    node_count = var.node_count
    auto_scale = false
  }
}