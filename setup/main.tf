```terraform
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
  advanced_machine_features {
    enable_nested_virtualization = false
  }
  can_ip_forward = false
  confidential_instance_config {
    enable_confidential_compute = false
  }
  disk {
    auto_delete  = true
    boot         = true
    disk_size_gb = 100
    disk_type    = "pd-standard"
    source_image = "debian-cloud/debian-11"
    type = "PERSISTENT"
  }
  machine_type = "n1-standard-1"
  name_prefix  = "mizuki-demo-joonix-instance-template-"
  network_interface {
    subnetwork = "projects/mizuki-demo-joonix/regions/asia-northeast1/subnetworks/default"
  }
  project = "mizuki-demo-joonix"
  region  = "asia-northeast1"
  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
    preemptible         = false
  }
}

resource "google_compute_instance_group_manager" "mig" {
  base_instance_name = "mizuki-demo-joonix-mig"
  name               = "mizuki-demo-joonix-mig"
  project            = "mizuki-demo-joonix"
  region             = "asia-northeast1"
  target_size        = 2
  version {
    instance_template = google_compute_instance_template.tpl.id
    name              = "primary"
  }
  wait_for_instances        = false
  wait_for_instances_status = "STABLE"
}

resource "google_compute_health_check" "http" {
  check_interval_sec = 5
  healthy_threshold  = 2
  http_health_check {
    port         = "80"
    proxy_header = "NONE"
    request_path = "/"
  }
  name                = "mizuki-demo-joonix-http-healthcheck"
  project             = "mizuki-demo-joonix"
  timeout_sec        = 5
  unhealthy_threshold = 2
}

resource "google_compute_backend_service" "default" {
  connection_draining_timeout_sec = 30
  health_checks                    = [google_compute_health_check.http.id]
  load_balancing_scheme           = "EXTERNAL"
  name                            = "mizuki-demo-joonix-backend-service"
  port_name                       = "http"
  protocol                        = "HTTP"
  project                         = "mizuki-demo-joonix"
  region                          = "asia-northeast1"
  timeout_sec                     = 30
}

resource "google_compute_url_map" "default" {
  default_service = google_compute_backend_service.default.id
  name            = "mizuki-demo-joonix-url-map"
  project          = "mizuki-demo-joonix"
}

resource "google_compute_target_http_proxy" "default" {
  name    = "mizuki-demo-joonix-http-proxy"
  project = "mizuki-demo-joonix"
  url_map = google_compute_url_map.default.id
}

resource "google_compute_forwarding_rule" "default" {
  all_ports           = false
  allow_global_access = false
  backend_service     = google_compute_backend_service.default.id
  ip_protocol         = "TCP"
  load_balancing_scheme = "EXTERNAL"
  name                = "mizuki-demo-joonix-forwarding-rule"
  network_tier        = "PREMIUM"
  port_range          = "80"
  project             = "mizuki-demo-joonix"
  region              = "asia-northeast1"
  target_http_proxy   = google_compute_target_http_proxy.default.id
}
```
