#!/bin/bash

HOSTNAME="<fill_in>"
HOST_IP="<fill_in>"
PLUG_IP="<fill_in>"

echo " !! Machine ($HOSTNAME) is about to be powered off..."

# Turn plug OFF
wizlight off --ip $PLUG_IP

echo ""
echo "Waiting 15 seconds before powering back on..."

for i in {15..1}; do
    echo -ne "Powering on in $i seconds...\r"
    sleep 1
done

echo ""
echo "Powering on the machine..."

# Turn plug ON
echo -n "{\"id\":1,\"method\":\"setState\",\"params\":{\"state\":true}}" | nc -u -w 1 $PLUG_IP 38899 > /dev/null 2>&1

echo ""
echo "Waiting for $HOSTNAME to come back online..."

# Wait for ping
until ping -c 1 -W 1 $HOST_IP > /dev/null 2>&1; do
    sleep 5
    echo "Still waiting for $HOSTNAME..."
done

echo ""
echo "$HOSTNAME is back online and ready for testing."

