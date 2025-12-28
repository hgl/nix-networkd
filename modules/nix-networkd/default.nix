{ lib, ... }:
let
  lib' = import ../../lib {
    inherit lib lib';
  };
in
{
  imports = [
    ./options.nix
    ./bridge.nix
    ./vlan.nix
    ./xfrm.nix
    ./sit.nix
    ./wan-dhcp.nix
    ./wan-pppoe.nix
    ./nftables.nix
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
