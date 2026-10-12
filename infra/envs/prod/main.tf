module "hosting" {
  source = "../../modules/hosting-env"

  project_id                 = var.project_id
  env                        = "prod"
  workload_identity_provider = var.workload_identity_provider
  # live へのデプロイ（Environment prod。承認必須）のみ
  deployer_subjects   = ["environment:prod"]
  deletion_protection = true
}
