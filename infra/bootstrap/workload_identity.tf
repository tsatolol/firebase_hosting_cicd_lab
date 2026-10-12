resource "google_iam_workload_identity_pool" "github" {
  project                   = google_project.this["admin"].project_id
  workload_identity_pool_id = "github"
  display_name              = "GitHub Actions"

  depends_on = [google_project_service.this["admin/iam.googleapis.com"]]
}

resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = google_project.this["admin"].project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-actions"
  display_name                       = "GitHub Actions OIDC"

  attribute_mapping = {
    "google.subject"                = "assertion.sub"
    "attribute.repository"          = "assertion.repository"
    "attribute.repository_owner_id" = "assertion.repository_owner_id"
  }

  # このリポジトリ以外が発行したトークンは、プール全体で拒否する
  attribute_condition = "assertion.repository == '${var.github_repository}' && assertion.repository_owner_id == '${var.github_repository_owner_id}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

locals {
  # OIDC トークンの sub ごとの principal。SA の利用はこの単位で許可する（リポジトリ全体には許可しない）
  github_subject_prefix = "principal://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/subject/repo:${var.github_repository}"
}
