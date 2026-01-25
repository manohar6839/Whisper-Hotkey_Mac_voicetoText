#!/bin/bash
#
# Whisper Hotkey Installer for macOS
# ==================================
# One-click installer for global voice-to-text
#
# Run with: bash install.sh
#

set -e  # Exit on any error

echo "=============================================="
echo "  🎙️ Whisper Hotkey Installer"
echo "=============================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Check if running on macOS
if [[ "$(uname)" != "Darwin" ]]; then
    echo -e "${RED}Error: This script is for macOS only${NC}"
    exit 1
fi

echo "Step 1: Checking for Homebrew..."
if ! command -v brew &> /dev/null; then
    echo -e "${YELLOW}Homebrew not found. Installing...${NC}"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add Homebrew to PATH for Apple Silicon Macs
    if [[ -f "/opt/homebrew/bin/brew" ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
    fi
else
    echo -e "${GREEN}✓ Homebrew found${NC}"
fi

echo ""
echo "Step 2: Installing Hammerspoon..."
if [[ -d "/Applications/Hammerspoon.app" ]]; then
    echo -e "${GREEN}✓ Hammerspoon already installed${NC}"
else
    brew install --cask hammerspoon
    echo -e "${GREEN}✓ Hammerspoon installed${NC}"
fi

echo ""
echo "Step 3: Installing portaudio and ffmpeg..."
brew install portaudio ffmpeg 2>/dev/null || true
echo -e "${GREEN}✓ Audio dependencies installed${NC}"

echo ""
echo "Step 4: Creating Python virtual environment..."
VENV_DIR="$SCRIPT_DIR/venv"

if [[ -d "$VENV_DIR" ]]; then
    echo -e "${YELLOW}Virtual environment already exists, updating...${NC}"
else
    python3 -m venv "$VENV_DIR"
    echo -e "${GREEN}✓ Virtual environment created${NC}"
fi

echo ""
echo "Step 5: Installing Python dependencies..."
source "$VENV_DIR/bin/activate"
pip install --upgrade pip -q
pip install -r "$SCRIPT_DIR/requirements.txt" -q
deactivate
echo -e "${GREEN}✓ Python packages installed${NC}"

echo ""
echo "Step 6: Making scripts executable..."
chmod +x "$SCRIPT_DIR/whisper_run.sh"
chmod +x "$SCRIPT_DIR/whisper_server_run.sh"
chmod +x "$SCRIPT_DIR/whisper_recorder.py"
chmod +x "$SCRIPT_DIR/whisper_server.py"
echo -e "${GREEN}✓ Scripts are executable${NC}"

echo ""
echo "Step 7: Setting up Hammerspoon config..."
mkdir -p ~/.hammerspoon

# Copy init.lua to Hammerspoon config, replacing SCRIPT_DIR placeholder
sed "s|\$SCRIPT_DIR|$SCRIPT_DIR|g" "$SCRIPT_DIR/init.lua" > ~/.hammerspoon/init.lua
echo -e "${GREEN}✓ Hammerspoon config installed${NC}"

echo ""
echo "Step 8: Starting Whisper background server..."
"$SCRIPT_DIR/whisper_server_run.sh" start
echo -e "${GREEN}✓ Server started${NC}"

echo ""
echo "=============================================="
echo -e "${GREEN}  ✅ Installation Complete!${NC}"
echo "=============================================="
echo ""
echo "Next steps:"
echo ""
echo "1. Open Hammerspoon from Applications"
echo "   (or run: open /Applications/Hammerspoon.app)"
echo ""
echo "2. Grant permissions when prompted:"
echo "   - Accessibility (System Settings → Privacy → Accessibility)"
echo "   - Microphone (will prompt on first recording)"
echo ""
echo "3. Click the Hammerspoon menu bar icon (🔨) → Reload Config"
echo ""
echo "4. Test it! Press Ctrl+Shift+Space to start recording"
echo ""
echo "=============================================="
echo "  Hotkey: Ctrl + Shift + Space"
echo "=============================================="
echo ""
echo "To start the server on future reboots:"
echo "  $SCRIPT_DIR/whisper_server_run.sh start"
echo ""
