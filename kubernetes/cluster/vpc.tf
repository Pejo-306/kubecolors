resource "google_compute_network" "main" {
  name                    = var.network_name
  description             = "VPC network for the kubecolors project"
  auto_create_subnetworks = false

  depends_on = [google_project_service.compute]
}

resource "google_compute_subnetwork" "main" {
  name          = var.subnet_name
  ip_cidr_range = var.subnet_cidr
  region        = var.region
  network       = google_compute_network.main.id

  depends_on = [google_project_service.compute]

  lifecycle {
    ignore_changes = [secondary_ip_range]
  }
}
