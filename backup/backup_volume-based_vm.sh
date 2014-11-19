#!/bin/bash

NOW=`date +%Y%m%d%H%M%S`

VM_NAME=$1
echo "VM name: $VM_NAME"

nova show --minimal $VM_NAME >/dev/null 2>&1
if [ "$?" -ne "0" ]; then
  echo "Wrong VM name specified or environment not set up correctly!"
  exit 1
fi

VM_ID=`nova list | grep $VM_NAME | awk '{print $2}'`
echo "VM ID: $VM_ID"
VMVOL_ID=`cinder list | grep $VM_ID | awk '{print $2}'`
echo "VM volume ID: $VMVOL_ID"
VM_SIZE=`cinder list | grep $VM_ID | awk '{print $8}'`
echo "VM volume size: $VM_SIZE GB"
SNAPSHOT_NAME="${NOW}_${VM_NAME}-snapshot"
echo "snapshot name: $SNAPSHOT_NAME"
BACKUPVOL_NAME="${NOW}_${VM_NAME}-backupvol"
echo "backup volume name: $BACKUPVOL_NAME"
BACKUPIMAGE_NAME="${NOW}_${VM_NAME}-backupimage"
echo "backup image name: $BACKUPIMAGE_NAME"


# create snapshot of VM volume
echo
echo cinder snapshot-create --force True --display-name $SNAPSHOT_NAME $VMVOL_ID
cinder snapshot-create --force True --display-name $SNAPSHOT_NAME $VMVOL_ID

if [ "$?" -ne "0" ]; then
  exit 1
fi

# wait until snapshot is ready
STATE='unknown'
while [ "$STATE" != "available" ]; do
  echo 'waiting for snapshot to be available ...'
  sleep 1
  STATE=`cinder snapshot-list | grep $SNAPSHOT_NAME | awk '{print $6}'`
done

echo
SNAPSHOT_ID=`cinder snapshot-list | grep $SNAPSHOT_NAME | awk '{print $2}'`
echo "backup snapshot ID: $SNAPSHOT_ID"

# create new backup volume from snapshot
echo
echo cinder create --snapshot-id $SNAPSHOT_ID --display-name $BACKUPVOL_NAME $VM_SIZE
cinder create --snapshot-id $SNAPSHOT_ID --display-name $BACKUPVOL_NAME $VM_SIZE

if [ "$?" -ne "0" ]; then
  exit 1
fi

# wait until backup volume is ready
STATE='unknown'
while [ "$STATE" != "available" ]; do
  echo 'waiting for backup volume to be available ...'
  sleep 10
  STATE=`cinder list | grep $BACKUPVOL_NAME | awk '{print $4}'`
done

# create image from backup volume
echo
echo cinder upload-to-image --disk-format qcow2 $BACKUPVOL_NAME $BACKUPIMAGE_NAME
cinder upload-to-image --disk-format qcow2 $BACKUPVOL_NAME $BACKUPIMAGE_NAME

if [ "$?" -ne "0" ]; then
  exit 1
fi

# wait until backup image is ready
STATE='unknown'
while [ "$STATE" != "active" ]; do
  echo 'waiting for backup image to be active ...'
  sleep 10
  STATE=`glance image-list | grep $BACKUPIMAGE_NAME | awk '{print $12}'`
done

# download backup image
echo
echo glance image-download --file /root/${BACKUPIMAGE_NAME}.img $BACKUPIMAGE_NAME
glance image-download --file /root/${BACKUPIMAGE_NAME}.img $BACKUPIMAGE_NAME

if [ "$?" -ne "0" ]; then
  exit 1
fi
