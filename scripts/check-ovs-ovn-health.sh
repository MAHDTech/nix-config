#!/usr/bin/env bash

echo "=================================================="
echo "Open vSwitch (OVS) Health Check"
echo "=================================================="

echo -e "\n1. OVS Service Status:"
systemctl status ovs-vswitchd.service --no-pager -l

echo -e "\n2. OVS Database Status:"
sudo ovs-vsctl --db=unix:/run/openvswitch/db.sock show

echo -e "\n3. OVS Bridge Details:"
sudo ovs-vsctl --db=unix:/run/openvswitch/db.sock list bridge

echo -e "\n4. OVS Ports and Interfaces:"
sudo ovs-vsctl --db=unix:/run/openvswitch/db.sock list port
sudo ovs-vsctl --db=unix:/run/openvswitch/db.sock list interface

echo -e "\n5. OVS External IDs (for OVN integration):"
sudo ovs-vsctl --db=unix:/run/openvswitch/db.sock get open_vswitch . external_ids

echo -e "\n6. OVS Flow Tables:"
sudo ovs-ofctl dump-flows br-int
sudo ovs-ofctl dump-flows incusbr0 2>/dev/null || echo "incusbr0 not found in OVS"

echo -e "\n=================================================="
echo "Open Virtual Network (OVN) Health Check"
echo "=================================================="

echo -e "\n1. OVN Service Status:"
systemctl status ovn-nb-ovsdb.service ovn-sb-ovsdb.service ovn-northd.service ovn-controller.service --no-pager -l

echo -e "\n2. OVN Northbound Database:"
sudo ovn-nbctl show
sudo ovn-nbctl list nb_global

echo -e "\n3. OVN Southbound Database:"
sudo ovn-sbctl show
sudo ovn-sbctl list chassis

echo -e "\n4. OVN Logical Switches:"
sudo ovn-nbctl ls-list
sudo ovn-nbctl list logical_switch

echo -e "\n5. OVN Logical Switch Ports:"
sudo ovn-nbctl lsp-list incusbr0 2>/dev/null || echo "No logical switch ports found for incusbr0"

echo -e "\n6. OVN Physical Network Mappings:"
sudo ovn-sbctl list chassis | grep -A5 -B5 external_ids

echo -e "\n=================================================="
echo "Incus Network Health Check"
echo "=================================================="

echo -e "\n1. Incus Network Status:"
incus network list
incus network show incusbr0 --project default

echo -e "\n2. Incus Bridge Details in OVS:"
sudo ovs-vsctl --db=unix:/run/openvswitch/db.sock port-to-br incusbr0 2>/dev/null || echo "incusbr0 not found as OVS port"

echo -e "\n3. Network Interface Status:"
ip addr show bond0 2>/dev/null || echo "bond0 interface not found"
ip addr show incusbr0 2>/dev/null || echo "incusbr0 interface not found"

echo -e "\n4. Bridge Configuration (Linux bridge vs OVS):"
brctl show 2>/dev/null | grep incusbr0 || echo "incusbr0 not found in Linux bridges"

echo -e "\n=================================================="
echo "Network Connectivity Test"
echo "=================================================="

echo -e "\n1. Bond0 Configuration:"
ip link show bond0 2>/dev/null || echo "bond0 not found"
cat /proc/net/bonding/bond0 2>/dev/null || echo "bond0 bonding info not available"

echo -e "\n2. Routing Table:"
ip route show | grep 10.10.200

echo -e "\n3. ARP Table for 10.10.200.x network:"
arp -a | grep "10.10.200" || echo "No ARP entries for 10.10.200.x"

echo -e "\n=================================================="
echo "Systemd Service Logs (Recent)"
echo "=================================================="

echo -e "\n1. OVS Logs:"
journalctl -u openvswitch.service --since "10 minutes ago" --no-pager | tail -20

echo -e "\n2. OVN Controller Logs:"
journalctl -u ovn-controller.service --since "10 minutes ago" --no-pager | tail -20

echo -e "\n3. Incus Preseed Logs:"
journalctl -u incus-preseed.service --since "10 minutes ago" --no-pager | tail -20

echo -e "\n=================================================="
echo "Health Check Complete"
echo "=================================================="
