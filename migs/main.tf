### Terraform snippets for MIGs
#
# You probably want instance_templates.tf or migs.tf.

provider "google" {
  project = "bleything-terraform-sandbox"
  zone    = "us-central1-a"
}

# this is used for various examples elsewhere in the repo
resource "google_compute_subnetwork" "example_subnet" {
  name          = "example-subnet"
  ip_cidr_range = "10.11.12.0/24"
  network       = "default"
}
