output "cluster_id" {
  description = "DigitalOcean Kubernetes cluster ID"
  value       = digitalocean_kubernetes_cluster.main.id
}

output "cluster_name" {
  description = "DigitalOcean Kubernetes cluster name"
  value       = digitalocean_kubernetes_cluster.main.name
}

output "cluster_endpoint" {
  description = "Kubernetes API server endpoint"
  value       = digitalocean_kubernetes_cluster.main.endpoint
}

output "cluster_region" {
  description = "DigitalOcean region where resources were created"
  value       = var.region
}

output "cluster_status" {
  description = "DOKS cluster status"
  value       = digitalocean_kubernetes_cluster.main.status
}

output "cluster_kubeconfig_raw" {
  description = "Raw kubeconfig for the cluster"
  value       = digitalocean_kubernetes_cluster.main.kube_config[0].raw_config
  sensitive   = true
}
