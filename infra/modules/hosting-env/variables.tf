variable "project_id" {
  description = "Firebase Hosting を有効にする GCP プロジェクト ID（bootstrap で作成済み）"
  type        = string
}

variable "env" {
  description = "環境名（stg / prod）"
  type        = string

  validation {
    condition     = contains(["stg", "prod"], var.env)
    error_message = "env は stg か prod を指定してください。"
  }
}

variable "workload_identity_provider" {
  description = "bootstrap の WIF プロバイダのリソース名（projects/<番号>/locations/global/workloadIdentityPools/github/providers/github-actions）"
  type        = string

  validation {
    condition     = can(regex("^projects/[0-9]+/locations/global/workloadIdentityPools/[^/]+/providers/[^/]+$", var.workload_identity_provider))
    error_message = "workload_identity_provider は projects/<番号>/locations/global/workloadIdentityPools/<プール>/providers/<プロバイダ> の形式で指定してください。"
  }
}

variable "github_repository" {
  description = "デプロイを許可する GitHub リポジトリ（owner/repo）"
  type        = string
  default     = "tsatolol/firebase_hosting_cicd_lab"
}

variable "github_repository_owner_id" {
  description = "GitHub リポジトリのオーナーの数値 ID（OIDC トークンの sub に含まれる）"
  type        = string
  default     = "30972312"
}

variable "github_repository_id" {
  description = "GitHub リポジトリの数値 ID（OIDC トークンの sub に含まれる）"
  type        = string
  default     = "1415534725"
}

variable "deployer_subjects" {
  description = "デプロイ用 SA を使える GitHub OIDC トークンの sub のうち、リポジトリ部分より後ろ（例: environment:stg, pull_request）"
  type        = list(string)
}

variable "deletion_protection" {
  description = "true にすると Hosting サイトを Terraform から削除できなくする"
  type        = bool
  default     = false
}
