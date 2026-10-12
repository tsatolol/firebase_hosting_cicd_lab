output "deployer_service_account" {
  description = "デプロイ用 SA のメールアドレス（GitHub Environment の DEPLOY_SA に登録する）"
  value       = google_service_account.deployer.email
}

output "hosting_url" {
  description = "Hosting サイトのデフォルト URL"
  value       = google_firebase_hosting_site.default.default_url
}
