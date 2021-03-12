output "input_bucket" {
  value = google_storage_bucket.input.url
}

output "output_bucket" {
  value = google_storage_bucket.output.url
}

output "run_service_url" {
  value = google_cloud_run_service.imgproc.status[0].url
}
