#!/bin/bash

# Update packages
sudo apt-get -y update
sudo apt-get -y upgrade
sudo apt-get -y dist-upgrade

# Install packages
sudo apt-get install -y iptables hostapd isc-dhcp-server

# Set timezone and language
sudo echo "America/Sao_Paulo" > /etc/timezone
sudo dpkg-reconfigure -f noninteractive tzdata

sudo apt-get install -y language-pack-pt-base

# Configure udhcpd
sudo bash -c 'cat > /etc/dhcp/dhcpd.conf' << EOT
ddns-update-style none;
default-lease-time 600;
max-lease-time 7200;
authoritative;
log-facility local7;

subnet 192.168.4.0 netmask 255.255.255.0 {
  range 192.168.4.10 192.168.4.60;
  option broadcast-address 192.168.4.255;
  option routers 192.168.4.1;
  default-lease-time 600;
  max-lease-time 7200;
  option domain-name "homez";
  option domain-name-servers 8.8.8.8, 8.8.4.4;
}
EOT

sudo sed -i 's/^INTERFACES=""/INTERFACES="wlan0" /g' /etc/default/isc-dhcp-server

# Set a static IP
sudo bash -c 'cat > /etc/network/interfaces' << EOT
auto lo

iface lo inet loopback
iface eth0 inet manual

allow-hotplug wlan0
iface wlan0 inet static
    address 192.168.4.1
    netmask 255.255.255.0
 EOT

sudo ifconfig wlan0 192.168.4.1

sudo bash -c 'cat > /etc/hostapd/hostapd.conf' << EOT
interface=wlan0
driver=nl80211
ssid=Server
hw_mode=g
channel=6
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=1 # 1 to Hide SSID
wpa=2
wpa_passphrase=123456789
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
EOT

sudo sed -i 's/^#DAEMON_CONF=""/DAEMON_CONF="\/etc\/hostapd\/hostapd.conf"/g' /etc/default/hostapd

sudo service hostapd start
sudo service udhcpd start

sudo update-rc.d hostapd enable
sudo update-rc.d udhcpd enable

sudo wget -O - https://nodejs.org/dist/v4.4.7/node-v4.4.7-linux-armv6l.tar.xz | sudo tar -C /usr/local/ --strip-components=1 -xJ
sudo apt-get install -y git
git clone https://github.com/renanvaz/arduino-mqtt-api.git

(crontab -u pi -l ; echo '@reboot node /home/pi/arduino-mqtt-api/lib/TestServerUDP.js') | crontab -u pi -
