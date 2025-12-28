# nix-networkd

nix-networkd offers a set of options to quickly configure network interfaces with systemd-networkd and nftables, with inspiration from [OpenWrt](https://openwrt.org).

Its features include:

1. Create a Bridge, VLAN or XFRM interface.
1. Create a WAN interface using either DHCP or PPPOE, with IPv6 support.
1. Create interface-scoped firewall rules.

For a real-world example, see how it's used in [my Nix configs](https://github.com/hgl/configs).

## TODO

- Multi-WAN support
