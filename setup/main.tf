```terraform
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
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
  region  = "us-central1" 
}

resource "google_compute_instance_template" "default" {
  name_prefix  = "appserver-template-"
  machine_type = "e2-medium"
  network_interface {
    network = "default"
  }
  disk {
    source_image = "debian-cloud/debian-11"
  }
  metadata_startup_script = "#!/bin/bash
    apt-get update
    apt-get install -y nginx
    service nginx start
  "
 advanced_machine_features {
    enable_nested_virtualization = false
  }
}

resource "google_compute_instance_group_manager" "mig_zone1" {
 name = "mig-zone1"
  base_instance_name = "appserver-zone1"
  version {
    instance_template = google_compute_instance_template.default.id
    name              = "primary"
  }
  zone = "us-central1-a"
  target_size = 2
}

resource "google_compute_instance_group_manager" "mig_zone2" {
 name = "mig-zone2"
  base_instance_name = "appserver-zone2"
  version {
    instance_template = google_compute_instance_template.default.id
    name              = "primary"
  }
  zone = "us-central1-f"
  target_size = 2
}

resource "google_sql_database_instance" "default" {
  name             = "cloudsql-instance"
  region           = "us-central1"
  database_version = "MYSQL_8_0"
  settings {
    tier = "db-f1-micro"
    availability_type = "ZONAL"
  }
}

resource "google_sql_database_instance" "replica" {
  name                = "cloudsql-replica"
  master_instance_name = google_sql_database_instance.default.name
  region              = "us-central1"
  database_version    = "MYSQL_8_0"
  settings {
    tier = "db-f1-micro"
    availability_type = "ZONAL"
  }
}

resource "google_compute_health_check" "http" {
  name               = "http-basic-check"
  http_health_check {
    port         = 80
    request_path = "/"
  }
}

resource "google_compute_backend_service" "default" {
  name                  = "backend-service"
  port_name             = "http"
  protocol              = "HTTP"
  timeout_sec           = 10
  health_checks         = [google_compute_health_check.http.id]
}

resource "google_compute_backend_service_group" "mig1" {
  backend_service = google_compute_backend_service.default.id
  instance_group  = google_compute_instance_group_manager.mig_zone1.instance_group
  zone            = "us-central1-a"
}

resource "google_compute_backend_service_group" "mig2" {
  backend_service = google_compute_backend_service.default.id
  instance_group  = google_compute_instance_group_manager.mig_zone2.instance_group
  zone            = "us-central1-f"
}

resource "google_compute_url_map" "default" {
  name            = "url-map"
  description     = "a description"
  default_service = google_compute_backend_service.default.id
  host_rule {
    hosts        = ["*"]
    path_matcher = "allpaths"
  }
  path_matcher {
    name            = "allpaths"
    default_service = google_compute_backend_service.default.id
  }
}


resource "google_compute_target_http_proxy" "default" {
  name        = "target-http-proxy"
  url_map     = google_compute_url_map.default.id
  description = "a description"
}

resource "google_compute_global_forwarding_rule" "default" {
  name                  = "forwarding-rule"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL"
  port_range            = "80"
  target                = google_compute_target_http_proxy.default.id
}
```
