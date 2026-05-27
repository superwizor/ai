variable "project_id" { type = string }

resource "google_artifact_registry_repository" "services" {
  project       = var.project_id
  location      = "europe-central2"
  repository_id = "services"
  description   = "Docker images for SuperWizor microservices"
  format        = "DOCKER"

  cleanup_policies {
    id     = "keep-last-30"
    action = "KEEP"
    most_recent_versions {
      keep_count = 30
    }
  }

  cleanup_policies {
    id     = "delete-untagged-after-7d"
    action = "DELETE"
    condition {
      tag_state  = "UNTAGGED"
      older_than = "604800s" # 7 days
    }
  }
}

output "registry_url" {
  value = "europe-central2-docker.pkg.dev/${var.project_id}/services"
}
