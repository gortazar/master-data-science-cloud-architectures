#!/bin/bash

# Check mandatory parameters
[ -z $HADOOP_ROL ] && { echo "Please set HADOOP_ROL environment variable to 'master' or 'slave' like this: export HADOOP_ROL=master"; exit 1; }
[ -z $HADOOP_MASTER_IP ] && { echo "Please set HADOOP_MASTER_IP environment variable with the private IP of the slave like this: export HADOOP_MASTER_IP=<ip>"; exit 1; }
[ -z $HADOOP_SLAVE_IP ] && { echo "Please set HADOOP_SLAVE_IP environment variable with the private IP of the slave like this: export HADOOP_SLAVE_IP=<ip>"; exit 1; }

# Install java from Oracle
echo "Installing Java..."
sudo add-apt-repository ppa:webupd8team/java
sudo apt-get update
sudo apt-get install -y oracle-java7-installer || { echo "Could not install Java"; exit 1; }
sudo update-java-alternatives -s java-7-oracle
echo "Java installed!"

if [ "$HADOOP_ROL" = "slave" ]; then
  echo "Enabling password authentication..."
  sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config || exit 1
  sudo service ssh restart || exit 1
  echo "Password authentication enabled!"
fi

# Add hadoopgroup & hadoopuser.
echo "Adding group hadoopgroup and user hadoopuser..."
sudo addgroup hadoopgroup || exit 1
echo "I'm going to add the hadoopuser user."
echo "The command to add the user will ask for a password. Please choose a password, enter it twice, and leave the rest of the fields blank"
sudo adduser --ingroup hadoopgroup hadoopuser || exit 1

echo "I'm going to run some commands as user 'hadoopuser'. Please enter the password when prompted"
su -c "$PWD/hadoopuser-install.sh $HADOOP_ROL $HADOOP_MASTER_IP $HADOOP_SLAVE_IP" - hadoopuser
