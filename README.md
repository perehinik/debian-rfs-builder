# Debian RootFS Builder

Build Debian Bookworm ARM64 root filesystem images for QEMU and embedded Linux development.

This project creates bootable **AArch64** Debian root filesystem images using `debootstrap`, then performs additional setup inside the image using QEMU.

## Features

- Build Debian Bookworm ARM64 root filesystem images
- Multiple image variants:
  - **minimal**
  - **default**
  - **xfce**
- QEMU-based second-stage initialization
- SSH-based post-install customization
- Native Linux and Docker builds
- Automatic SSH public key installation
- Produces raw `.img` disk images ready for QEMU or embedded devices

---

## Image Variants

### minimal

Creates a minimal Debian installation using:

```bash
debootstrap --variant=minbase
```

Suitable for headless systems and embedded devices.

### default

Creates a standard Debian installation using the default `debootstrap` package set.

This is the default image when no `-v` option is specified.

### xfce

Starts from the **default** image and installs the XFCE desktop environment during the post-install stage.

---

## Requirements

### Docker build (recommended)

Only Docker and an SSH public key are required.

Supported key names:

```text
~/.ssh/id_ed25519.pub
~/.ssh/id_ecdsa.pub
~/.ssh/id_rsa.pub
```

Generate one if necessary:

```bash
ssh-keygen -t ed25519
```

---

### Native build

When building without Docker, install the required tools:

```bash
sudo apt update

sudo apt install \
    debootstrap \
    qemu-system-aarch64 \
    qemu-user-static \
    gcc-aarch64-linux-gnu \
    binfmt-support
```

Additional packages may be required depending on the selected image variant.

---

## Quick Start

Build the default image:

```bash
./build.sh
```

Build a minimal image:

```bash
./build.sh -v minimal
```

Build an XFCE image:

```bash
./build.sh -v xfce
```

Build inside Docker:

```bash
./build.sh -d
```

or

```bash
./build.sh -v xfce -d
```

---

## Usage

```text
./build.sh [options]
```

Options:

| Option | Description |
|---------|-------------|
| `-v minimal` | Build minimal image |
| `-v default` | Build default image |
| `-v xfce` | Build XFCE image |
| `-d` | Run build inside Docker |
| `-h` | Show help |

---

## Build Process

The build consists of three major stages:

```text
build.sh
    │
    ├── first-stage.sh
    │      Creates the initial Debian root filesystem image using debootstrap.
    │
    ├── run-in-image-init.sh
    │      Boots the image in QEMU and executes second-stage.sh as init.
    │
    ├── run-in-image-ssh.sh
    │      Boots the image again and executes postinst.sh over SSH.
    │
    └── dist/
           Final image
```

---

## Project Structure

```text
.
├── aarch64-default/
├── aarch64-minimal/
├── aarch64-xfce/
├── build/
├── dist/
├── kernel/
├── postinst/
├── build.sh
├── run-in-image-init.sh
└── run-in-image-ssh.sh
```

### Variant directories

Each image variant contains its own customization scripts:

```text
first-stage.sh
second-stage.sh
postinst.sh
src/
```

Files inside `src/` are copied into the target root filesystem.

Example:

```text
src/etc/hostname
src/etc/hosts
src/etc/network/interfaces
```

---

## Output

Generated images are placed in:

```text
dist/
```

Example:

```text
dist/rootfs-bookworm-default.img
```

---

## SSH Key Installation

During the build, the first available SSH public key is automatically copied into the image.

Search order:

```text
~/.ssh/id_ed25519.pub
~/.ssh/id_ecdsa.pub
~/.ssh/id_rsa.pub
```

If none are found, the build stops with an error.

---

## Docker

Docker uses the image:

```text
perehiniak/linux-build-tools:1.0.0
```

Docker mode avoids installing build dependencies on the host.

Example:

```bash
./build.sh -v xfce -d
```

---

## How `run-in-image-init.sh` Works

1. Mounts the generated image.
2. Copies the requested script into `/qemu_env`.
3. Optionally copies an additional directory into `/qemu_env`.
4. Boots the image using `qemu-system-aarch64`.
5. Executes the copied script as the system's init process:

```text
init=/qemu_env/<script>
```

6. Cleans up temporary files after QEMU exits.

---

## How `run-in-image-ssh.sh` Works

This stage is similar to `run-in-image-init.sh`, except the image is allowed to boot normally and the specified script is executed over SSH.

This is primarily used for package installation and other post-install customization.

---

## Customizing Images

Modify one of the image variant directories:

```text
aarch64-minimal/
aarch64-default/
aarch64-xfce/
```

Typical customization points include:

- packages
- networking
- hostname
- users
- services
- desktop environment
- custom scripts

---

### `Permission denied` when running `apt`

The build must be running as root.

Use Docker mode or execute the build with sufficient privileges.

---

### No SSH key found

Generate one:

```bash
ssh-keygen -t ed25519
```

---

## License

This project is licensed under the GNU GPL v3 License.