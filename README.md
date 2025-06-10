# alpine-kvm

Alpine-based KVM/QEMU host configuration and virt-install scripts

## Prerequisites

- A fresh install of Alpine Linux 3.22 (Extended) using 'sys' or 'cryptsys'
- Intel CPU
- Two GPUs (one for passthrough, one for host)
- A working internet connection

## What do I do

After a fresh install of Alpine, you can curl/wget the `configure-alpine.sh` and run it on your system.

```bash
wget https://raw.githubusercontent.com/sureshjoshi/alpine-kvm/main/configure-alpine.sh
# Read through and closely examine the code in this file before running it
sh ./configure-alpine.sh
```

It is an interactive script which will best-effort setup your system as a QEMU/KVM host, allowing GPU passthrough to a Windows (or other) virtual machine.

The Alpine/Intel requirements are not necessarily dealbreakers, but this version of the script was only tested using those conditions. For example, this script could probably be modified for AMD by changing `intel_iommu` to `amd_iommu` in the configuration script, but that's untested.

Additionally, this script could theoretically work on a single-GPU system, but it would likely require some modifications and debugging/troubleshooting would be more difficult as this script binds the GPU at boot time, rather than on-demand (which a single-GPU system should prefer). 

## System Info

Here is the setup I run this on:

```bash
CPU: 13th Gen Intel Core i5-13600K
Motherboard: Gigabyte Z790I Aorus Ultra
GPU: Nvidia GeForce RTX 3060
```

And these are the installed software versions:

```bash
cat /etc/alpine-release 
# 3.22.0

qemu-system-x86_64 --version
# QEMU emulator version 10.0.0

libvirtd --version
# libvirtd (libvirt) 11.3.0

virt-install --version
# 5.0.0
```

## Useful Reading

- [How I Learned to Stop Worrying and Love Alpine](https://sureshjoshi.com/development/alpine-kvm-host)
- [Interactively Configuring Alpine as a KVM Host](https://sureshjoshi.com/development/alpine-kvm-config-script)
- [Provisioning Linux virtual machines with virt-install](https://sureshjoshi.com/development/alpine-kvm-virt-install-linux)
- ...Provisioning Windows virtual machines with virt-install... Apparently I never posted that one

## License

GNU General Public License v3.0 or later

See [LICENSE](LICENSE) to see the full text.
