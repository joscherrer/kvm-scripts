#!/bin/bash

mkdir -p .logs
touch .logs/${_new_name}.log
exec > >(tee -a .logs/${_new_name}.log) 2>&1

_base=archlinux-base
_new_name=$1
source ./utils.sh


virt-clone \
    --original ${_base} \
    --name "${_new_name}" \
    -f "/var/lib/libvirt/images/${_new_name}.qcow2" || exit 1

sudo virt-sysprep -d "${_new_name}" \
    --operations bash-history,dhcp-client-state,machine-id,lvm-uuids,logfiles,ssh-hostkeys,customize || exit 1

virsh_start_vm_sync "${_new_name}"

until
    _ip=$(virsh_get_ip "${_new_name}") > /dev/null 2>&1
do
    echo "Waiting for domain IP"
    sleep 2
done

until
    nc -z "${_ip}" 22 > /dev/null 2>&1
do
    echo "Waiting for ssh service"
    sleep 2
done

ssh-keyscan "${_ip}" >> ~/.ssh/known_hosts

ssh "${_ip}" "sudo hostnamectl set-hostname '${_new_name}.kvm.bbrain.io'"
ssh "${_ip}" "sudo systemctl restart systemd-{networkd,resolved}"

c=0
until
    ping -c 1 "${_new_name}.kvm.bbrain.io" > /dev/null 2>&1
do
    sleep 1; ((c++))
    [ $c -gt 5 ] && break
    echo "Waiting for fqdn"
done

ssh-keyscan "${_new_name}.kvm.bbrain.io" >> ~/.ssh/known_hosts

virsh_add_dhcp_host "${_new_name}" default
