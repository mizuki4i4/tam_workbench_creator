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
  name         = "apache-vm"
  zone         = "asia-northeast1-a"
 machine_type = "e2-small"
  boot_disk {
    initialize_params {
      image = "centos-cloud/centos-7"
    }
  }
 network_interface {
    network = "default"
  }

  metadata_startup_script = "#!/bin/bash
  yum update -y
  yum install httpd -y
  systemctl enable httpd
  systemctl start httpd
  "


}