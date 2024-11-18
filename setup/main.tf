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
  zone         = "asia-northeast1-a" 
  machine_type = "e2-standard-2"  
  name         = "vm1"
 network_interface {
    subnetwork = "default" 
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
  location = "ASIA-NORTHEAST1"
  storage_class = "STANDARD"
  uniform_bucket_level_access = true
}