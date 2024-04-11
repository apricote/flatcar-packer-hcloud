# Build Flatcar Snapshots on Hetzner Cloud with Packer

> [!IMPORTANT]
> This version of the README describes the process to build & test Hetzner OEM images using the Draft PR [flatcar/scripts#1880](https://github.com/flatcar/scripts/pull/1880).
> If you are a user looking to install Flatcar on Hetzner Cloud right now, you can check out the [`main` branch](https://github.com/apricote/flatcar-packer-hcloud/) of this repo.

## Requirements

- [Hetzner Cloud API Token](https://docs.hetzner.com/cloud/api/getting-started/generating-api-token/)
- [Packer](https://developer.hashicorp.com/packer)
- [Hetzner Cloud CLI](https://github.com/hetznercloud/cli) (`hcloud`)

## Building Image

See https://www.flatcar.org/docs/latest/reference/developer-guides/sdk-modifying-flatcar/

```
./build_packages
./build_image --replace
./image_to_vm --format hetzner
```

## Building Snapshots

In Hetzner Cloud, you can create a "Snapshot" of your server's disk. You can then use these snapshots to create new servers.

We will use Packer and the flatcar-install script to write the image we built in the previous step to the disk and then create a snapshot.

```shell
$ git clone --branch oem-image https://github.com/apricote/flatcar-packer-hcloud.git
$ cd flatcar-packer-hcloud
$ export HCLOUD_TOKEN=<Your Hetzner Cloud API Token>
$ packer init .

# This will build the Snapshot for x86. You need to specify the path to your local image file.
$ packer build . -var image_path=/path/to/flatcar_production_hetzner_image.bin.bz2
# ... Takes a few minutes
==> Builds finished. The artifacts of successful builds are:
--> hcloud.x86: A snapshot was created: 'flatcar-x86' (ID: 157132241)

$ hcloud image list --type=snapshot --selector=os=flatcar
ID          TYPE       NAME   DESCRIPTION   ARCHITECTURE   IMAGE SIZE   DISK SIZE   CREATED                        DEPRECATED
157132241   snapshot   -      flatcar-x86   x86            0.47 GB      20 GB       Sat Mar 30 16:48:22 CET 2024   -
```

## Create a Server

You can now create a new server from the snapshot. Not every feature might automatically work, as the snapshot is
missing the functionality from [`hc-utils`](https://github.com/hetznercloud/hc-utils). Configuring SSH Keys and User
Data (Ignition) will work as expected.

```shell
# Get ID of the most recent flatcar snapshot for x86
$ SNAPSHOT_ID=$(hcloud image list --type=snapshot --selector=os=flatcar --architecture=x86 -o=columns=id -o noheader --sort=created:desc | head -n1)

# Create a new server
# If you have, you can specify an Ignition config with `--user-data-from-file ignition-user.json`
$ hcloud server create --name flatcar-test --image $SNAPSHOT_ID --type cx11 --ssh-key <your-key>
# Wait about a minute or two for the server to be started

# Now you can login, the following is a helper that calls `ssh` with the public ipv4 address of the server
$ hcloud server ssh -u core flatcar-test
```
