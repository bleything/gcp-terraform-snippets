provider "google" {
  credentials = "../terraform-sa.key"

  # technically not necessary for this file since we pass the project in to the
  # module explicitly but it's a good habit to specify here so future resources
  # can reference it
  project = "REPLACE_ME"
}

module "imgproc" {
  source      = "./modules/imgproc"
  gcp_project = "REPLACE_ME"
}
