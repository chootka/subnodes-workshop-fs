#! /bin/bash
#
# Raspberry Pi network configuration / AP, MESH install script
# Author: Sarah Grant
# Contributors: Mark Hansen, Matthias Strubel, Danja Vasiliev
# took guidance from a script by Paul Miller : https://dl.dropboxusercontent.com/u/1663660/scripts/install-rtl8188cus.sh
# Updated 6 March 2019
#
# TO-DO
# - allow a selection of radio drivers
# - fix addressing to avoid collisions below w/avahi
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #





# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# first find out if this is RPi3 or not, based on revision code
# reference: http://www.raspberrypi-spy.co.uk/2012/09/checking-your-raspberry-pi-board-version/
REV="$(cat /proc/cpuinfo | grep 'Revision' | awk '{print $3}')"





# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# CHECK USER PRIVILEGES
(( `id -u` )) && echo "This script *must* be ran with root privileges, try prefixing with sudo. i.e sudo $0" && exit 1





# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #	
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #	
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #	
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #	
# LOAD CONFIG FILE WITH USER OPTIONS	
#	
#  READ configuration file	
. ./subnodes.config





# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# BEGIN INSTALLATION PROCESS
#

clear
echo "////////////////////////"
echo "// Welcome to Subnodes!"
echo "// ~~~~~~~~~~~~~~~~~~~~"
echo ""

read -p "This installation script will install a lighttpd / php / mysql stack, set up a wireless access point and captive portal, and provide the option of configuring a BATMAN-ADV mesh point. Make sure you have one (or two, if installing the additional mesh point) USB wifi radios connected to your Raspberry Pi before proceeding. Press any key to continue..."
echo ""
clear





# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# COPY CONFIG FILE TO /etc WITH USER OPTIONS
#
# Check if configuration exists, ask for overwriting
if [ -e /etc/subnodes.config ] ; then
        read -p "Older config file found! Overwrite? (y/n) [N] " yn
		case $yn in
			[Yy]* )
				echo "...overwriting"
				copy_ok="yes"
			;;
			[Nn]* ) echo "...not overwriting. Re-reading found configuration file."
					. /etc/subnodes.config
			;;
		esac
else
        copy_ok="yes"
fi

# copy config file to /etc
[ "$copy_ok" == "yes" ] && cp subnodes.config /etc





# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# CHECK THAT REQUIRED RADIOS ARE AVAILABLE FOR AP & MESH POINT [IF SELECTED]
#
# check that iw list does not fail with 'nl80211 not found'
echo -en "Checking that USB wifi radio is available for access point..."
readarray IW < <(iw dev | awk '$1~"phy#"{PHY=$1}; $1=="Interface" && $2~"wlan"{WLAN=$2; sub(/#/, "", PHY); print PHY " " WLAN}')
if [[ -z $IW ]] ; then
	echo -en "[FAIL]\n"
	echo "Warning! Wireless adapter not found! Please plug in a wireless radio after installation completes and before reboot."
	echo "Installation process will proceed in 5 seconds..."
	sleep 5
else
	echo -en "[OK]\n"
fi

# now check that iw list finds a radio other than wlan0 if mesh point option was set to 'y' in config file
case $DO_SET_MESH in
	[Yy]* )
		echo -en "Checking that USB wifi radio is available for mesh point..."
		readarray IW < <(iw dev | awk '$1~"phy#"{PHY=$1}; $1=="Interface" && $2!="wlan0"{WLAN=$2; sub(/#/, "", PHY); print PHY " " WLAN}')

		if [[ -z $IW ]] ; then
			echo -en "[FAIL]\n"
			echo "Warning! Second wireless adapter not found! Please plug in an addition wireless radio after installation completes and before reboot."
			echo "Installation process will proceed in 5 seconds..."
			sleep 5
		else
			echo -en "[OK]\n"
		fi
;;
esac




# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# SOFTWARE INSTALL
#

# update the packages
echo "Updating apt-get and installing dnsutils, samba, samba-common-bin, batctl, lighttpd, sqlite3 and php7.0 packages..."
apt-get update && apt-get install -y dnsutils samba samba-common-bin batctl lighttpd sqlite3 php7.0 php7.0-common php7.0-cgi php7.0-sqlite3
lighttpd-enable-mod fastcgi
lighttpd-enable-mod fastcgi-php
# restart lighttpd
service lighttpd force-reload
# Change the directory owner and group
chown -R www-data:www-data /var/www
# allow the group to write to the directory
chmod -R 775 /var/www
# Add the pi user to the www-data group
usermod -a -G www-data pi

echo ""
echo "Copying the subnodes configuration file to /etc..."





# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# DISABLE DHCPCD SINCE WE ARE RELYING ON STATIC IPs IN A CLOSED NETWORK
#
systemctl disable dhcpcd
systemctl enable networking





# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# CONFIGURE AN ACCESS POINT WITH CAPTIVE PORTAL AND SAMBA FILE SHARE  
#

clear
# create samba share directory
echo -en "Creating samba fileshare folder at /home/pi/public..."
mkdir -m 1775 /home/pi/public
chown pi:pi /home/pi/public

echo -en "Creating backup of samba configuration file..."
cp /etc/samba/smb.conf /etc/samba/smb.conf.bak
rc=$?
if [[ $rc != 0 ]] ; then
		echo -en "[FAIL]\n"
	exit $rc
else
	echo -en "[OK]\n"
fi	

echo -en "Copying smb.conf file over from scripts..."
cp conf/smb.conf /etc/samba/smb.conf
/etc/init.d/samba restart

echo -en "Symlink samba public directory to web server for read-only access at /var/www/public..."
# create a directory for browsing the public file share
ln -s /home/pi/public /var/www/html/public
touch /home/pi/public/helloworld.txt
echo "Hello world! Browse my file share :)"> /home/pi/public/helloworld.txt

# make the directory listing available for this directory
echo -en "Creating backup of lighttpd configuration file..."
cp /etc/lighttpd/lighttpd.conf /etc/lighttpd/lighttpd.conf.bak
rc=$?
if [[ $rc != 0 ]] ; then
		echo -en "[FAIL]\n"
	exit $rc
else
	echo -en "[OK]\n"
fi	
echo -en "Enable directory listing for /public folder..."
cat <<EOF >> /etc/lighttpd/lighttpd.conf
\$HTTP["url"] =~ "^/public($|/)" {
        dir-listing.activate = "enable"
}
EOF
	rc=$?
	if [[ $rc != 0 ]] ; then
			echo -en "[FAIL]\n"
		echo ""
		exit $rc
	else
		echo -en "[OK]\n"
	fi
echo -en "Restart lighttpd..."
# restart lighttpd
service lighttpd force-reload

echo "Configuring Access Point..."

# install required packages
echo ""
echo -en "Installing bridge-utils, hostapd and dnsmasq..."
apt-get install -y bridge-utils hostapd dnsmasq
echo -en "[OK]\n"

# backup the existing interfaces file
echo -en "Creating backup of network interfaces configuration file..."
cp /etc/network/interfaces /etc/network/interfaces.bak
rc=$?
if [[ $rc != 0 ]] ; then
		echo -en "[FAIL]\n"
	exit $rc
else
	echo -en "[OK]\n"
fi		

# create hostapd init file
echo -en "Creating default hostapd file..."
cat <<EOF > /etc/default/hostapd
DAEMON_CONF="/etc/hostapd/hostapd.conf"
EOF
	rc=$?
	if [[ $rc != 0 ]] ; then
			echo -en "[FAIL]\n"
		echo ""
		exit $rc
	else
		echo -en "[OK]\n"
	fi





# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# CONFIGURE A MESH POINT?

clear
echo "Checking whether to configure mesh point or not..."





# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# 	DO CONFIGURE MESH POINT 
#   (assumption is that there is at least one other node in the mesh network that is a gateway)
#

case $DO_SET_MESH in
	[Yy]* )
		clear
		echo "Configuring Raspberry Pi as a BATMAN-ADV mesh point..."
		echo ""
		echo "Enabling the batman-adv kernel module..."
		# add the batman-adv module to be started on boot
		sed -i '$a batman-adv' /etc/modules
		modprobe batman-adv;

		# configure dnsmasq.
		echo -en "Creating dnsmasq configuration file..."
		cat <<EOF > /etc/dnsmasq.conf
# Captive Portal logic (redirects traffic to our web server)
interface=br0
address=/#/$BRIDGE_IP
address=/apple.com/0.0.0.0

# DHCP server
dhcp-range=$BR_DHCP_START,$BR_DHCP_END,$DHCP_NETMASK,$DHCP_LEASE
dhcp-option=option:router,$DHCP_ROUTER

# DNS
# Set our DNS server to be our gateway
server=$DNS
EOF
	rc=$?
	if [[ $rc != 0 ]] ; then
    		echo -en "[FAIL]\n"
		echo ""
		exit $rc
	else
		echo -en "[OK]\n"
	fi

		# copy iface stanzas; create new /etc/network/interfaces
		echo -en "Creating new network interfaces with your settings..."
		cp network/interfaces/wlan0 /etc/network/interfaces.d/
		cp network/interfaces/br0 /etc/network/interfaces.d/

		cat <<EOF > /etc/network/interfaces
source-directory /etc/network/interfaces.d

auto lo
iface lo inet loopback

allow-hotplug eth0
auto eth0
iface eth0 inet dhcp

iface default inet dhcp
EOF
		rc=$?
		if [[ $rc != 0 ]] ; then
		    	echo -en "[FAIL]\n"
			echo ""
			exit $rc
		else
			echo -en "[OK]\n"
		fi

		# create hostapd configuration with user's settings
		echo -en "Creating hostapd.conf file..."
		cat <<EOF > /etc/hostapd/hostapd.conf
interface=wlan0
bridge=br0
driver=$RADIO_DRIVER
country_code=$AP_COUNTRY
ctrl_interface=/var/run/hostapd
ctrl_interface_group=0
ssid=$AP_SSID
hw_mode=g
channel=$AP_CHAN
beacon_int=100
auth_algs=1
wpa=0
ap_isolate=1
macaddr_acl=0
wmm_enabled=1
ieee80211n=1
EOF
		rc=$?
		if [[ $rc != 0 ]] ; then
			echo -en "[FAIL]\n"
			exit $rc
		else
			echo -en "[OK]\n"
		fi

		# COPY OVER START UP SCRIPTS
		echo ""
		echo "Adding startup scripts to init.d..."
		cp scripts/subnodes_ap.sh /etc/init.d/subnodes_ap
		chmod 755 /etc/init.d/subnodes_ap
		update-rc.d subnodes_ap defaults
		cp scripts/subnodes_mesh.sh /etc/init.d/subnodes_mesh
		chmod 755 /etc/init.d/subnodes_mesh
		update-rc.d subnodes_mesh defaults
	;;





# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# 	ACCESS POINT ONLY
#

	[Nn]* ) 
	# if no mesh point is created, set up network interfaces, hostapd and dnsmasq to operate without a bridge
		clear
		
		# configure dnsmasq
		echo -en "Creating dnsmasq configuration file with captive portal and DHCP server..."
		cat <<EOF > /etc/dnsmasq.conf
# Captive Portal logic (redirects traffic to our web server)
interface=wlan0
address=/#/$AP_IP
address=/apple.com/0.0.0.0

# DHCP server
dhcp-range=$AP_DHCP_START,$AP_DHCP_END,$DHCP_NETMASK,$DHCP_LEASE
EOF
		rc=$?
		if [[ $rc != 0 ]] ; then
	    		echo -en "[FAIL]\n"
			echo ""
			exit $rc
		else
			echo -en "[OK]\n"
		fi
		
		# copy iface stanzas; create new /etc/network/interfaces
		echo -en "Creating new network interfaces with your settings..."
		cp network/interfaces/wlan0 /etc/network/interfaces.d/
		cat <<EOF > /etc/network/interfaces
source-directory /etc/network/interfaces.d

auto lo
iface lo inet loopback

allow-hotplug eth0
auto eth0
iface eth0 inet dhcp

iface default inet dhcp
EOF
		rc=$?
		if [[ $rc != 0 ]] ; then
		    	echo -en "[FAIL]\n"
			echo ""
			exit $rc
		else
			echo -en "[OK]\n"
		fi

		# create hostapd configuration with user's settings
		echo -en "Creating hostapd.conf file..."
		cat <<EOF > /etc/hostapd/hostapd.conf
interface=wlan0
driver=$RADIO_DRIVER
country_code=$AP_COUNTRY
ctrl_interface=/var/run/hostapd
ctrl_interface_group=0
ssid=$AP_SSID
hw_mode=g
channel=$AP_CHAN
auth_algs=1
wpa=0
ap_isolate=1
macaddr_acl=0
wmm_enabled=1
ieee80211n=1
EOF
		rc=$?
		if [[ $rc != 0 ]] ; then
			echo -en "[FAIL]\n"
			exit $rc
		else
			echo -en "[OK]\n"
		fi

		# COPY OVER START UP SCRIPTS
		echo ""
		echo "Adding startup scripts to init.d..."
		cp scripts/subnodes_ap.sh /etc/init.d/subnodes_ap
		chmod 755 /etc/init.d/subnodes_ap
		update-rc.d subnodes_ap defaults
	;;
esac


echo "denyinterfaces wlan0" >> /etc/dhcpcd.conf


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# COPY OVER THE ACCESS POINT START UP SCRIPT + enable services
#

clear
#update-rc.d hostapd remove
update-rc.d hostapd enable
update-rc.d dnsmasq enable

read -p "Do you wish to reboot now? [N] " yn
	case $yn in
		[Yy]* )
			reboot;;
		[Nn]* ) exit 0;;
	esac
