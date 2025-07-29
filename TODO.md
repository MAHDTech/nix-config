# TODO

A to do list for tracking remaining issues with the incus cluster configuration.

- [x] Fix the destroy script to cleanly reset the database.
- [x] Fix the error because the cleanup script isnt cleaning the networks up correctly.
- [ ] Determine the health check commands that need to be run on each hypervisor.
- [ ] Determine the correct way to configure OVN for cluster mode.
- [ ] Ensure the OVN remote DB is synchronising correctly across all hypervisors.
- [ ] Verify health of OVS services on all hypervisors
  - [ ] HYPERVISOR-1
  - [ ] HYPERVISOR-2
  - [ ] HYPERVISOR-3
  - [ ] HYPERVISOR-4
- [ ] Verify health of OVS services on all hypervisors
  - [ ] HYPERVISOR-1
  - [ ] HYPERVISOR-2
  - [ ] HYPERVISOR-3
  - [ ] HYPERVISOR-4
- [ ] Verify health of Incus and Incus Preseed services on all hypervisors
  - [ ] HYPERVISOR-1
  - [ ] HYPERVISOR-2
  - [ ] HYPERVISOR-3
  - [ ] HYPERVISOR-4
- [ ] Review incusbr0 transparent bridge configuration and bond0 integration
- [ ] Review default instance profile using incusbr0 and resolve profile validation errors
- [ ] Review incusbr1 routed bridge configuration and bond0 integration
- [ ] Create test container with both interfaces for connectivity tests
- [ ] Verify DHCP pass-through on incusbr0; debug as needed
- [ ] Verify instance profiles using incusbr1 for DHCP and routing
- [ ] Document findings and update configuration accordingly
- [ ] Investigate missing /run/ovn sockets and fix RuntimeDirectory or permissions
- [ ] Add tmpfiles rule: symlink /var/run/ovn -> /run/ovn
- [ ] Confirm ovn-sbctl connects and chassis registers after fix
- [ ] Decide how to connect incusbr0 to bond0 (OVS port vs routing) and implement test
- [ ] Document static routes on Unifi router for 10.10.201.0/24 and 10.10.202.0/24
