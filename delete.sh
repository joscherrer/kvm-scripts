#!/bin/sh

source ./utils.sh
_domain=$1; c=0; _timeout=60

[ "$(virsh_vm_exists $_domain)" ] || exit 1
[ $(virsh_is_vm_running "$_domain") ] && virsh shutdown "$_domain"

while
    virsh_is_vm_running "$_domain"
do
    sleep 1; ((c++))
    [ "$c" -gt $_timeout ] && exit 1
done

virsh undefine \
    --nvram \
    --domain $_domain \
    --storage /var/lib/libvirt/images/$_domain.qcow2

virsh_delete_dhcp_host_by_domain "$_domain" "default"

