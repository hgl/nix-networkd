{
  lib,
  nixosRouterLib,
  config,
  ...
}:
let
  lib' = nixosRouterLib;
  concatMapBridgeAttrs = config.router.concatMapInterfaceAttrs ({ type, ... }: type == "bridge");
in
{
  config = lib.mkIf config.router.enable {
    systemd.network = {
      netdevs = concatMapBridgeAttrs (interface: {
        "${toString interface.priority}-${interface.name}" = {
          netdevConfig = {
            Name = interface.name;
            Kind = "bridge";
            MACAddress = "none";
          };
        };
      });
      links = concatMapBridgeAttrs (interface: {
        "${toString interface.priority}-${interface.name}" = {
          matchConfig = {
            OriginalName = interface.name;
          };
          linkConfig = {
            MACAddressPolicy = "none";
          };
        };
      });
      networks = concatMapBridgeAttrs (
        interface:
        {
          "${toString interface.priority}-${interface.name}" = {
            matchConfig = {
              Name = interface.name;
            };
            networkConfig = {
              ConfigureWithoutCarrier = true;
              IPv6AcceptRA = false;
              IPv6SendRA = false;
              DHCPPrefixDelegation = true;
              MulticastDNS = !interface.quarantine.enable;
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
            linkConfig = {
              RequiredForOnline = "no-carrier";
            };
            dhcpPrefixDelegationConfig = {
              SubnetId = interface.subnetId;
              Token = "static:::1";
            };
          };
        }
        // lib'.mapListToAttrs (
          port:
          lib.nameValuePair "${toString config.router.interfacePortPriority}-${port}" {
            matchConfig = {
              Name = port;
            };
            networkConfig = {
              Bridge = interface.name;
            };
          }
        ) interface.ports
      );
    };
  };
}
