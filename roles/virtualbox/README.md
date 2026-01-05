# VirtualBox Ansible Role

This Ansible role installs and configures Oracle VirtualBox on Ubuntu 24.04 LTS systems. It handles repository setup, package installation, Extension Pack installation, and USB passthrough configuration.

## Features

- **Repository Configuration**: Adds the official Oracle VirtualBox APT repository with proper GPG key management
- **VirtualBox Installation**: Installs the specified version of VirtualBox from the official repository
- **Extension Pack**: Optionally installs the VirtualBox Extension Pack for advanced features
- **USB Passthrough**: Configures user permissions for USB device access in virtual machines
- **Kernel Modules**: Ensures VirtualBox kernel modules are properly built and loaded
- **Service Management**: Enables and starts the VirtualBox service

## Requirements

- Ubuntu 24.04 LTS (Noble Numbat)
- Ansible 2.14 or higher
- Root/sudo access on target system

## Role Variables

### Main Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `virtualbox_version` | `"7.2"` | VirtualBox version to install (e.g., "7.2" for virtualbox-7.2 package) |
| `virtualbox_users` | `[]` | List of users to add to vboxusers group. If empty, uses `target_user` or `ansible_user` |
| `virtualbox_install_extension_pack` | `true` | Whether to install the VirtualBox Extension Pack |
| `virtualbox_enable_usb_passthrough` | `true` | Whether to configure USB passthrough (adds users to vboxusers group) |
| `virtualbox_create_udev_rules` | `false` | Whether to create additional udev rules for USB permissions |

### Repository Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `virtualbox_apt_key_url` | `"https://www.virtualbox.org/download/oracle_vbox_2016.asc"` | URL for Oracle VirtualBox GPG key |
| `virtualbox_apt_key_path` | `"/usr/share/keyrings/oracle-virtualbox-2016.gpg"` | Path to store the dearmored GPG key |
| `virtualbox_repository` | (see defaults) | APT repository line for VirtualBox |

### Dependency Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `virtualbox_dependencies` | (see defaults) | List of packages required for kernel module compilation |

## What This Role Does

### 1. Install Dependencies

Installs packages required for VirtualBox kernel module compilation:

- `build-essential`
- `dkms`
- `linux-headers-generic`
- `gcc`
- `make`
- `perl`

### 2. Add VirtualBox Repository

- Downloads the Oracle VirtualBox GPG key
- Converts the key to dearmored format for modern APT
- Adds the official VirtualBox repository

### 3. Install VirtualBox

Installs the specified version of VirtualBox (e.g., `virtualbox-7.2`).

### 4. Configure USB Passthrough

- Adds specified users to the `vboxusers` group
- This allows users to access USB devices from within virtual machines
- Optionally creates additional udev rules for USB device permissions

### 5. Install Extension Pack (Optional)

The Extension Pack provides additional features:

- USB 2.0 and USB 3.0 device support
- VirtualBox Remote Desktop Protocol (VRDP)
- Host webcam passthrough
- Disk image encryption with AES algorithm
- Intel PXE boot ROM
- Support for NVMe SSDs

### 6. Enable VirtualBox Service

Ensures the `vboxdrv` service is enabled and started, which manages the VirtualBox kernel modules.

## Example Usage

### Basic Usage

```yaml
- hosts: workstations
  roles:
    - role: virtualbox
```

### With Custom Configuration

```yaml
- hosts: workstations
  roles:
    - role: virtualbox
      vars:
        virtualbox_version: "7.2"
        virtualbox_users:
          - adam
          - developer
        virtualbox_install_extension_pack: true
        virtualbox_enable_usb_passthrough: true
```

### Minimal Installation (No Extension Pack)

```yaml
- hosts: workstations
  roles:
    - role: virtualbox
      vars:
        virtualbox_install_extension_pack: false
```

## Post-Installation Notes

### User Session Restart Required

After adding users to the `vboxusers` group, users must log out and log back in for the group membership to take effect. Alternatively, a system reboot will also apply the changes.

### Secure Boot Considerations

If your system uses UEFI Secure Boot, you may need to sign the VirtualBox kernel modules before they can be loaded. The following modules may require signing:

- `vboxdrv`
- `vboxnetadp`
- `vboxnetflt`

Consult your distribution's documentation for kernel module signing procedures.

### Verifying Installation

After running the playbook, you can verify the installation:

```bash
# Check VirtualBox version
vboxmanage -v

# Check if user is in vboxusers group
groups $USER

# Check if Extension Pack is installed
vboxmanage list extpacks

# Check if kernel modules are loaded
lsmod | grep vbox
```

## Handlers

This role includes the following handlers:

- **VirtualBox | Rebuild kernel modules**: Rebuilds VirtualBox kernel modules using `/sbin/rcvboxdrv setup`
- **VirtualBox | Reload udev rules**: Reloads udev rules after configuration changes

## Dependencies

This role has no dependencies on other roles.

## Sources and References

This role was created based on information from the following sources:

1. [Oracle VirtualBox Linux Downloads](https://www.virtualbox.org/wiki/Linux_Downloads) - Official download page
2. [Oracle VirtualBox 7.2 User Guide - Installation](https://docs.oracle.com/en/virtualization/virtualbox/7.2/user/installation.html) - Official documentation
3. [How to Install VirtualBox 7.2 on Ubuntu 24.04 LTS - Linuxiac](https://linuxiac.com/how-to-install-virtualbox-on-ubuntu-24-04-lts/)
4. [How to Install VirtualBox on Ubuntu 24.04 - Linux TLDR](https://linuxtldr.com/install-virtualbox/)
5. [Resolving USB Device Access Issues in VirtualBox on Linux](https://lucaspolloni.com/resolving-usb-device-access-issues-in-virtualbox-on-linux/)

## License

MIT

## Author

Adam
