import sys
import json

final_leases = []

with open('/var/lib/libvirt/dnsmasq/virbr0.status') as leases_file:
    _leases = json.load(leases_file)
#    print(_leases)
    for l in _leases:
        if 'hostname' in l:
            if l['hostname'] == sys.argv[1]:
               _leases.remove(l)

    final_leases = _leases

with open('/var/lib/libvirt/dnsmasq/virbr0.status', 'w') as leases_file2:
    json.dump(final_leases, leases_file2)
