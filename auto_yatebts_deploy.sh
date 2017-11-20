#!/bin/bash
#kycfeel
#Customized Portable Cell Network Setup Script v2.0 by Matthew May.

#Display welcome header
echo -e "\e[1mHello, Welcome to Portable Cell Network Setup Script v2.0\e[0m"
echo -e "\e[1mThis script is inteded to be run on Raspberri Pi\e[0m"
# Check for root
if [ "$EUID" -ne 0 ]
  then echo -e "\e[1m**MUST BE RUN WITH ROOT PRIVILEDGES**\n**Please Run Again**\e[0m"
  exit
fi

#Query the user for unattended installation variables
#What should the cell network name be?
echo -ne "\e[1mWhat should the cell network name be? : \e[0m"
read networkname;
#Add default network name if none specified
if [ -z $networkname ] ; then
	echo -e "\e[33mNetwork name not specified, pushing default name: \e[35mDuaneDunstonRF\e[0m"
	networkname="DuaneDunstonRF"
	fi
echo -e "\e[1mThe network name is, \e[35m$networkname\e[0m"
#Confirm network name
echo -ne "\e[1mIs that correct? (y/n): \e[0m"
read confirm;
if [ $confirm = "y" -o $confirm =  "Y" ] ; then
	echo -e "\e[32mNetwork name confirmed!\e[0m"
else
	echo -e "\e[31mNetwork name incorrect, Please run me again!\e[0m"
	exit
fi

#UPDATE & UPGRADE THE SYSTEM
echo -e "\e[1;32mStart Time: \e[0m `date -u`"
starttime=`date -u`
SECONDS=0
echo -e "\e[1;32mUPDATE & UPGRADE THE SYSTEM\e[0m"
apt-get -y update && apt-get -y upgrade

#INSTALL LOGISTICAL DEPENDENCIES
echo -e "\e[1;32mINSTALL LOGISTICAL DEPENDENCIES\e[0m"
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | sudo debconf-set-selections ## Thanks To:
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | sudo debconf-set-selections ## https://gist.github.com/alonisser/a2c19f5362c2091ac1e7
apt-get install -y git python-setuptools python-dev swig libccid pcscd pcsc-tools python-pyscard libpcsclite1 unzip cmake automake matchbox-keyboard iptables-persistent subversion
#Setup PySIM - If PySIM current version worked we would use this method commented. Falling back to old commit for intended operation
cd /usr/src
#   git clone git://git.osmocom.org/pysim pysim
wget https://github.com/osmocom/pysim/archive/2fc205ceb93a8c58d6ad88d3bfd6aa84c628514a.zip
unzip 2fc205ceb93a8c58d6ad88d3bfd6aa84c628514a.zip
cd pysim-2fc205ceb93a8c58d6ad88d3bfd6aa84c628514a
rm README
rm COPYING
mkdir ../pysim
mv * ../pysim
cd ../
rm 2fc205ceb93a8c58d6ad88d3bfd6aa84c628514a.zip
rm -rf pysim-2fc205ceb93a8c58d6ad88d3bfd6aa84c628514a
cd /usr/local/bin
ln -s /usr/src/pysim/pySim-prog.py pySim-prog.py
pySIM_Path=`which pySim-prog.py`
echo -e "\e[1;32mPySIM Installed To: $pySIM_Path\e[0m"

#INSTALL Apache, PHP, GCC, and USB dependencies
echo -e "\e[1;32mINSTALL Apache, PHP, and USB dependencies\e[0m"
apt-get install -y apache2 php5 libusb-1.0-0 libusb-1.0-0-dbg libusb-1.0-0-dev libgsm1 libgsm1-dev

#INSTALL BladeRF
echo -e "\e[1;32mINSTALL BladeRF\e[0m"
cd /tmp
wget -c https://github.com/Nuand/bladeRF/archive/master.zip
unzip master.zip
cd bladeRF-master
cd host
mkdir build
cd build
echo `cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local -DINSTALL_UDEV_RULES=ON ../`
make -j4
make install > /var/log/BladeRF_install.log
ldconfig
if dmesg | grep -q bladeRF; then
    echo -e "\e[1;32mBladeRF Successfully Detected!\e[0m"
else
    echo -e "\e[1;32mBladeRF Was Not Detected!\e[0m"
    read -n1 -r -p "Please connect the BladeRF...then press any key to continue..."
    if dmesg | grep -q bladeRF; then
        echo -e "\e[1;32mBladeRF Successfully Detected!\e[0m"
    else
        echo -e "\e[1;32mBladeRF Was Not Detected! Exiting Script...\e[0m"
        exit
    fi
fi

#INSTALL Yate & YateBTS
echo -e "\e[1;32mINSTALL Yate & YateBTS\e[0m"
cd /tmp
svn checkout http://yate.null.ro/svn/yate/trunk yate && svn checkout http://voip.null.ro/svn/yatebts/trunk yatebts
cd yate
./autogen.sh
./configure --prefix=/usr/local
make -j4
make install > /var/log/Yate_install.log
ldconfig
cd /tmp/yatebts
./autogen.sh
./configure --prefix=/usr/local
make -j4
make install > /var/log/YateBTS_install.log
ldconfig

#Setup Network In a Box Interface
echo -e "\e[1;32mSetup Network In a Box Interface (NIB)\e[0m"
#Link website directory
cd /var/www/html
ln -s /usr/local/share/yate/nipc_web nib
#Permission changes
chmod -R a+w /usr/local/etc/yate
#Update PySim Path for Web GUI
pypath="/var/www/html/nib/config.php"
sed -i '/<?php/ c\<?php\n$pysim_path = "/usr/local/bin";' $pypath
echo "##### BEGIN PySim #####"
echo `cat $pypath`
echo "##### END PySim #####"
#Create Desktop Startup Script
echo -e "\e[1;32mCreating Desktop Startup Script\e[0m"
scriptpath="/home/pi/StartYateBTS.sh"
tee $scriptpath > /dev/null <<EOF
#!/bin/bash
#Check for root
if [ "$EUID" -ne 0 ]
  then echo -e "\e[1m**MUST BE RUN WITH ROOT PRIVILEDGES**\n**Please Run Again as 'sudo -i ./StartYateBTS.sh'**\e[0m"
  exit
fi
yate -s &
firefox-esr http://localhost/nib &
EOF
echo "##### BEGIN StartYateBTS.sh #####"
echo `cat $scriptpath`
echo "##### END StartYateBTS.sh #####"
chmod +x $scriptpath

#Update YateBTS Config
echo -e "\e[1;32mUpdating YateBTS Config\e[0m"
yatebts_config="/usr/local/etc/yate/ybts.conf"
#GSM Settings
sed -i '/Radio.Band=/ c\Radio.Band=900' $yatebts_config
sed -i '/Radio.C0=/ c\Radio.C0=75' $yatebts_config
sed -i '/;Identity.MCC=/ c\Identity.MCC=001' $yatebts_config
sed -i '/;Identity.MNC=/ c\Identity.MNC=01' $yatebts_config
sed -i '/Radio.PowerManager.MinAttenDB=/ c\Radio.PowerManager.MinAttenDB=50\nIdentity.ShortName='$networkname'' $yatebts_config
sed -i '/Radio.PowerManager.MaxAttenDB=/ c\Radio.PowerManager.MaxAttenDB=50' $yatebts_config
#GSM Advanced Settings
sed -i '/;Cipher.Encrypt=/ c\Cipher.Encrypt=yes' $yatebts_config
sed -i '/;Cipher.RandomNeighbor=/ c\Cipher.RandomNeighbor=0.8' $yatebts_config
sed -i '/;Cipher.ScrambleFiller=/ c\Cipher.ScrambleFiller=yes' $yatebts_config
#GGSN Settings
sed -i '/;DNS=/ c\DNS=8.8.8.8' $yatebts_config
sysctl -w net.ipv4.ip_forward=1
iptables -A FORWARD --in-interface eth0 -j ACCEPT
iptables -A FORWARD --in-interface sgsntun -j ACCEPT
iptables --table nat -A POSTROUTING --out-interface eth0 -j MASQUERADE
iptables-save > /etc/iptables/rules.v4
#Tapping Settings
sed -i '/GSM=no/ c\GSM=yes' $yatebts_config
sed -i '/GPRS=no/ c\GPRS=yes' $yatebts_config
sed -i '/TargetIP=127.0.0.1/ c\TargetIP=127.0.0.1' $yatebts_config
echo "##### BEGIN VERIFY YBTS.CONF #####"
echo `cat $yatebts_config`
echo "##### VERIFIED YBTS.CONF #####"
#Update Welcome Message
cd /usr/local/share/yate/scripts
sed -i '/var msg_text/ c\var msg_text = "Welcome to '$networkname'. Your number is: "+msisdn+". **THIS NETWORK IS FOR AUTHORIZED USE ONLY**";' nib.js
echo "##### BEGIN nib.js #####"
echo `cat nib.js | grep msg_text`
echo "##### END nib.js #####"
#Update Yate Subscribers
yate_subscribers="/usr/local/etc/yate/subscribers.conf"
sed -i '/country_code=/ c\country_code=1' $yate_subscribers
sed -i '/;regexp=/ c\regexp=^00101' $yate_subscribers
echo "##### BEGIN VERIFY SUBSCRIBERS.CONF #####"
echo `cat $yate_subscribers`
echo "##### VERIFIED SUBSCRIBERS.CONF #####"
#Enable Call Logging
touch /var/log/yate-cdr.csv
chmod -R a+r /var/log/yate-cdr.csv
cd /usr/local/etc/yate
tee cdrfile.conf > /dev/null <<EOF
[general]
file=/var/log/yate-cdr.csv
tabs=false
EOF

# Raspberry Pi Hardening Script - Brendan Harlow
echo -e "\e[1;32mRunning Raspberry Pi Hardening Script\e[0m"
# Update the operating system
# Rationale:
# Periodically patches contain security enhancements, bug fixes, and additional features for functionality.
apt-get -y dist-upgrade

# Enable sticky bit on all world writable directories
# Rationale:
# Prevent unauthorized users from modifying or renaming files that belong to a different owner.
echo "Setting sticky bit on world writable directories"
df --local -P | awk {'if (NR!=1) print $6'} | xargs -I '{}' find '{}' -xdev -type d -perm -0002 2>/dev/null | xargs chmod o-t

# Remove unnecessary filesystems
# Rationale:
# Removing support for unneeded filesystem types reduces the local attack surface on the Pi.
echo "install cramfs /bin/true" >> /etc/modprobe.d/CIS.conf
echo "install freevxfs /bin/true" >> /etc/modprobe.d/CIS.conf
echo "install jffs2 /bin/true" >> /etc/modprobe.d/CIS.conf
echo "install hfs /bin/true" >> /etc/modprobe.d/CIS.conf
echo "install hfsplus /bin/true" >> /etc/modprobe.d/CIS.conf
echo "install squashfs /bin/true" >> /etc/modprobe.d/CIS.conf
echo "install udf /bin/true" >> /etc/modprobe.d/CIS.conf

# Remove unnecessary network protocols
# Rationale:
# The linux kernel supports uncommon network protocols that are unneeded for what our goals are for this project.
# Therefore they should be disabled.
echo "install dccp /bin/true" >> /etc/modprobe.d/CIS.conf
echo "install sctp /bin/true" >> /etc/modprobe.d/CIS.conf
echo "install rds /bin/true" >> /etc/modprobe.d/CIS.conf
echo "install tipc /bin/true" >> /etc/modprobe.d/CIS.conf

# Disable core dumps incase an application crashes
# Rationale:
# A core dump is the memory of an executable program. It is generally used to determine
# why a program aborted. It can also be used to glean confidential information from a core
# file.
echo "* hard core 0" >> /etc/security/limits.conf
echo 'fs.suid_dumpable = 0' >> /etc/sysctl.conf
sysctl -p
echo 'ulimit -S -c 0 > /dev/null 2>&1' >> /etc/profile

# Disable unnecessary services
# Rationale:
# It is best practice for security to disable unnecessary services that are not required for operation to prevent exploitation.
systemctl disable avahi-daemon
systemctl disable triggerhappy.service
systemctl disable bluetooth.service

# Change the pi user password
# Rationale:
# The default password needs to be changed from raspberry.
# Strong passwords protect systems from being hacked through brute force methods.
# Password set cannot be a dictionary word, meet certain length, and contain a mix of characters.
echo "Change the user password to meet security requirements"
passwd pi
echo -e "\e[1;32mPI Hardened\e[0m"

#SETUP COMPLETED
echo -e "\e[1;32mPortable Cell Network Ready!\e[0m"
echo -e "\e[1;32mStart Time: \e[0m$starttime"
echo -e "\e[1;32mEnd Time: \e[0m`date -u`"
duration=$SECONDS
echo -e "\e[1;32mScript Completed In: \e[0m$(($duration / 60))m $(($duration % 60))s"
read -n1 -r -p "Get Ready For Reboot...Press Any Key To Continue..."
reboot now
