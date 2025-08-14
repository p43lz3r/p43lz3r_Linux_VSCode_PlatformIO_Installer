#!/bin/bash

# Pop!_OS Development Environment Setup Script
# Sets up VSCode, PlatformIO, Python, Git, and Arduino development environment

set -e  # Exit on any error

echo "🚀 Setting up Pop!_OS Development Environment..."
echo "=================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check network connectivity
check_network() {
    print_status "Testing HTTPS connectivity to required servers..."
    local servers=("https://packages.microsoft.com" "https://raw.githubusercontent.com" "https://api.github.com")
    local failed_servers=()
    
    for server in "${servers[@]}"; do
        if ! curl -s --connect-timeout 5 --max-time 10 "$server" > /dev/null 2>&1; then
            failed_servers+=("$server")
        fi
    done
    
    if [ ${#failed_servers[@]} -gt 0 ]; then
        print_error "Cannot reach required servers for installation:"
        for server in "${failed_servers[@]}"; do
            print_error "  ✗ $server"
        done
        print_error "Please check your internet connection and try again."
        exit 1
    else
        print_status "✅ All required servers are reachable"
    fi
}

# Function to check system architecture
check_architecture() {
    print_status "Checking system architecture..."
    local arch=$(dpkg --print-architecture)
    
    case "$arch" in
        amd64|arm64|armhf)
            print_status "✅ Supported architecture detected: $arch"
            ;;
        *)
            print_error "❌ Unsupported architecture: $arch"
            print_error "This script supports: amd64, arm64, armhf"
            print_error "VSCode and other packages may not be available for your architecture."
            exit 1
            ;;
    esac
}

# Function to safely download with curl
safe_curl() {
    local url="$1"
    local output="$2"
    local max_retries=3
    local retry=0
    
    while [ $retry -lt $max_retries ]; do
        if [ -n "$output" ]; then
            # Download to file with HTTP status code checking
            if curl -sSL --connect-timeout 10 --max-time 30 --fail "$url" -o "$output"; then
                return 0
            fi
        else
            # Download to stdout with HTTP status code checking
            if curl -sSL --connect-timeout 10 --max-time 30 --fail "$url"; then
                return 0
            fi
        fi
        
        retry=$((retry + 1))
        if [ $retry -lt $max_retries ]; then
            print_warning "Download failed, retrying ($retry/$max_retries)..."
            sleep 2
        fi
    done
    
    print_error "Failed to download from $url after $max_retries attempts"
    return 1
}

# Function to verify VSCode extension installation
verify_vscode_extension() {
    local extension="$1"
    local max_attempts=3
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if code --list-extensions | grep -q "$extension"; then
            print_status "✅ Extension $extension installed successfully"
            return 0
        fi
        
        if [ $attempt -lt $max_attempts ]; then
            print_warning "Extension $extension not found, retrying installation..."
            code --install-extension "$extension" --force
        fi
        
        attempt=$((attempt + 1))
        sleep 2
    done
    
    print_error "❌ Failed to install extension $extension"
    return 1
}

# Check for sudo privileges early
print_status "Checking sudo privileges..."
if ! sudo -n true 2>/dev/null; then
    print_status "This script requires sudo privileges. You may be prompted for your password."
    if ! sudo true; then
        print_error "Sudo privileges required. Exiting."
        exit 1
    fi
fi

# Check system architecture compatibility
check_architecture

# Check network connectivity
print_status "Checking network connectivity..."
check_network

# Update system first
print_status "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install essential packages (check if already installed)
print_status "Installing essential packages..."
sudo apt install -y curl wget software-properties-common apt-transport-https ca-certificates gnupg lsb-release

# Check and install Git
if ! command -v git &> /dev/null; then
    print_status "Installing Git..."
    sudo apt install -y git
else
    print_status "Git already installed: $(git --version)"
fi

# Check and install Python3 and pip (usually pre-installed on Pop!_OS)
if ! command -v python3 &> /dev/null; then
    print_status "Installing Python3..."
    sudo apt install -y python3 python3-pip python3-venv
else
    print_status "Python3 already installed: $(python3 --version)"
fi

# Ensure pip is installed
if ! command -v pip3 &> /dev/null; then
    print_status "Installing pip3..."
    sudo apt install -y python3-pip
fi

# Ensure python3-venv is available
print_status "Ensuring python3-venv is installed..."
sudo apt install -y python3-venv

# Install VSCode if not present
if ! command -v code &> /dev/null; then
    print_status "Installing Visual Studio Code..."
    
    # Add Microsoft GPG key and repository with error handling
    if safe_curl "https://packages.microsoft.com/keys/microsoft.asc" | sudo gpg --dearmor -o /usr/share/keyrings/microsoft-archive-keyring.gpg; then
        echo "deb [arch=amd64,arm64,armhf signed-by=/usr/share/keyrings/microsoft-archive-keyring.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
        
        sudo apt update
        sudo apt install -y code
    else
        print_error "Failed to add Microsoft repository. Exiting."
        exit 1
    fi
else
    print_status "VSCode already installed: $(code --version | head -n1)"
fi

# Install PlatformIO Core (command line tool)
if ! command -v pio &> /dev/null; then
    print_status "Installing PlatformIO Core..."
    
    # Download PlatformIO installer to a temporary file first
    temp_installer="/tmp/get-platformio.py"
    if safe_curl "https://raw.githubusercontent.com/platformio/platformio-core-installer/master/get-platformio.py" "$temp_installer"; then
        print_status "Download completed. File size: $(wc -c < "$temp_installer") bytes"
        
        # Check if file exists and has content
        if [ ! -s "$temp_installer" ]; then
            print_error "Downloaded file is empty"
            rm -f "$temp_installer"
            exit 1
        fi
        
        # Show first few lines for debugging
        print_status "First few lines of downloaded file:"
        head -n 3 "$temp_installer"
        
        # Verify the downloaded file looks like a Python script (check for common Python patterns)
        if grep -q -E "(import |def |python|PlatformIO|#!/)" "$temp_installer"; then
            print_status "File validation passed, executing installer..."
            if python3 "$temp_installer"; then
                print_status "✅ PlatformIO Core installed successfully"
            else
                print_error "Failed to execute PlatformIO installer"
                rm -f "$temp_installer"
                exit 1
            fi
        else
            print_error "Downloaded file doesn't appear to be a valid Python script"
            print_error "File contents:"
            cat "$temp_installer"
            rm -f "$temp_installer"
            exit 1
        fi
        rm -f "$temp_installer"
    else
        print_error "Failed to download PlatformIO installer"
        exit 1
    fi
    
    # Add PlatformIO to PATH for current user (only if not already present)
    PIO_PATH_EXPORT='export PATH="$PATH:$HOME/.platformio/penv/bin"'
    if ! grep -Fxq "$PIO_PATH_EXPORT" ~/.bashrc; then
        print_status "Adding PlatformIO to PATH in ~/.bashrc..."
        echo "$PIO_PATH_EXPORT" >> ~/.bashrc
    else
        print_status "PlatformIO PATH already exists in ~/.bashrc"
    fi
    
    # Apply PATH for current session
    export PATH="$PATH:$HOME/.platformio/penv/bin"
    
    # Also add to current shell profile alternatives if they exist
    for profile in ~/.profile ~/.bash_profile ~/.zshrc; do
        if [[ -f "$profile" ]] && ! grep -Fxq "$PIO_PATH_EXPORT" "$profile"; then
            echo "$PIO_PATH_EXPORT" >> "$profile"
            print_status "Added PlatformIO PATH to $profile"
        fi
    done
else
    print_status "PlatformIO Core already installed: $(pio --version)"
fi

# Install PlatformIO IDE extension for VSCode with verification
print_status "Installing PlatformIO IDE extension for VSCode..."
verify_vscode_extension "platformio.platformio-ide"

# Install Python extension for VSCode with verification
print_status "Installing Python extension for VSCode..."
verify_vscode_extension "ms-python.python"

# Install C/C++ extension for VSCode with verification
print_status "Installing C/C++ extension for VSCode..."
verify_vscode_extension "ms-vscode.cpptools"

# Setup Arduino/Serial permissions
print_status "Setting up Arduino/Serial permissions..."

# Add user to dialout group for serial access
sudo usermod -a -G dialout $USER
print_status "Added $USER to dialout group"

# Check for BRLTTY (braille display interface) that can interfere with Arduino serial ports
print_status "Checking for BRLTTY (braille display interface)..."
if dpkg -l | grep -q "^ii.*brltty" 2>/dev/null; then
    print_warning "⚠️  BRLTTY is installed and can interfere with Arduino serial ports!"
    echo ""
    echo "🔍 What is BRLTTY?"
    echo "   BRLTTY is a braille display interface for visually impaired users."
    echo "   Unfortunately, it assumes USB-to-serial devices (like Arduino Nano,"
    echo "   boards with CH340, FTDI chips) are braille displays and takes over"
    echo "   the serial ports, preventing Arduino IDE/PlatformIO from accessing them."
    echo ""
    echo "📋 Affected Arduino boards:"
    echo "   • Arduino Nano (with CH340 or FTDI chips)"
    echo "   • Clone boards with CH340, CP210x, FT232R chips"
    echo "   • Many third-party Arduino-compatible boards"
    echo ""
    echo "🎯 Solutions:"
    echo "   1. Remove BRLTTY (recommended if you don't use braille displays)"
    echo "   2. Keep BRLTTY and configure it to ignore Arduino devices (advanced)"
    echo ""
    
    while true; do
        echo -n "❓ Do you want to remove BRLTTY? This will fix Arduino serial port issues. (y/n/info): "
        read -r brltty_choice
        
        case $brltty_choice in
            [Yy]* ) 
                print_status "Removing BRLTTY..."
                sudo apt remove -y brltty
                print_status "✅ BRLTTY removed successfully"
                break
                ;;
            [Nn]* ) 
                print_warning "BRLTTY kept installed. You may experience Arduino serial port issues."
                print_warning "If you have problems, you can manually remove it later with: sudo apt remove brltty"
                break
                ;;
            [Ii]* | "info" )
                echo ""
                echo "ℹ️  Additional Information:"
                echo "   • If you use a braille display, keep BRLTTY installed"
                echo "   • If you don't use braille displays, removing BRLTTY is safe"
                echo "   • You can always reinstall BRLTTY later with: sudo apt install brltty"
                echo "   • Alternative: Configure BRLTTY to ignore specific USB devices (advanced)"
                echo ""
                ;;
            * ) 
                echo "Please answer y (yes), n (no), or info for more information."
                ;;
        esac
    done
elif dpkg -l | grep -q "brltty" 2>/dev/null; then
    print_status "✅ BRLTTY packages found but not fully installed - no Arduino conflicts expected"
else
    print_status "✅ BRLTTY not installed - no Arduino serial port conflicts expected"
fi

# Install required packages for Arduino development
print_status "Installing Arduino development packages..."
# Note: python3-serial provides the pyserial functionality
sudo apt install -y python3-serial

# Check and install esptool for ESP32/ESP8266 development
if ! command -v esptool &> /dev/null && ! command -v esptool.py &> /dev/null; then
    print_status "Installing esptool for ESP32/ESP8266 development..."
    sudo apt install -y esptool
    esptool_was_installed=true
else
    if command -v esptool &> /dev/null; then
        print_status "esptool already installed: $(esptool version 2>/dev/null || echo 'version detection failed')"
    elif command -v esptool.py &> /dev/null; then
        print_status "esptool.py already installed: $(esptool.py version 2>/dev/null || echo 'version detection failed')"
    fi
    esptool_was_installed=false
fi

# Check for ESP32-S3 stub flasher file and download if missing
if command -v esptool &> /dev/null || command -v esptool.py &> /dev/null; then
    esp32s3_stub_path="/usr/lib/python3/dist-packages/esptool/targets/stub_flasher/stub_flasher_32s3.json"
    
    if [ ! -f "$esp32s3_stub_path" ]; then
        print_status "Checking ESP32-S3 support in esptool..."
        echo ""
        echo "ℹ️  About ESP32-S3 Support:"
        echo "   The ESP32-S3 is a newer chip that requires specific flasher stub files"
        echo "   to upload code properly. System packages of esptool are often outdated"
        echo "   and missing the ESP32-S3 stub file, causing upload failures."
        echo ""
        echo "🔧 What this fix does:"
        echo "   • Downloads the latest ESP32-S3 stub file from Espressif's GitHub"
        echo "   • Installs it in the correct location for your system's esptool"
        echo "   • Enables ESP32-S3 development without replacing entire esptool package"
        echo ""
        print_status "ESP32-S3 stub flasher file missing, checking GitHub availability..."
        
        # First check if the file is available on GitHub
        github_stub_url="https://raw.githubusercontent.com/espressif/esptool/master/esptool/targets/stub_flasher/1/esp32s3.json"
        if curl -sSL --connect-timeout 10 --max-time 15 --fail --head "$github_stub_url" > /dev/null 2>&1; then
            print_status "ESP32-S3 stub file found on GitHub, downloading..."
            
            # Create directory if it doesn't exist
            stub_dir="/usr/lib/python3/dist-packages/esptool/targets/stub_flasher"
            if [ ! -d "$stub_dir" ]; then
                print_status "Creating esptool stub_flasher directory..."
                sudo mkdir -p "$stub_dir"
            fi
            
            # Download ESP32-S3 stub file from GitHub
            temp_stub="/tmp/esp32s3_stub.json"
            if safe_curl "$github_stub_url" "$temp_stub"; then
                # Verify downloaded file is a valid JSON file and not empty
                if [ -s "$temp_stub" ] && python3 -c "import json; json.load(open('$temp_stub'))" 2>/dev/null; then
                    # Move to correct location with correct name
                    sudo mv "$temp_stub" "$esp32s3_stub_path"
                    sudo chmod 644 "$esp32s3_stub_path"
                    print_status "✅ ESP32-S3 stub flasher file installed successfully"
                else
                    print_error "Downloaded ESP32-S3 stub file appears invalid (not valid JSON or empty)"
                    print_status "File contents preview:"
                    head -n 5 "$temp_stub" 2>/dev/null || echo "Could not read file"
                    rm -f "$temp_stub"
                fi
            else
                print_error "Failed to download ESP32-S3 stub flasher file"
                print_warning "ESP32-S3 development may not work properly"
            fi
        else
            print_warning "⚠️  ESP32-S3 stub file not available on GitHub"
            echo ""
            echo "ℹ️  This may indicate:"
            echo "   • GitHub repository structure has changed"
            echo "   • File has been moved to a different location"
            echo "   • Temporary GitHub connectivity issues"
            echo ""
            echo "💡 Impact:"
            echo "   • ESP32/ESP8266 development will work normally"
            echo "   • ESP32-S3 specific development may have issues"
            echo "   • You can manually fix this later if needed"
            echo ""
            echo "🔗 Manual download URL: $github_stub_url"
            echo ""
            
            while true; do
                echo -n "❓ Continue with script setup without ESP32-S3 stub fix? (y/n): "
                read -r continue_choice
                
                case $continue_choice in
                    [Yy]* ) 
                        print_status "Continuing setup without ESP32-S3 stub fix..."
                        break
                        ;;
                    [Nn]* ) 
                        print_error "Setup cancelled by user due to ESP32-S3 stub issue"
                        print_status "You can retry the script later or manually install the stub file"
                        exit 1
                        ;;
                    * ) 
                        echo "Please answer y (yes to continue) or n (no, exit script)."
                        ;;
                esac
            done
        fi
    else
        print_status "✅ ESP32-S3 stub flasher file already available"
    fi
fi

# Install additional useful packages for embedded development
print_status "Installing additional development tools..."
sudo apt install -y build-essential cmake ninja-build

# Install serial terminal tools for monitoring and debugging
print_status "Installing serial terminal tools..."
sudo apt install -y minicom picocom screen

# Ensure FUSE is available for AppImages (Arduino IDE 2.x, etc.)
print_status "Installing FUSE for AppImage support..."
sudo apt install -y fuse3 libfuse2

# Check if UFW firewall might interfere with development
print_status "Checking firewall status..."
if command -v ufw &> /dev/null && ufw status | grep -q "Status: active"; then
    print_warning "⚠️  UFW firewall is active."
    echo ""
    echo "ℹ️  Firewall Impact on Development:"
    echo "   ✅ Arduino USB uploads: No issues (local communication)"
    echo "   ✅ VSCode/PlatformIO: No issues (outgoing connections allowed)"
    echo "   ⚠️  ESP32/ESP8266 OTA uploads: May be blocked (wireless programming)"
    echo "   ⚠️  Web-based Arduino programming: May be blocked"
    echo ""
    echo "💡 If you experience wireless programming issues later:"
    echo "   • Temporary disable: sudo ufw disable"
    echo "   • Or allow specific ports for your ESP projects"
    echo ""
elif command -v ufw &> /dev/null; then
    print_status "✅ UFW firewall is installed but disabled - no development conflicts expected"
else
    print_status "✅ No UFW firewall detected - no development conflicts expected"
fi

# Create a test Python virtual environment to verify everything works
print_status "Testing Python virtual environment..."
cd /tmp
python3 -m venv test_venv
source test_venv/bin/activate
pip install --upgrade pip
pip install pyserial
deactivate
rm -rf test_venv
print_status "Python virtual environment test successful"

# Test PlatformIO installation
print_status "Testing PlatformIO installation..."
if command -v pio &> /dev/null; then
    pio system info
    print_status "PlatformIO test successful"
else
    print_warning "PlatformIO might need PATH refresh. Try: source ~/.bashrc"
fi

# Create a sample project directory
PROJECTS_DIR="$HOME/Arduino_Projects"
if [ ! -d "$PROJECTS_DIR" ]; then
    print_status "Creating projects directory: $PROJECTS_DIR"
    mkdir -p "$PROJECTS_DIR"
fi

# Final instructions
echo ""
echo "=============================================="
echo -e "${GREEN}✅ Setup Complete!${NC}"
echo "=============================================="
echo ""
echo "📋 What was installed/configured:"
echo "  • VSCode with PlatformIO, Python, and C++ extensions"
echo "  • PlatformIO Core for command-line development"
echo "  • Git (if not already present)"
echo "  • Python3 with venv support"
echo "  • Serial/Arduino development tools"
echo "  • User added to dialout group for serial access"
echo "  • Projects directory: $PROJECTS_DIR"
echo ""
echo "🔄 Important: You need to LOG OUT and LOG BACK IN"
echo "   (or restart) for serial port permissions to take effect!"
echo ""
echo "🚀 Quick start:"
echo "  1. Open VSCode: code"
echo "  2. Install PlatformIO extension will auto-activate"
echo "  3. Create new PlatformIO project"
echo "  4. Connect Arduino and upload!"
echo ""
echo "📡 Test serial ports: ls /dev/ttyUSB* /dev/ttyACM*"
echo "🔍 Monitor serial: pio device monitor"
echo ""

# Check if reboot is recommended
if groups $USER | grep -q dialout; then
    print_status "Serial permissions should work after logout/login"
else
    print_warning "You may need to reboot for all permissions to take effect"
fi

print_status "Setup script completed successfully! 🎉"
