include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../..//environments/staging"
}

inputs = {
  project_id = "superwizor-ai-25ecd"
}
