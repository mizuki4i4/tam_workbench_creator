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


provider "google" {
  project = "mizuki-demo-joonix"
  region  = "asia-northeast1"
}

resource "google_cloud_scheduler_job" "startup_job" {
  name             = "startup-schedule"
  description      = "Schedule to start target server"
  schedule         = "0 9 * * *"
  time_zone        = "Asia/Tokyo"
  attempt_deadline = "320s"

  pubsub_target {
    topic_name = google_pubsub_topic.startup_topic.id
    data       = base64encode("START")
  }
}

resource "google_pubsub_topic" "startup_topic" {
  name = "startup-topic"
}

resource "google_cloud_scheduler_job" "shutdown_job" {
  name             = "shutdown-schedule"
  description      = "Schedule to stop target server"
  schedule         = "0 18 * * *"
  time_zone        = "Asia/Tokyo"
  attempt_deadline = "320s"

  pubsub_target {
    topic_name = google_pubsub_topic.shutdown_topic.id
    data       = base64encode("STOP")
  }
}

resource "google_pubsub_topic" "shutdown_topic" {
  name = "shutdown-topic"
}

resource "google_cloudfunctions2_function" "startup_function" {
  name        = "startup-function"
  location = "asia-northeast1"
  description = "Starts the target server"

  build_config {
    entry_point = "hello_http"
    runtime     = "python39"
    source {
      storage_source {
        bucket = google_storage_bucket.function_bucket.name
        object = google_storage_bucket_object.function_zip.name
      }
    }
  }

  service_config {
    max_instance_count = 3
    min_instance_count = 0
    available_memory   = "256M"
    ingress_settings           = "ALLOW_INTERNAL_ONLY"
    vpc_connector_egress_settings = "PRIVATE_RANGES_ONLY"
    vpc_connector = google_vpc_access_connector.connector.name
  }

  event_trigger {
    trigger_region = "asia-northeast1"
    event_type     = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic   = google_pubsub_topic.startup_topic.id
    retry_policy   = "RETRY_POLICY_RETRY"
  }
}

resource "google_cloudfunctions2_function" "shutdown_function" {
  name        = "shutdown-function"
  location = "asia-northeast1"
  description = "Stops the target server"

  build_config {
    entry_point = "hello_http"
    runtime     = "python39"
    source {
      storage_source {
        bucket = google_storage_bucket.function_bucket.name
        object = google_storage_bucket_object.function_zip.name
      }
    }
  }

  service_config {
    max_instance_count = 3
    min_instance_count = 0
    available_memory   = "256M"
    ingress_settings           = "ALLOW_INTERNAL_ONLY"
    vpc_connector_egress_settings = "PRIVATE_RANGES_ONLY"
    vpc_connector = google_vpc_access_connector.connector.name
  }

  event_trigger {
    trigger_region = "asia-northeast1"
    event_type     = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic   = google_pubsub_topic.shutdown_topic.id
    retry_policy   = "RETRY_POLICY_RETRY"
  }
}

resource "google_storage_bucket" "function_bucket" {
  location = "asia-northeast1"
  name                        = "mizuki-demo-joonix-function-bucket"
  uniform_bucket_level_access = true
}

resource "google_storage_bucket_object" "function_zip" {
  name   = "function-source.zip"
  bucket = google_storage_bucket.function_bucket.name
  source = "./function-source.zip"
}

resource "google_vpc_access_connector" "connector" {
  name          = "mizuki-demo-joonix-connector"
  region        = "asia-northeast1"
  ip_cidr_range = "10.8.0.0/28"
  network       = "projects/mizuki-demo-joonix/global/networks/default"
}