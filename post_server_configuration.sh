#!/bin/bash

#############################################
# Ubuntu Post Server Configuration Script
# Tested on: Ubuntu 20.04 LTS
# Written by: Eric Mathison (https://ericmathison.com/)
#
# Step 1: Create user
# Step 2: Harden sshd config
# Step 3: Configure iptables firewall
# Step 4: Configure unattended upgrades
# Step 5: Update packages
# Step 6: Change timezone
#############################################

USER="" # Create this user with sudo priveleges
USER_SSH_KEY="" # Add public key for new user
PORTS_TO_OPEN=22,80 # Allow access to these ports only. Use comma separated values without whitespaces
TIMEZONE="America/Anchorage" # Specify desired timezone

function main() {
    create_user
    sshd_config
    iptables_config
    unattended_upgrades
    update_packages
    change_timezone
}

function change_timezone() {
    # For a list of timezones type the following command in the console: timedatectl list-timezones
    timedatectl set-timezone $TIMEZONE
}

function create_user() {
    adduser --disabled-password --gecos "" $USER
    usermod -aG sudo $USER
    mkdir /home/$USER/.ssh/
    echo $USER_SSH_KEY > /home/$USER/.ssh/authorized_keys
    chmod 600 /home/$USER/.ssh/authorized_keys
    chmod 700 /home/$USER/.ssh/
    chown -R $USER:$USER /home/$USER/.ssh/
}

function sshd_config() {
    sed -i -r 's/^#?(PermitRootLogin|PasswordAuthentication) yes/\1 no/' /etc/ssh/sshd_config
    sed -i -r "s/.*PubkeyAuthentication.*/PubkeyAuthentication yes/g" /etc/ssh/sshd_config
    service ssh restart
}

function iptables_config() {
    iptables -F
    iptables -A INPUT -i lo -p all -j ACCEPT
    iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    iptables -P INPUT DROP
    iptables -P FORWARD DROP
    iptables -P OUTPUT ACCEPT

    # Open ports specified in $PORTS_TO_OPEN
    for i in $(echo $PORTS_TO_OPEN | sed "s/,/ /g")
    do
        iptables -A INPUT -p tcp --dport "$i" -j ACCEPT
    done

    # E: Unable to locate package iptables-persistent
    # Fix: run apt-get update before attempting to install iptables-persistent
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent
    iptables-save > /etc/iptables/rules.v4
}

function unattended_upgrades() {
    apt-get install -y unattended-upgrades

    FILE50='// Automatically upgrade packages from these (origin:archive) pairs'
    FILE50+='\nUnattended-Upgrade::Allowed-Origins {'
    FILE50+='\n\t"${distro_id}:${distro_codename}";'
    FILE50+='\n\t"${distro_id}:${distro_codename}-security";'
    FILE50+='\n\t"${distro_id}ESM:${distro_codename}";'
    FILE50+='\n\t"${distro_id}:${distro_codename}-updates";'
    FILE50+='\n};'
    FILE50+='\n\nUnattended-Upgrade::Package-Blacklist {'
    FILE50+='\n};'
    FILE50+='\n\nUnattended-Upgrade::DevRelease "auto";'
    echo -ne $FILE50 > /etc/apt/apt.conf.d/50unattended-upgrades

    FILE10='APT::Periodic::Update-Package-Lists "1";'
    FILE10+='\nAPT::Periodic::Download-Upgradeable-Packages "1";'
    FILE10+='\nAPT::Periodic::AutocleanInterval "7";'
    FILE10+='\nAPT::Periodic::Unattended-Upgrade "1";'
    echo -ne $FILE10 > /etc/apt/apt.conf.d/10periodic
}

function update_packages() {
    # DEBIAN_FRONTEND=noninteractive makes the default answers be used for all questions
    apt-get update && DEBIAN_FRONTEND=noninteractive apt-get -y upgrade && apt-get -y autoremove
}

main
