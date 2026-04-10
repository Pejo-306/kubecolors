variable "credentials_file" {
  description = "Path to GCP credentials JSON file (ADC or service account key)"
  type        = string
}

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "Primary GCP region for the cluster and subnet"
  type        = string
  default     = "europe-west3"
}

variable "cluster_name" {
  description = "GKE cluster name"
  type        = string
  default     = "kubecolors-cluster"
}

variable "network_name" {
  description = "VPC network name"
  type        = string
  default     = "kubecolors-network"
}

variable "subnet_name" {
  description = "Subnet name (primary range is subnet_cidr)"
  type        = string
  default     = "kubecolors-subnet"
}

variable "subnet_cidr" {
  description = "Primary IPv4 CIDR range for the subnet"
  type        = string
  default     = "192.168.0.0/24"
}

variable "dev_static_ip_name" {
  description = "Global static IP resource name for dev ingress"
  type        = string
  default     = "kubecolors-dev-ip"
}

variable "prod_static_ip_name" {
  description = "Global static IP resource name for prod ingress"
  type        = string
  default     = "kubecolors-prod-ip"
}

variable "deletion_protection" {
  description = "When true, Terraform cannot destroy the GKE cluster"
  type        = bool
  default     = true
}
