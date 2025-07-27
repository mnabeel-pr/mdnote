#!/bin/bash

# mdnote installation script

set -e

echo "🚀 Installing mdnote..."

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Installation directory
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"
CONFIG_DIR="$HOME/.config/mdnote"

# Check if running as root
if [ "$EUID" -eq 0 ] && [ -z "$FORCE_ROOT" ]; then 
   echo -e "${RED}⚠️  Please don't run this script as root!${NC}"
   echo "If you really need to, set FORCE_ROOT=1"
   exit 1
fi

# Check dependencies
check_dependency() {
    if ! command -v "$1" &> /dev/null; then
        echo -e "${YELLOW}⚠️  Warning: $1 is not installed.${NC}"
        if [ "$1" = "fzf" ]; then
            echo "   fzf is required for the task completion feature."
            echo "   Install it from: https://github.com/junegunn/fzf"
        fi
        return 1
    fi
    return 0
}

echo "Checking dependencies..."
check_dependency "bash"
check_dependency "grep"
check_dependency "awk"
check_dependency "fzf"

# Create config directory
echo "Creating config directory..."
mkdir -p "$CONFIG_DIR"

# Copy executable
echo "Installing mdnote to $INSTALL_DIR..."
if [ -w "$INSTALL_DIR" ]; then
    cp mdnote.sh "$INSTALL_DIR/mdnote"
    chmod +x "$INSTALL_DIR/mdnote"
else
    echo -e "${YELLOW}⚠️  Cannot write to $INSTALL_DIR${NC}"
    echo "Trying with sudo..."
    sudo cp mdnote.sh "$INSTALL_DIR/mdnote"
    sudo chmod +x "$INSTALL_DIR/mdnote"
fi

# Copy example config if no config exists
if [ ! -f "$CONFIG_DIR/config" ] && [ ! -f "$HOME/.mdnoterc" ]; then
    echo "Creating config file..."
    cp config.example "$CONFIG_DIR/config"
    
    # Try to detect a suitable editor
    DETECTED_EDITOR=""
    if [ -n "${EDITOR:-}" ]; then
        DETECTED_EDITOR="$EDITOR"
    else
        for editor in nano vim nvim code vi emacs; do
            if command -v "$editor" &> /dev/null; then
                DETECTED_EDITOR="$editor"
                break
            fi
        done
    fi
    
    # Update the config with detected editor
    if [ -n "$DETECTED_EDITOR" ]; then
        sed -i.bak "s/EDITOR_CMD=\"nano\"/EDITOR_CMD=\"$DETECTED_EDITOR\"/" "$CONFIG_DIR/config"
        rm -f "$CONFIG_DIR/config.bak"
        echo -e "${GREEN}✓ Detected editor: $DETECTED_EDITOR${NC}"
    fi
    
    echo -e "${YELLOW}📝 Please edit $CONFIG_DIR/config to set your vault path${NC}"
else
    echo "Config file already exists, skipping..."
fi

# Add to PATH if needed
if ! echo "$PATH" | grep -q "$INSTALL_DIR"; then
    echo -e "${YELLOW}⚠️  $INSTALL_DIR is not in your PATH${NC}"
    echo "Add this line to your shell config (.bashrc, .zshrc, etc.):"
    echo "  export PATH=\"\$PATH:$INSTALL_DIR\""
fi

echo -e "${GREEN}✅ mdnote installed successfully!${NC}"
echo ""
echo "Next steps:"
echo "  1. Edit the config file: $CONFIG_DIR/config"
echo "  2. Set your vault path in the config"
echo "  3. Run 'mdnote --help' to see available commands"
echo ""
echo "Quick start:"
echo "  mdnote \"Your first journal entry\""
echo "  mdnote -t \"Your first task\"" 