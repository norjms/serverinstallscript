#!/bin/bash
#
#Check if user is root

#Set Paths
PATH=/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/bin:/sbin
#Check for root
if [ $(id -u) != "0" ]; then
    echo "Error: You must be root to run this script, please use the root user to install the software."
    exit 1
fi
#--------------------------------------------------------------------------------------------------------------------------------
# Updated to check if packages are installed to save time
# What do we need anyway
function updatecheck ()
{
apt-get clean
if dpkg-query -W curl net-tools alsa-base alsa-utils debconf-utils git whiptail build-essential stunnel4 html2text apt-transport-https; then
return
else
debconf-apt-progress -- apt-get update
apt-get -y install sudo net-tools curl debconf-utils dnsutils unzip whiptail git build-essential alsa-base alsa-utils stunnel4 html2text apt-transport-https --force-yes
#debconf-apt-progress -- apt-get upgrade -y
fi
}
updatecheck

#--------------------------------------------------------------------------------------------------------------------------------

SECTION="Basic configuration"
# Read IP address
#
serverIP=$(ip route get 8.8.8.8 | awk '{ print $NF; exit }')
set ${serverIP//./ }
SUBNET="$1.$2.$3."

#Begin installer scripts
whiptail --title "Welcome to the Media Server Installation Script" --msgbox "This Debian Wheezy/Jessie and Ubuntu installer will prompt for valid users and ports, defaults are suggested in () for those in doubt" 8 78

source "functions.sh"

whiptail --ok-button "Install" --title "Media Server Installation Script" --checklist --separate-output "\nIP:   $serverIP\n\nChoose what you want to install:" 20 78 9 \
"Plex" "Plex Media Server        " off \
"Kodi" "Kodi Media Server        " off \
"SickRage" "Python Show Automation Finder" off \
"Sonarr" ".NET Show Automation Finder" off \
"Jackett" "Add custom providers to Sonarr" off \
"CouchPotato" "Video Automation Finder" off \
"HTPC Manager" "HTPC Management system" off \
"Madsonic" "Java media server" off \
"Subsonic" "Java media server" off \
"Samba" "Windows compatible file sharing        " off \
"NFS Tools" "Windows compatible file sharing        " off \
"Webmin" "Admin server web interface" off \
"SoftEther VPN server" "Advanced VPN solution" off \
"Varnish" "Reverse Proxy HTTP Accelerator" off \
"RUTORRENT" "RUTORRENT including nginx, PHP, and MariaDB" off \
"LEMP" "nginx, PHP, MariaDB" off 2>results
while read choice
do
   case $choice in
   		   "Samba") 			ins_samba="true";;
		   "Madsonic") 			ins_madsonic="true";;
		   "Subsonic") 			ins_subsonic="true";;
		   "Kodi") 			ins_kodi="true";;
		   "Plex") 			ins_plex="true";;
		   "NFS Tools") 		ins_nfs="true";;
		   "Jackett") 			ins_jackett="true";;
                   "SickRage") 			ins_sickrage="true";;
                   "Sonarr") 			ins_sonarr="true";;
                   "CouchPotato")		ins_couchpotato="true";;
                   "HTPC Manager")		ins_htpcmanager="true";;
                   "SoftEther VPN server") 	ins_vpn_server="true";;
                   "Webmin")			ins_webmin="true";;
                   "RUTORRENT")                 ins_rutorrent="true";;
		   "LEMP")			ins_lemp="true";;
		   "Varnish")			ins_varnish="true";;
                *)
                ;;
        esac
done < results

if [[ "$ins_subsonic" == "true" ]]; 			then install_subsonic;			fi
if [[ "$ins_madsonic" == "true" ]]; 			then install_madsonic;			fi
if [[ "$ins_webmin" == "true" ]]; 			then install_webmin;			fi
if [[ "$ins_jackett" == "true" ]]; 			then install_jackett;			fi
if [[ "$ins_kodi" == "true" ]]; 			then install_kodi;			fi
if [[ "$ins_plex" == "true" ]]; 			then install_plex;			fi
if [[ "$ins_samba" == "true" ]]; 			then install_samba; 			fi
if [[ "$ins_nfs" == "true" ]]; 				then install_nfs; 			fi
if [[ "$ins_vpn_server" == "true" ]]; 			then install_vpn_server; 		fi
if [[ "$ins_sickrage" == "true" ]]; 			then install_sickrage; 			fi
if [[ "$ins_sonarr" == "true" ]]; 			then install_sonarr; 			fi
if [[ "$ins_couchpotato" == "true" ]]; 			then install_couchpotato; 		fi
if [[ "$ins_htpcmanager" == "true" ]];                  then install_htpcmanager;               fi
if [[ "$ins_rutorrent" == "true" ]];                    then install_rutorrent;                 fi
if [[ "$ins_lemp" == "true" ]];                 	then install_lemp;                      fi
if [[ "$ins_varnish" == "true" ]];                 	then install_varnish;                   fi
#rm results
