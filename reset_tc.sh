#!/usr/bin/env bash
#
# reset_tc.sh
# Clears all traffic shaper rules on a specified interface.

IFACE="$1"

if [[ -z "$IFACE" ]]; then
  echo "Usage: $0 <interface>"
  echo "Example: $0 eth0"
  exit 1
fi

echo "Removing all existing tc configs on interface: $IFACE..."
tc qdisc del dev "$IFACE" root 2>/dev/null
tc qdisc del dev "$IFACE" ingress 2>/dev/null

# If you used an IFB interface for inbound shaping, remove that as well (example: ifb0)
# ip link set ifb0 down 2>/dev/null
# ip link del ifb0 2>/dev/null

echo "All tc qdiscs removed from $IFACE."
tc -s qdisc show dev "$IFACE"
