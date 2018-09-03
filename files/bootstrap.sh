Content-Type: multipart/mixed; boundary="==BOUNDARY=="
MIME-Version: 1.0

--==BOUNDARY==
MIME-Version: 1.0
Content-Type: text/text/x-shellscript; charset="us-ascii"
#!/bin/sh

yum update -y && yum install -y xfsprogs

# prepare and enable 4GB swapfile
cp /etc/fstab /etc/fstab.orig
dd if=/dev/zero of=/swapfile bs=1024 count=4194304
chmod 0600 /swapfile
mkswap /swapfile
swapon /swapfile
echo -e "/swapfile        swap    swap    defaults    0 0" | tee -a /etc/fstab
# prepare the volume
lsblk
mkfs -t xfs /dev/sdb
mkdir -p /data
UUID=$(xfs_admin -u /dev/sdb | sed -n 's/^UUID = \([^\"]*\)$/\1/p')
echo -e "UUID=$UUID        /data    xfs    defaults,nofail,noatime 0 2" | tee -a /etc/fstab
mount -a

# install and configure mongodb cloud manager (latest)
curl -OL https://cloud.mongodb.com/download/agent/automation/mongodb-mms-automation-agent-manager-latest.x86_64.rpm
rpm -U mongodb-mms-automation-agent-manager-latest.x86_64.rpm
echo -e "mmsGroupId=${CLOUD_MANAGER_GROUP_ID}" | tee -a /etc/mongodb-mms/automation-agent.config
echo -e "mmsApiKey=${CLOUD_MANAGER_API_KEY}" | tee -a /etc/mongodb-mms/automation-agent.config
chown mongod:mongod /data

service mongodb-mms-automation-agent start

--==BOUNDARY==
