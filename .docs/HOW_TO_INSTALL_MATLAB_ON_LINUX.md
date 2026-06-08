# Has anyone got MATLAB working in Archlinux ?

I need to install matlab for my course. I have academic license. I have tried the methods listed in Archwiki, none worked. So I gave and removed everything. Currently i am using MATLAB in windows (I have a dual boot setup).

Is there any way to actually get MATLAB working in Arch ??

[permalink](http://reddit.com/r/archlinux/comments/1n4ot2k/has_anyone_got_matlab_working_in_archlinux/)
by *Ill_Scratch_7432* (↑ 18/ ↓ 0)

## Comments

##### Here's the guide I made yesterday when I achieved to install it

## Install Docker, Distrobox and mpm (the matlab pacakge manager)

```bash
yay -S --noconfirm docker distrobox matlab-mpm-bin
```

- docker to use as backend on distrobox
- distrobox to launch with de necesary dependencies matlab
- matlab mpm to install in the host

(the performance when using docker is the almost the same as without it and I was able to install it almost everywhere, the use of docker it just due to my preference if it works it works)

```bash
## Activate docker and add it to the user group
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
newgrp docker 

$USER is generally obtainable via whoami


## Install matlab via mpm
mpm install --release=R2025b \
    --destination=$HOME/.local/MATLAB/R2025b \
    --products MATLAB 
```

This will take some time, grab a coffe and wait to finish, it might seem like its doing nothing but it just kinda slow.
I use the .local/MATLAB/2025b due to it not giving strange error, you will need to open the binary via ~/.local/MATLAB/R2025b/bin/matlab (I will explain later on how to create a .desktop to launch it via rofi or fuzzel or whatever)

```bash
## Create de container (Debian 13 Trixie o 12 Bookworm)
distrobox create -n matlab --image docker.io/debian:13

## Access the container
distrobox enter matlab
```

```bash

## When into the container update and install dependencies

## Basic
sudo apt-get update && sudo apt-get install -y build-essential git procps locales

## DE
sudo apt-get install task-desktop   
```

I install the whole thing, its overkill, but it works all the time, when trying to minimize i generally got huge errors.

## Activate license

Generally the matlab executable will fail the first time due to license problems.
You can activate it in the **in the box** via:

```bash
~/.local/MATLAB/R2025b/bin/glnxa64/MathWorksProductAuthorizer
```

This will give you a pop up to use your account to gain access to matlab.
If everything is alright proceed.

## Execute matlab

The general command

```bash
~/.local/MATLAB/R2025b/bin/matlab -desktop
```

If this fails execute without GUI, this is kinda of the same, the figures will still be printed eventhough you don't have a gui and can execute everything all right

```bash
~/.local/MATLAB/R2025b/bin/matlab -nodesktop
```

If this also fails then you can use outside of the box

```bash
/bin/sh -c "export _JAVA_AWT_WM_NONREPARENTING=1; /usr/bin/distrobox enter matlab -- /home/davidn/.local/MATLAB/R2025b/bin/matlab -desktop"
```

## Create a .desktop file (to access via rofi or fuzzel)

Go to ~/.local/share/applications/
create a file matlab.desktop (or whatever you want to name it)

```bash
[Desktop Entry]
Name=MATLAB
GenericName=Scientific Computing
Comment=MATLAB en contenedor Debian
Type=Application
Categories=Science;Development;Education;
Terminal=false
Icon=/home/davidn/.local/share/icons/distrobox/debian.png
Exec=/usr/bin/distrobox enter matlab -- /home/$user/.local/MATLAB/R2025b/bin/matlab -desktop
```

Change the $USER by your user, and the matlab location by yours, and this should launch matlab in desktop mode.

This guide is based on: <https://bbs.archlinux.org/viewtopic.php?id=305604&p=2>
