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

provider "google" {
  project = "mizuki-demo-joonix"
  region  = "asia-northeast1"
}

resource "google_compute_instance" "vm1" {
  name         = "vm1"
  machine_type = "e2-standard-2"
  zone         = "asia-northeast1-a" 
  network_interface {
    network = "default"
  }
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11" 
    }
  }
}

resource "google_storage_bucket" "default" {
  name                        = "mizuki-demo-joonix-bucket"
  location                    = "ASIA-NORTHEAST1" 
  storage_class              = "STANDARD"
  uniform_bucket_level_access = true
}