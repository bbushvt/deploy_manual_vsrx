# Update the server before applying the STIG configuration
```
yum repolist
yum update
```
shut down vSRX (request system power-off)
Then reboot the host
```reboot```

# Install the SCAP security guide
```yum install scap-security-guide*```

# Run the remediation
```
cd /usr/share/xml/scap/ssg/content/
oscap xccdf eval --profile xccdf_org.ssgproject.content_profile_cui --remediate /usr/share/xml/scap/ssg/content/ssg-rhel8-ds.xml
```

# Figure out which yum update removed 
* use yum history to get the list of yum commands that were run recently 
```yum history```

* Find the one that removed gssproxy
```
[root@ibmcnpivnss004 content]# yum history
Updating Subscription Management repositories.
ID     | Command line                                                                          | Date and time    | Action(s)      | Altered
--------------------------------------------------------------------------------------------------------------------------------------------
    13 | install -y usbguard                                                                   | 2021-02-24 16:09 | Install        |    4
    12 | install -y fapolicyd                                                                  | 2021-02-24 16:08 | Install        |    3
    11 | install -y aide                                                                       | 2021-02-24 16:05 | Install        |    1
    10 | remove -y tuned                                                                       | 2021-02-24 16:05 | Removed        |    6 EE
     9 | remove -y pigz                                                                        | 2021-02-24 16:05 | Removed        |    1
     8 | remove -y iprutils                                                                    | 2021-02-24 16:05 | Removed        |    1
     7 | remove -y gssproxy                                                                    | 2021-02-24 16:05 | Removed        |   33 EE    <- This one
     6 | install -y dnf-automatic                                                              | 2021-02-24 16:05 | Install        |    1
     5 | install -y tmux                                                                       | 2021-02-24 16:05 | Install        |    1
     4 | install scap-security-guide*                                                          | 2021-02-24 16:01 | Install        |    4
     3 | update                                                                                | 2021-02-24 15:51 | I, U           |  107
     2 | update                                                                                | 2021-02-10 15:46 | I, U           |   87
     1 |                                                                                       | 2021-02-02 15:54 | Install        | 1402 EE
[root@ibmcnpivnss004 content]#
```

* Use the 'yum history undo' command to undo the gssproxy removal
```
yum history undo 7
```

# Stop the vSRX appliance
# Reboot the server



