locals {
  services = [
    "firebase.googleapis.com",
    "firebasehosting.googleapis.com",
  ]

  deletion_policy = var.deletion_protection ? "PREVENT" : "DELETE"

  # projects/<番号>/locations/global/workloadIdentityPools/<プール>/providers/<プロバイダ> からプール名を取り出す
  workload_identity_pool = regex("^(projects/[^/]+/locations/global/workloadIdentityPools/[^/]+)/providers/", var.workload_identity_provider)[0]
}

resource "google_project_service" "this" {
  for_each = toset(local.services)

  project = var.project_id
  service = each.value
}

# 削除しても Terraform の state から外れるだけで、GCP 上の Firebase は残る（プロバイダの仕様）
resource "google_firebase_project" "this" {
  provider = google-beta

  project = var.project_id

  depends_on = [google_project_service.this]
}

# デフォルトサイト（サイト ID = プロジェクト ID）。Firebase 追加時に自動で作られている場合は、プロバイダがそれを取り込む
resource "google_firebase_hosting_site" "default" {
  provider = google-beta

  project         = var.project_id
  site_id         = var.project_id
  deletion_policy = local.deletion_policy

  depends_on = [google_firebase_project.this]
}
