variable "project_id" { type = string }

variable "network_name" {
  type    = string
  default = "superwizor-vpc"
}

variable "subnet_cidr" {
  type    = string
  default = "10.0.0.0/20"
}

resource "google_compute_network" "main" {
  name                    = var.network_name
  project                 = var.project_id
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "main" {
  name          = "${var.network_name}-subnet"
  project       = var.project_id
  network       = google_compute_network.main.id
  ip_cidr_range = var.subnet_cidr
  region        = "europe-central2"

  private_ip_google_access = true

  # VPC flow logs DISABLED — staging without real users doesn't need
  # network-level logging. Was INTERVAL_5_SEC / 50% / ALL_METADATA,
  # which generated ~100-200 PLN/month of Cloud Logging costs.
  # Re-enable selectively for network debugging if needed.
}

# Private Service Access dla Cloud SQL (private IP)
resource "google_compute_global_address" "private_service_range" {
  provider      = google-beta
  project       = var.project_id
  name          = "${var.network_name}-private-services"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.main.id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  provider                = google-beta
  network                 = google_compute_network.main.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_service_range.name]
  deletion_policy         = "ABANDON"
}

# Serverless VPC Access Connector dla Cloud Run → Cloud SQL
resource "google_vpc_access_connector" "main" {
  name          = "swvpc-connector"
  project       = var.project_id
  region        = "europe-central2"
  network       = google_compute_network.main.name
  ip_cidr_range = "10.8.0.0/28"
  min_instances = 2
  max_instances = 3
  machine_type  = "e2-micro"
}

output "network_id" { value = google_compute_network.main.id }
output "network_name" { value = google_compute_network.main.name }
output "subnet_id" { value = google_compute_subnetwork.main.id }
output "vpc_connector_id" { value = google_vpc_access_connector.main.id }
