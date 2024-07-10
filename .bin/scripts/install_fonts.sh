#!/bin/sh

FONT_DIR="$HOME/.local/share/fonts"
DOTFILES_FONT_DIR="$HOME/.dotfiles/system/fonts"
FONT_ZIP="$DOTFILES_FONT_DIR/FiraCode.zip"

# Create font directory if it doesn't exist
mkdir -p "$FONT_DIR"

# Unzip the Nerd Font into the font directory
unzip -o "$FONT_ZIP" -d "$FONT_DIR"

# Update the font cache
if command -v fc-cache > /dev/null; then
  fc-cache -fv
fi

echo "Nerd Font installed!"
