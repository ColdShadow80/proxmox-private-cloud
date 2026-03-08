CTID=$(cat /tmp/homelab_ctid)
STATIC_IP=192.168.1.50/24
GATEWAY=192.168.1.1

pct set $CTID --net0 name=eth0,bridge=vmbr0,ip=$STATIC_IP,gw=$GATEWAY
