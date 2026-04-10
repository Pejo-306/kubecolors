resource "google_compute_global_address" "dev" {
  name        = var.dev_static_ip_name
  description = "Global static IP address for kubecolors DEV overlay"

  depends_on = [google_project_service.compute]
}

resource "google_compute_global_address" "prod" {
  name        = var.prod_static_ip_name
  description = "Global static IP address for kubecolors PROD overlay"

  depends_on = [google_project_service.compute]
}
