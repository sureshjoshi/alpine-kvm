#! /bin/sh

# Creates a Windows virtual machine with GPU passthrough

set -e

# Check if any other qemu's using OVMF are running
if ps -ef | grep "qemu-system-x86_64" | grep -q "OVMF_CODE"; then
    echo "Windows VM is already running..."
    exit 1
fi

# Set defaults for the VM name, number of CPUs, amount of memory, and disk size
CPUS=4
THREADS=2
MEMORY_MB=8192
DISK="/dev/nvme1n1"
TMP_VARS_PATH="/tmp/ovmf_vars.fd"
WIN_ISO_PATH="Win10_22H2_English_x64v1.iso"
VIRTIO_ISO_PATH="virtio-win-0.1.240.iso"

while getopts ":hc:d:i:m:n:v:" arg; do
    case $arg in
        c) CPUS=${OPTARG};;
        d) DISK=${OPTARG};;
        i) WIN_ISO_PATH=${OPTARG};;
        m) MEMORY_MB=${OPTARG};;
        n) VM_NAME=${OPTARG};;
        t) THREADS=${OPTARG};;
        v) VIRTIO_ISO_PATH=${OPTARG};;
        h | *) echo "Usage: $0 [-c cpus] [-d disk (path)] [-i Windows ISO path] [-m memory (MB)] [-n name] [-t threads per core] [-v Virtio ISO path]"; exit 0;;
    esac
done

if [ -z $VM_NAME ]; then
    echo "VM name not specified..."
    exit 1
fi

echo "Copying OVMF_VARS.fd to $TMP_VARS_PATH..."
cp /usr/share/OVMF/OVMF_VARS.fd $TMP_VARS_PATH

# There is an implicit VCPU setting of socket * cores * threads (e.g. 1 socket, 4 cores, 2 threads = 8 VCPU)
# TODO: Check out the nuance/distinction between a VM core, a QEMU thread, and a Intel CPU thread
virt-install \
    --boot loader=/usr/share/OVMF/OVMF_CODE.fd,loader.readonly=yes,loader.type=pflash,nvram.template=$TMP_VARS_PATH,loader_secure=no \
    --cdrom $WIN_ISO_PATH \
    --connect qemu:///system \
    --controller type=scsi,model=virtio-scsi \
    --cpu host-passthrough,cache.mode=passthrough,topology.sockets=1,topology.dies=1,topology.cores=$CPUS,topology.threads=$THREADS \
    --debug \
    --disk $DISK,format=raw,bus=scsi,cache=none,driver.discard=unmap,driver.io=native \
    --disk $VIRTIO_ISO_PATH,device=cdrom,boot.order=2 \
    --features kvm_hidden=on \
    --graphics none \
    --hostdev 01:00.0,address.type=pci,address.multifunction=on \
    --hostdev 01:00.1,address.type=pci \
    --hostdev 0x8087:0x0033,address.type=usb \
    --hvm \
    --input evdev,source.dev=/dev/input/by-id/usb-Microsoft_Wired_Keyboard_600-event-kbd,source.grab=all,source.repeat=on,source.grabToggle=ctrl-ctrl \
    --input evdev,source.dev=/dev/input/by-id/usb-Razer_Razer_DeathAdder_Essential-event-mouse \
    --input keyboard,bus=virtio \
    --input mouse,bus=virtio \
    --memory $MEMORY_MB \
    --name $VM_NAME \
    --network network=default,model=virtio \
    --osinfo win10 \
    --virt-type kvm \
    --dry-run \
    --print-xml

#   <qemu:capabilities>
#     <qemu:del capability='usb-host.hostdevice'/>
#   </qemu:capabilities>