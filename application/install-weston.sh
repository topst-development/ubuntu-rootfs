#!/bin/bash

# APT updating
apt --fix-broken install -y || res=$?

echo "apt --fix-broken install"
if [ "${res}" = 1 ]; then
  echo "failed, apt --fix-broken install"
else
  echo "apt update"
  echo ""
  apt update -y || res=$?
  if [ "${res}" = 1 ]; then
    echo "failed, apt update"
  else
    echo "apt update"
    apt upgrade -y
  fi
fi

# Install Weston
# apt install -y weston gnome-colors gnome-human-icon-theme wlogout pcmanfm synaptic xwayland vlc jgmenu cinnamon fonts-baekmuk net-tools
# remove firefox library
apt install -y weston gnome-colors gnome-human-icon-theme wlogout pcmanfm synaptic xwayland vlc jgmenu net-tools bash file

# grant vlc as root
sed -i 's/geteuid/getppid/' /usr/bin/vlc

# Firefox install service file
# cat >/lib/systemd/system/firefox-install.service <<EOF
# [Unit]
# Description=Firefox Installation
# After=network.target

# [Service]
# ExecStart=/usr/bin/apt-get install -y firefox

# [Install]
# WantedBy=default.target
# EOF

# Weston service file
cat >/lib/systemd/system/weston.service <<EOF
[Unit]
Description=Weston Wayland compositor startup
RequiresMountsFor=/run
After=systemd-user-sessions.service

[Service]
User=root
EnvironmentFile=-/etc/systemd/weston.conf
PIDFile=/var/run/weston.pid
ExecStartPre=/bin/mkdir -p /run/user/root
ExecStartPre=/bin/chmod 0700 /run/user/root
ExecStart=/bin/bash -c 'sleep 5 && /usr/bin/weston \$OPTARGS'
ExecStop=/usr/bin/killall -9 weston
RestartSec=0
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Weston initial config file
cat > /usr/share/weston/weston.ini <<EOF
[core]
xwayland=true
shell=desktop-shell.so
require-input=false

[shell]
background-image=/usr/share/weston/TOPST-background.png
background-color=0xff002244
background-type=scale
panel-position=bottom
panel-color=0xff004977
clock-format=minutes
locking=false
lockscreen-icon=/usr/share/icons/gnome/256x256/actions/lock.png
lockscreen=/usr/share/backgrounds/gnome/pixels-l.png

[launcher]
path=/usr/bin/jgmenu --csv-file=/root/.config/jgmenu/jgmenu.csv --simple
icon=/usr/share/icons/gnome-colors-common/24x24/actions/system-log-out.png

[launcher]
path=/usr/bin/pcmanfm menu://applications
icon=/usr/share/icons/gnome-colors-common/24x24/places/gnome-colors.png

[launcher]
path=/usr/bin/synaptic-pkexec
icon=/usr/share/icons/gnome-colors-common/24x24/apps/synaptic.png

[launcher]
path=/usr/bin/pcmanfm
icon=/usr/share/icons/gnome-human/24x24/apps/file-manager.png

[launcher]
path=/usr/bin/weston-terminal --shell=/usr/bin/bash
icon=/usr/share/icons/gnome/24x24/apps/utilities-terminal.png

# [launcher]
# path=/usr/bin/firefox
# icon=/usr/share/icons/hicolor/24x24/apps/firefox.png
EOF

mkdir -p /root/.config/jgmenu

# Weston jgmenu config file
cat >/root/.config/jgmenu/jgmenu.csv <<EOF
VLC,vlc,vlc
# Browser,firefox,firefox
File manager,pcmanfm,pcmanfm
Terminal,weston-terminal --shell=/usr/bin/bash,org.gnome.Terminal
# Setting,gnome-control-center,org.gnome.Settings
Power,^checkout(power),power-manager

^tag(power)
Suspend,systemctl -i suspend,system-log-out
Reboot,systemctl -i reboot,system-reboot
Poweroff,systemctl -i poweroff,system-shutdown
EOF

cat >/root/.config/jgmenu/jgmenurc <<EOF
terminal_exec       = x-terminal-emulator
terminal_args       = -e
monitor             = 0
hover_delay         = 100
hide_back_items     = 1

menu_margin_x       = 0
menu_margin_y       = 30
menu_width          = 200
menu_padding_top    = 5
menu_padding_right  = 5
menu_padding_bottom = 5
menu_padding_left   = 5
menu_radius         = 1
menu_border         = 0
menu_halign         = left
menu_valign         = bottom

sub_spacing         = 1
sub_padding_top     = auto
sub_padding_right   = auto
sub_padding_bottom  = auto
sub_padding_left    = auto
sub_hover_action    = 1

item_margin_x       = 3
item_margin_y       = 3
item_height         = 25
item_padding_x      = 4
item_radius         = 1
item_border         = 0
item_halign         = left

sep_height          = 5

font                =
font_fallback       = xtg
icon_size           = 22
icon_text_spacing   = 10
icon_theme          =
icon_theme_fallback = xtg

arrow_string        = >
arrow_width         = 15

color_menu_bg = #000000 100
color_menu_bg_to = #000000 100
color_menu_border = #eeeeee 8

color_norm_bg = #000000 00
color_norm_fg = #eeeeee 100

color_sel_bg = #ffffff 20
color_sel_fg = #eeeeee 100
color_sel_border = #eeeeee 8

color_sep_fg = #ffffff 20 

color_scroll_ind = #eeeeee 40

color_title_fg = #eeeeee 50
color_title_bg = #000000 0
color_title_border = #000000 0
EOF

# Weston environment file
cat >/etc/systemd/weston.conf <<EOF
XDG_CONFIG_HOME=/usr/share/weston
XDG_RUNTIME_DIR=/run/user/root
OPTARGS="--tty=1 --idle-time=0 --log=/var/log/weston.log --continue-without-input"
IVI_DISPLAY_NUMBER=0
EOF

# Registor start service
systemctl enable weston
# systemctl enable firefox-install