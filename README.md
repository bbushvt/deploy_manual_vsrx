# Deploying the vSRX in IBM Cloud Manually
This is a process that can be followed to manually deploy a vSRX appliance on IBM Cloud (commerical or government).  
__This process is not endorsed by IBM, use at your own risk__

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

```virt-install --name vSRX --ram 4096 --cpu Skylake-Server,+vmx, --vcpus=2 --arch=x86_64 --disk path=/var/lib/libvirt/images/junos-vsrx3-x86-64-20.4R1.12.qcow2,size=16,device=disk,bus=ide,format=qcow2 --os-type linux --os-variant rhel7.0 --import --network=bridge:private,model=virtio --network=bridge:private,model=virtio --network=bridge:private,model=virtio --network=bridge:private,model=virtio --network=bridge:public,model=virtio --network=bridge:private,model=virtio --network=bridge:public,model=virtio --noautoconsole```

This will create a virtual machine with 2 cores and 4GB RAM as well as power on the VM.

### Primary

|NIC|ge device | Interface|
----|----------|-----------
|1| |fxp0|
|2| |em0|
|3|ge-0/0/0|fab0|
|4|ge-0/0/1|reth0|
|5|ge-0/0/2|reth1|
|6|ge-0/0/3|reth2|
|7|ge-0/0/4|reth3|

### Secondary

|NIC|ge device | Interface|
----|----------|-----------
|1| |fxp0|
|2| |em0|
|3|ge-7/0/0|fab0|
|4|ge-7/0/1|reth0|
|5|ge-7/0/2|reth1|
|6|ge-7/0/3|reth2|
|7|ge-7/0/4|reth3|

### Configuring cluster mode on the vSRX

Once booted, login with the root user and no password.  To get into the Juniper CLI, type cli and hit enter.

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

* Connect to the primary node and configure the following.  Note: Change Gateway-Node0 and Gateway-Node1 to site specific identifiers
```
set groups node0 system host-name Gateway-Node0
set groups node1 system host-name Gateway-Node1
set apply-groups "${node}"
set interfaces fab0 fabric-options member-interfaces ge-0/0/0
set interfaces fab1 fabric-options member-interfaces ge-7/0/0
set chassis cluster reth-count 4
set chassis cluster redundancy-group 0 node 0 priority 100
set chassis cluster redundancy-group 0 node 1 priority 1
set chassis cluster redundancy-group 1 node 0 priority 100
set chassis cluster redundancy-group 1 node 1 priority 1
set chassis cluster redundancy-group 1 preempt
set chassis cluster redundancy-group 1 interface-monitor ge-0/0/2 weight 130
set chassis cluster redundancy-group 1 interface-monitor ge-7/0/2 weight 130
set chassis cluster heartbeat-interval 2000
set chassis cluster heartbeat-threshold 8
set interfaces ge-0/0/1 gigether-options redundant-parent reth0
set interfaces ge-0/0/2 gigether-options redundant-parent reth1
set interfaces ge-0/0/3 gigether-options redundant-parent reth2
set interfaces ge-0/0/4 gigether-options redundant-parent reth3
set interfaces ge-7/0/1 gigether-options redundant-parent reth0
set interfaces ge-7/0/2 gigether-options redundant-parent reth1
set interfaces ge-7/0/3 gigether-options redundant-parent reth2
set interfaces ge-7/0/4 gigether-options redundant-parent reth3
set interfaces lo0 unit 0 family inet address 127.0.0.1/32
set interfaces reth0 redundant-ether-options redundancy-group 1
set interfaces reth0 unit 0 description "SL PRIVATE VLAN INTERFACE"
set interfaces reth1 redundant-ether-options redundancy-group 1
set interfaces reth1 unit 0 description "SL PUBLIC VLAN INTERFACE"
set interfaces reth2 vlan-tagging
set interfaces reth2 redundant-ether-options redundancy-group 1
set interfaces reth3 vlan-tagging
set interfaces reth3 redundant-ether-options redundancy-group 1
```

* Configure the address book, replace the address for SL_PRIV_MGMT with the private address and SL_PUB_MGMT with the public address

```
set security address-book global address SL_PRIV_MGMT 100.107.253.5
set security address-book global address SL_PUB_MGMT 192.255.58.101
set security address-book global address SL1 10.0.0.0/8
set security address-book global address SL2 100.100.0.0/16
set security address-book global address SL3 161.26.0.0/16
set security address-book global address SL4 100.96.0.0/11
set security address-book global address-set SERVICE address SL1
set security address-book global address-set SERVICE address SL2
set security address-book global address-set SERVICE address SL3
set security address-book global address-set SERVICE address SL4
```

* Configure the reth0 and reth1 interfaces, replace the addresses with the correct ones for your deployment
```
set interfaces reth0 unit 0 family inet address 100.107.253.5/26
set interfaces reth1 unit 0 family inet address 192.255.58.101/29
```

* Configure the security zones for SL_PUBLIC and SL_PRIVATE
```
set security policies from-zone SL-PRIVATE to-zone SL-PRIVATE policy Allow_Management match source-address any
set security policies from-zone SL-PRIVATE to-zone SL-PRIVATE policy Allow_Management match destination-address SL_PRIV_MGMT
set security policies from-zone SL-PRIVATE to-zone SL-PRIVATE policy Allow_Management match destination-address SERVICE
set security policies from-zone SL-PRIVATE to-zone SL-PRIVATE policy Allow_Management match application any
set security policies from-zone SL-PRIVATE to-zone SL-PRIVATE policy Allow_Management then permit
set security policies from-zone SL-PUBLIC to-zone SL-PUBLIC policy Allow_Management match source-address any
set security policies from-zone SL-PUBLIC to-zone SL-PUBLIC policy Allow_Management match destination-address SL_PUB_MGMT
set security policies from-zone SL-PUBLIC to-zone SL-PUBLIC policy Allow_Management match application junos-ssh
set security policies from-zone SL-PUBLIC to-zone SL-PUBLIC policy Allow_Management match application junos-https
set security policies from-zone SL-PUBLIC to-zone SL-PUBLIC policy Allow_Management match application junos-http
set security policies from-zone SL-PUBLIC to-zone SL-PUBLIC policy Allow_Management match application junos-icmp-ping
set security policies from-zone SL-PUBLIC to-zone SL-PUBLIC policy Allow_Management then permit
set security zones security-zone SL-PRIVATE interfaces reth0.0 host-inbound-traffic system-services all
set security zones security-zone SL-PUBLIC interfaces reth1.0 host-inbound-traffic system-services all
```

* Set the static routes, again replacing the information below with your site specific information
```
set routing-options static route 0.0.0.0/0 next-hop 192.255.58.97
set routing-options static route 10.0.0.0/8 next-hop 100.107.253.1
set routing-options static route 100.100.0.0/16 next-hop 100.107.253.1
set routing-options static route 161.26.0.0/16 next-hop 100.107.253.1
set routing-options static route 100.96.0.0/11 next-hop 100.107.253.1
```

* Create an admin user
```
set system login user admin authentication plain-text-password
set system login user admin class super-user
```

* Enable jweb (note, if you want to disable public interface access, don't enable reth1.0)
```
set system services web-management https port 8443
set system services web-management https interface reth1.0
set system services web-management https interface reth0.0
```