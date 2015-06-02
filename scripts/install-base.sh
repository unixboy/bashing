#!/bin/bash -e

# Make sure only root can run our script
if [[ $EUID -ne 0 ]] ; then
   echo "This script must be run as root" 2>&1
   exit 1
fi

source /etc/os-release
echo "Running" $VERSION

usage(){
  echo "Install Base System"
  echo
  echo "Install Base on Ubuntu Server 14.10"
  echo "Check OpenSSH on installation."
  echo
  echo "Usage: $0"
  echo "       Set the standard proxy 10.50.0.1 and port 3128"
  echo "       $0 -a proxy_server -p port"
  echo "       Set the proxy to: http://proxy_server:port"
  echo "       -s                Installation for Siemens environment"
  echo "       -a proxy_server   Set the proxy address [192.168.40.1]"
  echo "       -p port           Set the proxy port [3128]"

  exit 1
}

inst_git(){
  # Installing from Source
  # http://git-scm.com/book/en/v2/Getting-Started-Installing-Git#Installing-from-Source
  # Install dependencies
  apt-get -y install --no-install-recommends libcurl4-gnutls-dev libexpat1-dev gettext libz-dev libssl-dev make autoconf build-essential asciidoc xmlto
  cd $SRC
  GITVER=$(git ls-remote --tags https://github.com/git/git.git | grep v2. | grep -v - | grep -v \{ | sort -t '/' -k 3 -V | grep -Po 'refs/tags/\K.*' | tr " " "\n" | sed -n '$p')
  GITVER=${1:-$GITVER}
  curl -L --progress https://github.com/git/git/archive/$GITVER.tar.gz | tar xz
  cd git*
  make configure
  ./configure --prefix=/usr
  make all
  make man
  make install
  make install-man
  cd /etc
  rm -rf $SRC/git*
}

sel_git(){
  # Version Control Systems
  clear
  echo "Install Git from Github"
  echo "-----------------------------------------"
  IFS=' ' read -a GITALL <<< $(git ls-remote --tags https://github.com/git/git.git | grep -v - | grep -v { | sort -t '/' -k 3 -V | grep -Po 'refs/tags/\K.*')
  GITLATE=${GITALL[-1]}

  echo "Latest version is $GITLATE"
  while :
  do
    read -e -i "$GITLATE" -p "Enter Git version to install: " input
    GITVER="${input:-$GITLATE}"

    if [[ ${GITALL[@]} =~ $GITVER ]]; then
      echo "Ok! Installing git version $GITVER"
      inst_git $GITVER
      break
    else
      echo "Git version $GITVER is not available!"
    fi
  done
}

inst_etc(){
  # Install etckeeper from github
  apt-get -y install make
  cd $SRC
  git clone https://github.com/joeyh/etckeeper.git
  cd etckeeper
  make install
  cd /etc
  rm -rf $SRC/etckeeper
}

inst_hh(){
  # hstr - BASH History Suggest Box
  # https://github.com/dvorka/hstr
  ###################################################
  DEST=/usr/local/bin
  HHVER=$(git ls-remote --tags https://github.com/dvorka/hstr.git | sort -t '/' -k 3 -V | grep -Po 'refs/tags/\K.*' | tr " " "\n" | sed -n '$p')
  HHVER=${1:-$HHVER}
  HH_SOURCE=https://github.com/dvorka/hstr/releases/download/$HHVER/hh-$HHVER-bin-64b.tgz
  cd $SRC
  wget $HH_SOURCE
  tar zxf hh-*.tgz -C $DEST
  rm hh-*.tgz
  chown root:root $DEST/hh

  if grep -q "HH_CONFIG" ~/.bashrc; then
    echo hh configuration already done!
  else
    hh --show-configuration >> ~/.bashrc
  fi

  echo Installation finished: BASH History Suggest Box
}

while getopts ":sa:p:h" opt; do
  case $opt in
    s) siemens=1
       ;;
    a) proxy_server=$OPTARG
       echo $proxy_server
       ;;
    p) port=$OPTARG
       echo $port
       ;;
    h) usage
       ;;
   \?) usage
       ;;
    :) echo "Option -$OPTARG requires an argument." >&2
       usage
       ;;
  esac
done

# Some Environment Variables
HOST=$(hostname)
read -e -i "$HOST" -p "Enter Hostname: " input
HOST="${input:-$HOST}"

read -e -i "$SUDO_USER" -p "Enter Username: " input
SUSER="${input:-$SUDO_USER}"

if [ ! -z "$siemens" ] ; then
  DOMAIN=engineering.siemens.de
  EMAIL=caps.energy@siemens.com
else
  DOMAIN=fritz.box
  EMAIL=$HOST@anwa-soft.de
fi

read -e -i "$DOMAIN" -p "Enter Domain: " input
DOMAIN="${input:-$DOMAIN}"
read -e -i "$EMAIL" -p "Enter EMail: " input
EMAIL="${input:-$EMAIL}"

FQDN=$HOST.$DOMAIN
SRC=/usr/local/src
PS3="Pick an option: "
GITVER="v2.2.0"

#set ${SUSER:=wansner}
#read -e -i "$SUSER" -p "Username: " input
#SUSER="${input:-$SUSER}"
#echo $SUSER

#read -p "Enter Username [$SUSER]" input
#SUSER=${input:-$SUSER}
#echo $SUSER

# Update the System
apt-get -y update
apt-get -y dist-upgrade
apt-get -y autoremove

# Version Control Systems
clear
echo "Install Git"
echo "-----------------------------------------"
GITVER1=$(LC_MESSAGES=C apt-cache policy git | grep -Po 'Installed: \K.*')
GITVER2=$(LC_MESSAGES=C apt-cache policy git | grep -Po 'Candidate: \K.*')
GITVER3=$(git ls-remote --tags https://github.com/git/git.git | grep -v - | grep -v { | sort -t '/' -k 3 -V | grep -Po 'refs/tags/\K.*' | tr " " "\n" | sed -n '$p')

if git --version &>/dev/null; then
  # Git is installed
  GITVER4=$(git --version | grep -Po 'version \K.*')
  GITVER4=$(echo v$GITVER1)

  if [[ $GITVER1 == "(none)" ]] ; then
    options=("Install git from apt [$GITVER2]")
    options+=("Update git from source [$GITVER4 -> $GITVER3]")
  elif [[ $GITVER1 == $GITVER2 ]] ; then
    echo "Already the actual git version [$GITVER1] installed!"
    options=("Keep installed git from apt [$GITVER1]")
    options+=("Install git from source [$GITVER3]")
  fi
else
  options=("Install git from apt [$GITVER2]")
  options+=("Install git from source [$GITVER3]")
fi
options+=("Manual select git version from source")

# Git is NOT installed
select opt in "${options[@]}"; do
  case "$REPLY" in
    1) echo "Install git from apt"
      apt-get -y install git
      ;;
    2) echo "Install from source"
      inst_git $GITVER2
      ;;
    3) echo "Install from source"
      sel_git
      ;;
    *) echo "Invalid option. Try another one."
      continue;;
  esac
  echo "In select!"
# Installing from Paketmanager

  git config --global user.email "$SUSER@$FQN"
  git config --global user.name "$SUSER"
  git config --global push.default simple
  break
done
# Create
# sudo -s
ssh-keygen
# cat /root/.ssh/id_rsa.pub
# Put this key to gitlab

ETCVER1=$(LC_MESSAGES=C apt-cache policy etckeeper | grep -Po 'Candidate: \K.*')
echo $ETCVER1
ETCVER2=$(git ls-remote --tags https://github.com/joeyh/etckeeper.git | grep -v debian | grep -v - | grep -v { | sort -t '/' -k 3 -V | grep -Po 'refs/tags/\K.*' | tr " " "\n" | sed -n '$p')
echo $ETCVER2

clear
echo "Install etckeeper"
echo "-----------------------------------------"
options=("from apt [$ETCVER1]" "from git [$ETCVER2]")
select opt in "${options[@]}" "do not install"; do

    case "$REPLY" in

    1 ) echo "You picked $opt which is option $REPLY"
        ;;
    2 ) echo "You picked $opt which is option $REPLY"
        ;;

    $(( ${#options[@]}+1 )) ) echo "Go to next step!"
        break;;
    *) echo "Invalid option. Try another one."
        continue;;
    esac
echo "In select!"
done

#fi


#echo $GITVER
#ETCVER=$(git ls-remote --tags https://github.com/joeyh/etckeeper.git | grep -v debian | grep -v - | grep -v { | sort -t '/' -k 3 -V | grep -Po 'refs/tags/\K.*' | tr " " "\n" | sed -n '$p')
#echo $ETCVER

title="Install etckeeper"
prompt="Pick an option:"
ETCVER1=$(LC_MESSAGES=C apt-cache policy etckeeper | grep -Po 'Candidate: \K.*')
#echo $ETCVER1
ETCVER2=$(git ls-remote --tags https://github.com/joeyh/etckeeper.git | grep -v debian | grep -v - | grep -v { | sort -t '/' -k 3 -V | grep -Po 'refs/tags/\K.*' | tr " " "\n" | sed -n '$p')
#echo $ETCVER2

options=("from apt [$ETCVER1]" "from git [$ETCVER2]")

echo "$title"
PS3="$prompt "
select opt in "${options[@]}" "do not install"; do

    case "$REPLY" in

    1 ) echo "You picked $opt which is option $REPLY"
        ;;
    2 ) echo "You picked $opt which is option $REPLY"
        ;;

    $(( ${#options[@]}+1 )) ) echo "Go to next step!"
        break;;
    *) echo "Invalid option. Try another one."
        continue;;
#echo "In case!"
    esac
echo "In select!"
done

exit 0



# Install etckeeper from github
apt-get -y install make
cd $SRC
git clone https://github.com/joeyh/etckeeper.git
cd etckeeper
make install
# Install etckeeper from repository
apt-get -y install etckeeper
cd /etc
etckeeper uninit
# uncomment git and comment out bzr
sed -i "s|^VCS.*|#&|" /etc/etckeeper/etckeeper.conf
sed -i "s|^#VCS=\"git\"|VCS=\"git\"|" /etc/etckeeper/etckeeper.conf
#
git config user.email "$SUSER@$FQN"
git config user.name "$SUSER"

etckeeper init
git commit -m "Initial commit"
git gc # pack git repo to save a lot of space

# Configure etckeeper to run `git gc` after each apt run which will save a lot of disk space
cd /etc
cat > /etc/etckeeper/post-install.d/99git-gc << EOF
#!/bin/sh
exec git gc
EOF
chmod +x /etc/etckeeper/post-install.d/99git-gc
git add /etc/etckeeper/post-install.d/99git-gc
git commit -m "Run git gc after each apt run"

# Automatically push commits to a clone of the repository as a backup
cd /etc

git remote add backup git@gitlab.$DOMAIN:etc/$HOST.git
cat > /etc/etckeeper/commit.d/99git-push << EOF
#!/bin/sh
git push -u backup master
EOF
chmod +x /etc/etckeeper/commit.d/99git-push
git add /etc/etckeeper/commit.d/99git-push
git commit -m "Automatically push commits to backup repository"

# Install and set vim.nox as default editor
# Achtung! Installiert ruby!
apt-get -y install vim-nox
update-alternatives --set editor /usr/bin/vim.nox
git add .
git commit -a -m "Set default editor to vim.nox"

# Setup ntp
# dpkg-reconfigure tzdata
apt-get -y install ntp
service ntp stop
# set local time server
sed -i "/server 1./d" /etc/ntp.conf
sed -i "/server 2./d" /etc/ntp.conf
sed -i "/server 3./d" /etc/ntp.conf
# Siemens
if [ ! -z "$siemens" ] ; then
  sed -i "s/Ubuntu"\'"s/Siemens/" /etc/ntp.conf
  sed -i "0,/server 0.*/s/server 0.*/server 10.50.0.1/" /etc/ntp.conf
  sed -i "0,/server ntp.*/s/server ntp.*/server 155.45.163.127/" /etc/ntp.conf
# Privat
else
  sed -i "0,/server 0.*/s/server 0.*/server 192.168.2.1/" /etc/ntp.conf
  sed -i "s/Ubuntu"\'"s/ntp.pool/" /etc/ntp.conf
  sed -i "0,/server ntp.*/s/server ntp.*/server 0.de.pool.ntp.org/" /etc/ntp.conf
fi
ntpd -qg
service ntp start
cd /etc
git commit -a -m "Setup ntp Server"


# Install some tools
apt-get -y install mc
apt-get -y install htop
apt-get -y install cron-apt


# Webmin
###################################################
#~/install-webmin.sh
#cd /etc
#git add .
#git commit -a -m "Install and setup Webmin"

# hstr - BASH History Suggest Box
# https://github.com/dvorka/hstr
###################################################
clear
echo "Install BASH History Suggest Box"
echo "-----------------------------------------"
HHVER1=$(git ls-remote --tags https://github.com/dvorka/hstr.git | sort -t '/' -k 3 -V | grep -Po 'refs/tags/\K.*' | tr " " "\n" | sed -n '$p')
options=("from github [$HHVER1]")
if hh --version &>/dev/null; then
  # hh is installed
  HHVER2=$(hh --version  | grep -Po 'version \K.*' | sed 's/\"//g')
  if [[ "$HHVER1" == "$HHVER2" ]] ; then
    echo "Already the actual hh version [$HHVER2] installed!"
  else
  	echo "A newer hh version [$HHVER1] was found on Github!"
    options+=("Keep local [$HHVER2]")
  fi
else
    options+=("Skip hh installation")
fi

select opt in "${options[@]}"; do
  case "$REPLY" in
    1) echo $opt
      inst_hh $HHVER1
      break;;
    2) echo $opt
      break;;
    *) echo "Invalid option. Try another one."
      continue;;
    esac
done


# VMWare Tools
# Use Install VMWare Tools option in VMWare Client to attach media
###################################################
# Open VM Tools
if [[ $(dmesg | grep "VMware Virtual") ]]; then
  clear
  echo "System is running under VMware!"
  echo "Install VMWare Tools"
  echo "-----------------------------------------"
  unset $options

  VMVER1=$(LC_MESSAGES=C apt-cache policy open-vm-tools | grep -Po 'Installed: \K.*')
  VMVER2=$(LC_MESSAGES=C apt-cache policy open-vm-tools | grep -Po 'Candidate: \K.*')
  VMVER3="none"
  if [[ $VMVER1 == "(none)" ]] ; then
     options+=("Install VMWare Tools from apt (open-vm-tools) [$VMVER2]")
     #GITSRC=" source"
  elif [[ "$VMVER1" == "$VMVER2" ]] ; then
    echo "Already the actual VMware tools version [$VMVER1] installed!"
    options+=("Keep VMWare Tools from apt (open-vm-tools) [$VMVER2]")
  fi
  if vmtoolsd --version &>/dev/null; then
  	VMVER3=$(vmtoolsd --version | grep -Po 'version \K.*')
    options+=("Update VMWare Tools from source (VMWare-Tools CD) [Inst: $VMVER3]")
  else
    options+=("Install VMWare Tools from source (VMWare-Tools CD)")
  fi
  options+=("Skip VMWare Tools installation")
  select opt in "${options[@]}"; do
    case "$REPLY" in
      1) echo "Install from apt"
        #apt-get -y install open-vm-tools
        ;;
      2) echo "Install from source"
        #~/install-vmware-tools.sh
        ;;
      3) echo "Skip Installation"
        break;;
      *) echo "Invalid option. Try another one."
        continue;;
    esac
    cd /etc
    git add .
    git commit -a -m "Install VMWare Tools"
  done
fi

# Add/Change alias in bashrc
LINE=$(echo $(sed -n '/alias l=/=' ~/.bashrc))
echo $LINE
sed -i "$((++LINE)) i alias df='df -h'" ~/.bashrc
sed -i "$((++LINE)) i alias top='htop'" ~/.bashrc
sed -i "s|alias ll=.*|alias ll='ls -alhF'|" ~/.bashrc

chown -R $SUSER:$SUSER /home/$SUSER
