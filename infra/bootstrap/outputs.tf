output "project_ids" {
  description = "作成したプロジェクトの ID"
  value       = { for env, project in google_project.this : env => project.project_id }
}

output "tfstate_bucket" {
  description = "Terraform state を保存するバケット名"
  value       = google_storage_bucket.tfstate.name
}

output "workload_identity_provider" {
  description = "google-github-actions/auth の workload_identity_provider に渡す値"
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "terraform_service_accounts" {
  description = "Terraform 用 SA のメールアドレス"
  value       = { for name, sa in google_service_account.terraform : name => sa.email }
}

output "github_variables_commands" {
  description = "GitHub Variables を登録する gh コマンド（Environment を作成してから実行する）"
  value       = <<-EOT
    gh variable set GCP_WIF_PROVIDER --body '${google_iam_workload_identity_pool_provider.github.name}'
    gh variable set TF_STATE_BUCKET --body '${google_storage_bucket.tfstate.name}'
    gh variable set TF_PLAN_SA --body '${google_service_account.terraform["tf-plan"].email}'
    gh variable set STG_PROJECT_ID --body '${google_project.this["stg"].project_id}'
    gh variable set PROD_PROJECT_ID --body '${google_project.this["prod"].project_id}'
    gh variable set GCP_PROJECT_ID --env stg --body '${google_project.this["stg"].project_id}'
    gh variable set GCP_PROJECT_ID --env prod --body '${google_project.this["prod"].project_id}'
    gh variable set GCP_PROJECT_ID --env infra-stg --body '${google_project.this["stg"].project_id}'
    gh variable set GCP_PROJECT_ID --env infra-prod --body '${google_project.this["prod"].project_id}'
    gh variable set TF_APPLY_SA --env infra-stg --body '${google_service_account.terraform["tf-apply-stg"].email}'
    gh variable set TF_APPLY_SA --env infra-prod --body '${google_service_account.terraform["tf-apply-prod"].email}'
  EOT
}
