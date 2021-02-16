#!/bin/bash

# Backup the existing rc.local
/bin/cp /etc/rc.local /etc/rc.local.Backup

# Copy the new rc.local and set it to execute 
/bin/cp rc.local /etc/rc.local
chmod 755 /etc/rc.local

# copy the other scripts to the correct locations
/bin/cp dis_spoofchk_ena_trust.sh /bin/dis_spoofchk_ena_trust.sh
/bin/cp flow.sh /bin/flow.sh
/bin/cp irq.sh /bin/irq.sh
/bin/cp set_huge_pages.sh /bin/set_huge_pages.sh

# Set the other scripts to be executable
chmod 755 /bin/dis_spoofchk_ena_trust.sh
chmod 755 /bin/flow.sh
chmod 755 /bin/irq.sh
chmod 755 /bin/set_huge_pages.sh


