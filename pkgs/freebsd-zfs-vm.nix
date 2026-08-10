# FreeBSD VM for ZFS pool access via QEMU + USB passthrough
#
# FreeBSD has the most mature ZFS support of any non-Solaris OS.
# This downloads a FreeBSD cloud image and boots it with KVM acceleration,
# passing through the USB ZFS drive.
#
# Build:  nix build .#freebsd-zfs-vm
# Run:    sudo ./result/bin/freebsd-zfs-vm
# Console: root (no password on first boot) or FreeBSD console login
#
# Inside FreeBSD:
#   zpool import          # list available pools
#   zpool import <pool>   # import the pool
#   ls /<pool>/           # access data
#   zfs list              # list datasets
{pkgs}: let
  freebsdVersion = "14.2-RELEASE";
  imageUrl = "https://download.freebsd.org/releases/VM-IMAGES/${freebsdVersion}/amd64/Latest/FreeBSD-${freebsdVersion}-amd64.qcow2.xz";
in
  pkgs.writeShellApplication {
    name = "freebsd-zfs-vm";

    runtimeInputs = [
      pkgs.qemu
      pkgs.xz
      pkgs.curl
    ];

    text = ''
      IMG_DIR="''${XDG_DATA_HOME:-$HOME/.local/share}/freebsd-zfs-vm"
      IMG="$IMG_DIR/freebsd-${freebsdVersion}.qcow2"
      mkdir -p "$IMG_DIR"

      if [ ! -f "$IMG" ]; then
        echo "Downloading FreeBSD ${freebsdVersion} cloud image..."
        echo "URL: ${imageUrl}"
        curl -L "${imageUrl}" | xz -dc > "$IMG"
        echo "Download complete: $IMG"
      fi

      echo ""
      echo "=== FreeBSD ZFS VM ==="
      echo "USB passthrough: JMicron JMS567 (152d:0567) — 2x 16TB HDD"
      echo "SSH: ssh root@localhost -p 2222  (once FreeBSD is configured)"
      echo "Console: press Enter for login prompt"
      echo ""
      echo "Boot may take 30-60s on first run (cloud-init)."
      echo "Press Ctrl+A X to exit QEMU."
      echo ""

      exec qemu-system-x86_64 \
        -enable-kvm \
        -cpu host \
        -m 4G \
        -smp 4 \
        -drive file="$IMG",if=virtio,format=qcow2 \
        -nic user,model=virtio-net-pci,hostfwd=tcp::2222-:22 \
        -device qemu-xhci,id=xhci1 \
        -device usb-host,vendorid=0x152d,productid=0x0567 \
        -nographic
    '';
  }
