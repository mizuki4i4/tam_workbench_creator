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

resource "google_compute_instance_template" "tpl" {
  project      = "mizuki-demo-joonix"
  name_prefix  = "app-instance-template-"
  machine_type = "e2-medium"
  network_interface {
    network = "default"
  }
  disk {
    source_image = "debian-cloud/debian-11"
    boot         = true
  }

  metadata_startup_script = "#!/bin/bash\napt update\napt install -y nginx\nservice nginx start"
}

resource "google_compute_health_check" "http" {
  project = "mizuki-demo-joonix"
  name               = "http-basic-check"
  http_health_check {
    port         = "80"
    request_path = "/"
  }
}


resource "google_compute_instance_group_manager" "mig" {
  project              = "mizuki-demo-joonix"
  name                = "app-instance-group-manager"
  base_instance_name = "app-instance"
  version {
    instance_template = google_compute_instance_template.tpl.id
    name              = "primary"
  }
  target_size = 2
  zone        = "asia-northeast1-a" 

}


resource "google_compute_backend_service" "default" {
  project      = "mizuki-demo-joonix"
  name                  = "app-backend-service"
  port_name             = "http"
  protocol              = "HTTP"
  timeout_sec           = 10
  health_checks        = [google_compute_health_check.http.id]
}


resource "google_compute_backend_service_group_health" "default" {
 project = "mizuki-demo-joonix"
 backend_service = google_compute_backend_service.default.id
  group          = google_compute_instance_group_manager.mig.id
}

resource "google_compute_url_map" "default" {
  project = "mizuki-demo-joonix"
  name            = "app-url-map"
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
  project = "mizuki-demo-joonix"
  name    = "app-http-proxy"
  url_map = google_compute_url_map.default.id
}

resource "google_compute_ssl_certificate" "default" {
  project = "mizuki-demo-joonix"
  name        = "app-ssl-cert"
  private_key = file("path/to/private.key") 
  certificate = file("path/to/certificate.crt") 
}

resource "google_compute_target_https_proxy" "default" {
  project          = "mizuki-demo-joonix"
  name             = "app-https-proxy"
  url_map          = google_compute_url_map.default.id
  ssl_certificates = [google_compute_ssl_certificate.default.id]
}

resource "google_compute_global_forwarding_rule" "http" {
 project = "mizuki-demo-joonix"
  name    = "http-forwarding-rule"
  target  = google_compute_target_http_proxy.default.id
  ip_protocol = "TCP"
  port_range = "80"
}

resource "google_compute_global_forwarding_rule" "https" {
 project = "mizuki-demo-joonix"
  name    = "https-forwarding-rule"
  target  = google_compute_target_https_proxy.default.id
  ip_protocol = "TCP"
  port_range = "443"
}
```