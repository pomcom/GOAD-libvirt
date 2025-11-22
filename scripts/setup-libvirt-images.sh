#!/bin/bash

# GOAD Libvirt Image Setup Script
# This script helps you set up Windows VM templates for GOAD libvirt provider

set -e

LIBVIRT_DIR="/var/lib/libvirt/images"
REQUIRED_IMAGES=(
    "WinServer2019_x64.qcow2"
)
OPTIONAL_IMAGES=(
    "WinServer2016_x64.qcow2"
    "Windows10_22h2_x64.qcow2"
)

echo "🎯 GOAD Libvirt Image Setup"
echo "============================="
echo ""

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   echo "⚠️  Don't run this script as root. It will sudo when needed."
   exit 1
fi

# Check if libvirt is installed
if ! command -v virsh &> /dev/null; then
    echo "❌ libvirt not found. Please install libvirt first:"
    echo "   sudo pacman -S libvirt qemu-full virt-manager"
    exit 1
fi

echo "✅ libvirt found"

# Create libvirt directory if it doesn't exist
if [[ ! -d "$LIBVIRT_DIR" ]]; then
    echo "📁 Creating $LIBVIRT_DIR"
    sudo mkdir -p "$LIBVIRT_DIR"
fi

echo ""
echo "🔍 Checking for Windows VM images..."

missing_required=()
missing_optional=()

echo ""
echo "📋 Required Images (needed for most labs):"
for image in "${REQUIRED_IMAGES[@]}"; do
    full_path="$LIBVIRT_DIR/$image"
    if [[ -f "$full_path" ]]; then
        echo "✅ Found: $image"
    else
        echo "❌ Missing: $image"
        missing_required+=("$image")
    fi
done

echo ""
echo "📋 Optional Images (only for specific labs):"
for image in "${OPTIONAL_IMAGES[@]}"; do
    full_path="$LIBVIRT_DIR/$image"
    if [[ -f "$full_path" ]]; then
        echo "✅ Found: $image"
    else
        echo "💡 Missing: $image (optional)"
        missing_optional+=("$image")
    fi
done

if [[ ${#missing_required[@]} -eq 0 ]]; then
    echo ""
    if [[ ${#missing_optional[@]} -eq 0 ]]; then
        echo "🎉 All Windows images found! You're ready to use any GOAD lab with libvirt."
    else
        echo "🎉 Core image ready! You can run most GOAD labs with libvirt."
        echo "💡 Add optional images as needed for specific configurations."
    fi
    exit 0
fi

echo ""
echo "📝 Missing required images: ${missing_required[*]}"
if [[ ${#missing_optional[@]} -gt 0 ]]; then
    echo "📝 Missing optional images: ${missing_optional[*]}"
fi
echo ""
echo "🔧 Setup Options:"
echo ""
echo "🚀 Quick Start - Windows Server 2019 Only"
echo "==========================================="
echo "Most GOAD labs only need Windows Server 2019!"
echo ""
echo "1. Download Windows Server 2019 evaluation ISO (FREE, 180-day license):"
echo "   https://www.microsoft.com/en-us/evalcenter/download-windows-server-2019"
echo ""
echo "2. Create VM template using virt-install:"
echo "   virt-install --name win2019-template \\"
echo "     --ram 4096 --vcpus 2 \\"
echo "     --disk path=/var/lib/libvirt/images/WinServer2019_x64.qcow2,size=60,format=qcow2 \\"
echo "     --cdrom /path/to/windows-server-2019.iso \\"
echo "     --network bridge=virbr0 \\"
echo "     --graphics vnc \\"
echo "     --noautoconsole"
echo ""
echo "Option 2 - Use Existing Images"
echo "==============================="
echo "If you already have Windows qcow2 images:"
echo ""
echo "1. Copy them to $LIBVIRT_DIR with correct names:"
for image in "${missing_images[@]}"; do
    echo "   sudo cp /path/to/your-image.qcow2 $LIBVIRT_DIR/$image"
done
echo ""
echo "2. Set correct permissions:"
echo "   sudo chown libvirt-qemu:libvirt-qemu $LIBVIRT_DIR/*.qcow2"
echo "   sudo chmod 644 $LIBVIRT_DIR/*.qcow2"
echo ""
echo "Option 3 - Custom Paths"
echo "======================="
echo "Edit your GOAD globalsettings.ini and add:"
echo ""
echo "[libvirt_templates]"
for image in "${missing_images[@]}"; do
    template_name=$(echo "$image" | sed 's/.qcow2$//' | tr '[:upper:]' '[:lower:]')
    echo "${template_name} = /path/to/your/${image}"
done
echo ""
echo "💡 Note: Windows evaluation licenses are free for 180 days"
echo "💡 For production use, you'll need valid Windows licenses"

echo ""
echo "🚀 Once you have the images, run:"
echo "   python goad.py -t install -l MINILAB -p libvirt"