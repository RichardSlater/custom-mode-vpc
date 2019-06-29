terraform {
  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "richard-slater"

    workspaces {
      name = "acg-gcp-custom-mode-vpc"
    }
  }
}

provider "google" {
  credentials = "${file(".credentials/terraform-service-account.json")}"
  project     = "vpc-challenge-lab-245114"
  region      = "us-east1"
}

resource "google_project_service" "serviceusage" {
  service = "serviceusage.googleapis.com"
}

resource "google_project_service" "compute" {
  service = "compute.googleapis.com"

  disable_dependent_services = true

  depends_on = ["google_project_service.serviceusage"]
}

resource "google_project_service" "cloudresourcemanager" {
  service = "cloudresourcemanager.googleapis.com"

  disable_dependent_services = true

  depends_on = ["google_project_service.serviceusage"]
}

resource "google_compute_network" "frontend_network" {
  name                    = "frontend-network"
  auto_create_subnetworks = "true"

  depends_on = ["google_project_service.compute"]
}

resource "google_compute_network" "backend_network" {
  name                    = "backend-network"
  auto_create_subnetworks = "true"

  depends_on = ["google_project_service.compute"]
}