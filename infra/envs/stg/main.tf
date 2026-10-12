module "hosting" {
  source = "../../modules/hosting-env"

  project_id                 = var.project_id
  env                        = "stg"
  workload_identity_provider = var.workload_identity_provider
  # live へのデプロイ（Environment stg）と、PR のプレビューチャネルへのデプロイ
  deployer_subjects   = ["environment:stg", "pull_request"]
  deletion_protection = false
}
