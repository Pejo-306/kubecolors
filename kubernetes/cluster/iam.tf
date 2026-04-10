data "google_project" "current" {
  project_id = var.project_id
}

# Used by GKE for observability. Managed here by Terraform to avoid a warning in GKE console.
resource "google_project_iam_member" "compute_sa_default_node" {
  project = var.project_id
  role    = "roles/container.defaultNodeServiceAccount"
  member  = "serviceAccount:${data.google_project.current.number}-compute@developer.gserviceaccount.com"
}
