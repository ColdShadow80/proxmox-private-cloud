POOL=rpool
DATASET=docker
zfs create $POOL/$DATASET
echo "ZFS dataset created: $POOL/$DATASET"
