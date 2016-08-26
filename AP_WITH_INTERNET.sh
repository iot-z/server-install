#!/bin/bash

LOCK_FILE=./waiting-for-reboot

if [ ! -f "$LOCK_FILE" ]; then
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

up iptables-restore < /etc/iptables.ipv4.nat
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

# Create a cron job to continue after reboot
(crontab -u pi -l ; echo '@reboot bash /home/pi/AP.sh') | crontab -u pi -
sudo update-rc.d cron enable

touch $LOCK_FILE

sudo reboot
else
sudo sh -c 'echo 1 > /proc/sys/net/ipv4/ip_forward'
sudo sed -i 's/^#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
sudo iptables -A FORWARD -i eth0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -i wlan0 -o eth0 -j ACCEPT
sudo sh -c 'iptables-save > /etc/iptables.ipv4.nat'

sudo service hostapd start
sudo service udhcpd start

sudo update-rc.d hostapd enable
sudo update-rc.d udhcpd enable

# Remove the cron job
(crontab -u pi -l | grep -v '@reboot bash /home/pi/AP.sh') | crontab -u pi -
rm $LOCK_FILE

sudo wget -O - https://nodejs.org/dist/v4.4.7/node-v4.4.7-linux-armv6l.tar.xz | sudo tar -C /usr/local/ --strip-components=1 -xJ
sudo apt-get install -y git
git clone https://github.com/renanvaz/arduino-mqtt-api.git

(crontab -u pi -l ; echo '@reboot node /home/pi/arduino-mqtt-api/lib/TestServerUDP.js') | crontab -u pi -

fi
