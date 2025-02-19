#!/bin/bash

# Ask for user input
read -p "Enter the network interface (default: eth0): " INTERFACE
INTERFACE=${INTERFACE:-eth0}

read -p "Enter the port to limit: " PORT
read -p "Enter the speed limit (e.g., 20mbit): " LIMIT

echo "Applying bandwidth limit of $LIMIT on port $PORT for interface $INTERFACE..."

echo "Resetting iptables rules..."
iptables -F
iptables -t nat -F
iptables -t mangle -F
iptables -X
iptables -t nat -X
iptables -t mangle -X
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT

echo "Resetting tc configurations..."
tc qdisc del dev $INTERFACE root 2>/dev/null
tc qdisc del dev $INTERFACE ingress 2>/dev/null

echo "Marking packets for port $PORT with iptables..."
iptables -t mangle -A OUTPUT -p tcp --sport $PORT -j MARK --set-mark 1
iptables -t mangle -A PREROUTING -p tcp --dport $PORT -j MARK --set-mark 1

echo "Applying tc configurations for bandwidth limiting..."
tc qdisc add dev $INTERFACE root handle 1: htb default 10
tc class add dev $INTERFACE parent 1: classid 1:1 htb rate $LIMIT ceil $LIMIT
tc filter add dev $INTERFACE protocol ip parent 1:0 prio 1 handle 1 fw flowid 1:1

tc qdisc add dev $INTERFACE handle ffff: ingress
tc filter add dev $INTERFACE parent ffff: protocol ip prio 1 u32 match ip sport $PORT 0xffff police rate $LIMIT burst 20k drop
tc filter add dev $INTERFACE parent ffff: protocol ip prio 1 u32 match ip dport $PORT 0xffff police rate $LIMIT burst 20k drop

echo "Bandwidth limits applied successfully!"
