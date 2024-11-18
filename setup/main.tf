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


resource "google_compute_instance" "vm_instance" {
  name         = "vm1"
  machine_type = "e2-standard-2"
  zone         = "asia-northeast1-a" # Replace with your desired zone
 network_interface {
    subnetwork = "projects/mizuki-demo-joonix/regions/asia-northeast1/subnetworks/default"
    # Access config required to give the instance a public IP address
    access_config {
      # Ephemeral IP is fine for a demo environment, but consider reserving a static IP for production
    }
  }

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11" # Replace with your desired image
    }
  }
}

resource "google_storage_bucket" "default" {
  name                        = "mizuki-demo-joonix-gcs-bucket" # Provide a unique bucket name
  location                    = "asia-northeast1"
  uniform_bucket_level_access = true # Optional: Enable uniform bucket-level access for simplicity
 storage_class = "STANDARD"
}