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

data "google_compute_network" "default" {
  name = "default"
  project = "mizuki-demo-joonix" # Add project to data source
}

resource "google_compute_instance" "vm_instance" {
 name         = "vm1"
 machine_type = "e2-standard-2"
 project      = "mizuki-demo-joonix" # Add project
 network_interface {
    network = data.google_compute_network.default.id
    subnetwork = data.google_compute_network.default.self_link
 }

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
 size  = "100"
    }
  }
}

resource "google_storage_bucket" "default" {
  name                        = "mizuki-demo-joonix-gcs"
  storage_class               = "STANDARD"
  location                    = "ASIA-NORTHEAST1"
  project                    = "mizuki-demo-joonix" # Add project
 uniform_bucket_level_access = true
}