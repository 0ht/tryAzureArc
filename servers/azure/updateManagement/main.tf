// An Azure resource group
resource "azurerm_resource_group" "azure_rg" {
  name     = var.azure_resource_group
  location = var.azure_location
}

// A single Google Cloud Engine instance
// windows
resource "google_compute_instance" "win" {
  name         = "arc-gcp-demo-win2019"
  machine_type = "n2-standard-2"
  zone         = var.gcp_zone

  boot_disk {
    initialize_params {
      image = "windows-cloud/windows-2019"
    }
  }
  network_interface {
    network = "default"

    access_config {
      // Include this section to give the VM an external ip address
    }
  }
  metadata = {
    windows-startup-script-ps1 = local_file.install_arc_agent_ps1.content
  }

}

resource "local_file" "install_arc_agent_ps1" {
  content = templatefile("scripts/install_arc_agent.ps1.tmpl", {
    resourceGroup  = var.azure_resource_group
    location       = var.azure_location
    subscriptionId = var.subscription_id
    appId          = var.client_id
    appPassword    = var.client_secret
    tenantId       = var.tenant_id
    }
  )
  filename = "scripts/install_arc_agent.ps1"
}

// ubuntu
resource "google_compute_instance" "ubuntu" {
  name         = "arc-gcp-demo-ubuntu1804"
  machine_type = "e2-micro"
  zone         = var.gcp_zone

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-1804-lts"
    }
  }

  network_interface {
    network = "default"

    access_config {
      // Include this section to give the VM an external ip address
    }
  }
  metadata = {
    ssh-keys = "${var.admin_username}:${file("~/.ssh/id_rsa.pub")}"
  }
  provisioner "file" {
    source      = "scripts/vars.sh"
    destination = "/tmp/vars.sh"

    connection {
      type        = "ssh"
      host        = google_compute_instance.ubuntu.network_interface.0.access_config.0.nat_ip
      user        = var.admin_username
      private_key = file("~/.ssh/id_rsa")
      timeout     = "2m"
    }
  }
  provisioner "file" {
    source      = "scripts/install_arc_agent.sh"
    destination = "/tmp/install_arc_agent.sh"

    connection {
      type        = "ssh"
      host        = google_compute_instance.ubuntu.network_interface.0.access_config.0.nat_ip
      user        = var.admin_username
      private_key = file("~/.ssh/id_rsa")
      timeout     = "2m"
    }
  }
  provisioner "remote-exec" {
    inline = [
      "sudo apt-get install -y python-ctypes",
      "sudo chmod +x /tmp/install_arc_agent.sh",
      "/tmp/install_arc_agent.sh",
    ]

    connection {
      type        = "ssh"
      host        = google_compute_instance.ubuntu.network_interface.0.access_config.0.nat_ip
      user        = var.admin_username
      private_key = file("~/.ssh/id_rsa")
      timeout     = "2m"
    }
  }
}

resource "local_file" "install_arc_agent_sh" {
  content = templatefile("scripts/install_arc_agent.sh.tmpl", {
    resourceGroup = var.azure_resource_group
    location      = var.azure_location
    }
  )
  filename = "scripts/install_arc_agent.sh"
}


// A variable for extracting the external ip of the instance
// ubuntu
output "ip_ubuntu" {
  value = google_compute_instance.ubuntu.network_interface.0.access_config.0.nat_ip
}

// windows instance
output "ip_windows" {
  value = google_compute_instance.win.network_interface.0.access_config.0.nat_ip
}