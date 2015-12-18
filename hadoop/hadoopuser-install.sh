#!/bin/bash

HADOOP_ROL=$1
HADOOP_MASTER_IP=$2
HADOOP_SLAVE_IP=$3

if [ "$HADOOP_ROL" = "master" ]; then
  echo "Generating rsa key pair and injecting it into slave $HADOOP_SLAVE_IP"
  ssh-keygen -t rsa -P ""
  cat /home/hadoopuser/.ssh/id_rsa.pub >> /home/hadoopuser/.ssh/authorized_keys || exit 1
  chmod 600 .ssh/authorized_keys
fi

if [ "$HADOOP_ROL" = "slave" ]; then
  echo "Allowing PasswordAuthentication"
  sudo sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
  sudo service ssh restart
fi

echo "Downloading & extracting hadoop..."
wget http://apache.rediris.es/hadoop/common/hadoop-2.6.0/hadoop-2.6.0.tar.gz
tar xvf hadoop-2.6.0.tar.gz
mv hadoop-2.6.0 hadoop
echo "Hadoop downloaded & extracted"

echo "Setting environment variables needed by hadoop..."
echo 'export HADOOP_HOME=/home/hadoopuser/hadoop' >> .bashrc
echo 'export JAVA_HOME=/usr/lib/jvm/java-7-oracle' >> .bashrc
echo 'export PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin' >> .bashrc

sed -i 's|export JAVA_HOME=${JAVA_HOME}|export JAVA_HOME=/usr/lib/jvm/java-7-oracle|' /home/hadoopuser/hadoop/etc/hadoop/hadoop-env.sh
echo "Succesfully changed environment variables!"

cat > /home/hadoopuser/hadoop/etc/hadoop/core-site.xml <<-EOF
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
<property>
  <name>hadoop.tmp.dir</name>
  <value>/home/hadoopuser/tmp</value>
  <description>Temporary Directory.</description>
</property>

<property>
  <name>fs.defaultFS</name>
  <value>hdfs://$HADOOP_MASTER_IP:54310</value>
  <description>Use HDFS as file storage engine</description>
</property>
</configuration>
EOF

if [ "$HADOOP_ROL" = "master" ]; then
cat > /home/hadoopuser/hadoop/etc/hadoop/mapred-site.xml <<-EOF
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
<property>
 <name>mapreduce.jobtracker.address</name>
 <value>$HADOOP_MASTER_IP:54311</value>
 <description>The host and port that the MapReduce job tracker runs
  at. If "local", then jobs are run in-process as a single map
  and reduce task.
</description>
</property>
<property>
 <name>mapreduce.framework.name</name>
 <value>yarn</value>
 <description>The framework for running mapreduce jobs</description>
</property>
</configuration>
EOF
fi

echo "Initializing hdfs..."
mkdir -p /home/hadoopuser/hadoop-data/hdfs/namenode || exit 1
mkdir -p /home/hadoopuser/hadoop-data/hdfs/datanode || exit 1

cat > hadoop/etc/hadoop/hdfs-site.xml <<-EOF
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
<property>
 <name>dfs.replication</name>
 <value>2</value>
 <description>Default block replication.
  The actual number of replications can be specified when the file is created.
  The default is used if replication is not specified in create time.
 </description>
</property>
<property>
 <name>dfs.namenode.name.dir</name>
 <value>/home/hadoopuser/hadoop-data/hdfs/namenode</value>
 <description>Determines where on the local filesystem the DFS name node should store the name table(fsimage). If this is a comma-delimited list of directories then the name table is replicated in all of the directories, for redundance
 </description>
</property>
<property>
 <name>dfs.datanode.data.dir</name>
 <value>/home/hadoopuser/hadoop-data/hdfs/datanode</value>
 <description>Determines where on the local filesystem an DFS data node should store its blocks. If this is a comma-delimited list of directories, then data will be stored in all named directories, typically on different devices.
 </description>
</property>
</configuration>
EOF

cat > /home/hadoopuser/hadoop/etc/hadoop/yarn-site.xml <<-EOF
<?xml version="1.0"?>
<configuration>

<!-- Site specific YARN configuration properties -->
<property>
 <name>yarn.nodemanager.aux-services</name>
 <value>mapreduce_shuffle</value>
</property>
<property>
 <name>yarn.resourcemanager.scheduler.address</name>
 <value>$HADOOP_MASTER_IP:8030</value>
</property>
<property>
 <name>yarn.resourcemanager.address</name>
 <value>$HADOOP_MASTER_IP:8032</value>
</property>
<property>
  <name>yarn.resourcemanager.webapp.address</name>
  <value>$HADOOP_MASTER_IP:8088</value>
</property>
<property>
  <name>yarn.resourcemanager.resource-tracker.address</name>
  <value>$HADOOP_MASTER_IP:8031</value>
</property>
<property>
  <name>yarn.resourcemanager.admin.address</name>
  <value>$HADOOP_MASTER_IP:8033</value>
</property>
</configuration>
EOF

if [ "$HADOOP_ROL" = "master" ]; then
  cat > /home/hadoopuser/hadoop/etc/hadoop/slaves <<-EOF
  $HADOOP_MASTER_IP
  $HADOOP_SLAVE_IP
EOF

  echo "Formating hdfs..."
  ./hadoop/bin/hdfs namenode -format
  echo "hdfs initialized!"
fi

if [ "$HADOOP_ROL" = "master" ]; then
  echo "To complete configuration run the following commands:"
  echo "ssh-copy-id -i ~/.ssh/id_rsa.pub hadoopuser@$HADOOP_SLAVE_IP"
  echo "Login to slave with the key. This command should not ask for a password.\nType exit when logged into the slave to return to master"
  echo "ssh hadoopuser@$HADOOP_SLAVE_IP"
  echo "On the Amazon AWS security group add a new rule and configure it as follows:"
  echo "Select security group on instance details"
  echo "Click on Edit, then on Add rule"
  echo "Add the following rules, each line represents a rule, and fields are separated by commas"
  echo "Custom TCP Rule, TCP, 54310, $HADOOP_SLAVE_IP/32"
  echo "Custom TCP Rule, TCP, 8030-8033, $HADOOP_SLAVE_IP/32"
  echo "Custom TCP Rule, TCP, 8088, Anywhere"
  echo "Custom TCP Rule, TCP, 50010, Anywhere"
fi
