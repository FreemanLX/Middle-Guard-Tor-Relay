#!/bin/bash

catcherr(){
   case $1 in
   0)
       echo "$(tput setaf 1)Linux update failed. Please retry later."
	   ;;
   1)
       echo "$(tput setaf 1)Unable to install unattended upgrades. Please retry later."
       ;;	   
   esac	   
   exit	   
}


verifydepedencies(){
    REQUIRED_PKG=$1
	if ! which $REQUIRED_PKG > /dev/null; then
	  apt -y install $REQUIRED_PKG &> /dev/null
	  if(($? != 0)); then 
	    echo "$(tput setaf 1)Couldn't install $REQUIRED_PKG."
	    exit
      fi
      else
          echo "$(tput setaf 7)$REQUIRED_PKG is installed."	       
	fi
}

#Step 0 checking if the script is runned as root or not
if (( $EUID != 0 )); then
    echo "$(tput setaf 3)Please run this script as root."
    exit
fi

#The basics to setup a mid relay TOR
read -p 'Enter your nickname: ' nickname
read -p 'Enter your contact info e.g tor@e-mail.com: ' contactinfo
read -p 'Enter the port that you want to setup the relay e.g 443: ' port
read -sp 'Enter your password: ' password
printf "\n"
#Step 1 installs necessary depedencies for installation
echo "$(tput setaf 2)Step 1: Installing necessary depedencies for TOR and Nyx installation"
declare -a listofdepedencies=("lsb-core" "cmake" "gcc" "glib-2.0" "pkg-config" "python3" "python3-distutils")
for i in "${listofdepedencies[@]}"
do
   verifydepedencies "$i"
done

#Step 2 prepares Ubuntu / Debian to be automatically updated
echo "$(tput setaf 2)Step 2: Enabling and configuring automatic software updates"
apt -y update && apt -y upgrade &> /dev/null
if (( $? !=0 )); then catcherr 0 
fi
apt -y install unattended-upgrades apt-listchanges bsd-mailx &> /dev/null
if (( $? !=0 )); then catcherr 1
fi

#Step 3 configures a repository, to be able install TOR
echo "$(tput setaf 2)Step 3: Configuring repository for TOR installation"
Distro=$(lsb_release -c --short)
verifydepedencies "apt-transport-https"

#Saving the repository links to /etc/apt/sources.list.d/tor.list
printf 'deb [signed-by=/usr/share/keyrings/tor-archive-keyring.gpg] https://deb.torproject.org/torproject.org %s main\n' $Distro > /etc/apt/sources.list.d/tor.list
printf 'deb-src [signed-by=/usr/share/keyrings/tor-archive-keyring.gpg] https://deb.torproject.org/torproject.org %s main\n' $Distro >> /etc/apt/sources.list.d/tor.list
wget -qO- https://deb.torproject.org/torproject.org/A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89.asc | gpg --dearmor | tee /usr/share/keyrings/tor-archive-keyring.gpg > /dev/null
apt -y update &> /dev/null
apt -y install tor deb.torproject.org-keyring  &> /dev/null

#Step 4 installs and configures TOR
echo "$(tput setaf 2)Step 4: Installing and configuring TOR "
tput setaf 7
if ! which "tor" > /dev/null; then
	  apt -y install tor &> /dev/null
	  if(($? != 0)); then 
	    echo "$(tput setaf 1)Couldn't install tor."
	    exit
      fi
      else
          apt -y --reinstall install tor &> /dev/null
          if(($? != 0)); then 
	         echo "$(tput setaf 1)Couldn't reinstall tor."
	      exit
          fi		  
	fi
apt -y install tor
systemctl enable tor

#Generate a hash password for security reasons.
hashedPassword=$(tor --hash-password $password | tail -1)
printf "#\nNickname %s\n#\nContactInfo %s\n#\nORPort %s\n#\nExitRelay %d\n#\nSocksPort %d\nSocksListenAddress 127.0.0.1\n#\nControlPort 9051\nHashedControlPassword %s\n#\nExitPolicy reject *:*\n#\nDirPort 9030" $nickname $contactinfo $port 0 0 $hashedPassword > /etc/tor/torrc

#Step 5 just enables the TOR services and installs Nyx for monitoring
echo "$(tput setaf 2)Step 5: Enabling TOR service and installing Nyx"
verifydepedencies "nyx"
systemctl start tor
