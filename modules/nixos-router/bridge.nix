{
  lib,
  nixosRouterLib,
  config,
  ...
}:
let
  lib' = nixosRouterLib;
  bridgeInterfaces = lib.filterAttrs (
    _: interface: interface.type == "bridge"
  ) config.router.interfaces;
in
{
  config = {
    systemd.network = {
      netdevs = lib.mapAttrs' (
        _: interface:
        lib.nameValuePair "${toString interface.priority}-${interface.name}" {
          netdevConfig = {
            Name = interface.name;
            Kind = "bridge";
            MACAddress = "none";
          };
        }
      ) bridgeInterfaces;
      links = lib.mapAttrs' (
        _: interface:
        lib.nameValuePair "${toString interface.priority}-${interface.name}" {
          matchConfig = {
            OriginalName = interface.name;
          };
          linkConfig = {
            MACAddressPolicy = "none";
          };
        }
      ) bridgeInterfaces;
      networks = lib.concatMapAttrs (
        _: interface:
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
              SubnetId = lib'.decToHex interface.subnetId;
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
      ) bridgeInterfaces;
    };
  };
}
