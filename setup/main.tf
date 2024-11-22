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
    source_image = "centos-cloud/centos-7"
    auto_delete  = true
    boot         = true
  }
}

resource "google_compute_instance_group_manager" "mig" {
  project             = "mizuki-demo-joonix"
  name                = "app-instance-group-manager"
  base_instance_name = "app-vm"
  version {
    instance_template = google_compute_instance_template.tpl.id
    name              = "primary"
  }
  zone        = "asia-northeast1-b"
  target_size = 2
}

resource "google_compute_health_check" "http" {
  project = "mizuki-demo-joonix"
  name               = "http-basic-check"
  http_health_check {
    port         = "80"
    request_path = "/"
  }
}

resource "google_compute_backend_service" "default" {
  project        = "mizuki-demo-joonix"
  name           = "backend-service"
  port_name      = "http"
  protocol       = "HTTP"
  timeout_sec    = 10
  health_checks = [google_compute_health_check.http.id]
}

resource "google_compute_target_http_proxy" "default" {
  project = "mizuki-demo-joonix"
  name    = "http-lb-proxy"
  url_map = google_compute_url_map.urlmap.id
}

resource "google_compute_url_map" "urlmap" {
  project = "mizuki-demo-joonix"
  name            = "urlmap"
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
        response_headers_to_remove = ["X-Forwarded-For"]
        response_headers_to_add {
          header_name  = "X-Forwarded-For"
          header_value = "127.0.0.1"
          replace = true
        }
      }
      match_rules {
        full_path_match = "/*"
        header_matches {
          name        = "User-Agent"
          exact_match = "Mozilla/*"
        }
      }
      url_redirect {
        https_redirect = false
        strip_query   = false
        path_redirect = "/some/path"
      }
    }
  }
  test {
    service = google_compute_backend_service.default.id
    host    = "*"
    path    = "/"
  }
}

resource "google_compute_forwarding_rule" "http" {
  project       = "mizuki-demo-joonix"
  name          = "http-content-rule"
  ip_protocol   = "TCP"
  port_range    = "80"
  target_http_proxy = google_compute_target_http_proxy.default.id
}

resource "google_compute_backend_service_group_health" "default" {
  backend_service = google_compute_backend_service.default.id
  group           = google_compute_instance_group_manager.mig.instance_group
}