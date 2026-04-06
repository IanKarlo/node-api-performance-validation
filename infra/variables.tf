variable "do_token" {
  description = "DigitalOcean API token"
  type        = string
  sensitive   = true
}

variable "region" {
  description = "DigitalOcean region for all resources"
  type        = string
  default     = "nyc1"
}

variable "cluster_name" {
  description = "DOKS cluster name"
  type        = string
  default     = "node-api-perf-cluster"
}

variable "kubernetes_version" {
  description = "Optional DOKS Kubernetes version slug (example: 1.35.1-do.0). Leave empty to auto-select latest available."
  type        = string
  default     = ""
}

variable "node_pool_name" {
  description = "Primary node pool name"
  type        = string
  default     = "default-pool"
}

variable "node_size" {
  description = "DigitalOcean node size slug"
  type        = string
  default     = "s-2vcpu-4gb"
}

variable "node_count" {
  description = "Number of nodes in the primary pool"
  type        = number
  default     = 2
}
