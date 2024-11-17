resource "google_compute_instance_template" "tpl" {
  project = "mizuki-demo-joonix"
  region  = "asia-northeast1"
  name_prefix  = "mizuki-demo-joonix-template-"

  network_interface {
    network = "default"
  }

  disk {
    source_image = "centos-cloud/centos-7"
    disk_size_gb = 20
    boot         = true
  }

  machine_type = "n1-standard-1"

  metadata_startup_script = "#!/bin/bash
    yum -y update
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo 'Hello, World!' > /var/www/html/index.html"

}

resource "google_compute_instance_group_manager" "mig" {
 project = "mizuki-demo-joonix"
  name = "mizuki-demo-joonix-mig"
 zone = "asia-northeast1-b"
  version {
    instance_template = google_compute_instance_template.tpl.self_link
    name              = "primary"
  }
  base_instance_name = "mizuki-demo-joonix-instance"
 target_size = 2
}

resource "google_compute_health_check" "http" {
  project = "mizuki-demo-joonix"
  name               = "mizuki-demo-joonix-http-hc"
  http_health_check {
    port         = "80"
 request_path = "/"
  }
}

resource "google_compute_backend_service" "default" {
  project = "mizuki-demo-joonix"
  name = "mizuki-demo-joonix-backend-service"
  port_name = "http"
 protocol = "HTTP"
  health_checks = [google_compute_health_check.http.id]
  timeout_sec = 10
}

resource "google_compute_target_instance_group" "tig" {
  project = "mizuki-demo-joonix"
 zone = "asia-northeast1-b" 
  name = "mizuki-demo-joonix-tig"
  instance_group = google_compute_instance_group_manager.mig.instance_group
}

resource "google_compute_url_map" "urlmap" {
 project = "mizuki-demo-joonix"

  name            = "mizuki-demo-joonix-url-map"
  default_service = google_compute_backend_service.default.id

  host_rule {
    hosts        = ["*"]
    path_matcher = "allpaths"
  }

  path_matcher {
    name            = "allpaths"
    default_service = google_compute_backend_service.default.id

    route_rules {
      header_action {
        request_headers_to_remove = ["X-Forwarded-For"]
      }
      url_redirect {
 host_redirect = "www.example.com" 
        https_redirect         = false
        redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
        strip_query            = false
      }
    }
  }
}

resource "google_compute_target_http_proxy" "http_proxy" {
 project = "mizuki-demo-joonix"
  name    = "mizuki-demo-joonix-http-proxy"
 url_map = google_compute_url_map.urlmap.id
}

resource "google_compute_global_forwarding_rule" "http_forwarding_rule" {
  project = "mizuki-demo-joonix"
  name       = "mizuki-demo-joonix-http-forwarding-rule"
 target_http_proxy = google_compute_target_http_proxy.http_proxy.id
 ip_protocol = "TCP"
  port_range = "80"
}