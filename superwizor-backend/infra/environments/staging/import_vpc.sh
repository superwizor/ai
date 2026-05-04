#!/bin/bash
terraform import module.vpc.google_compute_subnetwork.main projects/superwizor-ai-25ecd/regions/europe-central2/subnetworks/superwizor-vpc-subnet
terraform import module.vpc.google_compute_global_address.private_service_range projects/superwizor-ai-25ecd/global/addresses/superwizor-vpc-private-services
terraform import module.vpc.google_vpc_access_connector.main projects/superwizor-ai-25ecd/locations/europe-central2/connectors/swvpc-connector
