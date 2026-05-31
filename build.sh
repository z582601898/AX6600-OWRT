#!/bin/bash
set -e

# Setup environment variables matching the CI workflow
export GITHUB_WORKSPACE="/home/z582601898/workspace/OpenWRT-CI"
export WRT_CONFIG="IPQ60XX-WIFI-YES"
export WRT_THEME="aurora"
export WRT_NAME="OWRT"
export WRT_SSID="OWRT"
export WRT_WORD="12345678"
export WRT_IP="192.168.10.1"
export WRT_PW="无"
export WRT_REPO="https://github.com/VIKINGYFY/immortalwrt.git"
export WRT_BRANCH="main"
export WRT_SOURCE="VIKINGYFY/immortalwrt"

echo "=== WRT Local Compilation Orchestrator ==="
echo "Workspace: $GITHUB_WORKSPACE"
echo "Target Device: JDCloud AX6600 Athena (re-cs-02)"
echo "Plugins Configured: OpenClash, Passwall, Docker, Dawn/Usteer, Samba4"

# 1. Clone the Openwrt/Immortalwrt repository
if [ ! -d "wrt" ]; then
    echo "-> Cloning Immortalwrt repository (branch: $WRT_BRANCH)..."
    git clone --depth=1 --single-branch --branch $WRT_BRANCH $WRT_REPO ./wrt/
else
    echo "-> 'wrt' directory already exists. Skipping clone."
fi

# 2. Fix script endings and permissions
echo "-> Cleaning scripts..."
find ./Scripts/ -type f -name "*.sh" -exec dos2unix {} \; -exec chmod +x {} \;

# 3. Update and Install Feeds
cd wrt
echo "-> Updating feeds..."
./scripts/feeds update -a
echo "-> Installing feeds..."
./scripts/feeds install -a

# 4. Custom Packages
echo "-> Running package customization..."
cd package
$GITHUB_WORKSPACE/Scripts/Packages.sh
$GITHUB_WORKSPACE/Scripts/Handles.sh
cd ..

# 5. Config Setup and Settings
echo "-> Applying config files..."
# Clear config if already exists, then combine target config and general config
rm -f .config
cat $GITHUB_WORKSPACE/Config/$WRT_CONFIG.txt $GITHUB_WORKSPACE/Config/GENERAL.txt >> .config

echo "-> Applying settings customization..."
$GITHUB_WORKSPACE/Scripts/Settings.sh

echo "-> Running make defconfig to expand configuration and check dependencies..."
make defconfig

# 6. Download Packages
echo "-> Downloading all source packages for offline build..."
make download -j$(nproc)

# 7. Compile
echo "-> Launching compilation..."
make -j$(nproc) || make -j1 V=s

echo "=== Compilation Complete ==="
echo "Compiled images are located in: wrt/bin/targets/qualcommax/ipq60xx/"
