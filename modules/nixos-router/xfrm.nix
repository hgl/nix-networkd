{
  lib,
  config,
  ...
}:
let
  concatMapXfrmAttrs = config.router.concatMapInterfaceAttrs ({ type, ... }: type == "xfrm");
  concatMapXfrms = config.router.concatMapInterfaces ({ type, ... }: type == "xfrm");
in

{
  config = lib.mkIf config.router.enable {
    systemd.network = {
      netdevs = concatMapXfrmAttrs (interface: {
        "${toString interface.priority}-${interface.name}" = {
          netdevConfig = {
            Name = interface.name;
            Kind = "xfrm";
          };
          xfrmConfig = {
            InterfaceId = interface.xfrmId;
          };
        };
      });
      networks =
        {
          "${toString config.router.interfacePortPriority}-lo" = {
            matchConfig = {
              Name = "lo";
            };
            networkConfig = {
              Xfrm = concatMapXfrms (interface: [ interface.name ]);
            };
          };
        }
        // concatMapXfrmAttrs (interface: {
          "${toString interface.priority}-${interface.name}" = {
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
          };
        });
    };
  };
}
