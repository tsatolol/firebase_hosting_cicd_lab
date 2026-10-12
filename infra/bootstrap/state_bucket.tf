resource "google_storage_bucket" "tfstate" {
  project  = google_project.this["admin"].project_id
  name     = "${var.project_prefix}-tfstate-${local.suffix}"
  location = var.region

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }

  # 古い state のバージョンは 10 世代まで残す
  lifecycle_rule {
    condition {
      num_newer_versions = 10
      with_state         = "ARCHIVED"
    }
    action {
      type = "Delete"
    }
  }

  depends_on = [google_project_service.this["admin/storage.googleapis.com"]]
}
