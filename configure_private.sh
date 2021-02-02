#!/usr/bin/bash

export BRIDGE_NAME="private"
export IP="10.176.37.198/26"
export GW="10.176.37.193"
export STATIC_ROUTE_1="10.0.0.0/8"
export STATIC_ROUTE_2="166.9.0.0/16"
export STATIC_ROUTE_3="161.26.0.0/16"
export BOND_NAME="bond0"
export BOND_OPTIONS="mode=802.3ad"
export BOND_SLAVE_1="eno1"
export BOND_SLAVE_2="eno3"

# Create the Bridge
nmcli con add type bridge ifname $BRIDGE_NAME con-name $BRIDGE_NAME
nmcli con modify $BRIDGE_NAME ipv4.method static ipv4.address $IP ipv6.method ignore

# Setup the Bond
nmcli con add type bond ifname $BOND_NAME con-name $BOND_NAME bond.options $BOND_OPTIONS

# Add the slaves to the Bond
nmcli con add type ethernet con-name $BOND_NAME-slave-$BOND_SLAVE_1 ifname $BOND_SLAVE_1 master $BOND_NAME
nmcli con add type ethernet con-name $BOND_NAME-slave-$BOND_SLAVE_2 ifname $BOND_SLAVE_2 master $BOND_NAME

# Add the bond to the Bridge
nmcli con modify $BOND_NAME master $BRIDGE_NAME slave-type bridge

# Set the static routes
nmcli con modify $BRIDGE_NAME +ipv4.routes "$STATIC_ROUTE_1 $GW"
nmcli con modify $BRIDGE_NAME +ipv4.routes "$STATIC_ROUTE_2 $GW"
nmcli con modify $BRIDGE_NAME +ipv4.routes "$STATIC_ROUTE_3 $GW"

# Bring up the bridge interface
nmcli con up $BOND_NAME
nmcli con up $BRIDGE_NAME
