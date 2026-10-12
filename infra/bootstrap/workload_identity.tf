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
  # GitHub の OIDC トークンの sub は、オーナーとリポジトリに数値 ID が付いた形式になっている。
  #   例: repo:tsatolol@30972312/firebase_hosting_cicd_lab@1415534725:pull_request
  # 実際の値は terraform.yml の「Show OIDC token claims」ステップで確認できる。
  github_repository_parts = split("/", var.github_repository)
  github_subject_repo     = "repo:${local.github_repository_parts[0]}@${var.github_repository_owner_id}/${local.github_repository_parts[1]}@${var.github_repository_id}"

  # OIDC トークンの sub ごとの principal。SA の利用はこの単位で許可する（リポジトリ全体には許可しない）
  github_subject_prefix = "principal://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/subject/${local.github_subject_repo}"
}
