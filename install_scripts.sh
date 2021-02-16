#!/bin/bash

# Backup the existing rc.local
cp /etc/rc.local /etc/rc.local.Backup

# Copy the new rc.local and set it to execute 
cp rc.local /etc/rc.local
chmod 755 /etc/rc.local

# copy the other scripts to the correct locations
cp dis_spoofchk_ena_trust.sh /bin/.
cp flow.sh /bin/.
cp irq.sh ./bin/.
cp set_huge_pages.sh ./bin/.

# Set the other scripts to be executable
chmod 755 /bin/flow.sh
chmod 755 /bin/irq.sh
chmod 755 /bin/set_huge_pages.sh


