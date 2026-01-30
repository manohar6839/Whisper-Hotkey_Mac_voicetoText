#!/bin/bash

# ===========================================
# Whisper Mac Dictation - Automated Installer
# ===========================================

set -e

echo "========================================"
echo "🎤 Whisper Mac Dictation Installer"
echo "========================================"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="$HOME/MyProjects/whisper_hotkey"
HAMMERSPOON_DIR="$HOME/.hammerspoon"

# Helper functions
print_status() { echo -e "${GREEN}✓${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }

check_command() {
    if command -v "$1" &> /dev/null; then
        print_status "$1 found"
        return 0
    else
        return 1
    fi
}

# Step 1: Check/Install Homebrew
echo "📦 Step 1: Checking Homebrew..."
if ! check_command brew; then
    print_warning "Homebrew not found. Installing..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Add to PATH for Apple Silicon
    if [[ -f /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
fi
echo ""

# Step 2: Install system dependencies
echo "📦 Step 2: Installing system dependencies..."

if ! check_command python3; then
    brew install python@3.11
fi

if ! check_command ffmpeg; then
    print_warning "Installing ffmpeg..."
    brew install ffmpeg
else
    print_status "ffmpeg found"
fi

if ! brew list portaudio &>/dev/null; then
    print_warning "Installing portaudio..."
    brew install portaudio
else
    print_status "portaudio found"
fi

if [[ ! -d "/Applications/Hammerspoon.app" ]]; then
    print_warning "Installing Hammerspoon..."
    brew install --cask hammerspoon
else
    print_status "Hammerspoon found"
fi
echo ""

# Step 3: Create project directory
echo "📁 Step 3: Setting up project directory..."
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"
print_status "Directory: $INSTALL_DIR"
echo ""

# Step 4: Create Python virtual environment
echo "🐍 Step 4: Setting up Python environment..."
if [[ ! -d "$INSTALL_DIR/venv" ]]; then
    python3 -m venv venv
    print_status "Virtual environment created"
else
    print_status "Virtual environment exists"
fi

source venv/bin/activate
pip install --upgrade pip -q
print_status "pip upgraded"

pip install openai-whisper pyaudio numpy -q
print_status "Python packages installed (whisper, pyaudio, numpy)"
echo ""

# Step 5: Copy Python script
echo "📄 Step 5: Installing scripts..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -f "$SCRIPT_DIR/whisper_dictate.py" ]]; then
    cp "$SCRIPT_DIR/whisper_dictate.py" "$INSTALL_DIR/"
    print_status "whisper_dictate.py installed"
else
    print_error "whisper_dictate.py not found in $SCRIPT_DIR"
    exit 1
fi
echo ""

# Step 6: Setup Hammerspoon
echo "🔨 Step 6: Configuring Hammerspoon..."
mkdir -p "$HAMMERSPOON_DIR"

if [[ -f "$SCRIPT_DIR/init.lua" ]]; then
    # Backup existing config
    if [[ -f "$HAMMERSPOON_DIR/init.lua" ]]; then
        cp "$HAMMERSPOON_DIR/init.lua" "$HAMMERSPOON_DIR/init.lua.backup.$(date +%Y%m%d_%H%M%S)"
        print_warning "Existing config backed up"
    fi
    
    cp "$SCRIPT_DIR/init.lua" "$HAMMERSPOON_DIR/"
    print_status "Hammerspoon config installed"
else
    print_error "init.lua not found in $SCRIPT_DIR"
    exit 1
fi
echo ""

# Step 7: Download Whisper model
echo "🤖 Step 7: Downloading Whisper model (base)..."
python3 -c "import whisper; whisper.load_model('base')" 2>/dev/null
print_status "Whisper 'base' model ready"
echo ""

# Step 8: Permissions reminder
echo "========================================"
echo "🔐 IMPORTANT: Grant Permissions!"
echo "========================================"
echo ""
echo "Open System Settings and enable these:"
echo ""
echo "1. Privacy & Security → Accessibility"
echo "   → Enable Hammerspoon ✓"
echo ""
echo "2. Privacy & Security → Microphone"
echo "   → Enable Hammerspoon ✓"
echo ""
echo "========================================"
echo ""

# Step 9: Launch Hammerspoon
echo "🚀 Launching Hammerspoon..."
open -a Hammerspoon
echo ""

# Done!
echo "========================================"
echo -e "${GREEN}✅ Installation Complete!${NC}"
echo "========================================"
echo ""
echo "Usage: Press ⌘⇧V anywhere to dictate"
echo ""
echo "Files installed:"
echo "  📁 $INSTALL_DIR"
echo "  📄 $HAMMERSPOON_DIR/init.lua"
echo ""
echo "Troubleshooting:"
echo "  - Click Hammerspoon icon → Console for logs"
echo "  - Run: rm /tmp/whisper_dictation.lock (if stuck)"
echo ""
echo "Enjoy! 🎤"
