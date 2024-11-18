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

# Configure the Google Cloud provider

provider "google" {
  project = "mizuki-demo-joonix"
  region  = "asia-northeast1"
}

# GKE Cluster
resource "google_container_cluster" "primary" {
  name     = "mizuki-demo-joonix-cluster"
  location = "asia-northeast1"

  network    = "default"
  subnetwork = "default"

 initial_node_count = 1

  node_config {
    machine_type = "e2-medium" # Example machine type
  }
}



# Cloud SQL for Postgres
resource "google_sql_database_instance" "default" {
  name             = "mizuki-demo-joonix-postgres"
  region           = "asia-northeast1"
  database_version = "POSTGRES_14" # Example Postgres version
  settings {
    tier = "db-f1-micro" # Example tier
  }
  deletion_protection = false # Allows for destroying in Terraform
}

# GCS Bucket
resource "google_storage_bucket" "default" {
  name                        = "mizuki-demo-joonix-storage"
  location                    = "asia-northeast1"
  storage_class               = "STANDARD"
 uniform_bucket_level_access = true
}