packer {
  required_plugins {
    hcloud = {
      source  = "github.com/hetznercloud/hcloud"
      version = "~> 1"
    }
  }
}

variable "hcloud_token" {
  type      = string
  default   = "${env("HCLOUD_TOKEN")}"
  sensitive = true
}

variable "hcloud_server_type" {
  type = map(string)
  default = {
      x86 = "cx11"
      arm = "cax11"
  }
}

variable "image_base_url" {
  type = string
  default = "https://bincache.flatcar-linux.net/images"
}

variable "image_version_id" {
  type = string
  default = "9999.0.0+hetzner"
}

variable "flatcar_install_script" {
    type    = string
    default = "https://raw.githubusercontent.com/flatcar/init/flatcar-master/bin/flatcar-install"
}

locals {
  hcloud_location = "fsn1"
  hcloud_rescue = "linux64"
  hcloud_initial_os = "ubuntu-22.04"
  flatcar_oem_id = "hetzner"

  board = {
    x86 = "amd64"
    arm = "arm64"
  }
}

source "hcloud" "flatcar" {
  token = var.hcloud_token

  image       = local.hcloud_initial_os
  location    = local.hcloud_location
  rescue      = local.hcloud_rescue

  snapshot_labels = {
    os              = "flatcar"
  }

  ssh_username = "root"
}


build {
  source "hcloud.flatcar" {
    name = "x86"
    server_type = var.hcloud_server_type["x86"]
    snapshot_name = "flatcar-x86"
  }

  source "hcloud.flatcar" {
    name = "arm"
    server_type = var.hcloud_server_type["arm"]
    snapshot_name = "flatcar-arm"
  }

  provisioner "shell" {
    inline = [
      # Download script and dependencies
      "apt-get -y install gawk",
      "curl -fsSLO --retry-delay 1 --retry 60 --retry-connrefused --retry-max-time 60 --connect-timeout 20 ${var.flatcar_install_script}",
      "chmod +x flatcar-install",

      # Install flatcar
      "./flatcar-install -v -s -o hetzner -b ${var.image_base_url}/${local.board[source.name]} -V ${var.image_version_id}",
    ]
  }
}
