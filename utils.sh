#!/bin/sh

# get_ip <mac>
get_ip()
{
    [ -z ${1+x} ] && return 2
    local _mac=$1
    local _ip_line=$(arp -an | grep "${_mac}")
    echo "$_ip_line" | awk '{print $2}' | tr -d '()'
}

# virsh_vm_exists <domain>
virsh_vm_exists()
{
    virsh list --all | awk '{print $2}' | grep $1
}

# virsh_get_ip <domain>
virsh_get_ip()
{
    [ -z ${1+x} ] && return 2
    local _domain=$1
    local _mac=$(virsh_get_mac "$_domain")
    local _ip=$(get_ip "$_mac")
    [ -z "$_ip" ] && return 1
    echo "$_ip"
}

# virsh_get_mac <domain>
virsh_get_mac()
{
    [ -z ${1+x} ] && return 2
    local _domain=$1
    virsh dumpxml "${_domain}" | xpath -q -e 'string(//mac/@address)'
}

# virsh_is_vm_running <domain>
virsh_is_vm_running()
{
    [ -z ${1+x} ] && return 2
    local _state=$(virsh domstate $1)
    [ "$_state" = "shut off" ] && return 1
    [ "$_state" = "running" ] && return 0
}

# virsh_start_vm_sync <domain>
# Start a vm and wait until completion
# returns 0 if started successfully
# returns 1 if vm didn't start before timeout
virsh_start_vm_sync()
{
    [ -z ${1+x} ] && return 2
    local _domain=$1
    local _timeout=60
    local c=0
    virsh start "$_domain"
    until
        virsh_is_vm_running $_domain
    do
        sleep 1; ((c++))
        [ $c -gt $_timeout ] && return 1
    done
    return 0
}

# virsh_shutdown_vm_sync <domain>
# Stop a vm and wait until completion
# returns 0 if stopped successfully
# returns 1 if vm didn' t stop before timeout
# returns 2 if argument not provided
virsh_shutdown_vm_sync()
{
    [ -z ${1+x} ] && return 2
    local _domain=$1
    local _timeout=60
    local c=0
    virsh shutdown "$_domain"
    while 
        virsh_is_vm_running $_domain
    do
        sleep 1; ((c++))
        [ $c -gt $_timeout ] && return 1
    done
    return 0
}

# virsh_delete_vm_sync <domain>
# Delete the specied vm. It first shuts it down.
virsh_delete_vm()
{
    [ -z ${1+x} ] && return 2
    local _domain=$1
    virsh_shutdown_vm_sync "$_domain"
    virsh undefine \
        --nvram \
        --domain "$_domain" \
        --storage /var/lib/libvirt/images/$_domain.qcow2
}

# virsh_add_dhcp_host <domain> <network>
# Sets a new dhcp host in specified network
# returns 0 if edited successfully
# returns 1 if an error has occured
virsh_add_dhcp_host()
{
    local _domain=$1
    local _network=$2
    _mac=$(virsh_get_mac $_domain)
    _ip=$(get_ip $_mac)
    virsh net-update "$_network" add ip-dhcp-host \
        "<host mac='${_mac}' name='${_domain}' ip='${_ip}' />" \
        --live --config
}

# virsh_delete_dhcp_host <domain> <network>
# Deletes a dhcp host in specified network
# returns 0 if deleted successfully
# returns 1 if an error has occured
virsh_delete_dhcp_host()
{
    local _domain=$1
    local _network=$2
    _mac=$(virsh_get_mac $_domain)
    _ip=$(get_ip $_mac)
    virsh net-update "$_network" delete ip-dhcp-host \
        "<host mac='${_mac}' name='${_domain}' ip='${_ip}' />" \
        --live --config
}

# virsh_delete_dhcp_host_by_domain <domain> <network>
virsh_delete_dhcp_host_by_domain()
{
    local _domain=$1
    local _network=$2
    _ip_dhcp_host=$(virsh_get_dhcp_host_by_domain "$_domain" "$_network")
    virsh net-update "$_network" \
        delete ip-dhcp-host "$_ip_dhcp_host" --live --config
}

# virsh_get_dhcp_host_by_domain <domain> <network>
virsh_get_dhcp_host_by_domain()
{
    local _domain=$1
    local _network=$2
    virsh net-dumpxml $_network | \
        xpath -q -e '//host' | \
        grep "name=\"$_domain\""
}
