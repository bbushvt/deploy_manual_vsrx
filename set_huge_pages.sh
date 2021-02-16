#!/bin/bash
page_file=/sys/devices/system/node/node1/hugepages/hugepages-1048576kB/nr_hugepages
echo 'content of the page file:'
cat $page_file
echo 'set huge pages to 4 on numa node 1'
echo 4 > $page_file
echo 'content of the page file now:'
cat $page_file
