include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../..//environments/staging"
}

inputs = {
  project_id      = "superwizor-ai-25ecd"
  # billing-svc Cloud Run URL — wstrzykiwane po pierwszym deployu.
  # Empty zostawia scheduler jobs jako paused (defensive bootstrap mode).
  billing_svc_url = "https://billing-svc-e3f32b232q-lm.a.run.app"
}
