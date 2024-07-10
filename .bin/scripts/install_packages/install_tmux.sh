#!/bin/bash

install_on_debian(){
    # Install tmux
    sudo apt install tmux

    # Make a symlink to your tmux configuration
    ln -s $HOME/.dotfiles/packages/config/tmux/tmux.conf $HOME/.tmux.conf

    # Clone TPM (Tmux Plugin Manager)
    git clone https://github.com/tmux-plugins/tpm $HOME/.dotfiles/packages/config/tmux/tpm

    # Start tmux and install plugins using TPM
    tmux new-session -d -s temp_session  # Create a new detached tmux session
    tmux send-keys -t temp_session 'tmux source ~/.tmux.conf' Enter  # Source the tmux configuration file
    sleep 1  # Wait briefly to ensure the configuration is sourced
    tmux send-keys -t temp_session ':PlugInstall' Enter  # Install plugins using TPM (assuming :PlugInstall is the command for TPM)
    tmux send-keys -t temp_session 'exit' Enter  # Exit the tmux session once done
    tmux attach-session -t temp_session  # Attach to the temporary session to see the installation progress
}

install_on_debian

echo "Tmux installation complete.."
