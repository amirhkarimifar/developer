#!/usr/bin/env bash
#
# guarantee_minimum_port.sh
# Provides a strict minimum bandwidth guarantee for a specified port,
# while capping total interface capacity.

# Usage:
#   sudo ./guarantee_minimum_port.sh <interface> <port> <guaranteed_mbps> <total_mbps>
# Example:
#   sudo ./guarantee_minimum_port.sh eth0 8080 5 10

IFACE="$1"
PORT="$2"
GUAR_Mbps="$3"
TOTAL_Mbps="$4"

if [[ -z "$IFACE" || -z "$PORT" || -z "$GUAR_Mbps" || -z "$TOTAL_Mbps" ]]; then
  echo "Usage: $0 <interface> <port> <guaranteed_mbps> <total_mbps>"
  echo "Example: $0 eth0 8080 5 10"
  exit 1
fi

# Convert numeric values (e.g. 5) into strings recognized by tc (e.g. 5mbit)
GUAR_RATE="${GUAR_Mbps}mbit"
TOTAL_RATE="${TOTAL_Mbps}mbit"

# We'll give the default class a small base (could change as needed)
DEFAULT_RATE="1mbit"
DEFAULT_CEIL="$TOTAL_RATE"

echo "Interface       = $IFACE"
echo "Port            = $PORT"
echo "Guaranteed Rate = $GUAR_RATE"
echo "Total Capacity  = $TOTAL_RATE"
echo "------------------------------------------"

# 1. Cleanup existing qdisc rules on this interface
tc qdisc del dev "$IFACE" root 2>/dev/null

# 2. Create the root qdisc with total capacity
tc qdisc add dev "$IFACE" root handle 1: htb default 20
tc class add dev "$IFACE" parent 1: classid 1:1 htb rate "$TOTAL_RATE" ceil "$TOTAL_RATE"

# 3. Class for guaranteed traffic on the specified port
#    Guaranteed at least GUAR_RATE, can go up to TOTAL_RATE
tc class add dev "$IFACE" parent 1:1 classid 1:10 htb rate "$GUAR_RATE" ceil "$TOTAL_RATE"
tc qdisc add dev "$IFACE" parent 1:10 handle 10: sfq perturb 10

# 4. Default class for everything else
tc class add dev "$IFACE" parent 1:1 classid 1:20 htb rate "$DEFAULT_RATE" ceil "$DEFAULT_CEIL"
tc qdisc add dev "$IFACE" parent 1:20 handle 20: sfq perturb 10

# 5. Attach a port-based filter to direct traffic into the guaranteed class
tc filter add dev "$IFACE" protocol ip parent 1:0 prio 1 u32 \
    match ip protocol 6 0xff \
    match ip dport "$PORT" 0xffff \
    flowid 1:10

echo "Port $PORT is guaranteed $GUAR_RATE on $IFACE (up to $TOTAL_RATE)."
echo "Run 'tc -s qdisc show dev $IFACE' to see stats."
