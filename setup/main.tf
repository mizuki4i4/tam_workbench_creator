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

resource "google_compute_instance_template" "tpl" {
  project      = "mizuki-demo-joonix"
  name_prefix  = "app-template-"
  machine_type = "e2-medium"
  network_interface {
    network = "default"
  }
  disk {
    source_image = "debian-cloud/debian-9"
  }

 # Install a simple web server for demonstration purposes.
  advanced_machine_features {
    enable_nested_virtualization = false
  }
}



resource "google_compute_instance_group_manager" "mig" {

 project      = "mizuki-demo-joonix"
  name = "app-mig"
  version {
    instance_template = google_compute_instance_template.tpl.id
    name              = "primary"
  }
  base_instance_name = "app-vm"
 zone = "asia-northeast1-a"
  target_size = 2

}

resource "google_compute_health_check" "http" {
  project = "mizuki-demo-joonix"
 name = "http-basic-check"
  http_health_check {
    port = "80"
 }
}

resource "google_compute_backend_service" "default" {
  project  = "mizuki-demo-joonix"
 name = "backend-service"
  port_name = "http"
  protocol  = "HTTP"
  timeout_sec = 10
 health_checks = [google_compute_health_check.http.id]
}

resource "google_compute_target_pool" "default" {
 project = "mizuki-demo-joonix"
 name = "target-pool"
}



resource "google_compute_forwarding_rule" "http" {
 project = "mizuki-demo-joonix"
  name = "http-forwarding-rule"
  ip_protocol = "TCP"
  load_balancing_scheme = "EXTERNAL"
  port_range            = "80"
  target                = google_compute_target_pool.default.id
}


resource "google_compute_target_pool_health_check" "default" {
  project = "mizuki-demo-joonix"
  target_pool = google_compute_target_pool.default.id
 health_check = google_compute_health_check.http.id
}


resource "google_compute_region_instance_group_manager" "mig-as-backend" {

  project = "mizuki-demo-joonix"
  name    = "mig-as-backend"
  region  = "asia-northeast1"
 version {
    instance_template = google_compute_instance_template.tpl.id
    name              = "primary"
 }
  base_instance_name = "mig-as-backend"

  distribution_policy_zones = ["asia-northeast1-a", "asia-northeast1-b", "asia-northeast1-c"]
 target_size = 2
}



resource "google_compute_region_backend_service" "default" {

 project = "mizuki-demo-joonix"
  name = "region-backend-service"
  health_checks = [google_compute_health_check.http.id]
 load_balancing_scheme = "EXTERNAL"
 protocol = "HTTP"
 timeout_sec = 10
}


resource "google_compute_region_health_check" "http" {
 project = "mizuki-demo-joonix"
  name = "region-http-basic-check"
  http_health_check {
    port = "80"
 request_path = "/"
 }

}