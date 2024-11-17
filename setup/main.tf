```terraform
resource "google_compute_region_backend_service" "default" {
 project = "mizuki-demo-joonix"
  name                  = "app-regional-backend-service"
  region                = "asia-northeast1"
  protocol              = "HTTP"
  timeout_sec           = 10
  health_checks         = [google_compute_region_health_check.http.id]
 load_balancing_scheme = "INTERNAL"
}

resource "google_compute_backend_service_group_health" "mig_health" {
  backend_service  = google_compute_region_backend_service.default.id
 group = google_compute_instance_group_manager.mig.id
}

resource "google_compute_forwarding_rule" "default" {
 project = "mizuki-demo-joonix"
  name        = "http-content-rule"
  ip_protocol = "TCP"
  port_range  = "80"

  backend_service = google_compute_region_backend_service.default.id

  network = "default"
  all_ports = true
  allow_global_access = false # Required for Internal TCP/UDP Proxy load balancers
}
```
