#! /bin/sh

# This script is a best-effort attempt to setup Alpine Linux (3.19.1) as a QEMU/KVM host
# It assumes an Intel CPU (though it could probably be modified for AMD by find/replace "intel_iommu" to "amd_iommu").
# This is meant to be run on a fresh Alpine Linux (Extended) installation with either 'sys' or 'cryptsys' installations.
# This script is the "what", and more information about the "why" can be found at https://sureshjoshi.com

set -e

function main() {
    echo "Starting interactive Alpine Linux QEMU/KVM (with GPU passthrough) setup"
    ensure_alpine

    echo
    echo "********** DISCLAIMER **********"
    echo "This script has only been tested on Alpine Linux (Extended) 3.19.1"
    echo "This script should be run on a brand new Alpine 'sys' (or 'cryptsys') installation. Otherwise, your mileage might vary..."
    echo "********** DISCLAIMER **********"
    echo

    read -rp "  Have you enabled virtualization in your BIOS? [y/n]" ok
    ensure_yes_or_exit "$ok" "If virtualization is not enabled, this script won't work. Exiting..."

    read -rp "  Have you enabled VT-d in your BIOS? [y/n]" ok
    ensure_yes_or_exit "$ok" "If VT-d is not enabled, you cannot perform GPU passthrough to a VM. Exiting..."

    read -rp "  Have you setup your initial display output to your secondary GPU (or iGPU) in your BIOS? [y/n]" ok
    ensure_yes_or_exit "$ok" "If the GPU you want to passthrough is used as your initial display, it would be messier to perform GPU passthrough to a VM. Exiting..."

    echo
    echo "Ensure main and community repositories are available"
    ensure_repos

    echo
    echo "Ensure all required APKs are available"
    install_apks

    echo
    echo "Ensure libvirtd is started"
    ensure_libvirtd

    echo
    echo "Ensure udev is started"
    ensure_udev

    echo
    echo "Ensure intel_iommu is enabled in grub"
    ensure_grub_iommu

    echo
    echo "Ensure VFIO modules are loaded"
    ensure_vfio

    echo
    echo "After a successful reboot, please manually verify the following questions to ensure the script ran correctly"
    verify
}

function ensure_alpine() {
    if [ -f /etc/alpine-release ]; then
        return
    fi

    echo "  This script is meant to be run on Alpine Linux only, not currently running on Alpine. Exiting..."
    exit 1
}

# Ensure `main` and `community` are available in `/etc/apk/repositories`
function ensure_repos() {
    local repos_file="/etc/apk/repositories"
    local main="http://dl-cdn.alpinelinux.org/alpine/latest-stable/main"
    local community="http://dl-cdn.alpinelinux.org/alpine/latest-stable/community"

    # Check if main is not in /etc/apk/repositories
    if ! grep -q "$main" "$repos_file"; then
        echo "  [changed] Adding $main to $repos_file"
        echo "$main" >> "$repos_file"
    else
        echo "  [ok] $main already in $repos_file"
    fi

    # Check if community is not in /etc/apk/repositories
    if ! grep -q "$community" "$repos_file"; then
        echo "  [changed] Adding $community to $repos_file"
        echo "$community" >> "$repos_file"
    else
        echo "  [ok] $community already in $repos_file"
    fi
}

function install_apks() {
    echo "  [changed] Updating APK package list"
    apk update

    apk add \
        chrony \
        doas \
        eudev \
        less \
        libvirt-daemon \
        lm-sensors \
        lm-sensors-detect \
        logrotate \
        openssh \
        ovmf \
        pciutils \
        qemu-hw-usb-host \
        qemu-img \
        qemu-system-x86_64 \
        udev-init-scripts \
        usbutils \
        virt-install \
        wpa_supplicant
}

function ensure_libvirtd() {
    rc-update add libvirtd
    rc-service libvirtd restart
    echo "  [changed] Re-started libvirtd service"
}

# https://wiki.alpinelinux.org/wiki/Eudev#Manually
function ensure_udev() {
    rc-update add udev sysinit
    rc-update add udev-trigger sysinit
    rc-update add udev-settle sysinit
    rc-update add udev-postmount default

    rc-service udev restart
    rc-service udev-trigger restart
    rc-service udev-settle restart
    rc-service udev-postmount restart

    echo "  [changed] Re-started udev services"
}

function ensure_grub_iommu() {
    local default_file="/etc/default/grub"
    local boot_file="/boot/grub/grub.cfg"

    if grep -q "intel_iommu=on iommu=pt" $default_file; then
        echo "  [ok] intel_iommu=on and iommu=pt are already enabled in $default_file"
    else
        read -rp "  Current CMDLINE does not support IOMMU: $(grep ^GRUB_CMDLINE_LINUX_DEFAULT $default_file) - add command? [y/n]" ok
        ensure_yes_or_exit "$ok" "IOMMU is required for GPU passthrough. Exiting..."

        backup_file $default_file
        sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"$/GRUB_CMDLINE_LINUX_DEFAULT="\1 intel_iommu=on iommu=pt"/' $default_file
        echo "  [changed] Added intel_iommu=on and iommu=pt to $default_file"
    fi

    if grep -q "intel_iommu=on iommu=pt" $boot_file; then
        echo "  [ok] grub configuration ($boot_file) was already re-built with iommu defaults"
    else
        backup_file $boot_file
        grub-mkconfig -o $boot_file
        echo "  [changed] Re-built grub configuration ($boot_file) to include intel_iommu=on and iommu=pt"
        echo "  ** Please reboot your system to test if the IOMMU settings work **"
    fi
}

# Ensure the vfio modules are loaded
# This is a helper function to call each of the other functions in a reasonable order
function ensure_vfio() {
    ensure_vfio_modules
    ensure_vfio_feature
    ensure_vfio_modprobe
    ensure_initfs_built
    ensure_grub_vfio
}

# Ensure the vfio modules are loaded
# Instructions from: https://wiki.alpinelinux.org/wiki/KVM#vfio
# You can manually look for these modules at /lib/modules/6.6.14-0-lts/kernel/drivers/vfio/
function ensure_vfio_modules() {
    local modules_file="/etc/mkinitfs/features.d/vfio.modules"
    local modules="kernel/drivers/vfio/vfio.ko.* \
        kernel/drivers/vfio/vfio_iommu_type1.ko.* \
        kernel/drivers/vfio/pci/vfio-pci.ko.*"
        
    if [ -f $modules_file ]; then
        # TODO: This would be better as a lazy backup
        backup_file $modules_file
    else
        echo "  [changed] Creating $modules_file"
        touch $modules_file
    fi

    for module in $modules; do
        if grep -q $module $modules_file; then
            echo "  [ok] $module is already in $modules_file"
        else
            echo $module >> $modules_file
            echo "  [changed] Added $module to $modules_file"
        fi
    done
}

function ensure_vfio_feature() {
    local conf_file="/etc/mkinitfs/mkinitfs.conf"

    if grep -q "vfio" $conf_file; then
        echo "  [ok] vfio feature is already enabled in $conf_file"
    else
        read -rp "  Current mkinitfs features are missing vfio: $(grep ^features $conf_file) - add vfio? [y/n]" ok
        ensure_yes_or_exit "$ok" "vfio feature is required for GPU passthrough. Exiting..."

        backup_file $conf_file
        sed -i 's/^features="\(.*\)"$/features="\1 vfio"/' $conf_file
        echo "  [changed] Added vfio to features in $conf_file"
    fi
}

# Instruct mkinitfs to load the following module and rebuild the kernel ramdisk
# Requires input to decide which PCI id to passthrough
# If the file is not exactly as expected, we're deleting it and starting from scratch
function ensure_vfio_modprobe() {
    local modprobe_file="/etc/modprobe.d/vfio.conf"

    echo "  Listing IOMMU groups:"
    list_iommu_groups
    read -rp "  Enter the PCI device ID you want to passthrough (e.g. 1a2b:3c4d): " pci_id
    if [ ${#pci_id} -ne 9 ]; then
        echo "  PCI ID must be in the format 1a2b:3c4d. Exiting..."
        exit 1
    fi

    local line1="options vfio-pci ids=$pci_id"
    local line2="options vfio_iommu_type1 allow_unsafe_interrupts=1"
    local line3="softdep igb pre: vfio-pci"

    # If the modprobe_file exists, and all of the lines are not in it - back it up, as we're making a new one
    if [ -f $modprobe_file ]; then
        if ! grep -q "$line1" $modprobe_file || ! grep -q "$line2" $modprobe_file || ! grep -q "$line3" $modprobe_file; then
            backup_file $modprobe_file
        else
            echo "  [ok] $modprobe_file already exists with the correct lines"
            return
        fi
    fi

    touch $modprobe_file
    echo "$line1" > $modprobe_file
    echo "$line2" >> $modprobe_file
    echo "$line3" >> $modprobe_file
    echo "  [changed] Added lines containing $pci_id to $modprobe_file"
}

# No good way to figure out whether initfs was generated other than timestamp or installing `lsinitrd`
# So, just rebuild the initfs anyways [shrug]
function ensure_initfs_built() {
    mkinitfs
    echo "  [changed] Re-built kernel ramdisk with new vfio-pci ID ($pci_id)"
}

function ensure_grub_vfio() {
    local default_file="/etc/default/grub"
    local boot_file="/boot/grub/grub.cfg"
    local vfio_modules="vfio,vfio-pci,vfio_iommu_type1"

    if grep -q $vfio_modules $default_file; then
        echo "  [ok] vfio modules are already enabled in $default_file"
    else
        read -rp "  Current CMDLINE missing vfio modules: $(grep ^GRUB_CMDLINE_LINUX_DEFAULT $default_file) - add modules? [y/n] " ok
        ensure_yes_or_exit "$ok" "vfio modules are required for GPU passthrough. Exiting..."

        backup_file $default_file

        # Add vfio modules to end of modules list
        sed -i "s/\(modules=[^ ]*\)/\1,$vfio_modules/" $default_file
        echo "  [changed] Added $vfio_modules to $default_file"
    fi

    if grep -q $vfio_modules $boot_file; then
        echo "  [ok] grub configuration ($boot_file) was already re-built with vfio modules"
    else
        backup_file $boot_file
        grub-mkconfig -o $boot_file
        echo "  [changed] Re-built grub configuration ($boot_file) to include $vfio_modules"
        echo "  ** Please reboot your system to test if the VFIO settings work **"
    fi
}

function verify() {
    echo
    rc-service libvirtd status
    read -rp "  Is libvirtd started? [y/n]" ok
    ensure_yes_or_warn "$ok" "libvirtd is not started, please ensure the APK is installed and that 'rc-update add libvirtd && rc-service libvirtd start' enables it (see 'ensure_libvirtd')"

    echo
    rc-service udev status
    read -rp "  Is udev started? [y/n]" ok
    ensure_yes_or_warn "$ok" "udev is not started, please ensure the APKs are installed and that the services are installed/started (see 'ensure_udev')"

    echo
    dmesg | grep "IOMMU enabled"
    read -rp "  Is IOMMU enabled? [y/n]" ok
    ensure_yes_or_warn "$ok" "IOMMU is not enabled, please ensure 'intel_iommu=on' is in your GRUB command line, re-build GRUB, and reboot (see 'ensure_grub_iommu')"

    echo
    dmesg | grep VFIO
    read -rp "  Is vfio enabled? [y/n]" ok
    ensure_yes_or_warn "$ok" "VFIO is not enabled, please ensure VFIO modules are loaded, features are added to mkinitfs, and modprobe is configured (see 'ensure_vfio')"

    echo
    lspci -nnk | grep -A2 VGA
    read -rp "  Is the GPU you want to pass through marked as in use by 'vfio-pci'? [y/n]" ok
    ensure_yes_or_warn "$ok" "The selected GPU is not in use by 'vfio-pci'. Please ensure the modprobe configuration is correct and the vfio modules are loaded in GRUB (see 'ensure_vfio')"
}

function backup_file() {
    local file=$1
    local backup_file="$file.$(date +%s)"

    if [ -f "$backup_file" ]; then
        echo "  [ok] Backup file $backup_file already exists. Exiting..."
        exit 1
    fi

    echo "  [changed] Backing up $file to $backup_file"
    cp "$file" "$backup_file"
}

function ensure_yes_or_exit() {
    response=$1
    msg=$2

    case "$response" in
        [yY]|[yY][eE][sS])
            return
            ;;
    esac

    echo "  $msg"
    exit 1
}

function ensure_yes_or_warn() {
    response=$1
    msg=$2

    case "$response" in
        [yY]|[yY][eE][sS])
            return
            ;;
    esac

    echo "  [WARNING] $msg"
}

# # From section 2.2 (https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF#Ensuring_that_the_groups_are_valid)
function list_iommu_groups() {
    for g in $(find /sys/kernel/iommu_groups/* -maxdepth 0 -type d | sort -V); do
        echo "IOMMU Group ${g##*/}:"
        for d in $g/devices/*; do
            echo -e "\t$(lspci -nns ${d##*/})"
        done;
    done;
}

main "$@"; exit
