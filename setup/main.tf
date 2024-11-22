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

resource "google_compute_instance" "vm_instance" {
 project      = "mizuki-demo-joonix"
  zone         = "asia-northeast1-a" 
  machine_type = "e2-standard"
  name         = "vm1"
 network_interface {
    subnetwork = "projects/mizuki-demo-joonix/regions/asia-northeast1/subnetworks/default"

  }
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11" 
    }
  }
}


resource "google_storage_bucket" "default" {
 project = "mizuki-demo-joonix"
  name                        = "mizuki-demo-joonix-gcs-bucket"
 location = "asia-northeast1"
  storage_class = "STANDARD"
 uniform_bucket_level_access = true 

}