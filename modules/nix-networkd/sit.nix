{
  lib,
  config,
  ...
}:
let
  sitInterfaces = lib.filterAttrs (_: interface: interface.type == "sit") config.networkd.interfaces;
in
{
  systemd.network = {
    netdevs = lib.mapAttrs' (
      _: interface:
      lib.nameValuePair "${toString interface.priority}-${interface.name}" {
        netdevConfig = {
          Name = interface.name;
          Kind = "sit";
          MTUBytes = interface.mtu;
        };
        tunnelConfig = {
          Local = interface.local;
          Remote = interface.remote;
          Independent = true;
          TTL = interface.ttl;
        };
      }
    ) sitInterfaces;
    networks = lib.mapAttrs' (
      _: interface:
      lib.nameValuePair "${toString interface.priority}-${interface.name}" {
        matchConfig = {
          Name = interface.name;
        };
        networkConfig = {
          Address = interface.addresses;
          Gateway = lib.toList interface.gateway;
        };
      }
    ) sitInterfaces;
  };
  # Not let the sit kernal module create the sit0 fallback interface
  # https://github.com/systemd/systemd/issues/37942#issuecomment-3002423859
  boot.kernel.sysctl = lib.mkIf (sitInterfaces != { }) {
    "net.core.fb_tunnels_only_for_init_net" = 2;
  };
}
