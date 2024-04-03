# Build Flatcar Snapshots on Hetzner Cloud with Packer

## Requirements

- Hetzner Cloud API Token
- Packer
- Butane
- Hetzner Cloud CLI (`hcloud`)

This only works on Flatcar > `3913.0.0`, as this version has the appropriate versions of `ignition` and `afterburn` that
add support for the Hetzner Cloud metadata service.

## Building Snapshots

```shell
$ git clone ... # TODO
$ export HCLOUD_TOKEN=...
$ packer init flatcar.pkr.hcl
$ butane butane-oem.yaml --pretty --strict --output=ignition-oem.json

# This will build Snapshots for x86 and arm. If you only need one, you can add
# `--only=hcloud.x86` or `--only=hcloud.arm` to the `packer build` command.
$ packer build flatcar.pkr.hcl
# ... Takes a few minutes
==> Builds finished. The artifacts of successful builds are:
--> hcloud.x86: A snapshot was created: 'flatcar-alpha-x86' (ID: 157132241)
--> hcloud.arm: A snapshot was created: 'flatcar-alpha-arm' (ID: 157132252)

$ hcloud image list --type=snapshot --selector=os=flatcar
ID          TYPE       NAME   DESCRIPTION         ARCHITECTURE   IMAGE SIZE   DISK SIZE   CREATED                        DEPRECATED
157132241   snapshot   -      flatcar-alpha-x86   x86            0.47 GB      20 GB       Sat Mar 30 16:48:22 CET 2024   -
157132252   snapshot   -      flatcar-alpha-arm   arm            0.42 GB      40 GB       Sat Mar 30 16:48:24 CET 2024   -
```

## Create a Sever

You can now create a new server from the snapshot. Not every feature might automatically work, as the snapshot is
missing the functionality from [`hc-utils`](https://github.com/hetznercloud/hc-utils). Configuring SSH Keys and User
Data (Ignition) will work as expected.

```shell
# Get ID of the most recent flatcar snapshot for x86
$ SNAPSHOT_ID=$(hcloud image list --type=snapshot --selector=os=flatcar --architecture=x86 -o=columns=id -o noheader --sort=created:desc | head -n1)

# Create a new server
# If you have, you can specify an Ignition config with `--user-data-from-file ignition-user.json`
$ hcloud server create --name flatcar-test --image $SNAPSHOT_ID --type cx11 --ssh-key <your-key>
# Takes a minute or two

# Now you can login, the following is a helper that calls `ssh` with the public ipv4 address of the server
$ hcloud server ssh flatcar-test
```
