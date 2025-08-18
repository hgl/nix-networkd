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
    ./bridge.nix
    ./vlan.nix
    ./xfrm.nix
    ./sit.nix
    ./wan-dhcp.nix
    ./wan-pppoe.nix
    ./nftables.nix
    ./ddns.nix
  ];
  config = {
    _module.args.nixNetworkdLib = lib';
    networking = {
      useDHCP = false;
      firewall.enable = false;
      nftables.enable = true;
    };
    systemd.network.enable = true;
  };
}
