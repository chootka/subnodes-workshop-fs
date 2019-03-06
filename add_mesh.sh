#! /bin/bash
#
# Raspberry Pi Mesh Point configuration
# Author: Sarah Grant
# Updated 6 March 2019
#
# TO-DO
# - fix addressing to avoid collisions below w/avahi
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #





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
echo "// Subnodes Mesh Point"
echo "// ~~~~~~~~~~~~~~~~~~~~"
echo ""

read -p "This installation script will add a mesh point to your Subnodes set up. It is assumed that you have already installed a Subnodes access point and now wish to add a mesh point. Make sure you plugged a second wireless radio into your Raspberry Pi. Press any key to continue..."
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

		# configure dnsmasq
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
		cp network/interfaces/wlan0 /etc/network/interfaces.d/wlan0
		cp network/interfaces/br0 /etc/network/interfaces.d/br0

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

		# COPY OVER MESH START UP SCRIPT
		echo ""
		echo "Adding mesh startup script to init.d..."
		cp scripts/subnodes_mesh.sh /etc/init.d/subnodes_mesh
		chmod 755 /etc/init.d/subnodes_mesh
		update-rc.d subnodes_mesh defaults
	;;

	[Nn]* ) 
	# if no mesh point is created, set up network interfaces, hostapd and dnsmasq to operate without a bridge
		clear
		
		# configure dnsmasq
		echo -en "Oops, did you set the DO_SET_MESH flag to 'y' in subnodes.config?"
		exit 0;
	;;
esac

read -p "Do you wish to reboot now? [N] " yn
	case $yn in
		[Yy]* )
			reboot;;
		[Nn]* ) exit 0;;
	esac
