provider "google" {
  credentials = "../terraform-sa.key"
  project     = "REPLACE_ME"
}

# we'll need this later to look up the project ID and number
data "google_project" "project" {}

resource "google_project_service" "api" {
  service                    = "${each.value}.googleapis.com"
  disable_on_destroy         = false
  disable_dependent_services = false

  for_each = toset([
    "cloudbuild",
    "containerregistry",
    "iam",
    "pubsub",
    "run",
    "vision",
  ])
}

### set up storage buckets

resource "google_storage_bucket" "input" {
  name          = "${data.google_project.project.name}-input"
  location      = "US"
  force_destroy = false

  lifecycle_rule {
    condition {
      age = 3
    }

    action {
      type = "Delete"
    }
  }
}

resource "google_storage_bucket" "output" {
  name          = "${data.google_project.project.name}-output"
  location      = "US"
  force_destroy = false

  lifecycle_rule {
    condition {
      age = 3
    }

    action {
      type = "Delete"
    }
  }
}

### set up cloud run service

resource "google_cloud_run_service" "imgproc" {
  name     = "imgproc"
  location = "us-central1"

  template {
    spec {
      containers {
        image = "gcr.io/${data.google_project.project.name}/imageproc-tf"

        env {
          name  = "BLURRED_BUCKET_NAME"
          value = google_storage_bucket.output.name
        }
      }
    }
  }

  # terraform doesn't know that the service needs to be enabled first, so we
  # need to give it a hint
  depends_on = [
    google_project_service.api["run"]
  ]
}

### set up the storage -> run notification

# create the topic
resource "google_pubsub_topic" "topic" {
  name = "imgproc-notifications"
}

# look up the default storage SA
data "google_storage_project_service_account" "default" {}

# give the SA `roles/pubsub.publisher` on the topic
resource "google_pubsub_topic_iam_binding" "notifications" {
  topic   = google_pubsub_topic.topic.id
  role    = "roles/pubsub.publisher"
  members = ["serviceAccount:${data.google_storage_project_service_account.default.email_address}"]
}

# configure the notification
resource "google_storage_notification" "notification" {
  bucket         = google_storage_bucket.input.name
  payload_format = "JSON_API_V1"
  topic          = google_pubsub_topic.topic.id
  event_types    = ["OBJECT_FINALIZE", "OBJECT_METADATA_UPDATE"]
  depends_on     = [google_pubsub_topic_iam_binding.notifications]
}

### set up the pubsub -> run trigger

# first create a service account
resource "google_service_account" "run_invoker" {
  account_id = "cloud-run-invoker"
}

# then give the SA `roles/run.invoker` on the Run service
resource "google_cloud_run_service_iam_binding" "invoker" {
  service  = google_cloud_run_service.imgproc.name
  location = google_cloud_run_service.imgproc.location
  role     = "roles/run.invoker"
  members = [
    "serviceAccount:${google_service_account.run_invoker.email}"
  ]
}

# make sure pubsub can create oauth tokens
resource "google_project_iam_binding" "pubsub_token_creator" {
  role = "roles/iam.serviceAccountTokenCreator"
  members = [
    "serviceAccount:service-${data.google_project.project.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
  ]
}

# create a push subscription
resource "google_pubsub_subscription" "subscription" {
  name  = "imgproc"
  topic = google_pubsub_topic.topic.name

  push_config {
    push_endpoint = google_cloud_run_service.imgproc.status[0].url

    oidc_token {
      service_account_email = google_service_account.run_invoker.email
    }
  }
}
