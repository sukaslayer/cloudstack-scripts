#!/bin/sh
SERVICEOFFERINGID="2b45be75-0ec8-4683-91a0-d95414da310d"
TEMPLATEID="94013c8f-b615-467f-8df2-635ac4c5efb5"
ZONEID="4a5bc8e5-bab9-4f92-9249-d57ef8a0f9f8"
NETWORKOFFERINGID="eb3a2a70-25a1-4009-928c-ff3ce06f82b4"
DISKOFFERINGID="9f99ac08-fc04-4975-b952-990679b4cf6e"
ACCOUNTNAME=$1
VMNAME=${1}"-1"
alias cloudmonkey="cloudmonkey -c /root/.cloudmonkey/.config"
DOMAINID=`cloudmonkey  list domains name="$ACCOUNTNAME"|grep -A1 domain:|grep -oE "[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}"`
echo domainid: $DOMAINID
ACCOUNTID=`cloudmonkey list accounts domainid="$DOMAINID"|grep -A1 account:|grep -oE "[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}"`
echo accountid: $ACCOUNTID
NETNAME=${1}"net"
echo network name $NETNAME
NETWORKID=`cloudmonkey create network displaytext=$NETNAME name=$NETNAME zoneid=$ZONEID \
  networkofferingid=$NETWORKOFFERINGID account=$1 domainid=$DOMAINID networkdomain=colobridge|grep -A1 network:|grep -oE "[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}"`
echo networkid: $NETWORKID
echo "quering ipaddress"
cloudmonkey associate ipaddress \
  account=$ACCOUNTNAME \
  domainid=$DOMAINID \
  networkid=$NETWORKID \
  zoneid=$ZONEID > ipaddress.tmp
IPADDRESSID=`cat ipaddress.tmp |grep -A1 ipaddress:|grep -oE "[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}"`
IPADDRESS=`cat ipaddress.tmp |sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g"|grep -E "ipaddress(.*)="|awk '{print $3}'`
echo "ipaddress:" $IPADDRESS
echo "creating egress rule"
cloudmonkey create egressfirewallrule networkid=$NETWORKID cidrlist=0.0.0.0/0 protocol=all > /dev/null
echo "creating ingress rule for tcp"
cloudmonkey create firewallrule networkid=$NETWORKID ipaddressid=$IPADDRESSID \
  cidrlist=0.0.0.0/0 protocol=tcp startport=1 endport=65535 > /dev/null
echo "creating ingress rule for udp"
cloudmonkey create firewallrule  networkid=$NETWORKID ipaddressid=$IPADDRESSID \
  cidrlist=0.0.0.0/0 protocol=udp startport=1 endport=65535 > /dev/null
echo "creating ingress rule for icmp"
cloudmonkey api createFirewallRule networkid=$NETWORKID ipaddressid=$IPADDRESSID \
   protocol=ICMP cidrlist=0.0.0.0/0  icmptype=-1 icmpcode=-1 > /dev/null
echo "creating vm $VMNAME"
cloudmonkey api deployVirtualMachine  \
  serviceofferingid=$SERVICEOFFERINGID \
  zoneid=$ZONEID \
  templateid=$TEMPLATEID \
  networkIds=$NETWORKID \
  account=$ACCOUNTNAME \
  domainid=$DOMAINID \
  name=$VMNAME \
  displayname=$VMNAME \
  diskofferingid=$DISKOFFERINGID > deployVirtualMachine.tmp
VMID=`cat deployVirtualMachine.tmp|grep -A1 virtualmachine:|grep -oE "[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}"`
PASSWORD=`cat deployVirtualMachine.tmp|sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g"|head -n 2|head -n 1|awk '{print $3}'`
echo "creating firewall rules"
cloudmonkey api createPortForwardingRule  ipaddressid=$IPADDRESSID   \
  networkid=$NETWORKID virtualmachineid=$VMID \
  openfirewall=false privateport=1 publicport=1 privateendport=65535 publicendport=65535 protocol=tcp > /dev/null
cloudmonkey api createPortForwardingRule  ipaddressid=$IPADDRESSID   \
  networkid=$NETWORKID virtualmachineid=$VMID \
  openfirewall=false privateport=1 publicport=1 privateendport=65535 publicendport=65535 protocol=udp > /dev/null
echo "-------------------"
echo VM created.
echo "ip: $IPADRESS"
echo "root / $PASSWORD"
exit 0
