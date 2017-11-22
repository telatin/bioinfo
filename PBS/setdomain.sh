#!/bin/bash

SN=$1
if [ x$SN == 'x' ];
then
	exit;
	echo Setting to default;
	SN='SERVER.NAME';
fi
echo $SN > /etc/torque/server_name
echo $SN > /var/spool/torque/server_priv/acl_svr/acl_hosts
echo root@$SN > /var/spool/torque/server_priv/acl_svr/operators
echo root@$SN > /var/spool/torque/server_priv/acl_svr/managers
echo "$SN np=4" > /var/spool/torque/server_priv/nodes
echo $SN > /var/spool/torque/mom_priv/config

echo "CHECK /etc/hosts for $1"
