# GitHub Actions から Firebase Hosting へデプロイする SA
resource "google_service_account" "deployer" {
  project      = var.project_id
  account_id   = "deployer"
  display_name = "Firebase Hosting deployer (${var.env})"
}

locals {
  deployer_roles = [
    "roles/firebasehosting.admin",
    # firebase-tools が API の有効状態を確認し、クォータをこのプロジェクトに付けるため
    "roles/serviceusage.serviceUsageConsumer",
  ]
}

resource "google_project_iam_member" "deployer" {
  for_each = toset(local.deployer_roles)

  project = var.project_id
  role    = each.value
  member  = google_service_account.deployer.member
}

# OIDC トークンの sub 単位で利用を許可する（リポジトリ全体には許可しない）
resource "google_service_account_iam_member" "deployer_wif" {
  for_each = toset(var.deployer_subjects)

  service_account_id = google_service_account.deployer.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principal://iam.googleapis.com/${local.workload_identity_pool}/subject/repo:${var.github_repository}:${each.value}"
}
