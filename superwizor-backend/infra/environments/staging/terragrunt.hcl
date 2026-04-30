include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../..//environments/staging"
}

inputs = {
  project_id = "superwizor-staging"
}
