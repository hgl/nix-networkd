{
  lib,
  nixosRouterLib,
  config,
  ...
}:
let
  lib' = nixosRouterLib;
  concatMapVlanAttrs = config.router.concatMapInterfaceAttrs ({ type, ... }: type == "vlan");
in
{
  config = lib.mkIf config.router.enable {
    systemd.network = {
      netdevs = concatMapVlanAttrs (
        interface:
        {
          "${toString interface.priority}-${interface.name}" = {
            netdevConfig = {
              Name = interface.name;
              Kind = "bridge";
            };
          };
        }
        // lib'.mapListToAttrs (
          port:
          lib.nameValuePair "${toString config.router.interfacePortPriority}-${port}" {
            netdevConfig = {
              Name = "${port}.${toString interface.vlanId}";
              Kind = "vlan";
            };
            vlanConfig = {
              Id = interface.vlanId;
            };
          }
        ) interface.ports
      );
      networks = concatMapVlanAttrs (
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
              VLAN = "${port}.${toString interface.vlanId}";
            };
          }
        ) interface.ports
        // lib'.mapListToAttrs (
          port:
          lib.nameValuePair
            "${toString config.router.interfacePortPriority}-${port}.${toString interface.vlanId}"
            {
              matchConfig = {
                Name = "${port}.${toString interface.vlanId}";
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
