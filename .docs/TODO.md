# Linux - Configuration and planning

<!-- toc -->

- [Environment and base image selection](#environment-and-base-image-selection)
- [Desktop and interface customization](#desktop-and-interface-customization)
- [Automation and setup scripts](#automation-and-setup-scripts)
- [Documentation and help system](#documentation-and-help-system)
- [Persistence and image creation](#persistence-and-image-creation)

<!-- tocstop -->

## Environment and base image selection

- [ ] Decide distro and base image
  - Candidates: Linux Mint, Fedora, Omarchy, Ubuntu ...
- [ ] Set up a local virtual machine or test machine to build and capture the configuration (Docker?)
- [ ] Install essential development and utility packages:
  - System: [`rclone`](https://github.com/rclone/rclone), [`tmux`](https://github.com/tmux/tmux), [`git`](https://git-scm.com/), [`curl`](https://github.com/curl/curl), [`pandoc`](https://pandoc.org/), [`jq`](https://github.com/jqlang/jq) (needed for Västtrafik API processing)
  - Editors/Tools: [`neovim`](https://neovim.io/), `python3-devel`
  - Libraries: `python3-matplotlib`, `python3-numpy`, `python3-scipy`
  - Hub preparation: [`newsboat`](https://github.com/newsboat/newsboat)
  - Plugin managers: [`LazyVim`](https://www.lazyvim.org/), ([`tmux`](https://github.com/tmux-plugins/tpm) or [`tpack`](https://github.com/tmuxpack/tpack)) (good opportunity fix my own config)
  - Fonts: Set up some [`nerdfont`](https://www.nerdfonts.com/)

## Desktop and interface customization

- [ ] Decide desktop environment
  - Candidates: [`Gnome`](https://www.gnome.org/)
- [ ] Decide file manager
  - Candidates: [`Nemo`](https://github.com/linuxmint/nemo)
- [ ] Configure some default keybinds via dconf/gsettings scripts:
  - `Super + Enter`: Open terminal
  - `Super + E`: Open file manager
  - `Super + Q`: Close window etc.
- [ ] Decide tiling window manager for hub prep (possible to toggle between TWM and DE?)
  - Candidates: [`pop-shell`](https://github.com/pop-os/shell), [`Hyprland`](https://hypr.land/), [`i3`](https://i3wm.org/), [`Sway`](https://swaywm.org/)

## Automation and setup scripts

- [ ] **OneDrive Script (`setup-onedrive`):**
  - Script to invoke `rclone config`
  - Automatically create the remote definition for OneDrive.
  - Add a systemd user service template to mount the OneDrive folder at login.
- [ ] **Eduroam Script (`setup-eduroam`):**
  - Automate certificate placement in `~/.config/eduroam`
  - Use `nmcli` to generate the wireless profile (WPA2-Enterprice, PEAP, MSCHAPv2)
- [ ] **Shell configuration:**
  - Create a custom `.bashrc` or `.bash_profile`.
  - Add git branch visibility to the prompt
  - Add basic aliases (e.g., `ll`, `la`, `ls tree`)

## Documentation and help system

- [ ] Create the master markdown documentation file covering:
  - Basic CLI usage (cd, ls, mkdir, rm, chmod, chown, lsblk)
  - Describe some basics on how the OS is structured and how operates:
    - File system: `root`, `mnt`, `boot` `etc`, `dev`, `usr`, `var`, `opt`, `bin` ...
    - Privilege: `user`, `groups`, `sudo`
    - Shell scripts ([`sh`](https://github.com/dylanaraps/pure-sh-bible) vs. [`bash`](https://github.com/dylanaraps/pure-bash-bible) vs. [`zsh`]())
      - Importance of POSIX compliance for backwards compatibility in microcontrollers.
  - Navigation and keybinds (automation script or package that figure this out dynamically)
  - Package management: (`dnf`, `apt` or whatever the distro offers)
  - Tmux and Neovim cheat sheets
- [ ] Implement the access command script (e.g. `helpme` and `help-hub`)
  - Create a man page
  - Parse flag `-t` / `--tui`: Render documentation in terminal using `glow` or `less`
  - Parse flag `-w` / `--web`: Open documentation as local styled HTML page in browser

**Note to self:** start using /dev/ for development stuff

## Persistence and image creation

- [ ] Package the configuration into a reproducible shell script or Ansible playbook.
- [ ] Configure the live image or target installation to run in the post-install configuration script on initial boot.
- [ ] Flash the final image onto the target USB drive with a persistent storage partition.
