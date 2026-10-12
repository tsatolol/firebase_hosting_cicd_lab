# バケット名は init 時に -backend-config="bucket=..." で渡す（GitHub Variables の TF_STATE_BUCKET）
terraform {
  backend "gcs" {
    prefix = "envs/stg"
  }
}
