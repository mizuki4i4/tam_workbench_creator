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
  project = "mizuki-demo-joonix"
  region  = "asia-northeast1"
  name_prefix  = "default-instance-template-"
  advanced_machine_features {
    enable_nested_virtualization = false
  }

 machine_type = "e2-medium"
  disk {
    source_image = "debian-cloud/debian-11"
    auto_delete  = true
    boot         = true
  }
  network_interface {
    network = "default"
  }


}

resource "google_compute_instance_group_manager" "mig" {
  project = "mizuki-demo-joonix"
  zone = "asia-northeast1-b" # Replace with your desired zone
  name = "mig-joonix"
  version {
 instance_template = google_compute_instance_template.tpl.id
 name              = "primary"
  }
 base_instance_name = "mig-joonix-vm"
  target_size = 2 # Replace with your desired number of instances

}


resource "google_compute_health_check" "http" {
  project     = "mizuki-demo-joonix"
  name        = "http-health-check"
  http_health_check {
    port         = "80"
 request_path = "/"
  }
}


resource "google_compute_backend_service" "default" {
 project = "mizuki-demo-joonix"
  name = "backend-service-joonix"
  port_name = "http"
 protocol = "HTTP"
  health_checks = [google_compute_health_check.http.id]
 timeout_sec = 10
}

resource "google_compute_target_instance" "default" {
  count = 2
 project = "mizuki-demo-joonix"
  zone = "asia-northeast1-b"
  name = "target-instance-${count.index}"
 instance = google_compute_instance_group_manager.mig.id
}


resource "google_compute_url_map" "urlmap" {
  project = "mizuki-demo-joonix"
 name = "urlmap-joonix"

  default_service = google_compute_backend_service.default.id

  host_rule {
    hosts        = ["*"]
    path_matcher = "allpaths"
  }

  path_matcher {
    name            = "allpaths"
    default_service = google_compute_backend_service.default.id

    route_rules {
      priority = 1
      header_action {
        request_headers_to_remove = ["X-Forwarded-For"]
      }
      match_rules {
 full_path_match = "/*"
      }
      url_redirect {
 redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
        https_redirect        = false
        strip_query           = false
      }
    }
  }

}

resource "google_compute_target_http_proxy" "default" {
  project = "mizuki-demo-joonix"
  name    = "http-proxy-joonix"
  url_map = google_compute_url_map.urlmap.id
}

resource "google_compute_forwarding_rule" "default" {
  project = "mizuki-demo-joonix"
  name    = "forwarding-rule-joonix"
  region  = "asia-northeast1"
  ip_protocol = "TCP"
  load_balancing_scheme = "EXTERNAL"
 target_http_proxy = google_compute_target_http_proxy.default.id
}