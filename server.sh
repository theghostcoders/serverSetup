#!/usr/bin/env bash

# ----------------------------------------------------------------------
# - Grand Fantasia Server Setup Installer                              -
# ----------------------------------------------------------------------
# - ver 1.1
# - added option to change db user 
# ---
# - ver 1.0
# - first release
# - read the readme.org file for more info
# - coders: GaRocK

# Control vars
SERVERPATH="/root/gfonline"
IP=""            # format 0.0.0.0
PORT=6543        # client and LoginServer port
DBUSER="postgre" # default but not recomended
DBPASS=""        # if not set will generate a 32 char password
PSQLVER=""       # must match the /etc/postgre folder
REBOOT=0         # DO NOT CHANGE THIS MANUALLY
EXPERT_MODE=0    # DO NOT CHANGE THIS MANUALLY

# Vars for File Checksum DON'T CHANGE THIS
# checksums are using SHA1 algorithm
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

# Read arguments and set default values for SERVERPATH, IP, and PORT
while getopts ":d:a:u:p:xh" opt; do
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
    h|help)
      # Display usage message
      echo "$YELLOW Usage: setup.sh [-d PATH] [-a IP] [-p PORT] [-x] [-h]"
      echo "    -d PATH:"
      echo "         Set the directory where the server will be installed"
      echo "    -a IP:"
      echo "         Set the IP of the server for configuration"
      echo "    -u USER:"
      echo "         Set the username for the database"
      echo "    -p PORT: (EXPERIMENTAL/ADVANCED USERS ONLY)"
      echo "         Set the PORT where the Gateway Server will be listening"
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

# Update apt and install packages and dependencies
apt update && apt upgrade -y

apt install -y sudo psmisc wget unzip postgresql pwgen ufw

# Get PostgreeSQL version to use as the main postgree directory
# as /etc/postgreesql/$PSQLVER/main
if [ "$PSQLVER" == "" ]; then
  PSQLVER=$(psql --version | cut -c 19-20)
#  PSQLVER=$(psql --version | awk '{print $3}' | cut -d . -f 1-2)
fi

# Set DB password if none is previously manually set
if [ "$DBPASS" == "" ]; then
  DBPASS=$(pwgen -s 48 1)
fi

# Set IP if not set by argument or manually in the control vars
if [ "$IP" == "" ]; then
  # Try to automatically get IP (excluding 127.0.0.1)
  IP=$(ip a | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | uniq )

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
  output_message "info" "Your server IP was set to: $IP by flag [-a]."  
fi


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
  #echo "$WARNING [Warning] $SERVERPATH exists!$NC"
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

# =============== 1. Config OS ===============
echo "$INFO========================= 1. Config OS =========================$NC"

echo "$MISC 1.1 Pre configure postgres$NC"
# --- Pre config postgres
# Enter postgres dir and change the mode for listening everyone
cd /etc/postgresql/$PSQLVER/main
sed -i "s/#listen_addresses = 'localhost'/listen_adresses = '*'/g" postgresql.conf

#TODO Remember to check if ipv6 is needed for this setup!
# Change pg_hba configuration for host to accept connections
sed -i "s,host    all             all             127.0.0.1/32            md5,host    all             all             0.0.0.0/0               md5,g" pg_hba.conf

sed -i "s,peer,trust,g" pg_hba.conf


#cat <<EOF > /etc/postgresql/$PSQLVER/main/pg_hba.conf
# TYPE  DATABASE        USER            ADDRESS                 METHOD

# "local" is for Unix domain socket connections only
#local   all             postgres                                peer
#local   all             all                                     peer
# IPv4 local connections:
#host    all             all             127.0.0.1/32            md5
# IPv4  external connections:
#host    all             all             0.0.0.0/0               md5
# IPv6 local connections:
#host    all             all             ::1/128                 md5
# replications
#local   replication     all                                     peer
#host    replication     all             127.0.0.1/32            md5
#host    replication     all             ::1/128                 md5
#EOF

# Restart postgres so changes take effect
systemctl restart postgresql

# Wait for 5 seconds so database will be on
sleep 5

# Create superuser $DBUSER with $DBPASS
sudo -u postgres createuser -s $DBUSER
sudo -u postgres psql -c "ALTER user $DBUSER WITH password '$DBPASS';"

# Set password in postgres #123 for testing only!
sudo -u postgres psql -c "ALTER user postgres WITH password '123';"

echo "$DBUSER" > /root/dbinfo
echo "$DBPASS" >> /root/dbinfo

output_message "success" "Done! user: $DBUSER passwd: $DBPASS"

echo "$GREEN Data saved at /root/dbinfo"

echo "$MISC 1.2 Preparing IP for hexpatch$NC"

# Prepare IP for hexpatch (convert it to hex as a mask)
# Mask will look like 192.168.0.10 in hexadecimal (2 precision)
# or \xc0\xa8\x00\x0a to be more exact (C0 A8 00 0A, individually convert as 192 168 0 10)
#HEXEDIP=$printf '\\x%02x\\x%02x\\x%02x\n' $(echo "IP" | grep -o [0-9]* | head -n1) $(echo "IP" | grep -o [0-9]* | head -n2 | tail -n1) $(echo "$IP" | grep -o [0-9]* | head -n3 | tail -n1)
HEXEDIP=$(printf '\\x%02x\\x%02x\\x%02x\\x%02x\n' $(echo "$IP" | grep -o [0-9]* ))

output_message "success" "Done! IP(hex): $HEXEDIP"

# --- OS syscalls

echo "$MISC 1.3 Preparing OS Syscalls$NC"
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


# =============== 2. Download ===============
echo "$SUCCESS========================= 2. Download =========================$NC"

cd $SERVERPATH

#TODO upload ALL FILES in VPS
#for now we'll use anonfiles (and I test in my home webserver)

rm -f server.zip

wget --no-check-certificate http://192.168.1.140/downloads/gf/server.zip -O server.zip --show-progress

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
# old was antiroot
sed -i "s/YOUR_DB_PASS_HERE/$DBPASS/g" setup.ini
sed -i "s/YOUR_DB_USER_HERE/$DBUSER/g" setup.ini
sed -i "s/YOUR_DB_PASS_HERE/$DBPASS/g" GatewayServer/setup.ini
sed -i "s/YOUR_DB_USER_HERE/$DBUSER/g" GatewayServer/setup.ini

# Change start directories
# old default: ~/GF/006.058.64.64/
# stop has no dir
sed -i "s,/root/GF,$SERVERPATH,g" start

# debug purposes CODE STOPS HERE! ------------------------------------- ------------------------------------------------------------------------
#exit

# =============== 3. Config DB ===============
echo "$INFO========================= 3. Config DB =========================$NC"

# Temporarly set permissions so postgree can act!
chmod 777 /root -R

systemctl restart postgresql
sudo -u postgres psql -c "create database \"SpiritKingAccount\" encoding 'UTF8' template template0;"
sudo -u postgres psql -c "create database \"ElfDB\" encoding 'UTF8' template template0;"

# We'll create the useles ak dbs for debug purposes
sudo -u postgres psql -c "create database \"FFAccount\" encoding 'UTF8' template template0;"
sudo -u postgres psql -c "create database \"FFMember\" encoding 'UTF8' template template0;"
sudo -u postgres psql -c "create database \"FFDB1\" encoding 'UTF8' template template0;"
sudo -u postgres psql -c "create database \"FFDB\" encoding 'UTF8' template template0;"

# New Files
sudo -u postgres psql -c "create database \"accounts\" encoding 'UTF8' template template0;"

sudo -u postgres psql -c "create database \"GF_GS\" encoding 'UTF8' template template0;"

sudo -u postgres psql -c "create database \"GF_LS\" encoding 'UTF8' template template0;"

sudo -u postgres psql -c "create database \"GF_MS\" encoding 'UTF8' template template0;"

sudo -u postgres psql -c "create database \"item_receipt\" encoding 'UTF8' template template0;"

sudo -u postgres psql -c "create database \"item_receivable\" encoding 'UTF8' template template0;"

sudo -u postgres psql -d GF_GS -c "\i '$SERVERPATH/SQL/GF_GS.sql';"
sudo -u postgres psql -d GF_LS -c "\i '$SERVERPATH/SQL/GF_LS.sql';"
sudo -u postgres psql -d GF_MS -c "\i '$SERVERPATH/SQL/GF_MS.sql';"
sudo -u postgres psql -d accounts -c "\i '$SERVERPATH/SQL/accounts.sql';"
sudo -u postgres psql -d item_receipt -c "\i '$SERVERPATH/SQL/item_receipt.sql';"
sudo -u postgres psql -d item_receivable -c "\i '$SERVERPATH/SQL/item_receivable.sql';"


sudo -u postgres psql -d FFAccount -c "\i '$SERVERPATH/SQL/FFAccount.sql';"
sudo -u postgres psql -d FFMember -c "\i '$SERVERPATH/SQL/FFMember.sql';"
sudo -u postgres psql -d FFDB1 -c "\i '$SERVERPATH/SQL/FFDB1.sql';"
sudo -u postgres psql -d FFDB -c "\i '$SERVERPATH/SQL/FFDB.sql';"

sudo -u postgres psql -d FFAccount -c "UPDATE worlds SET ip = '$IP' WHERE ip = 'YOUR_IP_HERE';"
sudo -u postgres psql -d FFDB1 -c "UPDATE serverstatus SET ext_address = '$IP' WHERE ext_address = 'YOUR_IP_HERE';"


# =============== 4. Patch ===============
echo "$YELLOW========================= 4. Patch =========================$NC"
# Patching the Server!
sed -i "s,\xc3\x3c\xd0\x00,$HEXEDIP,g" "WorldServer/WorldServer"
sed -i "s,\xc3\x3c\xd0\x00,$HEXEDIP,g" "ZoneServer/ZoneServer"

# --- PORT VARS

GATEWAYPORT=5560  # GATEWAY PORT
HTTPPORT=7878     # HTTP SERVER PORT
TICKETPORT=7777   #  TICKET SERVER PORT  #(server/TicketServer/Setup.ini)
AHPORT=15306  #  AUCTION HOUSE PORT AHNETSERVER
GMTOOLPORT=10320  #  GM TOOL PORT
CGIPORT=20060     #  CGI PORT

if [ $EXPERT_MODE == 1 ]; then

  # =============== 5. Port Config ===============
  echo "$RED========================= 5. Port Config =========================$NC"

  output_message "info" "PORT CONFIG (EXPERT MODE ON) please read"
  #echo "$INFO PORT CONFIG (EXPERT MODE)$NC"
  echo "$YELLOW Port config can be a useful way of managing multiple servers of the same game "
  echo "in a single VPS (if you are really willing to do that, you have a lot of stuff"
  echo " to do... Good Luck on the databases and extra configs)"
  echo "This method also can be a good way of evading ISP port denying (if you have"
  echo "trouble with that)$NC"
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

# =============== 4/5. Firewall Config ===============
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
sudo ufw allow 5568 /TCP      # AK PORT 2
sudo ufw allow 10021/TCP      #  ZONE SERVER
sudo ufw allow 10022/TCP      #  ZONE SERVER
sudo ufw enable
sudo ufw status numbered


# Set Aliases for Start/Stop Server
if [ "$(cat /root/.bashrc | grep startserver=)" != "" ]; then
  sed -i "/alias startserver=/d" /root/.bashrc
  sed -i "/alias stopserver=/d" /root/.bashrc  
  output_message "success" "Old alias removed!"
fi

echo "alias startserver='$SERVERPATH/start'" >> /root/.bashrc
echo "alias stopserver='$SERVERPATH/stop'" >> /root/.bashrc
output_message "success" "Alias Created!"

#revoke permissions
chmod 640 /root -R 

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
echo "$MISC Start server command: startserver"
echo "Stop server command: stopserver$NC"
echo "$GREEN This information will be saved at root directory as /root/serverinfo!$NC"

echo "[Server Information]" > /root/serverinfo
echo "IP: $IP" >> /root/serverinfo
echo "PostgreSQL version: $PSQLVER" >> /root/serverinfo
echo "DB User: $DBUSER" >> /root/serverinfo
echo "DB Pass: $DBPASS" >> /root/serverinfo
echo "Start and stop server commands bellow" >> /root/serverinfo
echo "startserver" >> /root/serverinfo
echo "stopserver" >> /root/serverinfo

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
