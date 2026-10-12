terraform {
  required_version = "~> 1.16.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.6"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 8.6"
    }
  }
}

# Firebase の API はクォータプロジェクトの指定が必要なため、このプロジェクトに付け替える
provider "google" {
  user_project_override = true
  billing_project       = var.project_id
}

provider "google-beta" {
  user_project_override = true
  billing_project       = var.project_id
}
