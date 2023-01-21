#!/usr/bin/env bash

# ----------------------------------------------------------------------
# - Grand Fantasia Server Setup Installer                              -
# ----------------------------------------------------------------------
# - ver 1.2
# - Now we have a changelog.

export LC_ALL=C

# Control vars
SERVERPATH="/root/gfonline"
IP=""               # format 0.0.0.0
PORT=6543           # Client and LoginServer port
DBUSER="postgres"   # default but not recomended
DBPASS=""           # if not set will generate a 32 char password
PSQLVER=""          # must match the /etc/postgre folder

# Control vars that you must not change
VPS_MODE=0          # (0 = off, 1 = on) USE FLAG -v instead!
REBOOT=0            # DO NOT CHANGE THIS MANUALLY
EXPERT_MODE=0       # DO NOT CHANGE THIS MANUALLY

# Offset address for patching DON'T CHANGE THIS
ZONE_OFFSET=822D47  # DO NOT CHANGE THIS MANUALLY
WORLD_OFFSET=3EA7A7 # DO NOT CHANGE THIS MANUALLY

# Server.zip URL
SERVERZIPURL="http://192.168.1.140/downloads/gf/server.zip"

# File SHA1 Checksum DON'T CHANGE THIS
SERVERCHECKSUM="4298dccdcb1f951b806e53498ac0df76ca36dd44"

# Colors
NC=$'\e[0m'
RED=$'\e[0;31m'
GREEN=$'\e[0;32m'
YELLOW=$'\e[0;33m'
ERROR=$'\e[1;97;41m'
WARNING=$'\e[1;97;43m'
SUCCESS=$'\e[1;97;42m'
INFO=$'\e[1;97;104m'
MISC=$'\e[1;30;47m'

# Define a function to output messages with the appropriate color code
output_message() {
  case "$1" in
    error)
      printf "%s [ERROR] %s %s\n" "$ERROR" "$2" "$NC"
      ;;
    warning)
      printf "%s [WARNING] %s %s\n" "$WARNING" "$2" "$NC"
      ;;
    info)
      printf "%s [INFO] %s %s\n" "$INFO" "$2" "$NC"
      ;;
    success)
      printf "%s [SUCCESS] %s %s\n" "$SUCCESS" "$2" "$NC"
      ;;
    *)
      printf "%s [MESSAGE] %s %s\n" "$MISC" "$2" "$NC"
      ;;
  esac
}

# Check if running as root
if [ "$EUID" -ne 0 ]
  then output_message "error" " Please run this script as root."
  exit
fi

# Check for internet connection and if server files are available
ping -c 1 google.com
if [ $? -eq 0 ]; then
  output_message "success" "You have internet connection"
  wget --spider $SERVERZIPURL
  if [ $? -eq 0 ]; then
    output_message "success" "server.zip is available"
  else
    output_message "error" "Server Files are not available at $SERVERZIPURL"
    echo "$ERROR Exiting...$NC"
    exit
  fi
else
  output_message "error" "You have no internet connection. Exiting..."
  exit
fi


# Read arguments and set default values for SERVERPATH, IP, and PORT
while getopts ":d:a:u:p:v:xh" opt; do
  case $opt in
    d|dir)
      SERVERPATH=$OPTARG
      ;;
    a|address)
      IP=$OPTARG
      ;;
    u|user)
      DBUSER=$OPTARG
      ;;
    p|port)
      PORT=$OPTARG
      ;;
    x|expert-mode)
      EXPERT_MODE=1
    ;;
    v|vps-mode)
      VPS_MODE=1
    ;;
    h|help)
      # Display usage message
      echo "$YELLOW Usage: setup.sh [-d PATH] [-a IP] [-u USER] [-p PORT] [-v] [-x] [-h]"
      echo "    -d PATH:"
      echo "         Set the directory where the server will be installed"
      echo "    -a IP:"
      echo "         Set the IP of the server for configuration"
      echo "    -u USER:"
      echo "         Set the username for the database"
      echo "    -p PORT: (EXPERIMENTAL/ADVANCED USERS ONLY)"
      echo "         Set the PORT where the Gateway Server will be listening"
      echo "    -v:"
      echo "         Set the VPS Mode to ON and get your external IP automatically"
      echo "    -x:"
      echo "         unlock manual config for ports of the server, this mode is"
      echo "         ONLY RECOMENDED FOR ADVANCED USERS and WILL REQUIRE further DB configuration!"
      echo "    -h:"
      echo "         Display this help message.$NC"
      exit
      ;;
    \?)
      output_message "error" "Invalid option: -$OPTARG"
      exit
      ;;
    :)
      output_message "error" "Option -$OPTARG requires an argument."
      echo "$ERROR [ERROR] Option -$OPTARG requires an argument.$NC"
      exit
      ;;
  esac
done

# =============== 0. Pre Config ===============
echo "$INFO========================= 0. Pre Config =========================$NC"

output_message "misc" "[0.0] Updating System and installing dependencies..."

# Update apt and install packages and dependencies
apt update && apt upgrade -y

apt install -y sudo psmisc wget unzip postgresql pwgen ufw


output_message "misc" "[0.1] Preparing directories"

# Check if SERVERPATH is set to / and exits if it is!

if [ "$SERVERPATH" == "/" ]; then
  # Display error message and exit
  output_message "error" " Invalid value for SERVERPATH: $SERVERPATH$NC"
  echo "SERVERPATH cannot be set to /"
  exit
fi

# Create directory if doesn't exists warning the user if exists

if [ -d $SERVERPATH ]; then
  output_message "Warning" "$SERVERPATH exists!"
  output_message "warning" "Running this script can potentially harm or damage your existing server "
  echo "$WARNING configuration and data if it exists AND/OR if is already setup and running. $NC"
  echo "$WARNING Do you want to continue running this script? (y/n)$NC"
  read OPVAR
  
  if [ "$OPVAR" != "y" ] && [ "$OPVAR" != "Y" ] ; then
    output_message "misc" "You choose to quit, exiting!"
    exit
  fi
else
  # Finally creates the directory
  mkdir $SERVERPATH -m 777
fi


# Handle if couldn't create directory
if [ ! -d $SERVERPATH ]; then
  output_message "error" "FATAL ERROR: Couldn't create $SERVERPATH directory, check your permissions and try again!"
  exit
fi

output_message "misc" "[0.2] Setting initial variables."

# Get PostgreeSQL version to use as the main postgree directory
# as /etc/postgreesql/$PSQLVER/main
if [ "$PSQLVER" == "" ]; then
  PSQLVER=$(psql --version | cut -c 19-20)
#  PSQLVER=$(psql --version | awk '{print $3}' | cut -d . -f 1-2) # This gets the full name, not recomended
fi

# Set DB password if none is previously manually set (48 characters)
if [ "$DBPASS" == "" ]; then
  DBPASS=$(pwgen -s 48 1)
fi

# If it is in a vps, try to get external IP
if [ $VPS_MODE == 1 ]; then
  output_message "info" "You are using a VPS, your IP will be autoset, check if it is right!"
  IP="$(dig +short myip.opendns.com @resolver1.opendns.com)"
  if [ "$IP" != "" ]; then
    output_message "info" "Your server IP is set to your WAN IP: $IP by flag [-v]"
  else
    output_message "error" "Couldn't get your WAN IP, you will be prompted to insert it manually"
  fi
fi

output_message "misc" "[0.3] Gathering IP information."

# Set IP if not set by argument or manually in the control vars
if [ "$IP" == "" ]; then
  # Try to automatically get IP (excluding 127.0.0.1) if not in VPS mode
  if [ $VPS_MODE == 0 ]; then
    IP=$(ip a | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | uniq )
  fi
  # Count the valid obtained IPs
  IPCOUNT=$( echo "$IP" | wc -l )  
  
  if [ "$IPCOUNT" == 1 ]; then
    output_message "info" "Your server IP is set to: $IP"
  fi
  
  if [ "$IPCOUNT" == 0 ] || [ "$IPCOUNT" -ge 2 ]; then
    if [ "$IPCOUNT" -ge  2 ]; then
      output_message "warning" "IP couldn't be obtained automatically, more than one valid IP was found"
    fi
    if [ "$IPCOUNT" == 0 ]; then
      output_message "warning" "IP couldn't be obtained automatically, no valid IP was found"
    fi
  
    echo "$YELLOW Valid IP found: $IPCOUNT"
    echo "$IP"
    echo "You will be prompted to manually insert your ip now!"
    echo "Format for ip has to be 0.0.0.0"
    echo "Enter your IP: "
    read IP
    echo "$NC"
  fi
else
  if [ $VPS_MODE == 0 ]; then
    output_message "info" "Your server IP was set to: $IP by flag [-a]."  
  fi
fi

# =============== 1. Download ===============
echo "$SUCCESS========================= 1. Download =========================$NC"

cd $SERVERPATH

#TODO upload ALL FILES in VPS
#for now we'll use anonfiles (and I test in my home webserver)

#TODO upload client to zip then extract to serve in webserver
#TODO create webserver

rm -f server.zip

wget --no-check-certificate $SERVERZIPURL -O server.zip --show-progress

if [ ! -f server.zip ]; then
  output_message "error" "server.zip couldn't be downloaded or couldn't be found!"
  exit
fi

SERVERZIPCHECKSUM=$(sha1sum server.zip | awk {'print $1'})

# Verify Checksum from config file and exit if doesn't match
if [ "$SERVERZIPCHECKSUM" != "$SERVERCHECKSUM" ]; then
  output_message "error" "server.zip is corrupted (checksum doesn't match)"
  exit
else
  output_message "success" "server.zip is good, unzipping"
fi

unzip server.zip
rm -r server.zip

# --- SERVER FOLDER
#cd server

# Set password in ini configurations files
sed -i "s/YOUR_DB_PASS_HERE/$DBPASS/g" setup.ini
sed -i "s/YOUR_DB_USER_HERE/$DBUSER/g" setup.ini
sed -i "s/YOUR_DB_PASS_HERE/$DBPASS/g" GatewayServer/setup.ini
sed -i "s/YOUR_DB_USER_HERE/$DBUSER/g" GatewayServer/setup.ini

# Change start directory
sed -i "s,/root/GF,$SERVERPATH,g" start
sed -i "s,/root/GF,$SERVERPATH,g" restart


# =============== 2. Patch ===============
echo "$YELLOW========================= 2. Patch =========================$NC"

echo "$MISC [2.1] Preparing IP for hexpatch$NC"

# This part is adapted from BUKK's project since it works better than the old method

# Split ip into parts using separator as . (dot), zeroing last char, this will transform
# 192.168.1.20 in 192.168.1.0
IPSPLIT=(${IP//./ })
IPSPLIT[3]=0
IPSTR="${IPSPLIT[0]}.${IPSPLIT[1]}.${IPSPLIT[2]}.${IPSPLIT[3]}"

HEXEDIP=""

# Transform the IPSTR into 
for char in $(echo "$IPSTR" | grep -o .); do
    HEXEDIP+=$(printf '%02x' "'$char")
done

HEXEDIP+="000000"   # fill tail with zeros

# Here we end the copy/paste

output_message "success" "Done! IP(hex): $HEXEDIP"

# Patching the Server!
#sed -i "s,\xc3\x3c\xd0\x00,$HEXEDIP,g" "WorldServer/WorldServer"
#sed -i "s,\xc3\x3c\xd0\x00,$HEXEDIP,g" "ZoneServer/ZoneServer"

output_message "misc" "[2.2] Patching server binaries"

IPBYTES=$(echo $HEXEDIP | sed 's/(..)/\\x\1/g')

cp "WorldServer/WorldServer" "WorldServer/WorldServer.bak"

echo -en $IPBYTES | dd of=WorldServer/WorldServer bs=1 seek=$((0x$WORLD_OFFSET)) count=${#IPBYTES} conv=notrunc # >/dev/null 2>&1

cp "ZoneServer/ZoneServer" "ZoneServer/ZoneServer.bak"

echo -en $IPBYTES | dd of=ZoneServer/ZoneServer bs=1 seek=$((0x$ZONE_OFFSET)) count=${#IPBYTES} conv=notrunc # >/dev/null 2>&1

output_message "success" "Server patched successfully"


# =============== 3. Config OS ===============
echo "$INFO========================= 3. Config OS =========================$NC"

# --- OS syscalls

echo "$MISC [3.1] Preparing OS Syscalls$NC"

#Enable vsyscall in emulate
if [ "$(cat /proc/cmdline | grep vsyscall=emulate)" == "" ]; then
  sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=\"/GRUB_CMDLINE_LINUX_DEFAULT=\"vsyscall=emulate /g" "/etc/default/grub"
  sudo update-grub
  REBOOT=1
  output_message "success" "Done! vsyscall is in emulate mode"
else
  output_message "success" "Done! vsyscall was already in emulate mode"
  REBOOT=0
fi


echo "$MISC [3.2] Pre configure postgres$NC"
# --- Pre config postgres
# Enter postgres dir and change the mode for listening everyone
cd /etc/postgresql/$PSQLVER/main

# Change postgresql to accept connections from outside
sed -i "s/#listen_addresses = 'localhost'/listen_adresses = '*'/g" postgresql.conf

# Change pg_hba configuration for host to accept md5 connections
sed -i "s,local   all             postgres                                peer,local   all             postgres                                md5,g" pg_hba.conf
sed -i "s,local   all             all                                     peer,local   all             all                                     md5,g" pg_hba.conf
sed -i "s,host    all             all             127.0.0.1/32            md5,host    all             all             0.0.0.0/0               md5,g" pg_hba.conf

# Restart cluster
pg_ctlcluster 13 main stop
pg_ctlcluster 13 main start

# Restart postgres so changes take effect
systemctl restart postgresql

# Wait for 5 seconds so database will be on
sleep 5

# Temporarly set permissions so postgree can act!
chmod 777 /root -R

# Create superuser $DBUSER with $DBPASS if is not postgres
if [ "$DBUSER" != "postgres" ]; then  
  sudo -u postgres createuser -s $DBUSER
  sudo -u postgres psql -c "ALTER user $DBUSER WITH password '$DBPASS';"
else
  # Set password in postgres as DBPASS
  sudo -u postgres psql -c "ALTER user postgres WITH password '$DBPASS';"
fi

# Save credentials to file
echo "$DBUSER" > /root/dbinfo
echo "$DBPASS" >> /root/dbinfo

output_message "success" "Done! user: $DBUSER passwd: $DBPASS"

echo "$GREEN Data saved at /root/dbinfo"


# =============== 4. Config DB ===============
echo "$INFO========================= 4. Config DB =========================$NC"

echo "$MISC [4.1] Creating databases.$NC"

#sudo -u postgres psql -c "create database \"SpiritKingAccount\" encoding 'UTF8' template template0;"
#sudo -u postgres psql -c "create database \"ElfDB\" encoding 'UTF8' template template0;"

# Set the proper IP on databases
sed -i "s/YOUR_IP_HERE/$IP" $SERVERPATH/SQL/GF_LS.sql
sed -i "s/YOUR_IP_HERE/$IP" $SERVERPATH/SQL/GF_GS.sql

# New SQL Files
#sudo -u postgres psql -c "create database \"GF_GS\" encoding 'UTF8' template template0;"
#sudo -u postgres psql -c "create database \"GF_LS\" encoding 'UTF8' template template0;"
#sudo -u postgres psql -c "create database \"GF_MS\" encoding 'UTF8' template template0;"
sudo -u postgres psql -c "create database \"GF_GS\" encoding 'LATIN1' template template0;"
sudo -u postgres psql -c "create database \"GF_LS\" encoding 'LATIN1' template template0;"
sudo -u postgres psql -c "create database \"GF_MS\" encoding 'LATIN1' template template0;"


echo "$MISC [4.2] Importing tables.$NC"

sudo -u postgres psql -d GF_GS -c "\i '$SERVERPATH/SQL/GF_GS.sql';"
sudo -u postgres psql -d GF_LS -c "\i '$SERVERPATH/SQL/GF_LS.sql';"
sudo -u postgres psql -d GF_MS -c "\i '$SERVERPATH/SQL/GF_MS.sql';"
sudo -u postgres psql -d GF_LS -c "\i '$SERVERPATH/SQL/accounts.sql';"
sudo -u postgres psql -d GF_LS -c "\i '$SERVERPATH/SQL/item_receipt.sql';"
sudo -u postgres psql -d GF_LS -c "\i '$SERVERPATH/SQL/item_receivable.sql';"

#sudo -u postgres psql -d GF_LS -c "UPDATE worlds SET ip = '$IP' WHERE ip = 'YOUR_IP_HERE';"
#sudo -u postgres psql -d GF_GS -c "UPDATE serverstatus SET ext_address = '$IP' WHERE ext_address = 'YOUR_IP_HERE';"


# --- PORT VARS

GATEWAYPORT=5560  # GATEWAY PORT
HTTPPORT=7878     # HTTP SERVER PORT
TICKETPORT=7777   # TICKET SERVER PORT  #(server/TicketServer/Setup.ini)
AHPORT=15306      # AUCTION HOUSE PORT AHNETSERVER
GMTOOLPORT=10320  # GM TOOL PORT
CGIPORT=20060     # CGI PORT

if [ $EXPERT_MODE == 1 ]; then

  # =============== 5. Port Config ===============
  echo "$RED========================= 5. Port Config =========================$NC"

  output_message "info" "PORT CONFIG (EXPERT MODE ON) please read"
  #echo "$INFO PORT CONFIG (EXPERT MODE)$NC"
  echo "$YELLOW Port config can be a useful way of managing multiple servers of the same game "
  echo "in a single VPS (if you are really willing to do that, you have a lot of stuff"
  echo " to do... Good Luck on the databases and extra configs)"
  echo "This method also can be a good way of evading ISP port denying (if you have"
  echo "trouble with that while hosting your server at home)$NC"
  output_message "warning" "Please notice that this process is not automated and you WILL"
  output_message "warning" "HAVE TO manually config your databases for getting the desired"
  output_message "warning" "results! \nWhat do you want to do now?"
  #echo "$WARNING Please notice that this process is not automated and you will have to manually"
  #echo "config your databases for getting the desired result!$NC"
  echo "$YELLOW [1] Get me out of here!$NC"
  echo "$RED[2] I know what I am doing, lets continue configuring ports.$NC"
  echo "Your answer (1/2):$NC"
  read OPVAR
  
  if [ $OPVAR == 2 ]; then
    output_message "misc" "You choose to config the PORTS, please type the numbers properly"
    #echo "$INFO Gateway Server Port (5560):$NC"
    output_message "info" "Gateway Server Port (5560):"
    read GATEWAYPORT
    sed -i "s/5560/$GATEWAYPORT/g" GatewayServer/setup.ini
    sed -i "s/5560/$GATEWAYPORT/g" ../setup.ini
    echo "$GATEWAYPORT" > GatewayServer/.port
    
    output_message "info" "HTTP Server Port (7878):$NC"
    read HTTPPORT
    sed -i "s/7878/$HTTPPORT/g" HTTPAServer/setup.ini
    sed -i "s/7878/$HTTPPORT/g" GatewayServer/setup.ini

    output_message "info" "Ticket Server Port (7777):"
    read TICKETPORT
    sed -i "s/7777/$TICKETPORT/g" TicketServer/setup.ini
    sed -i "s/7777/$TICKETPORT/g" start

    output_message "info" "AH Server Port (15306):"
    read AHPORT
    sed -i "s/15306/$AHPORT/g" WorldServer/AHThunkConfig.ini

    output_message "info" "GM Tool Server Port (10320):"
    read GMTOOLPORT
    sed -i "s/10320/$GMTOOLPORT/g" ZoneServer/setup.ini

    output_message "info" "CGI Port (20060):"
    read CGIPORT
    sed -i "s/20060/$CGIPORT/g" ZoneServer/setup.ini

    output_message "info" "Login Server Port (6543):$NC"
    read PORT
    sed -i "s/6543/$PORT/g" LoginServer/setup.ini
    output_message "info" "[INFO] PLEASE READ!$NC"
    output_message "warning" "Please don't forget to change it on your client ini too!"
    echo "Wait 20 seconds to continue$NC"
    sleep 20

  fi
fi

# =============== Firewall Config ===============
echo "$INFO========================= Firewall Config =========================$NC"

# It's better to use the previous declared vars so we don't lose data
# even if EXPERT MODE was invoked and used properly
# The vars used for each port are listed bellow
# GATEWAYPORT, HTTPPORT, TICKETPORT, AHPORT, GMTOOLPORT, CGIPORT
# PORT (this last one stands for Login port)

sudo ufw allow postgres       # postgresql application
sudo ufw allow "$GATEWAYPORT" # GATEWAY PORT
sudo ufw allow "$HTTPPORT"    # HTTP SERVER PORT
#sudo ufw allow 18624/TCP # TICKET SERVER PORT (server/Setup.ini) AURA ONLY
sudo ufw allow "$TICKETPORT"  #  TICKET SERVER PORT  #(server/TicketServer/Setup.ini)
sudo ufw allow "$PORT"        #  LOGIN SERVER
sudo ufw allow "$AHPORT"      #  AUCTION HOUSE PORT AHNETSERVER
sudo ufw allow "$GMTOOLPORT"  #  GM TOOL PORT
sudo ufw allow "$CGIPORT"     #  CGI PORT
sudo ufw allow 5567/TCP       #  AK PORT 1
sudo ufw allow 5568/TCP       #  AK PORT 2
sudo ufw allow 10021/TCP      #  ZONE SERVER
sudo ufw allow 10022/TCP      #  ZONE SERVER
sudo ufw allow ssh            #  SSH
sudo ufw enable
sudo ufw status numbered


# Set Aliases for Start/Stop Server
if [ "$(cat /root/.bashrc | grep startserver=)" != "" ]; then
  sed -i "/alias startserver=/d" /root/.bashrc
  sed -i "/alias stopserver=/d" /root/.bashrc 
  sed -i "/alias restartserver=/d" /root/.bashrc  
  sed -i "/alias serverstats=/d" /root/.bashrc   
  output_message "success" "Old alias removed!"
fi

echo "alias startserver='$SERVERPATH/start'" >> /root/.bashrc
echo "alias stopserver='$SERVERPATH/stop'" >> /root/.bashrc
echo "alias restartserver='$SERVERPATH/restart'" >> /root/.bashrc
echo "alias serverstats='$SERVERPATH/serverstats'" >> /root/.bashrc
output_message "success" "Alias Created!"

#revoke permissions
chmod 644 /root -R 

chmod 777 $SERVERPATH
echo "Entering $SERVERPATH"
cd $SERVERPATH
chmod +x start
chmod +x stop

source /root/.bashrc

output_message "success" "Your sever is ready!"

output_message "misc" "Here are some information about it."
echo "$INFO [Server Info]"
echo "Server Path: $SERVERPATH"
echo "IP: $IP"
echo "PostgreSQL version: $PSQLVER"
echo "DB User: $DBUSER"
echo "DB Pass: $DBPASS $NC"
echo "$MISC Server command aliases:"
echo "startserver"
echo "stopserver"
echo "restartserver"
echo "serverstats$NC"
echo "$GREEN This information will be saved at root directory as /root/serverinfo!$NC"

echo "[Server Info]" > /root/serverinfo
echo "IP: $IP" >> /root/serverinfo
echo "PostgreSQL version: $PSQLVER" >> /root/serverinfo
echo "DB User: $DBUSER" >> /root/serverinfo
echo "DB Pass: $DBPASS" >> /root/serverinfo
echo "Server aliases bellow" >> /root/serverinfo
echo "startserver   : start your server" >> /root/serverinfo
echo "stopserver    : stop your server" >> /root/serverinfo
echo "restartserver : restart your server" >> /root/serverinfo
echo "serverstats   : show your server stats" >> /root/serverinfo

if [ $REBOOT == 1 ]; then
  output_message "warning" "Your server has to reboot for proper configuration."
  output_message "warning" "Your server is going to reboot in 10 seconds."
  echo "$RED 10"  
  sleep 1
  echo "9"  
  sleep 1
  echo "8"  
  sleep 1
  echo "7"  
  sleep 1
  echo "6"  
  sleep 1
  echo "5"  
  sleep 1
  echo "4"  
  sleep 1
  echo "3"  
  sleep 1
  echo "2"  
  sleep 1
  echo "1"  
  sleep 1
  echo "$NC Rebooting..."
  sudo reboot
fi
