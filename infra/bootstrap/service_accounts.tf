# GitHub Actions から Terraform（infra/envs）を実行する SA。admin プロジェクトに置く。
locals {
  terraform_service_accounts = {
    "tf-plan" = {
      display_name = "Terraform plan (PR)"
      # PR のジョブ（Environment なし）からだけ使える
      subject = "pull_request"
    }
    "tf-apply-stg" = {
      display_name = "Terraform apply (stg)"
      subject      = "environment:infra-stg"
    }
    "tf-apply-prod" = {
      display_name = "Terraform apply (prod)"
      subject      = "environment:infra-prod"
    }
  }

  # tf-plan はプランを作るための読み取り権限だけを持つ
  plan_roles = [
    "roles/viewer",
    "roles/iam.securityReviewer",
    # envs のプロバイダは課金・クォータを各 env プロジェクトに付け替える（user_project_override）ため必要
    "roles/serviceusage.serviceUsageConsumer",
  ]

  plan_role_bindings = {
    for pair in setproduct(local.env_names, local.plan_roles) : "${pair[0]}/${pair[1]}" => {
      env  = pair[0]
      role = pair[1]
    }
  }

  state_object_prefix = "projects/_/buckets/${google_storage_bucket.tfstate.name}/objects"
}

resource "google_service_account" "terraform" {
  for_each = local.terraform_service_accounts

  project      = google_project.this["admin"].project_id
  account_id   = each.key
  display_name = each.value.display_name

  depends_on = [google_project_service.this["admin/iam.googleapis.com"]]
}

resource "google_service_account_iam_member" "terraform_wif" {
  for_each = local.terraform_service_accounts

  service_account_id = google_service_account.terraform[each.key].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "${local.github_subject_prefix}:${each.value.subject}"
}

# --- env プロジェクトへの権限 ---

resource "google_project_iam_member" "plan" {
  for_each = local.plan_role_bindings

  project = google_project.this[each.value.env].project_id
  role    = each.value.role
  member  = google_service_account.terraform["tf-plan"].member
}

# ラボ用途のため owner を使う（理由は docs/spec.md §7.2）
resource "google_project_iam_member" "apply_owner" {
  for_each = toset(local.env_names)

  project = google_project.this[each.key].project_id
  role    = "roles/owner"
  member  = google_service_account.terraform["tf-apply-${each.key}"].member
}

# --- state バケットへの権限 ---

# オブジェクトの一覧取得はバケット単位でしか許可できないため、条件なしで付与する
resource "google_storage_bucket_iam_member" "state_list" {
  for_each = local.terraform_service_accounts

  bucket = google_storage_bucket.tfstate.name
  role   = "roles/storage.legacyBucketReader"
  member = google_service_account.terraform[each.key].member
}

# tf-plan は envs/ 以下の state を読むだけ（bootstrap の state は読めない）
resource "google_storage_bucket_iam_member" "state_plan" {
  bucket = google_storage_bucket.tfstate.name
  role   = "roles/storage.objectViewer"
  member = google_service_account.terraform["tf-plan"].member

  condition {
    title      = "envs-state-only"
    expression = "resource.name.startsWith(\"${local.state_object_prefix}/envs/\")"
  }
}

# tf-apply-<env> は自分の環境の state だけを読み書きできる
resource "google_storage_bucket_iam_member" "state_apply" {
  for_each = toset(local.env_names)

  bucket = google_storage_bucket.tfstate.name
  role   = "roles/storage.objectUser"
  member = google_service_account.terraform["tf-apply-${each.key}"].member

  condition {
    title      = "envs-${each.key}-state-only"
    expression = "resource.name.startsWith(\"${local.state_object_prefix}/envs/${each.key}/\")"
  }
}
