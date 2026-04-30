remote_state {
  backend = "gcs"
  config = {
    bucket   = "superwizor-tfstate-eu2"
    prefix   = "${path_relative_to_include()}"
    project  = "superwizor-tfstate"
    location = "europe-central2"
  }
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<TF
terraform {
  required_version = ">= 1.7"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 6.0"
    }
  }
}

provider "google" {
  region = "europe-central2"
}

provider "google-beta" {
  region = "europe-central2"
}
TF
}
