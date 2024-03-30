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

variable "flatcar_install_script" {
    type    = string
    default = "https://raw.githubusercontent.com/flatcar/init/flatcar-master/bin/flatcar-install"
}

variable "flatcar_channel" {
  type    = string
  default = "alpha"
}

locals {
  hcloud_location = "fsn1"
  hcloud_rescue = "linux64"
  hcloud_initial_os = "ubuntu-22.04"
  flatcar_oem_id = "hetzner"
}

source "hcloud" "flatcar" {
  token = var.hcloud_token

  image       = local.hcloud_initial_os
  location    = local.hcloud_location
  rescue      = local.hcloud_rescue

  snapshot_labels = {
    os              = "flatcar"
    "flatcar.channel" = var.flatcar_channel
  }

  ssh_username = "root"
}


build {
  source "hcloud.flatcar" {
    name = "x86"
    server_type = var.hcloud_server_type["x86"]
    snapshot_name = "flatcar-${var.flatcar_channel}-x86"
  }

  source "hcloud.flatcar" {
    name = "arm"
    server_type = var.hcloud_server_type["arm"]
    snapshot_name = "flatcar-${var.flatcar_channel}-arm"
  }

  provisioner "file" {
    source      = "ignition-oem.json"
    destination = "/ignition.json"
  }

  provisioner "shell" {
    inline = [
      # Download script and dependencies
      "apt-get update",
      "apt-get -y install gawk",
      "curl -fsSLO --retry-delay 1 --retry 60 --retry-connrefused --retry-max-time 60 --connect-timeout 20 ${var.flatcar_install_script}",
      "chmod +x flatcar-install",

      # Install flatcar
      "./flatcar-install -s -C ${var.flatcar_channel} -i /ignition.json",

      # Setup Kernel Parameters for OEM Platform
      "mkdir /root/OEM",
      "mount /dev/disk/by-label/OEM /root/OEM",
      "echo 'set oem_id=${local.flatcar_oem_id}' > /root/OEM/grub.cfg",
      "umount /root/OEM",
    ]
  }
}
