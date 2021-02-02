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
echo "options kvm-intel nested=1 enable_apicv=n" >> /etc/modprobe.d/kvm.conf
```

The following settings will enable Virtual Functions for the network cards.  First, modify /etc/default/grub adding "intel_iommu=on iommu=pt" to the GRUB_CMDLINE_LINUX line

```
before:
GRUB_CMDLINE_LINUX="crashkernel=auto resume=/dev/mapper/cl-swap rd.lvm.lv=cl/root rd.lvm.lv=cl/swap rhgb quiet"
after:
GRUB_CMDLINE_LINUX="crashkernel=auto resume=/dev/mapper/cl-swap rd.lvm.lv=cl/root rd.lvm.lv=cl/swap rhgb quiet intel_iommu=on iommu=pt"

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
echo "ACTION=="add", SUBSYSTEM=="net", ENV{ID_NET_DRIVER}=="i40e", ATTR{device/sriov_numvfs}="8" >> /etc/udev/rules.d/virtual-functions.rules"
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

At this point you should be able to reach the internet and resolve DNS names.  Next you should install git and clone this repository to your gateway appliance.

### 