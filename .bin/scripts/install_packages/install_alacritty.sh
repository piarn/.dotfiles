#!/bin/bash

install_on_debian() {
	sudo apt install alacritty
	ln -s $HOME/.dotfiles/packages/config/alacritty $HOME/.config/
}

install_on_debian

echo "Alacritty installation complete..."
