CTID=$(cat /tmp/homelab_ctid)
TEMPLATE=$(pveam available | grep debian-12 | head -n1 | awk '{print $2}')
pveam download local $TEMPLATE

pct create $CTID local:vztmpl/$TEMPLATE \
 --hostname docker-host \
 --cores 4 \
 --memory 8192 \
 --rootfs local-lvm:50 \
 --features nesting=1,keyctl=1 \
 --net0 name=eth0,bridge=vmbr0,ip=dhcp

pct start $CTID
