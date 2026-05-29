# imagebuilder

Build an ImmortalWrt x86/64 KVM test image with only the runtime dependencies
needed for testing locally built `dae`, `daed`, and `luci-app-daed` APKs.

This repository intentionally does **not** bake these packages into the image:

- `dae`
- `daed`
- `luci-app-daed`

Those packages should be installed later from the test build artifacts, so the
VM validates the packages from `wall` / `luci-app-daed` instead of the official
feed packages.

## Default Image

- Version: ImmortalWrt `25.12-SNAPSHOT`
- Target: `x86/64`
- Profile: `generic`
- Rootfs partition: `1024` MB
- ImageBuilder URL:
  `https://downloads.immortalwrt.org/releases/25.12-SNAPSHOT/targets/x86/64/immortalwrt-imagebuilder-25.12-SNAPSHOT-x86-64.Linux-x86_64.tar.zst`

## Extra Packages

The workflow adds only runtime dependencies:

```text
luci
kmod-sched-core
kmod-sched-bpf
kmod-veth
kmod-xdp-sockets-diag
curl
nano
```

If the selected ImmortalWrt feed does not publish one of these packages, the
build should fail. That is intentional because `dae/daed` will not be
installable cleanly on that image either.

The workflow runs `make manifest` before building the image. This catches common
feed problems earlier, especially:

- snapshot ImageBuilder and package feeds are out of sync
- `vmlinux-btf` is not published for the selected target/feed

ImageBuilder can only install packages that already exist in the feed. It cannot
build `vmlinux-btf` or kernel modules by itself. If `vmlinux-btf` is missing,
use one of these paths:

- retry later after ImmortalWrt snapshot feeds finish syncing
- switch `imagebuilder_url` to a release/rc ImageBuilder and build `dae/daed`
  APKs against the same release/rc
- rebuild `dae/daed` with BPF_DEPENDS instead of the `vmlinux-btf` dependency

## First Boot Defaults

The generated image applies these defaults on first boot:

- LAN IP: `192.168.3.249/24`
- Gateway: `192.168.3.254`
- DNS: `192.168.3.254`, `223.5.5.5`
- SSH port: `9167`

No root password is written into this repository or the generated image. The
image keeps the OpenWrt default empty root password, so the first LuCI/console
login should set a new password. For unattended access, inject an SSH public key
using a private workflow/secret-based step.

## Build

Run the `Build daed test image` workflow manually from GitHub Actions.

The workflow uploads generated images as an artifact. When `publish_release` is
set to `true`, it also publishes a GitHub release.
