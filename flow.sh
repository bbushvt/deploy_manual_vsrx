ethtool -s eno1 autoneg off
sleep 2
ethtool -A eno1 rx off tx off
sleep 2
ethtool -G eno1 rx 4096 tx 4096
sleep 2
ethtool -s eno2 autoneg off
sleep 2
ethtool -A eno2 rx off tx off
sleep 2
ethtool -G eno2 rx 4096 tx 4096
sleep 2
ethtool -s eno3 autoneg off
sleep 2
ethtool -A eno3 rx off tx off
sleep 2
ethtool -G eno3 rx 4096 tx 4096
sleep 2
ethtool -s eno4 autoneg off
sleep 2
ethtool -A eno4 rx off tx off
sleep 2
ethtool -G eno4 rx 4096 tx 4096
sleep 2
