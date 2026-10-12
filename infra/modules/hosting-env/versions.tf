terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 8.6"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 8.6"
    }
  }
}
