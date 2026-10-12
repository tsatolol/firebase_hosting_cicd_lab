output "deployer_service_account" {
  description = "デプロイ用 SA のメールアドレス（GitHub Environment の DEPLOY_SA に登録する）"
  value       = module.hosting.deployer_service_account
}

output "hosting_url" {
  description = "Hosting サイトのデフォルト URL"
  value       = module.hosting.hosting_url
}
