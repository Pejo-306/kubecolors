resource "google_container_cluster" "autopilot" {
  name     = var.cluster_name
  location = var.region

  network    = google_compute_network.main.id
  subnetwork = google_compute_subnetwork.main.id

  enable_autopilot = true

  ip_allocation_policy {}

  deletion_protection = var.deletion_protection

  depends_on = [
    google_project_service.container,
    google_project_service.compute,
  ]

  lifecycle {
    ignore_changes = [
      node_pool,
      node_config,
      cluster_autoscaling,
      in_transit_encryption_config,
    ]
  }
}
