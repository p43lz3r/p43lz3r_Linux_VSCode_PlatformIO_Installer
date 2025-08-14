# Linux Mint Arduino/Embedded Development Setup

**One-click script to install VSCode/Platformio IDE and other tools for Arduino and ESP32 embedded development.**

## 🚀 What This Script Does

Automatically sets up a professional embedded development environment with:

- **VSCode** with PlatformIO, Python, and C++ extensions
- **PlatformIO Core** for Arduino and embedded development  
- **Arduino development tools** (esptool, serial libraries, build tools)
- **Serial port access** configuration (dialout group, permissions)
- **ESP32-S3 support** (downloads missing stub files for newer chips)
- **Linux-specific fixes** (BRLTTY removal, firewall awareness)

## 🎯 Key Features

### Solves issues
- **BRLTTY conflict resolution** - Interactive removal of braille interface that probably blocks Arduino serial ports
- **ESP32-S3 stub fix** - Downloads missing flasher files for newest ESP32 chips
- **Network resilience** - Retry logic with proper error handling
- **Firewall awareness** - Detects UFW status and provides guidance

### Professional Quality
- **Idempotent** - Safe to run multiple times
- **Comprehensive validation** - Verifies installations and downloads
- **Detailed logging** - Clear status messages and error handling

## 🔧 What Gets Installed

| Component | Purpose |
|-----------|---------|
| VSCode + Extensions | IDE with PlatformIO, Python, C++ support |
| PlatformIO Core | Command-line embedded development |
| esptool | ESP32/ESP8266 flashing and debugging |
| Serial tools | minicom, picocom, screen for debugging |
| Build tools | GCC, CMake, Ninja for compilation |
| FUSE support | Arduino IDE 2.x AppImage compatibility |

## 🚨 Linux-Specific Fixes

### BRLTTY Removal
Removes braille display interface that conflicts with Arduino serial ports - a common issue affecting:
- Arduino Nano (CH340, FTDI chips)
- ESP32/ESP8266 boards  
- Clone Arduino boards

### ESP32-S3 Support
Downloads missing stub flasher files from Espressif's GitHub to enable support for newest ESP32-S3 chips in older system packages.

## 🏃‍♂️ Quick Start

```bash
# Download the script
wget https://github.com/p43lz3r/p43lz3r_Linux_VSCode_PlatformIO_Installer/blob/main/VSCode_PlatformIO_Installer.sh

# Make executable
chmod +x VSCode_PlatformIO_Installer.sh

# Run (will prompt for sudo when needed)
./VSCode_PlatformIO_Installer.sh
```

## ⚠️ Important Notes

- **Logout/login required** after script completes (for dialout group permissions)

## 📋 Tested On


- Linux Mint 22 Cinnamon (fresh installation)

---
