# NixOS Router

NixOS Router offers a set of opinionated options tailored for routers, built on systemd-networkd and nftables, with inspiration from [OpenWrt](https://openwrt.org).

Its features include:

1. Create a Bridge, VLAN or XFRM interface.
1. Create a WAN interface using either DHCP or PPPOE, with IPv6 support.
1. (Optionally) Update DDNS on WAN IP changes.
1. Create interface-scoped firewall rules.
1. Use Dnsmasq as the DNS resolver, DHCPv4 server and also for IPv6 Neighbor Discovery.
1. Use systemd-resolved for Multicast DNS.
1. (Optionally) use AdGuard Home for ad blocking.

For a real-world example, see how it's used in [my Nix configs](https://github.com/hgl/configs) (under `nodes/routers`).

## Options

[NixOS Router option code](./modules/nixos-router/options.nix) is documented and should be fairly readable.

## TODO

- Better DDNS support
- When `networking.nameservers` is empty, use DNS from DHCP for WAN
- Multi-WAN support
