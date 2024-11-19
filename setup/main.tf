terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
}

terraform {
  backend "gcs" {
    bucket = "tam-workbench-creator-state-bucket"
    prefix = "mizuki-demo-joonix"
  }
}

provider "google" {
  project = "mizuki-demo-joonix"
  region  = "asia-northeast1"
}

resource "google_storage_bucket" "tam_workbench_creator" {
  name          = "tam-workbench-creator-upload-bucket"
  project = "mizuki-demo-joonix"
  location      = "asia-northeast1"
  storage_class = "STANDARD"
  force_destroy = true

  versioning {
    enabled = true
  }
}

# GKE Cluster
resource "google_container_cluster" "primary" {
  name     = "standard-cluster"
  location = "asia-northeast1"
  initial_node_count = 1 # You can adjust this value

  networking_mode = "VPC_NATIVE"
  ip_allocation_policy {
    cluster_ipv4_cidr_block = "/17" # Example CIDR block
    services_ipv4_cidr_block = "/20" # Example CIDR block
  }

  # Use the default network
  network    = "projects/mizuki-demo-joonix/global/networks/default"
  subnetwork = "projects/mizuki-demo-joonix/regions/asia-northeast1/subnetworks/default" # Assuming default subnetwork exists
}


# Cloud SQL for Postgres
resource "google_sql_database_instance" "default" {
  name             = "postgres-instance"
  region           = "asia-northeast1"
  database_version = "POSTGRES_14" # Or the version you require
  settings {
    tier = "db-f1-micro" # Choose the appropriate tier
    ip_configuration {
      ipv4_enabled    = false # Private IP only (best practice)
      private_network = "projects/mizuki-demo-joonix/global/networks/default"

    }
  }

}




# Cloud Storage Bucket (for GCS)
resource "google_storage_bucket" "default" {
  name                        = "gcs-bucket-standard"
  location = "asia-northeast1"
  storage_class = "STANDARD" # Or the class you prefer
 uniform_bucket_level_access = true
}