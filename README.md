# Deploying the vSRX in IBM Cloud Manually
This is a process that can be followed to manually deploy a vSRX appliance on IBM Cloud (commerical or government).  
__This process is not endorced by IBM, use at your own risk__

Requirements (Commerical):
* Gateway appliance deploy using Bring Your Own Gateway (Documentation is for HA)
* Red Hat Based Linux OS (RHEL or CentOS) Version 8 - This can be adapted to other version of Linux but may require changes to work

Requirements (Federal):
* VRA Gateway Appliance deployed (HA)
* Red Hat Based Linux OS (RHEL or CentOS) Version 8 - This can be adapted to other version of Linux but may require changes to work

## High Level Installation Process
* Install Red Hat Based Linux on each of the bare metal servers (RHEL or CentOS)
* Configure the public network 
* Clone this git repo to each of the servers so scripts can be used to create the bridge configuration
* Configure each server for SR-IOV
* Install KVM dependancies 
* Deploy the vSRX virtual machine
* Configure the vSRX VM with the Virtual Function (VF) NICs
* Configure the vSRX for HA (create a cluster)
* Finish the vSRX configuration

## Detailed Installation Process
### Install Red Hat Based Linux
1. Using the IBM Cloud Portal, get the IPMI Web Interface address and connect to it.
2. Using the Java client (Java installation required) mount the RHEL or CentOS installation ISO
3. Boot the server, it should boot off CD
4. Complete the server installation, minimal server install, no network configuration required at this point in time

### Configure Virtualization Options
Need to ensure that Nested Virtualization is enabled and APICv is disabled.  We'll accomplish this my adding a configuration file for modprobe

```
echo "options kvm-intel nested=1 enable_apicv=n pml=n" >> /etc/modprobe.d/kvm.conf
```

The following settings will enable Virtual Functions for the network cards.  First, modify /etc/default/grub adding "intel_iommu=on iommu=pt" to the GRUB_CMDLINE_LINUX line

```
before:
GRUB_CMDLINE_LINUX="crashkernel=auto resume=/dev/mapper/cl-swap rd.lvm.lv=cl/root rd.lvm.lv=cl/swap rhgb quiet"
after:
GRUB_CMDLINE_LINUX="crashkernel=auto resume=/dev/mapper/cl-swap rd.lvm.lv=cl/root rd.lvm.lv=cl/swap rhgb quiet intel_iommu=on iommu=pt"

```

Then regenerate the GRUB Configuration
```
grub2-mkconfig -o /boot/grub2/grub.cfg
```

Next is to configure the server to create the VF's on boot.  The first part is to determine which NIC driver we are using:  
```
[root@localhost ~]# ethtool -i eno1
driver: i40e    <- This is the driver
version: 2.8.20-k
firmware-version: 7.00 0x80004feb 1.2228.0
expansion-rom-version:
bus-info: 0000:18:00.0
supports-statistics: yes
supports-test: yes
supports-eeprom-access: yes
supports-register-dump: yes
supports-priv-flags: yes
[root@localhost ~]#

```

Then we create a udev rule to create the VFs, replacing i40e with the correct driver for your NIC.  This will create 8 VFs
```
echo 'ACTION=="add", SUBSYSTEM=="net", ENV{ID_NET_DRIVER}=="i40e", ATTR{device/sriov_numvfs}="8"' >> /etc/udev/rules.d/virtual-functions.rules
```


### Configure a temporary public network interface 
There are 4 Physical NICs on these bare metal servers (assuming you provisioned with redundant connections)
| Interface | Network |
|-----------|:--------|
| eno1      | Private |
| eno2      | Public  |
| eno3      | Private |
| eno4      | Public  |

For this phase we are going to configure eno2 with its public address so additional scripts can be downloaded to configure the more complicated bridge configuration
 * Get the public IP address for the server from the IBM Cloud Portal
 * Configure the eno2 interface with that Public IP address
    
     ```nmcli con modify eno2 ipv4.method static ipv4.address x.x.x.x/x ipv6.method ignore```
 * Configure the default route to use your Gateway (Gateway IP obtained from IBM Cloud Portal)
    
     ```nmcli con modify eno2 +ipv4.routes "0.0.0.0/0 x.x.x.x"```
 * Configure DNS to allow name resolution
    
     ```nmcli con modify eno2 ipv4.dns "8.8.8.8"```
 * Bring up the interface
     
     ```nmcli con up eno2```

At this point you should be able to reach the internet and resolve DNS names.  Next you should grab the zip file from github that contains all the scripts and xml files

```wget https://github.com/bbushvt/deploy_manual_vsrx/archive/main.zip```

Shut down eno2 after the scripts have been downloaded

```nmcli con down eno2```

### Complete the Host Network Config

Upzip the main.zip file that was downloaded above.

```unzip main.zip```

This will create a directory "deploy_manual_vsrx-main" where several scripts are located as well as the interface configuration files for the Network Functions.  Here we need to make some changes to the scrips
* Edit the configure_public.sh script, replacing the value for IP and GW with the appropriate values obtained from the IBM Cloud Portal
```
export IP="169.46.59.69/29"
export GW="169.46.59.65"
```

* Edit the configure_private.sh script, replacing the value for IP and GW with the appropriate values obtained from the IBM Cloud Portal
```
export IP="10.176.37.198/26"
export GW="10.176.37.193"
```

* Make the scripts executable

```
chmod 755 configure_private.sh
chmod 755 configure_public.sh
```

* run each of the scripts 
```
./configure_private.sh
./configure_public.sh
```



### Deploy the vSRX
The following instructions assume the vSRX qcow2 image is called 'junos-vsrx3-x86-64-20.4R1.12.qcow2' and is located in /root
* Copy the vSRX image to the default image location

```cp /root/junos-vsrx3-x86-64-20.4R1.12.qcow2 /var/lib/libvirt/images/.```

* Change the ownership of the image file to qemu and the group to kvm

```chown qemu.kvm /var/lib/libvirt/images/junos-vsrx3-x86-64-20.4R1.12.qcow2```

* Change the permissions on the vSRX image file to 644

```chmod 644 /var/lib/libvirt/images/junos-vsrx3-x86-64-20.4R1.12.qcow2```

* Install the vSRX image using the following command

```virt-install --name vSRX --ram 4096 --cpu Skylake-Server,+vmx, --vcpus=2 --arch=x86_64 --disk path=/var/lib/libvirt/images/junos-vsrx3-x86-64-20.4R1.12.qcow2,size=16,device=disk,bus=ide,format=qcow2 --os-type linux --os-variant rhel7 --import```

This will create a virtual machine with 2 cores and 4GB RAM as well as power on the VM.

### Configuring the vSRX Networks
After the vSRX has been fully deployed (booted to a login prompt), login as root (no password), and shutdown the VM (be sure to do this in the VM and not the host)

```shutdown -h now```

Once the shutdown is complete, power off the vSRX VM.  Using the GUI we are going to modify the existing NIC and add an additionial one.

* Using the Virtual Machine Manager (virt-manager) GUI, open the vSRX VM and click on the configuration icon in the menu bar (light bulb)
* Select the virst NIC and change the "Network source" to "Bridge private: Host device bond0", then click "Apply"
* Click on the "Add Hardware" button in the bottom left
* Select "Network" in the left pane
* Change "Network source" to "Bridge private: Host device bond0", then click "Finish"
* Close the virtual machine window

Next, configure the vSRX VM to use the SR-IOV Network Functions we created above.  From the deploy_manual_vsrx-main/interface_config_files directory, run the following commands:
```
for x in interface_* ; do virsh attach-device vSRX $x --config; done
```


This should be done on both host systems to configure the networks correctly for both vSRX deployments.  Complete this section before moving on to configuring each vSRX to be part of the cluster

### Configuring cluster mode on the vSRX

Once the Virtual Functions have been assigned, power on the vSRX.  Once booted, login with the root user and no password.  To get into the Juniper CLI, type cli and hit enter.

* Once in the Juniper CLI, configure the root password
```
configure
set system root-authentication plain-text-password
commit
exit
```

* Configure the system to be in cluster mode
On the first node:
```
set chassis cluster cluster-id 1 node 0 reboot
````
On the second node:
```
set chassis cluster cluster-id 1 node 1 reboot
````
Each node will then reboot, when they come back up, login as root, then enter the Juniper CLI by typing cli and hitting enter.

* Configure the fabric interfaces on each node, the reth count, and the cluster redundancy group
```
configure
set interfaces fab0 fabric-options member-interfaces ge-0/0/0
set interfaces fab0 fabric-options member-interfaces ge-0/0/9
set interfaces fab1 fabric-options member-interfaces ge-7/0/0
set interfaces fab1 fabric-options member-interfaces ge-7/0/9
set chassis cluster reth-count 4
set chassis cluster redundancy-group 0 node 0 priority 100
set chassis cluster redundancy-group 0 node 1 priority 1
set chassis cluster redundancy-group 1 node 0 priority 100
set chassis cluster redundancy-group 1 node 1 priority 1

commit
```




