{
  networkd-ipmon,
}:
{
  lib,
  config,
  ...
}:
let
  lib' = import ../../lib {
    inherit lib lib';
  };
in
{
  imports = [
    networkd-ipmon.nixosModules.networkd-ipmon
    ./options.nix
    ./dnsmasq.nix
    ./resolved.nix
    ./adguardhome.nix
    ./bridge.nix
    ./vlan.nix
    ./xfrm.nix
    ./wan-dhcp.nix
    ./nft.nix
    ./ddns.nix
  ];
  config = lib.mkIf config.router.enable {
    _module.args.nixosRouterLib = lib';
    boot.kernel.sysctl = {
      "net.ipv4.conf.all.forwarding" = true;
      "net.ipv6.conf.all.forwarding" = true;
    };
    networking = {
      useDHCP = false;
      firewall.enable = false;
      nftables.enable = true;
    };
    systemd.network.enable = true;
  };
}
