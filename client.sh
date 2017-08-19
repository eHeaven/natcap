#!/bin/bash

echo 1 > /proc/sys/net/ipv4/ip_forward

iptables -F
iptables -F -t nat
iptables -P INPUT ACCEPT
iptables -P FORWARD DROP

iptables -I FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 
iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

iptables -A FORWARD -m mark --mark 0x99 -j ACCEPT
iptables -t nat -A POSTROUTING -m mark --mark 0x99 -j MASQUERADE

# forward for subnet as router
iptables -A FORWARD -s 192.168.0.0/16 -j ACCEPT
iptables -t nat -A POSTROUTING -s 192.168.0.0/16 -j MASQUERADE

ipset destroy cniplist
ipset destroy gfwlist
ipset destroy udproxylist
ipset restore -f cniplist.set
ipset create gfwlist iphash
ipset create udproxylist iphash
ipset add udproxylist 8.8.8.8

# load && run
# server is 47.88.231.224 for example
# server line format: server ip.ip.ip.ip:port-X
# X    ==> e,o
#          e=encryption o=non-encryption
# port ==> 65535,1-65535,0
#          65535=Random port, 1-65534=Specific port, 0=Original port
# .example line: server 47.88.231.224:65535-e
# .example line: server 47.88.231.224:22-e
# .example line: server 47.88.231.224:0-e
rmmod natcap >/dev/null 2>&1
( modprobe natcap mode=0 || insmod ./natcap.ko mode=0 ) && {
cat <<EOF >>/dev/natcap_ctl
clean
debug=3
disabled=0
encode_mode=TCP
server_persist_timeout=86400
server 47.88.231.224:65535-e
EOF
}
