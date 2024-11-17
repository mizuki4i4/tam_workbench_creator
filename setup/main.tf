```terraform
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"  # Stick with original version to avoid conflicts
    }
  }
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

data "google_compute_network" "default" {
  name = "default"
}

resource "google_compute_instance_template" "default" {
  name_prefix  = "web-app-"
  machine_type = "e2-medium"
  network_interface {
    network = data.google_compute_network.default.id
  }

  disk {
    source_image = "debian-cloud/debian-11"
    disk_size_gb = 100
  }
}

resource "google_compute_region_instance_group_manager" "mig_zone1" {
  name               = "mig-zone1"
  base_instance_name = "web-app-zone1"
  version {
    instance_template = google_compute_instance_template.default.id
    name              = "primary"
  }

  auto_healing_policies {
    initial_delay_sec = 300
    health_check = google_compute_health_check.http.id
  }
  target_size = 2
  distribution_policy_zones = ["asia-northeast1-a"]
}

resource "google_compute_region_instance_group_manager" "mig_zone2" {
  name               = "mig-zone2"
  base_instance_name = "web-app-zone2"
  version {
    instance_template = google_compute_instance_template.default.id
    name              = "primary"
  }
  auto_healing_policies {
    initial_delay_sec = 300
    health_check = google_compute_health_check.http.id
  }
  target_size = 2
  distribution_policy_zones = ["asia-northeast1-f"]
}

resource "google_compute_health_check" "http" {
  name               = "http-health-check"
  http_health_check {
    port = 80
  }
}

resource "google_compute_backend_service" "default" {
  name                  = "backend-service"
  health_checks         = [google_compute_health_check.http.id]
  protocol              = "HTTP"
  load_balancing_scheme = "EXTERNAL"


  backend {
    group = google_compute_region_instance_group_manager.mig_zone1.instance_group
  }
  backend {
    group = google_compute_region_instance_group_manager.mig_zone2.instance_group
  }
}

resource "google_compute_url_map" "default" {
  name            = "url-map"
  default_service = google_compute_backend_service.default.id
}

resource "google_compute_target_http_proxy" "default" {
  name    = "http-proxy"
  url_map = google_compute_url_map.default.id
}

resource "google_compute_forwarding_rule" "default" {
  name               = "forwarding-rule"
  ip_protocol        = "TCP"
  port_range         = "80"
  target             = google_compute_target_http_proxy.default.id
  load_balancing_scheme = "EXTERNAL"
}
```