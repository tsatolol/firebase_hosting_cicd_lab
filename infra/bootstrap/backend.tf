# state は admin プロジェクトの GCS バケットに置く。
# バケット名は bootstrap で作るため、init 時に -backend-config="bucket=..." で渡す。
# 初回の apply だけは backend_override.tf（ローカル state）を使う。手順は docs/setup.md を参照。
terraform {
  backend "gcs" {
    prefix = "bootstrap"
  }
}
