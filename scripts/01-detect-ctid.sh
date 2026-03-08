NEXTID=$(pvesh get /cluster/nextid)
echo "Next free CTID: $NEXTID"
echo $NEXTID > /tmp/homelab_ctid
