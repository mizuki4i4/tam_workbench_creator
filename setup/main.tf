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
    source_image = "centos-cloud/centos-7"
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
  name = "mizuki-demo-joonix-mig"
  project = "mizuki-demo-joonix"
  target_size = 2
  version {
 instance_template = google_compute_instance_template.tpl.id
    name              = "primary"
  }
  zone = "asia-northeast1-b"
  wait_for_instances = false # or true, depending on your needs
}


resource "google_compute_health_check" "http" {
  check_interval_sec = 5
 healthy_threshold  = 2
  http_health_check {
    port         = "80"
    proxy_header = "NONE"
    request_path = "/"
  }
  name               = "mizuki-demo-joonix-http-hc"
  project            = "mizuki-demo-joonix"
 timeout_sec         = 5
  unhealthy_threshold = 2
}



resource "google_compute_backend_service" "default" {
 connection_draining_timeout_sec = 300
  health_checks                    = [google_compute_health_check.http.id]
 load_balancing_scheme            = "EXTERNAL"
  name                            = "mizuki-demo-joonix-backend-service"
 port_name                       = "http"
 protocol                        = "HTTP"
  project                         = "mizuki-demo-joonix"
 timeout_sec                      = 30
}

resource "google_compute_url_map" "default" {
 default_service      = google_compute_backend_service.default.id
  description          = "a description"
 host_rule {
    hosts        = ["*"]
    path_matcher = "allpaths"
  }
  name                = "mizuki-demo-joonix-url-map"
  path_matcher {
 default_service = google_compute_backend_service.default.id
    name            = "allpaths"
    route_rules {
      header_action {
 request_headers_to_add {
          header_name  = "X-Forwarded-For"
          header_value = "127.0.0.1"
          replace       = true
        }
      }
      match_rules {
        full_path_match = "/*"
        header_matches {
          exact_match = "text/html"
          header_name = "Content-Type"
          invert_match = false
        }
      }
      priority = 1
      service = google_compute_backend_service.default.id
      # The url_redirect block is commented out as it conflicts with default_service
      # url_redirect {
      #   host_redirect = "www.example.com"
      #   https_redirect  = false
      #   path_redirect = "/"
      #   redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
      #   strip_query   = true
      # }
    }
  }
 project = "mizuki-demo-joonix"
}


resource "google_compute_target_http_proxy" "default" {
 name    = "mizuki-demo-joonix-http-proxy"
 project = "mizuki-demo-joonix"
 url_map = google_compute_url_map.default.id
}


resource "google_compute_target_https_proxy" "default" {
  name             = "mizuki-demo-joonix-https-proxy"
 project          = "mizuki-demo-joonix"
  # You MUST provide valid SSL certificates here.  Placeholders are not sufficient.
 ssl_certificates = [google_compute_ssl_certificate.default.id] # Replace with actual SSL certificates
 url_map          = google_compute_url_map.default.id
}

resource "google_compute_ssl_certificate" "default" {
  name_prefix = "mizuki-demo-joonix-ssl-cert-"
  private_key = file("path/to/private.key") # Replace with your private key file
  certificate = file("path/to/certificate.crt")  # Replace with your certificate file
}



resource "google_compute_global_forwarding_rule" "http" {
 ip_protocol    = "TCP"
  load_balancing_scheme = "EXTERNAL"
  name                  = "mizuki-demo-joonix-http-forwarding-rule"
  port_range            = "80"
 project               = "mizuki-demo-joonix"
  target                = google_compute_target_http_proxy.default.id
}


resource "google_compute_global_forwarding_rule" "https" {
 ip_protocol    = "TCP"
  load_balancing_scheme = "EXTERNAL"
  name                  = "mizuki-demo-joonix-https-forwarding-rule"
  port_range            = "443"
 project               = "mizuki-demo-joonix"
  target                = google_compute_target_https_proxy.default.id
}


Key changes and explanations:

* **`wait_for_instances` in `google_compute_instance_group_manager`:**  Set to `false` for faster creation, but be aware instances might not be ready immediately after apply.  Consider setting to `true` in production or if you need instances to be immediately available.
* **`url_redirect` conflict:**  The `url_redirect` block within the `route_rules` was commented out.  It conflicts with `default_service` because you can't have both a redirect and a default service for the same path matcher.  You must choose one or the other depending on your desired behavior.
* **SSL Certificate:**  Placeholders for SSL certificates have been replaced with a resource `google_compute_ssl_certificate.default` and its `id` is used in the `google_compute_target_https_proxy`. **You MUST replace the example paths to your private key and certificate files.** You can use other methods to generate or import certificates as needed. You can't use placeholder values; you need actual certificates for HTTPS to work.


This revised code provides a more complete and functional configuration.  Remember to replace the placeholder file paths for your SSL certificate with your actual files.  Choose between redirect or default service in the URL map based on your requirements.  And finally, consider the implications of `wait_for_instances` in your environment.