# プロジェクト ID とバケット名で共有するサフィックス（4 桁の 16 進数）
resource "random_id" "suffix" {
  byte_length = 2
}

locals {
  suffix = random_id.suffix.hex

  projects = {
    admin = "${var.project_prefix}-admin-${local.suffix}"
    stg   = "${var.project_prefix}-stg-${local.suffix}"
    prod  = "${var.project_prefix}-prod-${local.suffix}"
  }

  env_names = ["stg", "prod"]

  # 全プロジェクトで有効にする API。
  # WIF でのトークン交換（sts / iamcredentials）と、envs の Terraform が API 有効化や SA 作成をするための API。
  base_services = [
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "serviceusage.googleapis.com",
    "sts.googleapis.com",
  ]

  # admin プロジェクトにだけ追加で有効にする API
  admin_services = [
    "storage.googleapis.com",
  ]

  project_services = merge(
    { for pair in setproduct(keys(local.projects), local.base_services) : "${pair[0]}/${pair[1]}" => {
      project = pair[0]
      service = pair[1]
    } },
    { for service in local.admin_services : "admin/${service}" => {
      project = "admin"
      service = service
    } },
  )
}

# 組織がない個人アカウントでは SA がプロジェクトを作れないため、ここ（ユーザー権限）で作る
resource "google_project" "this" {
  for_each = local.projects

  name            = each.value
  project_id      = each.value
  billing_account = var.billing_account_id
  deletion_policy = "PREVENT"

  labels = {
    app        = var.project_prefix
    env        = each.key
    managed-by = "terraform"
  }
}

resource "google_project_service" "this" {
  for_each = local.project_services

  project = google_project.this[each.value.project].project_id
  service = each.value.service
}
