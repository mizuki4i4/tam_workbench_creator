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

resource "google_compute_instance" "vm1" {
 project      = "mizuki-demo-joonix"
  zone         = "asia-northeast1-a" # default zone
  machine_type = "e2-standard-2" # default machine type
  name         = "vm1"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11" # default image
    }
  }

 network_interface {
    network = "default"
 }
}

resource "google_storage_bucket" "gcs_bucket" {
 project = "mizuki-demo-joonix"
  name                        = "mizuki-demo-joonix-gcs" # Bucket names must be globally unique
  location = "asia-northeast1" # default location
 storage_class = "STANDARD"
 uniform_bucket_level_access = true # best practice
}