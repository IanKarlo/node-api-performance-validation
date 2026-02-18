resource "digitalocean_kubernetes_cluster" "main" {
  name          = var.cluster_name
  region        = var.region
  version       = var.kubernetes_version
  auto_upgrade  = true
  surge_upgrade = true

  node_pool {
    name       = var.node_pool_name
    size       = var.node_size
    node_count = var.node_count
    auto_scale = false
  }
}