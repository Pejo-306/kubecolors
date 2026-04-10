output "cluster_name" {
  description = "GKE cluster name"
  value       = google_container_cluster.autopilot.name
}

output "cluster_location" {
  description = "GKE cluster region/location"
  value       = google_container_cluster.autopilot.location
}

output "dev_static_ip_address" {
  description = "Reserved global IPv4 for dev ingress (configure DNS A record to this)"
  value       = google_compute_global_address.dev.address
}

output "prod_static_ip_address" {
  description = "Reserved global IPv4 for prod ingress (configure DNS A record to this)"
  value       = google_compute_global_address.prod.address
}
