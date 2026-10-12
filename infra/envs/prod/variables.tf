variable "project_id" {
  description = "GCP プロジェクト ID（CI では TF_VAR_project_id で渡す）"
  type        = string
}

variable "workload_identity_provider" {
  description = "WIF プロバイダのリソース名（CI では TF_VAR_workload_identity_provider で渡す）"
  type        = string
}
