#!/bin/bash


###################################################################################################
#
# Description :  Configure Swarm Mode One Box
#               - Docker
#               - Docker Compose
#               - Swarm Mode masters
#               - Swarm Mode agents
#
# Source :  https://github.com/Azure/acs-engine/blob/master/parts/configure-swarmmode-cluster.sh
#
# Updates :
#       - March 2017
#         version : 1.0
#         Author : Didier Morhain - Engie IT / One Cloud Team
#               Add compatibility with RHEL7
#               Add the possibility to choose docker and docker compose version
#               Add Azurefile docker volume driver
#       - August 2017
#         version : 1.0
#         Author : Didier Morhain - Engie IT / One Cloud Team
#               Fix manager and worker detection
#               Update docker version from 17.03 to 17.06
#               Update docker compose version from 1.14.0 to 1.15.0
#
###################################################################################################


FILENAME=$(basename $0)
FNAME="${FILENAME%.*}"
LOG=/var/log/azure/$FNAME.log

exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>${LOG} 2>&1

set -x

DOCKER_VERSION="17.06.0"
DOCKER_COMPOSE_VERSION="1.16.0"
AZUREFILE_VOLUMEDRIVER_VERSION="0.5.1"
RHEL_UPDATE=off


#############
# Parameters
#############

MANAGERCOUNT=${1}
MANAGERPREFIX=${2,,}
MANAGERIP=${3}
AZUREUSER=${4}
#AZURE_STORAGE_ACCOUNT=${5}
#AZURE_STORAGE_ACCOUNT_KEY=${6}
POSTINSTALLSCRIPTURI=${7}

MANAGERID=$(echo ${MANAGERPREFIX: -8})
MANAGERFIRSTADDR=$(echo $MANAGERIP | awk -F. '{print $4}')
BASESUBNET=$(echo $MANAGERIP | awk -F. '{print $1"."$2"."$3"."}')
VMNAME=`hostname`
VMNAMEID=$(echo ${VMNAME: -8})
VMNUMBER=`echo $VMNAME | sed 's/.*[^0-9]\([0-9]\+\)*$/\1/'`
VMPREFIX=`echo $VMNAME | sed 's/\(.*[^0-9]\)*[0-9]\+$/\1/'`

sudo sh -c 'echo "rhui2-cds01.eu-central-1.aws.ce.redhat.com" >> /etc/yum.repos.d/rhui-load-balancers.conf'
sudo sh -c 'echo "rhui2-cds02.eu-central-1.aws.ce.redhat.com" >> /etc/yum.repos.d/rhui-load-balancers.conf'
sudo yum install curl
sudo yum install -y firewalld firewall-config
sudo systemctl enable firewalld.service
sudo systemctl start  firewalld
sudo yum install -y  wget


echo -e "\Starting Swarm Mode cluster configuration"
date
ps ax

echo -e "\nMaster Count: $MANAGERCOUNT"
echo "Master ID: $MANAGERID"
echo "Master Prefix: $MANAGERPREFIX"
echo "Master First Addr: $MANAGERFIRSTADDR"
echo "vmname: $VMNAME"
echo "vmname ID: $VMNAMEID"
echo "VMNUMBER: $VMNUMBER, VMPREFIX: $VMPREFIX"
echo "BASESUBNET: $BASESUBNET"
echo "AZUREUSER: $AZUREUSER"


#while ( ! (find /var/log/azure/Microsoft.Azure.Extensions.CustomScript/*/CommandExecution.log | xargs grep "state is: enabled"));
#do
#  sleep 5
#done


###################
# Common Functions
###################


isplatform()
{
  DETECTED_OS=$(awk -F= '/^ID=/ { print tolower($2) }' /etc/*-release | sed 's/\"//g')
  if [ "$1" == "$DETECTED_OS" ]
        then
                true
        else
                false
  fi
}


isinstalled()
{
 if isplatform rhel ; then
    if rpm -q "$@" >/dev/null 2>&1; then
       true
     else
       false
    fi
 elif isplatform ubuntu ; then
    if dpkg -l "$@" >/dev/null 2>&1; then
       true
     else
       false
    fi
 fi
}



ensureAzureNetwork()
{
  # ensure the network works
  networkHealthy=1
  for i in {1..12}; do
    wget -O/dev/null https://bing.com
    if [ $? -eq 0 ]
    then
      # hostname has been found continue
      networkHealthy=0
      echo "the network is healthy"
      break
    fi
    sleep 10
  done
  if [ $networkHealthy -ne 0 ]
  then
    echo "the network is not healthy, aborting install"
    ifconfig
    ip a
    exit 2
  fi
  # ensure the host ip can resolve
  networkHealthy=1
  for i in {1..120}; do
    hostname -i
    if [ $? -eq 0 ]
    then
      # hostname has been found continue
      networkHealthy=0
      echo "the network is healthy"
      break
    fi
    sleep 1
  done
  if [ $networkHealthy -ne 0 ]
  then
    echo "the network is not healthy, cannot resolve ip address, aborting install"
    ifconfig
    ip a
    exit 2
  fi
}

ensureAzureNetwork

HOSTADDR=$(hostname -I | awk '{print $1}')

ismaster ()
{
  #if [ "$MANAGERPREFIX" == "$VMPREFIX" ]
  if [ "${MANAGERID,,}" == "${VMNAMEID,,}" ]
  then
    return 0
  else
    return 1
  fi
}
if ismaster ; then
  echo -e "\nThis node is a master"
fi

isagent()
{
  if ismaster ; then
    return 1
  else
    return 0
  fi
}
if isagent ; then
  echo -e "\nThis node is an agent"
fi

MANAGER0IPADDR="${BASESUBNET}${MANAGERFIRSTADDR}"

######################
# resolve self in DNS
######################

echo "${HOSTADDR// /} ${VMNAME,,}" | sudo tee -a /etc/hosts


######################
# RHEL 7 requirements
######################

rhel_requirements()
{
  #if grep -q -i "release 7" /etc/redhat-release
  if isplatform rhel
  then
        RHEL_VERSION=$(cat /etc/redhat-release)
        echo -e "\nRunning $RHEL_VERSION"
        if [ "$RHEL_UPDATE" == "on" ]
        then
            echo -e "\nUpdating RHEL ..."
                        sudo rm -fr /var/cache/yum/*
                        sudo yum clean all
            sudo yum update -y --exclude=WALinuxAgent
        fi
        echo -e "\nSetting firewall rules for Docker Swarm installation ..."
            echo "Opening port 2375/tcp"
        sudo firewall-cmd --zone=public --add-port=2375/tcp --permanent
                echo "Opening port 2376/tcp"
        sudo firewall-cmd --zone=public --add-port=2376/tcp --permanent
        echo "Opening port 2377/tcp"
        sudo firewall-cmd --zone=public --add-port=2377/tcp --permanent
        echo "Opening port 7946/tcp"
        sudo firewall-cmd --zone=public --add-port=7946/tcp --permanent
        echo "Opening port 7946/udp"
        sudo firewall-cmd --zone=public --add-port=7946/udp --permanent
        echo "Opening port 4789/tcp"
        sudo firewall-cmd --zone=public --add-port=4789/tcp --permanent
        echo "Opening port 4789/udp"
        sudo firewall-cmd --zone=public --add-port=4789/udp --permanent
        echo "Reloading firewall configuration"
        sudo firewall-cmd --reload
        # adding Docker repo to the system
        sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        sudo yum makecache fast
        # Creating /var/lib/docker before installing docker-engine-selinux to avoid warnings during docker installation
        sudo mkdir  /var/lib/docker
  fi
}

rhel_requirements


################
# Install Docker
################

echo -e "\nInstalling and configuring Docker"

installDocker()

{
  for i in {1..10}; do
    curl https://releases.rancher.com/install-docker/17.06.sh | sh
    if [ $? -eq 0 ]
    then
      # hostname has been found continue
      echo "Docker installed successfully"
      break
    fi
    sleep 10
  done
}






time installDocker

sudo usermod -aG docker $AZUREUSER

echo "Configuring Docker to start on boot"
sudo systemctl enable docker


echo "Updating Docker daemon options"

updateDockerDaemonOptions()
{
#    sudo mkdir -p /etc/systemd/system/docker.service.d
#    # Start Docker and listen on :2375 (no auth, but in vnet) and
#    # also have it bind to the unix socket at /var/run/docker.sock
#    sudo bash -c 'echo "[Service]
#    ExecStart=
#    ExecStart=/usr/bin/docker daemon -H tcp://0.0.0.0:2375 -H unix:///var/run/docker.sock
#  " > /etc/systemd/system/docker.service.d/override.conf'
     DOKCKER_START="ExecStart=/usr/bin/dockerd -H unix:///var/run/docker.sock -H tcp://0.0.0.0:2375"
     sudo sed -i --follow-symlinks "s|^ExecStart.*|$DOKCKER_START|" /etc/systemd/system/multi-user.target.wants/docker.service
     sudo systemctl daemon-reload
     sudo systemctl restart docker
}

if ismaster ; then
time updateDockerDaemonOptions
fi

echo -e "\nInstalling Docker Compose"

installDockerCompose()
{
  for i in {1..10}; do
    sudo wget --tries 4 --retry-connrefused --waitretry=15 -qO/usr/local/bin/docker-compose https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VERSION/docker-compose-`uname -s`-`uname -m`
    if [ $? -eq 0 ]
    then
      # hostname has been found continue
      echo "docker-compose installed successfully"
      break
    fi
    sleep 10
  done
}
time installDockerCompose
sudo chmod +x /usr/local/bin/docker-compose

echo -e "\nStarting docker"
sudo systemctl start docker


ensureDocker()
{
  # ensure that docker is healthy
  dockerHealthy=1
  for i in {1..3}; do
    sudo docker info
    if [ $? -eq 0 ]
    then
      # hostname has been found continue
      dockerHealthy=0
      echo "Docker is healthy"
      sudo docker ps -a
      echo -e "\nVerifying that docker is installed correctly by running the hello-world image"
      sudo docker run hello-world
      sudo docker ps -a
      break
    fi
    sleep 10
  done
  if [ $dockerHealthy -ne 0 ]
  then
    echo "Docker is not healthy"
  fi
}
ensureDocker


##############################################
# configure init rules restart all processes
##############################################


if ismaster ; then
    if [ "${HOSTADDR// /}" = "$MANAGERIP" ]; then
          echo "Creating a new Swarm on first master"
          sudo docker swarm init --advertise-addr ${MANAGERIP}:2377 --listen-addr ${MANAGERIP}:2377
    else
        echo "Secondary master attempting to join an existing Swarm"
        swarmmodetoken=""
        swarmmodetokenAcquired=1
        for i in {1..120}; do
            swarmmodetoken=$(docker -H $MANAGERIP:2375 swarm join-token -q manager)
            if [ $? -eq 0 ]; then
                swarmmodetokenAcquired=0
                break
            fi
            sleep 5
        done
        if [ $swarmmodetokenAcquired -ne 0 ]
        then
            echo "Secondary master couldn't connect to Swarm, aborting install"
            exit 2
        fi
        sudo docker swarm join --token $swarmmodetoken $MANAGER0IPADDR:2377
    fi
fi


if isagent ; then
    echo "Agent attempting to join an existing Swarm"
    swarmmodetoken=""
    swarmmodetokenAcquired=1
    for i in {1..120}; do
        swarmmodetoken=$(sudo docker -H $MANAGER0IPADDR:2375 swarm join-token -q worker)
        if [ $? -eq 0 ]; then
            swarmmodetokenAcquired=0
            break
        fi
        sleep 5
    done
    if [ $swarmmodetokenAcquired -ne 0 ]
    then
        echo "Agent couldn't join Swarm, aborting install"
        exit 2
    fi
    sudo docker swarm join --token $swarmmodetoken $MANAGER0IPADDR:2377
fi


#########################################
# Install azurefile docker volume driver
#########################################

install_azurefile_volumedriver()
{
   # check if the prerequisite 'cifs-utils' package is installed
   if isplatform rhel
   then
        if isinstalled cifs-utils ; then
           echo -e "\nCheck if cifs-utils package is installed ... ok"
        else
           echo -e "\nInstallation of cifs-utils package ..."
           sudo yum install cifs-utils -y
        fi
   elif isplatform ubuntu ; then
        if isinstalled cifs-utils ; then
           echo -e "\nCheck if cifs-utils package is installed ... ok"
        else
           echo -e "\nInstallation of cifs-utils package ..."
           sudo apt-get install -y cifs-utils
        fi

   fi
   sudo wget --tries 4 --retry-connrefused --waitretry=15 -qO/usr/bin/azurefile-dockervolumedriver https://github.com/Azure/azurefile-dockervolumedriver/releases/download/v${AZUREFILE_VOLUMEDRIVER_VERSION}/azurefile-dockervolumedriver
   sudo chmod +x /usr/bin/azurefile-dockervolumedriver
   echo "# Environment file for azurefile-dockervolumedriver.service
#
# AF_OPTS=--debug
# AZURE_STORAGE_BASE=core.windows.net

AZURE_STORAGE_ACCOUNT=${AZURE_STORAGE_ACCOUNT}
AZURE_STORAGE_ACCOUNT_KEY=${AZURE_STORAGE_ACCOUNT_KEY}" | sudo tee -a /etc/default/azurefile-dockervolumedriver
   echo "[Unit]
Description=Azure File Service Docker Volume Driver
Documentation=https://github.com/Azure/azurefile-dockervolumedriver/
Requires=docker.service
After=nfs-utils.service
Before=docker.service

[Service]
EnvironmentFile=/etc/default/azurefile-dockervolumedriver
ExecStart=/usr/bin/azurefile-dockervolumedriver $AF_OPTS
Restart=always
StandardOutput=syslog

[Install]
WantedBy=multi-user.target" | sudo tee -a /etc/systemd/system/azurefile-dockervolumedriver.service
   sudo systemctl daemon-reload
   sudo systemctl enable azurefile-dockervolumedriver
   sudo systemctl start azurefile-dockervolumedriver
}
#install_azurefile_volumedriver


ensureAzurefile_volumedriver()
{
 # ensure that azurefile docker volume driver  is healthy
   sudo systemctl status azurefile-dockervolumedriver
   if [ $? -eq 0 ]
   then
        echo "Azurefile docker volume driver is healthy"
   else
        echo "!! Azurefile docker volume driver is not healthy !!"
   fi
   echo "Creating a new volume voltest using azurefile driver ..."
   sudo docker volume list | grep -v local
   sudo docker volume create -d azurefile -o share=sharetest --name=voltest
   sudo docker volume list | grep -v local
}
#ensureAzurefile_volumedriver


#######################
# POST INSTALL SCRIPT
#######################

if [ "$POSTINSTALLSCRIPTURI" != "disabled" ]
then
  echo "downloading, and kicking off post install script"
  /bin/bash -c "wget --tries 20 --retry-connrefused --waitretry=15 -qO- $POSTINSTALLSCRIPTURI | nohup /bin/bash >> /var/log/azure/cluster-bootstrap-postinstall.log 2>&1 &"
fi


#################################
# End of script : check & clean
#################################

echo "processes at end of script"
ps ax
date
sudo bash -c 'docker rm $(docker ps -a -q)'
sudo bash -c 'docker rmi $(docker images -a -q)'
sudo docker volume remove voltest
echo "completed Swarm Mode cluster configuration"

#echo "restart system to install any remaining software"
#if isagent ; then
#  shutdown -r now
#else
#  # wait 1 minute to restart master
#  /bin/bash -c "shutdown -r 1 &"
#fi

