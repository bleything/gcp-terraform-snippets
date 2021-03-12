### Important Note!
#
# one thing you'll see in this file is that we specify the project on every
# resource. Inside a module it's generally best to be explicit about projects.
# This allows you to create resources within different projects by creating
# multiple instances of the module rather than having to create multiple
# providers or configs.
#
# tl;dr: pass the project ID into a module and specify it on every resource
# unless you're extremely sure you're never going to be working in more than one
# project at once.

# we'll need this later to look up the project number
data "google_project" "project" {
  project_id = var.gcp_project
}

resource "google_project_service" "api" {
  project = var.gcp_project

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
  project       = var.gcp_project
  name          = "${var.gcp_project}-input"
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
  project       = var.gcp_project
  name          = "${var.gcp_project}-output"
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
  project  = var.gcp_project
  name     = "imgproc"
  location = "us-central1"

  template {
    spec {
      containers {
        image = "gcr.io/${var.gcp_project}/imageproc-tf"

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
  project = var.gcp_project
  name    = "imgproc-notifications"
}

# look up the default storage SA
data "google_storage_project_service_account" "default" {
  project = var.gcp_project
}

# give the SA `roles/pubsub.publisher` on the topic
resource "google_pubsub_topic_iam_binding" "notifications" {
  project = var.gcp_project
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
  project    = var.gcp_project
  account_id = "cloud-run-invoker"
}

# then give the SA `roles/run.invoker` on the Run service
resource "google_cloud_run_service_iam_binding" "invoker" {
  project  = var.gcp_project
  location = google_cloud_run_service.imgproc.location
  service  = google_cloud_run_service.imgproc.name
  role     = "roles/run.invoker"
  members = [
    "serviceAccount:${google_service_account.run_invoker.email}"
  ]
}

# make sure pubsub can create oauth tokens
resource "google_project_iam_binding" "pubsub_token_creator" {
  project = var.gcp_project
  role    = "roles/iam.serviceAccountTokenCreator"
  members = [
    "serviceAccount:service-${data.google_project.project.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
  ]
}

# create a push subscription
resource "google_pubsub_subscription" "subscription" {
  project = var.gcp_project
  name    = "imgproc"
  topic   = google_pubsub_topic.topic.name

  push_config {
    push_endpoint = google_cloud_run_service.imgproc.status[0].url

    oidc_token {
      service_account_email = google_service_account.run_invoker.email
    }
  }
}
