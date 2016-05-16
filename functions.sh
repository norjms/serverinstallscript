#!/bin/bash
#
# (c) Igor Pecovnik
# 
#get ip
showip=$(ifconfig eth0 | awk -F"[: ]+" '/inet addr:/ {print $4}')
#get architecture
if uname -m | grep -i arm > /dev/null; then
ARCH=ARM
else
ARCH=x86
fi
#functions
function unrartest {
if hash unrar 2>/dev/null; then
	return
else
	cpunum=$(nproc)	
	apt-get install build-essential -y
	cd /tmp
	RARVERSION=$(wget -q http://www.rarlab.com/rar_add.htm -O - | grep unrarsrc | awk -F "[\"]" ' NR==1 {print $2}')
	wget $RARVERSION
	tar -xvf unrarsrc*.tar.gz
	cd unrar
	make -j$cpunum -f makefile
	install -v -m755 unrar /usr/bin
	cd ..
	rm -R unrar*
	rm unrarsrc-*.tar.gz
fi }

function monotest {
if hash mono 2>/dev/null; then
	return
else
echo "Installing mono"
if !(uname -m | grep -i armv6 > /dev/null); then
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF
cat >> /etc/apt/sources.list.d/mono-xamarin.list <<EOF
# Mono
deb http://download.mono-project.com/repo/debian wheezy main
EOF
else
debconf-apt-progress -- install libmono-cil-dev -y
cd /tmp
wget https://www.dropbox.com/s/k6ff6s9bfe4mfid/mono_3.10-armhf.deb
dpkg -i mono_3.10-armhf.deb
rm mono_3.10-armhf.deb
fi
fi
}

function javatest {
if hash java 2>/dev/null; then
	return
else
if !(cat /etc/apt/sources.list.d/webupd8team-java.list | grep -q Java > /dev/null);then
cat >> /etc/apt/sources.list.d/webupd8team-java.list <<EOF
# Java
deb http://ppa.launchpad.net/webupd8team/java/ubuntu trusty main
deb-src http://ppa.launchpad.net/webupd8team/java/ubuntu trusty main
EOF
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys EEA14886
fi
debconf-apt-progress -- apt-get update
echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | debconf-set-selections
apt-get install oracle-java8-installer -y	
fi }

install_webmin () {
#--------------------------------------------------------------------------------------------------------------------------------
# Install webmin
#--------------------------------------------------------------------------------------------------------------------------------
debconf-apt-progress -- apt-get install libauthen-pam-perl libio-pty-perl libnet-ssleay-perl libapt-pkg-perl apt-show-versions libwww-perl -y
wget http://www.webmin.com/download/deb/webmin-current.deb
dpkg -i webmin*
rm webmin*
echo "Webmin is running at https://$showip:10000"
}

install_lemp () {
#--------------------------------------------------------------------------------------------------------------------------------
# Install lemp
#--------------------------------------------------------------------------------------------------------------------------------
debconf-apt-progress -- apt-get install mysql-server mysql-client nginx php5-fpm php5-dev php5-mysql php5-dev -y
echo "LEMP installed"
}

install_rutorrent () {
#--------------------------------------------------------------------------------------------------------------------------------
# Install rutorrent
#--------------------------------------------------------------------------------------------------------------------------------
debconf-apt-progress -- apt-get install mysql-server mysql-client nginx php5-fpm php5-dev php5-mysql php5-dev -y
apt-get -y install autoconf build-essential ca-certificates comerr-dev curl cfv dtach htop irssi libcloog-ppl-dev libcppunit-dev libcurl3 libncurses5-dev libterm-readline-gnu-perl libsigc++-2.0-dev libperl-dev libtool libxml2-dev ncurses-base ncurses-term ntp patch pkg-config php7.0 php7.0-cli php7.0-dev php7.0-fpm php7.0-curl php7.0-mcrypt php7.0-xmlrpc php7.0-json pkg-config python-scgi git screen subversion texinfo unrar-free unzip zlib1g-dev libcurl4-openssl-dev mediainfo -y
#Change open file limits
sudo sed -i '/# End of file/ i\* hard nofile 32768\n* soft nofile 32768\n' /etc/security/limits.conf
SERVERIP=$(ip route get 8.8.8.8 | awk 'NR==1 {print $NF}')
cd ~
mkdir source
cd source
svn co https://svn.code.sf.net/p/xmlrpc-c/code/stable xmlrpc
curl http://rtorrent.net/downloads/libtorrent-0.13.6.tar.gz | tar xz
curl http://rtorrent.net/downloads/rtorrent-0.9.6.tar.gz | tar xz
#Install xmlrpc
cd xmlrpc
./configure --prefix=/usr --enable-libxml2-backend --disable-libwww-client --disable-wininet-client --disable-abyss-server --disable-cg
make
make install
#Making libtorrent
cd ../libtorrent-0.13.6
./autogen.sh
./configure --prefix=/usr
make -j2
make install
#Making rtorrent
cd ../rtorrent-0.9.6
./autogen.sh
./configure --prefix=/usr --with-xmlrpc-c
make -j2
make install
ldconfig
#Making directories
cd ~ && mkdir rtorrent && cd rtorrent
mkdir .session downloads watch
echo "rutorrent Installed"
}

install_basic (){
#--------------------------------------------------------------------------------------------------------------------------------
# Set hostname, FQDN, add to sources list
#--------------------------------------------------------------------------------------------------------------------------------
serverIP=$(ip route get 8.8.8.8 | awk '{ print $NF; exit }')
set ${serverIP//./ }
SUBNET="$1.$2.$3."
HOSTNAMEFQDN=$(hostname -f)
HOSTNAMEFQDN=$(whiptail --inputbox "\nWhat is your full qualified hostname for $serverIP ?" 10 78 $HOSTNAMEFQDN --title "$SECTION" 3>&1 1>&2 2>&3)
exitstatus=$?; if [ $exitstatus = 1 ]; then exit 1; fi
set ${HOSTNAMEFQDN//./ }
HOSTNAMESHORT="$1"
cp /etc/hosts /etc/hosts.backup
cp /etc/hostname /etc/hostname.backup
sed -e 's/127.0.0.1       localhost/127.0.0.1       localhost.localdomain   localhost/g' -i /etc/hosts
cat >> /etc/hosts <<EOF
${serverIP} ${HOSTNAMEFQDN} ${HOSTNAMESHORT}
EOF
echo "$HOSTNAMESHORT" > /etc/hostname
/etc/init.d/hostname.sh start >/dev/null 2>&1
}


create_ispconfig_configuration (){
#--------------------------------------------------------------------------------------------------------------------------------
# ISPConfig autoconfiguration
#--------------------------------------------------------------------------------------------------------------------------------
cat > /tmp/isp.conf.php <<EOF
<?php
\$autoinstall['language'] = 'en'; // de, en (default)
\$autoinstall['install_mode'] = 'standard'; // standard (default), expert

\$autoinstall['hostname'] = '$HOSTNAMEFQDN'; // default
\$autoinstall['mysql_hostname'] = 'localhost'; // default: localhost
\$autoinstall['mysql_root_user'] = 'root'; // default: root
\$autoinstall['mysql_root_password'] = '$mysql_pass';
\$autoinstall['mysql_database'] = 'dbispconfig'; // default: dbispcongig
\$autoinstall['mysql_charset'] = 'utf8'; // default: utf8
\$autoinstall['http_server'] = '$server'; // apache (default), nginx
\$autoinstall['ispconfig_port'] = '8080'; // default: 8080
\$autoinstall['ispconfig_use_ssl'] = 'y'; // y (default), n

/* SSL Settings */
\$autoinstall['ssl_cert_country'] = 'AU';
\$autoinstall['ssl_cert_state'] = 'Some-State';
\$autoinstall['ssl_cert_locality'] = 'Chicago';
\$autoinstall['ssl_cert_organisation'] = 'Internet Widgits Pty Ltd';
\$autoinstall['ssl_cert_organisation_unit'] = 'IT department';
\$autoinstall['ssl_cert_common_name'] = \$autoinstall['hostname'];
?>
EOF
}

install_varnish (){
#--------------------------------------------------------------------------------------------------------------------------------
# Install high-performance HTTP accelerator
#-------------------------------------------------------------------------------------------------------------------------------- 
apt-get install apt-transport-https -y
wget -O - https://repo.varnish-cache.org/GPG-key.txt | apt-key add -
cat > /etc/apt/sources.list.d/varnish-cache.list<<EOF
deb-src https://repo.varnish-cache.org/debian/ jessie varnish-4.1
EOF
apt-get update
apt-get build-dep varnish -y
cd /tmp
apt-get source varnish -y
rm varnish_*.dsc
rm varnish_*.orig.tar.gz
rm varnish_*.diff.gz
cd varnish-4*
./configure --prefix=/usr
make -j$(ncpu)
make install
cp debian/varnish.init /etc/init.d/varnish
chmod +x /etc/init.d/varnish
cp debian/varnish.default /etc/default/varnish
update-rc.d varnish defaults
mkdir -p /etc/varnish
cp etc/example.vcl /etc/varnish/default.vcl
dd if=/dev/random of=/etc/varnish/secret count=1
service varnish start
echo "Configure Varnish with WordPress using this guide http://goo.gl/zlvBdB"
}

install_sonarr (){
#--------------------------------------------------------------------------------------------------------------------------------
# sonarr
#--------------------------------------------------------------------------------------------------------------------------------
NZBDRONEUSER=$(whiptail --inputbox "Enter the user to run Sonarr as (usually pi)" 8 78 "pi" --title "$SECTION" 3>&1 1>&2 2>&3)
exitstatus=$?; if [ $exitstatus = 1 ]; then exit 1; fi
if ! getent passwd $NZBDRONEUSER > /dev/null; then
echo "User $NZBDRONEUSER doesn't exist, exiting, restart the installer"
exit
fi
#if !(cat /etc/apt/sources.list | grep -q Sonarr > /dev/null);then
#cat > /etc/apt/sources.list.d/sonarr.list <<EOF
#deb http://archive.raspbian.org/raspbian wheezy main contrib non-free
#EOF
#debconf-apt-progress -- apt-get update
#debconf-apt-progress -- apt-get install libmono-cil-dev -y --force-yes
#rm /etc/apt/sources.list.d/sonarr.list
#debconf-apt-progress -- apt-get update
monotest
cat > /etc/apt/sources.list.d/sonarr.list <<EOF
# Sonarr
deb http://apt.sonarr.tv/ master main
EOF
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys FDA5DFFC
#debconf-apt-progress -- apt-get update
apt-get update
apt-get install nzbdrone -y --force-yes
chown -R $NZBDRONEUSER:$NZBDRONEUSER /opt/NzbDrone
#Create nzbdrone script
cd /etc/init.d/
wget https://raw.github.com/blindpet/MediaServerInstaller/usenet/scripts/nzbdrone
sed -i "/RUN_AS=/c\RUN_AS=$NZBDRONEUSER" /etc/init.d/nzbdrone
if uname -a | grep armv6 > /dev/null; then
sed -i "/DAEMON=/c\DAEMON=/usr/local/bin/mono" /etc/init.d/nzbdrone
fi
chmod +x /etc/init.d/nzbdrone
cd /tmp
update-rc.d nzbdrone defaults
service nzbdrone start
echo "Sonarr is running on $showip:8989"
echo "Configure Sonarr at HTPCGuides.com http://goo.gl/06iXEw"
}

install_jackett (){
#--------------------------------------------------------------------------------------------------------------------------------
# jackett
#--------------------------------------------------------------------------------------------------------------------------------
#hash mono 2>/dev/null || { echo >&2 "Mono isn't installed, install Sonarr first.  Aborting."; exit 1; }
JACKETTUSER=$(whiptail --inputbox "Choose the owner of the downloads folder (usually pi)" 8 78 "pi" --title "$SECTION" 3>&1 1>&2 2>&3)
exitstatus=$?; if [ $exitstatus = 1 ]; then exit 1; fi
if ! getent passwd $JACKETTUSER > /dev/null; then
echo "User $JACKETTUSER doesn't exist, exiting, restart the installer"
exit
fi
monotest
debconf-apt-progress -- apt-get update
debconf-apt-progress -- apt-get install mono-complete -y
jackettver=$(wget -q https://github.com/Jackett/Jackett/releases/latest -O -  | grep -E \/tag\/ | awk -F "[><]" '{print $3}')
wget -q https://github.com/Jackett/Jackett/releases/download/$jackettver/Jackett.Binaries.Mono.tar.gz
tar -xvf Jackett*
mkdir /opt/jackett
sudo mv Jackett/* /opt/jackett
chown -R $JACKETTUSER:$JACKETTUSER /opt/jackett
#init
cd /etc/init.d
wget https://raw.github.com/blindpet/MediaServerInstaller/usenet/scripts/jackett
sed -i s"/RUN_AS=htpcguides/RUN_AS=$JACKETTUSER/" /etc/init.d/jackett
chmod +x /etc/init.d/jackett
cd /tmp
update-rc.d jackett defaults
service jackett start
echo "Jackett is running on $showip:9117"
echo "Configure Jackett at HTPCGuides.com http://goo.gl/A9i7ah"
}

install_sickrage (){
#--------------------------------------------------------------------------------------------------------------------------------
# sickrage
#--------------------------------------------------------------------------------------------------------------------------------
SICKRAGEUSER=$(whiptail --inputbox "Enter the user to run SickRage as (usually pi)" 8 78 "pi" --title "$SECTION" 3>&1 1>&2 2>&3)
exitstatus=$?; if [ $exitstatus = 1 ]; then exit 1; fi
if ! getent passwd $SICKRAGEUSER > /dev/null; then
echo "User $SICKRAGEUSER doesn't exist, exiting, restart the installer"
exit
fi
unrartest
debconf-apt-progress -- apt-get install git-core libssl-dev libxslt1-dev libxslt1.1 libxml2-dev libxml2 libssl-dev libffi-dev python-pip python-dev -y
pip install pyopenssl
sudo git clone https://github.com/SickRage/SickRage.git /opt/sickrage
sudo chown -R $SICKRAGEUSER:$SICKRAGEUSER /opt/sickrage
cat > /etc/default/sickrage <<EOF
SR_USER=$SICKRAGEUSER
SR_HOME=/opt/sickrage
SR_DATA=/opt/sickrage
SR_PIDFILE=/home/$SICKRAGEUSER/.sickrage.pid
EOF
FINDSICKRAGE=$(find /opt/sickrage -name init.ubuntu)
cp $FINDSICKRAGE /etc/init.d/sickrage
chmod +x /etc/init.d/sickrage
update-rc.d sickrage defaults
service sickrage start
echo "SickRage is running on $showip:8081"
echo "Configure SickRage at HTPCGuides.com http://goo.gl/I2jtbg"
}

install_couchpotato (){
#--------------------------------------------------------------------------------------------------------------------------------
# couchpotato
#--------------------------------------------------------------------------------------------------------------------------------
COUCHPOTATOUSER=$(whiptail --inputbox "Enter the user to run CouchPotato as (usually pi)" 8 78 "pi" --title "$SECTION" 3>&1 1>&2 2>&3)
exitstatus=$?; if [ $exitstatus = 1 ]; then exit 1; fi
if ! getent passwd $COUCHPOTATOUSER > /dev/null; then
echo "User $COUCHPOTATOUSER doesn't exist, exiting, restart the installer"
exit
fi
unrartest
debconf-apt-progress -- apt-get install -y zlib1g-dev libffi-dev libssl-dev libxslt1-dev libxml2-dev python python-pip python-dev build-essential
pip install cryptography
pip install pyopenssl
pip install pyopenssl --upgrade
git clone http://github.com/RuudBurger/CouchPotatoServer /opt/CouchPotato
chown -R $COUCHPOTATOUSER:$COUCHPOTATOUSER /opt/CouchPotato
cat > /etc/default/couchpotato <<EOF
CP_HOME=/opt/CouchPotato
CP_USER=$COUCHPOTATOUSER
CP_PIDFILE=/home/$COUCHPOTATOUSER/.couchpotato.pid
CP_DATA=/opt/CouchPotato
EOF
cp /opt/CouchPotato/init/ubuntu /etc/init.d/couchpotato
chmod +x /etc/init.d/couchpotato
update-rc.d couchpotato defaults
service couchpotato start
echo "CouchPotato is running on $showip:5050"
echo "Configure CouchPotato at HTPCGuides.com http://goo.gl/uwaTUI"
}

install_htpcmanager (){
#--------------------------------------------------------------------------------------------------------------------------------
# htpcmanager
#--------------------------------------------------------------------------------------------------------------------------------
HTPCUSER=$(whiptail --inputbox "Enter the user to run HTPC Manager as (usually pi)" 8 78 "pi" --title "$SECTION" 3>&1 1>&2 2>&3)
exitstatus=$?; if [ $exitstatus = 1 ]; then exit 1; fi
if ! getent passwd $HTPCUSER > /dev/null; then
echo "User $HTPCUSER doesn't exist, exiting, restart the installer"
exit
fi
debconf-apt-progress -- apt-get update
debconf-apt-progress -- apt-get install build-essential git python-imaging python-dev python-setuptools python-pip vnstat smartmontools -y
pip install psutil
git clone https://github.com/Hellowlol/HTPC-Manager /opt/HTPCManager
chown -R $HTPCUSER:$HTPCUSER /opt/HTPCManager
cp /opt/HTPCManager/initscripts/initd /etc/init.d/htpcmanager
sed -i "/APP_PATH=/c\APP_PATH=/opt/HTPCManager" /etc/init.d/htpcmanager
chmod +x /etc/init.d/htpcmanager
update-rc.d htpcmanager defaults
service htpcmanager start
echo "HTPC Manager is running on $showip:8085"
}

install_madsonic (){
#--------------------------------------------------------------------------------------------------------------------------------
# install Madsonic
#--------------------------------------------------------------------------------------------------------------------------------
MADSONICUSER=$(whiptail --inputbox "Enter the user to run Madsonic as (usually pi)" 8 78 "pi" --title "$SECTION" 3>&1 1>&2 2>&3)
exitstatus=$?; if [ $exitstatus = 1 ]; then exit 1; fi
if ! getent passwd $MADSONICUSER > /dev/null; then
echo "User $MADSONICUSER doesn't exist, exiting, restart the installer"
exit
fi
javatest
MADSONIC=$(wget -q http://beta.madsonic.org/pages/download.jsp -O - | grep .deb | awk -F "[\"]" ' NR==1 {print $2}')
MADSONICVER=$(echo $MADSONIC | awk 'match($0, /[0-9]\.[0-9]/) {print substr($0, RSTART, RLENGTH)}')
MADSONICFILE=$(echo $MADSONIC | awk 'match($0, /[0-9][0-9].+/) {print substr($0, RSTART, RLENGTH)}')
wget http://www.madsonic.org/download/$MADSONICVER/$MADSONICFILE -O madsonic.deb
dpkg -i madsonic.deb
rm madsonic.deb
debconf-apt-progress -- apt-get install libav-tools xmp lame flac -y
rm /var/madsonic/transcode/ffmpeg
rm /var/madsonic/transcode/lame
rm /var/madsonic/transcode/xmp
rm /var/madsonic/transcode/flac
ln -s /usr/bin/avconv /var/madsonic/transcode/ffmpeg
ln -s /usr/bin/flac /var/madsonic/transcode/flac
ln -s /usr/bin/xmp /var/madsonic/transcode/xmp
ln -s /usr/bin/lame /var/madsonic/transcode/lame
sed -i "/MADSONIC_USER=/c\MADSONIC_USER=$MADSONICUSER" /etc/default/madsonic
service madsonic start
echo "Madsonic will run on $showip:4040 and autostart on boot"
echo "Use $showip:4040 for initial Madsonic setup"
}

install_subsonic (){
#--------------------------------------------------------------------------------------------------------------------------------
# install Subsonic
#--------------------------------------------------------------------------------------------------------------------------------
SUBSONICUSER=$(whiptail --inputbox "Enter the user to run Subsonic as (usually pi)" 8 78 "pi" --title "$SECTION" 3>&1 1>&2 2>&3)
exitstatus=$?; if [ $exitstatus = 1 ]; then exit 1; fi
if ! getent passwd $SUBSONICUSER > /dev/null; then
echo "User $SUBSONICUSER doesn't exist, exiting, restart the installer"
exit
fi
javatest
SUBSONIC=$(wget -q http://www.subsonic.org/pages/download.jsp -O - | grep .deb | awk -F "[\"]" ' NR==1 {print $2}')
SUBSONICFILE=$(echo $SUBSONIC | awk 'match($0, /subsonic.+\.deb$/) {print substr($0, RSTART, RLENGTH)}')
cd /tmp
wget http://subsonic.org/download/$SUBSONICFILE -O subsonic.deb
dpkg -i subsonic.deb
rm subsonic.deb
sed -i "/SUBSONIC_USER=/c\SUBSONIC_USER=$SUBSONICUSER" /etc/default/subsonic
debconf-apt-progress -- apt-get install libav-tools xmp lame flac -y
rm /var/subsonic/transcode/ffmpeg
rm /var/subsonic/transcode/lame
rm /var/subsonic/transcode/xmp
rm /var/subsonic/transcode/flac
ln -s /usr/bin/avconv /var/subsonic/transcode/ffmpeg
ln -s /usr/bin/flac /var/subsonic/transcode/flac
ln -s /usr/bin/xmp /var/subsonic/transcode/xmp
ln -s /usr/bin/lame /var/subsonic/transcode/lame
service subsonic start
echo "Subsonic will run on $showip:4040 and autostart on boot"
echo "Use $showip:4040 for initial Subsonic setup"
}

install_nfs (){
#--------------------------------------------------------------------------------------------------------------------------------
# install NFS
#--------------------------------------------------------------------------------------------------------------------------------
debconf-apt-progress -- apt-get -y install nfs-server nfs-common
echo "NFS is installed, configure on HTPCGuides.com http://goo.gl/njEc6C"
}

install_plex (){
#--------------------------------------------------------------------------------------------------------------------------------
# install PlexWheezy
#--------------------------------------------------------------------------------------------------------------------------------
if ! uname -a | grep -E "armv7|686|x86_64" > /dev/null; then
echo You are not using an armv7, x86 or x64 device...
exit 1
fi
debconf-apt-progress -- apt-get update
apt-get install libc6 libexpat1 -y
lddtest=$(ldd --version | awk 'NR==1{print $5}')
if [[ "$lddtest" == 2.13 ]]; then
plexrepo=wheezy
else
plexrepo=jessie
fi
if ! locale -a | grep -i en_US > /dev/null; then
sed -i 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/Ig' /etc/locale.gen
/usr/sbin/locale-gen en_US.UTF-8
echo "Attempted to generate locales"
fi
#if uname -a | grep -i arm > /dev/null; then
#PLEXARCH=ARM
#else
#PLEXARCH=x86
#fi
if [ $ARCH == ARM ]; then
	if !(cat /etc/apt/sources.list.d/pms.list | grep -q Plex > /dev/null);then
cat > /etc/apt/sources.list.d/pms.list <<EOF
# Plex
deb http://dev2day.de/pms/ $plexrepo main
EOF
	wget -O - http://dev2day.de/pms/dev2day-pms.gpg.key | apt-key add -
	fi
fi
if [ $ARCH == x86 ]; then
	if !(cat /etc/apt/sources.list.d/plex.list | grep -q Plex > /dev/null);then
	wget -O - http://shell.ninthgate.se/packages/shell-ninthgate-se-keyring.key | sudo apt-key add -
cat >> /etc/apt/sources.list.d/plex.list <<EOF
# Plex
deb http://www.deb-multimedia.org wheezy main non-free
deb http://shell.ninthgate.se/packages/debian wheezy main
EOF
apt-get update
apt-get install deb-multimedia-keyring -y --force-yes
	fi
fi
debconf-apt-progress -- apt-get update
debconf-apt-progress -- apt-get install plexmediaserver -y
echo "Plex is running on $showip:32400/web and will autostart on boot"
echo "Configuration guides on HTPCGuides.com and force transcoding http://goo.gl/avCu85"
echo "If Plex isn't running try running manually with bash /usr/lib/plexmediaserver/start.sh"
echo "You may need to go here for troubleshooting locales: http://goo.gl/M063Oi"
}

install_kodi (){
#--------------------------------------------------------------------------------------------------------------------------------
# install kodi raspberry pi
#--------------------------------------------------------------------------------------------------------------------------------

if ! uname -a | grep raspberrypi > /dev/null; then
echo not Raspberry Pi...
exit 1
else
    rm /etc/apt/sources.list.d/mene.list
cat > /etc/apt/sources.list.d/mene.list <<EOF
deb http://archive.mene.za.net/raspbian jessie contrib
EOF
apt-key adv --keyserver keyserver.ubuntu.com --recv-key 5243CDED
debconf-apt-progress -- apt-get update
debconf-apt-progress -- apt-get install kodi -y
addgroup --system input
usermod -a -G audio,video,input,dialout,plugdev,tty kodi

usermod -a -G input kodi

cat > /etc/udev/rules.d/99-input.rules <<EOF
SUBSYSTEM=="input", GROUP="input", MODE="0660"
KERNEL=="tty[0-9]*", GROUP="tty", MODE="0660"
EOF
#echo "ENABLED=1" > /etc/default/kodi
sed -i s'/ENABLED=0/ENABLED=1/' /etc/default/kodi

sed -i "/gpu_mem=/c\gpu_mem=128" /boot/config.txt
echo "Kodi has been installed, reboot"
fi
}

install_samba (){
#--------------------------------------------------------------------------------------------------------------------------------
# install Samba file sharing
#--------------------------------------------------------------------------------------------------------------------------------
# Read samba user / pass / group
SMBUSER=$(whiptail --inputbox "What is your samba username?" 8 78 $SMBUSER --title "$SECTION" 3>&1 1>&2 2>&3)
exitstatus=$?; if [ $exitstatus = 1 ]; then exit 1; fi
SMBPASS=$(whiptail --inputbox "What is your samba password?" 8 78 $SMBPASS --title "$SECTION" 3>&1 1>&2 2>&3)
exitstatus=$?; if [ $exitstatus = 1 ]; then exit 1; fi
SMBGROUP=$(whiptail --inputbox "What is your samba group?" 8 78 $SMBGROUP --title "$SECTION" 3>&1 1>&2 2>&3)
exitstatus=$?; if [ $exitstatus = 1 ]; then exit 1; fi
#
debconf-apt-progress -- apt-get -y install samba samba-common-bin
useradd $SMBUSER
echo -ne "$SMBPASS\n$SMBPASS\n" | passwd $SMBUSER
echo -ne "$SMBPASS\n$SMBPASS\n" | smbpasswd -a -s $SMBUSER
service samba stop
service smbd stop
service nmbd stop
 cat > /etc/samba/smb.conf <<"EOF"
[global]
	workgroup = SMBGROUP
	server string = %h server
	hosts allow = SUBNET
	log file = /var/log/samba/log.%m
	max log size = 1000
	syslog = 0
	panic action = /usr/share/samba/panic-action %d
	load printers = yes
	printing = cups
	printcap name = cups

[printers]
	comment = All Printers
	path = /var/spool/samba
	browseable = no
	public = yes
	guest ok = yes
	writable = no
	printable = yes
	printer admin = SMBUSER

[print$]
	comment = Printer Drivers
	path = /etc/samba/drivers
	browseable = yes
	guest ok = no
	read only = yes
	write list = SMBUSER
	
[ext]
	comment = Storage	
	path = /ext
	writable = yes
	public = no
	valid users = SMBUSER
	force create mode = 0777
	force directory mode = 0777
EOF
sed -i "s/SMBGROUP/$SMBGROUP/" /etc/samba/smb.conf
sed -i "s/SMBUSER/$SMBUSER/" /etc/samba/smb.conf
sed -i "s/SUBNET/$SUBNET/" /etc/samba/smb.conf
mkdir /ext
chmod -R 777 /ext
service samba start
service smbd start
service nmbd start
echo I did not code this section so if you have issues use the link below
echo See configuration details on HTPCGuides.com http://goo.gl/tQEaHK
}

install_cups (){
#--------------------------------------------------------------------------------------------------------------------------------
# Install printer system
#--------------------------------------------------------------------------------------------------------------------------------
debconf-apt-progress -- apt-get -y install cups lpr foomatic-filters
sed -e 's/Listen localhost:631/Listen 631/g' -i /etc/cups/cupsd.conf
sed -e 's/<Location \/>/<Location \/>\nallow $SUBNET/g' -i /etc/cups/cupsd.conf
sed -e 's/<Location \/admin>/<Location \/admin>\nallow $SUBNET/g' -i /etc/cups/cupsd.conf
sed -e 's/<Location \/admin\/conf>/<Location \/admin\/conf>\nallow $SUBNET/g' -i /etc/cups/cupsd.conf
service cups restart
service samba restart
} 

install_vpn_server (){
#--------------------------------------------------------------------------------------------------------------------------------
# Script downloads latest stable
#--------------------------------------------------------------------------------------------------------------------------------
ebconf-apt-progress -- apt-get install build-essential ncurses-dev libreadline-dev libssl-dev -y
cd /tmp
SOFTETHERVER=$(wget -q http://www.softether-download.com/files/softether/ -O - | html2text | grep rtm | tail -n 1 | awk '{print $4}')
SOFTETHERPROG=$(wget -q http://www.softether-download.com/files/softether/$SOFTETHERVER/Source_Code/ -O - | html2text | grep gz | awk '{print $4}')
wget http://www.softether-download.com/files/softether/$SOFTETHERVER/Source_Code/$SOFTETHERPROG -O softether.tar.gz
mkdir -p /tmp/softether
tar --strip-components=1 -xvf softether.tar.gz -C /tmp/softether
cd /tmp/softether
( echo 1 && \
  echo 1 \ && echo 1 ) \
 | ./configure 
make -j$(nproc)
make install
cp /tmp/softether/debian/softether-vpnserver.init /etc/init.d/vpnserver
chmod +x /etc/init.d/vpnserver
mkdir -p /var/lock/subsys
update-rc.d vpnserver defaults
service vpnserver start
}

install_DashNTP (){
#--------------------------------------------------------------------------------------------------------------------------------
# Install DASH and ntp service
#--------------------------------------------------------------------------------------------------------------------------------
echo "dash dash/sh boolean false" | debconf-set-selections
dpkg-reconfigure -f noninteractive dash > /dev/null 2>&1
debconf-apt-progress -- apt-get -y install ntp ntpdate
} 

install_MySQL (){
#--------------------------------------------------------------------------------------------------------------------------------
# MYSQL
#--------------------------------------------------------------------------------------------------------------------------------
mysql_pass=$(whiptail --inputbox "What is your mysql root password?" 8 78 $mysql_pass --title "$SECTION" 3>&1 1>&2 2>&3)
exitstatus=$?; if [ $exitstatus = 1 ]; then exit 1; fi
echo "mysql-server-5.5 mysql-server/root_password password $mysql_pass" | debconf-set-selections
echo "mysql-server-5.5 mysql-server/root_password_again password $mysql_pass" | debconf-set-selections
debconf-apt-progress -- apt-get -y install mysql-client mysql-server
#Allow MySQL to listen on all interfaces
cp /etc/mysql/my.cnf /etc/mysql/my.cnf.backup
sed -i 's|bind-address           = 127.0.0.1|#bind-address           = 127.0.0.1|' /etc/mysql/my.cnf
service mysql restart >> /dev/null
}

install_PureFTPD (){
#--------------------------------------------------------------------------------------------------------------------------------
# Install PureFTPd
#--------------------------------------------------------------------------------------------------------------------------------
debconf-apt-progress -- apt-get -y install pure-ftpd-common pure-ftpd-mysql

sed -i 's/VIRTUALCHROOT=false/VIRTUALCHROOT=true/' /etc/default/pure-ftpd-common
echo 1 > /etc/pure-ftpd/conf/TLS
mkdir -p /etc/ssl/private/

openssl req -x509 -nodes -days 7300 -newkey rsa:2048 -subj "/C=/ST=/L=/O=/CN=$(hostname -f)" -keyout /etc/ssl/private/pure-ftpd.pem -out /etc/ssl/private/pure-ftpd.pem
chmod 600 /etc/ssl/private/pure-ftpd.pem
/etc/init.d/pure-ftpd-mysql restart
}
