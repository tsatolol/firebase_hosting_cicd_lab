variable "billing_account_id" {
  description = "プロジェクトにリンクする課金アカウント ID（XXXXXX-XXXXXX-XXXXXX）"
  type        = string

  validation {
    condition     = can(regex("^[0-9A-F]{6}-[0-9A-F]{6}-[0-9A-F]{6}$", var.billing_account_id))
    error_message = "billing_account_id は XXXXXX-XXXXXX-XXXXXX 形式（英大文字と数字）で指定してください。"
  }
}

variable "github_repository" {
  description = "Workload Identity 連携を許可する GitHub リポジトリ（owner/repo）"
  type        = string
  default     = "tsatolol/firebase_hosting_cicd_lab"
}

variable "github_repository_owner_id" {
  description = "GitHub リポジトリのオーナーの数値 ID（オーナー名の付け替えによるなりすましを防ぐ）"
  type        = string
  default     = "30972312"
}

variable "github_repository_id" {
  description = "GitHub リポジトリの数値 ID（OIDC トークンの sub に含まれる）"
  type        = string
  default     = "1415534725"
}

variable "region" {
  description = "state バケットなどを置くリージョン"
  type        = string
  default     = "asia-northeast1"
}

variable "project_prefix" {
  description = "プロジェクト ID などの接頭辞"
  type        = string
  default     = "fhcl"
}
