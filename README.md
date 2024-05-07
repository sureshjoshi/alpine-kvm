# alpine-kvm

Alpine-based KVM/QEMU host configuration and virt-install scripts

## Prerequisites

- A fresh install of Alpine Linux 3.19 (Extended) using 'sys' or 'cryptsys'
- Intel CPU
- Two GPUs (one for passthrough, one for host)
- A working internet connection

## What do I do

After a fresh install of Alpine, you can curl/wget the `configure-alpine.sh` and run it on your system.

It is an interactive script which will best-effort setup your system as a QEMU/KVM host, allowing GPU passthrough to a Windows (or other) virtual machine.

The Alpine/Intel requirements are not necessarily dealbreakers, but this version of the script was only tested using those conditions. For example, this script could probably be modified for AMD by changing `intel_iommu` to `amd_iommu` in the configuration script, but that's untested.

Additionally, this script could theoretically work on a single-GPU system, but it would likely require some modifications and debugging/troubleshooting would be more difficult as this script binds the GPU at boot time, rather than on-demand (which a single-GPU system should prefer). 

## License

GNU General Public License v3.0 or later

See [LICENSE](LICENSE) to see the full text.
