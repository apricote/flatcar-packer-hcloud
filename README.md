# Build Flatcar Snapshots on Hetzner Cloud with Packer

## Requirements

- [Hetzner Cloud API Token](https://docs.hetzner.com/cloud/api/getting-started/generating-api-token/)
- [Packer](https://developer.hashicorp.com/packer)
- [Hetzner Cloud CLI](https://github.com/hetznercloud/cli) (`hcloud`)

This requires Flatcar version `3941.1.0+`.

## 1. Building Snapshots

In Hetzner Cloud, you can create a "Snapshot" of your server's disk. You can then use these snapshots to create new
servers.

We will use Packer and the `flatcar-install` script to write the pre-built images from Flatcar CI to the disk and then
create a snapshot.

```shell
$ git clone https://github.com/apricote/flatcar-packer-hcloud.git
$ cd flatcar-packer-hcloud
$ export HCLOUD_TOKEN=<Your Hetzner Cloud API Token>
$ packer init .

# This will build the snapshot for x86 and Arm.
$ packer build .
# ... Takes a few minutes
==> Builds finished. The artifacts of successful builds are:
--> hcloud.x86: A snapshot was created: 'flatcar-beta-3941.1.0-x86' (ID: 157132241)
--> hcloud.arm: A snapshot was created: 'flatcar-beta-3941.1.0-arm' (ID: 157132242)

$ hcloud image list --type=snapshot --selector=os=flatcar
ID          TYPE       NAME   DESCRIPTION                 ARCHITECTURE   IMAGE SIZE
167650172   snapshot   -      flatcar-beta-3941.1.0-arm   arm            0.41 GB
167650577   snapshot   -      flatcar-beta-3941.1.0-x86   x86            0.47 GB
```

## 2. Create a Server

You can now create a new server from the snapshot. Configuring SSH Keys and User Data (Ignition) will work as expected.

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

## Options

If you need to configure the Flatcar installation or the resulting image, there are a few packer variables that you can
set.

- `channel`: To choose a different Flatcar channel, defaults to `beta` (as `stable` does not have Hetzner images yet)
- `version`: If you want to install a specific version, defaults to `current`
- `labels`: See [section below](#labels)

### Labels

The `labels` variable controls the labels that are added to the resulting image. This can be helpful if you use a tool
that requires specific image labels, like `caph-image-name`
for [`cluster-api-provider-hetzner`](https://github.com/syself/cluster-api-provider-hetzner/blob/v1.0.0-beta.35/docs/topics/node-image.md#creating-a-node-image).

The following variables are supported:

- `$architecture`: The Hetzner Cloud API architecture (`x86` or `arm`).
- `$version`: The Flatcar version, if you are using `current`, this is resolved to the actual version in the snapshot.
- `$channel`: The Flatcar release channel.

The default labels are:

- `os=flatcar`
- `flatcar-channel=$channel`
- `version=$version`
- `architecture=$architecture`

## Known Issues

These features do not work with Flatcar as of version 3941.1.0:

- **Volume Automount**: You need to mount volumes manually.
- **Setting & Resetting Root Passwords**: You need to configure an SSH Key through the API or Ignition User Data.
