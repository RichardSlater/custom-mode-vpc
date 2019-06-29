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

data "google_project" "project" {}

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

resource "google_project_service" "iam" {
  service = "iam.googleapis.com"

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

resource "google_project_iam_custom_role" "base_compute_role" {
  role_id = "base_compute_role"
  title   = "Base Compute Role"
  permissions = [
    "logging.logEntries.create",
    "monitoring.metricDescriptors.create",
    "monitoring.metricDescriptors.get",
    "monitoring.metricDescriptors.list",
    "monitoring.monitoredResourceDescriptors.get",
    "monitoring.monitoredResourceDescriptors.list",
    "monitoring.timeSeries.create"
  ]

  depends_on = ["google_project_service.iam"]
}

resource "google_service_account" "backend_service_account" {
  account_id   = "backend"
  display_name = "Backend Service"
}

resource "google_project_iam_member" "backend_service_account_role_binding" {
  role   = "projects/${data.google_project.project.project_id}/roles/${google_project_iam_custom_role.base_compute_role.role_id}"
  member = "serviceAccount:${google_service_account.backend_service_account.email}"

  depends_on = [
    "data.google_project.project",
    "google_project_iam_custom_role.base_compute_role",
    "google_service_account.backend_service_account"
  ]
}

resource "google_service_account" "frontend_service_account" {
  account_id   = "frontend"
  display_name = "Frontend Service"
}

resource "google_project_iam_member" "frontend_service_account_role_binding" {
  role   = "projects/${data.google_project.project.project_id}/roles/${google_project_iam_custom_role.base_compute_role.role_id}"
  member = "serviceAccount:${google_service_account.frontend_service_account.email}"

  depends_on = [
    "data.google_project.project",
    "google_project_iam_custom_role.base_compute_role",
    "google_service_account.frontend_service_account"
  ]
}

resource "google_compute_instance_template" "frontend_instance_template" {
  name = "frontend-template"

  instance_description = "Frontend Instances"
  machine_type         = "f1-micro"
  can_ip_forward       = false

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
  }

  disk {
    source_image = "debian-cloud/debian-9"
    auto_delete  = true
    boot         = true
  }

  network_interface {
    network = "${google_compute_network.frontend_network.name}"
  }

  service_account {
    email  = "serviceAccount:${google_service_account.frontend_service_account.email}"
    scopes = ["default"]
  }

  depends_on = [
    "google_compute_network.frontend_network",
    "google_service_account.frontend_service_account"
  ]
}

resource "google_compute_instance_template" "backend_instance_template" {
  name = "backend-template"

  instance_description = "Backend Instances"
  machine_type         = "f1-micro"
  can_ip_forward       = false

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
  }

  disk {
    source_image = "debian-cloud/debian-9"
    auto_delete  = true
    boot         = true
  }

  network_interface {
    network = "${google_compute_network.backend_network.name}"
  }

  service_account {
    email  = "serviceAccount:${google_service_account.backend_service_account.email}"
    scopes = ["default"]
  }

  depends_on = [
    "google_compute_network.backend_network",
    "google_service_account.backend_service_account"
  ]
}