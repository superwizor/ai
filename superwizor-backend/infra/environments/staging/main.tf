# module "org_policies" {
#   source     = "../../modules/org-policies"
#   project_id = var.project_id
# }

module "vpc" {
  source     = "../../modules/vpc"
  project_id = var.project_id
}

module "kms" {
  source     = "../../modules/kms"
  project_id = var.project_id
  depends_on = [module.vpc]
}

module "artifact_registry" {
  source     = "../../modules/artifact-registry"
  project_id = var.project_id
}

module "cloud_sql" {
  source       = "../../modules/cloud-sql"
  project_id   = var.project_id
  network_id   = module.vpc.network_id
  kms_key_name = module.kms.database_key_id

  depends_on = [module.vpc, module.kms]
}

module "wif" {
  source      = "../../modules/wif"
  project_id  = var.project_id
  github_repo = "baciok91/superwizor-backend"
}

module "audit_logs" {
  source     = "../../modules/audit-logs"
  project_id = var.project_id
}
