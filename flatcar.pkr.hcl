packer {
  required_plugins {
    hcloud = {
      source  = "github.com/hetznercloud/hcloud"
      version = "~> 1.4.0"
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

variable "channel" {
  type    = string
  default = "beta"
}

variable "version" {
  type    = string
  default = "current"
}

variable "labels" {
  // Available replacements:
  // $architecture
  // $board
  // $channel
  // $version - if "current" was specified, this is resolved to the actual version
  type = map(string)
  default = {
    os              = "flatcar"
    flatcar-channel = "$channel"
    flatcar-board   = "$board"
    version         = "$version"
    architecture    = "$architecture"
  }
}

locals {
  boards = {
    x86 = "amd64-usr"
    arm = "arm64-usr"
  }

  architectures = ["x86", "arm"]

  // If the user wants the "current" version, we still want to make the
  // actual version id available through labels + snapshot description
  //
  // regex matches: FLATCAR_VERSION=1234.0.0
  version = regex("FLATCAR_VERSION=(\\d+\\.\\d+\\.\\d+)", data.http.version_info.body)[0]
}

data "http" "version_info" {
  // We assume that both boards have the same version
  url = "https://${var.channel}.release.flatcar-linux.net/amd64-usr/${var.version}/version.txt"
}

source "hcloud" "flatcar" {
  token = var.hcloud_token

  image    = "ubuntu-22.04"
  location = "fsn1"
  rescue   = "linux64"

  ssh_username = "root"
}


build {
  dynamic "source" {
    for_each = local.architectures
    labels   = ["hcloud.flatcar"]

    content {
      name          = source.value
      server_type   = var.hcloud_server_type[source.value]
      snapshot_name = "flatcar-${var.channel}-${local.version}-${source.value}"

      snapshot_labels = {
        for k, v in var.labels : k => replace(replace(replace(replace(v,
          "$channel", var.channel),
          "$version", local.version),
          "$architecture", source.value),
          "$board", local.boards[source.value])
      }
    }
  }

  provisioner "shell" {
    inline = [
      # Download script and dependencies
      "apt-get -y install gawk",
      "curl -fsSLO --retry-delay 1 --retry 60 --retry-connrefused --retry-max-time 60 --connect-timeout 20 https://raw.githubusercontent.com/flatcar/init/flatcar-master/bin/flatcar-install",
      "chmod +x flatcar-install",

      # Install flatcar
      "./flatcar-install -s -o hetzner -C ${var.channel} -B ${local.boards[source.name]} -V ${var.version} ",
    ]
  }
}
