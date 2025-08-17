{
  lib,
  config,
  ...
}:
let
  xfrmInterfaces = lib.filterAttrs (_: interface: interface.type == "xfrm") config.router.interfaces;
in
{
  config = lib.mkIf config.router.enable {
    systemd.network = {
      netdevs = lib.mapAttrs' (
        _: interface:
        lib.nameValuePair "${toString interface.priority}-${interface.name}" {
          netdevConfig = {
            Name = interface.name;
            Kind = "xfrm";
          };
          xfrmConfig = {
            InterfaceId = interface.xfrmId;
          };
        }
      ) xfrmInterfaces;
      networks =
        {
          "${toString config.router.interfacePortPriority}-lo" = {
            matchConfig = {
              Name = "lo";
            };
            networkConfig = {
              Xfrm = lib.mapAttrsToList (_: interface: interface.name) xfrmInterfaces;
            };
          };
        }
        // lib.mapAttrs' (
          _: interface:
          lib.nameValuePair "${toString interface.priority}-${interface.name}" {
            matchConfig = {
              Name = interface.name;
            };
            networkConfig = {
              IPv6AcceptRA = false;
              IPv6SendRA = false;
            };
            addresses = [
              {
                Address = interface.ipv6 {
                  interfaceId = 1;
                  prefixLength = 64;
                };
                DuplicateAddressDetection = "none";
              }
              {
                Address = interface.ipv4 {
                  hostId = 1;
                  prefixLength = 24;
                };
                DuplicateAddressDetection = "none";
              }
            ];
          }
        ) xfrmInterfaces;
    };
  };
}
