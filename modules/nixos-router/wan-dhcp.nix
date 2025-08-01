{
  lib,
  config,
  ...
}:
let
  concatMapWanAttrs = config.router.concatMapInterfaceAttrs (
    interface: interface.type == "wan" && interface.connectionType or null == "dhcp"
  );
in
{
  config = lib.mkIf config.router.enable {
    systemd.network = {
      links = concatMapWanAttrs (interface: {
        "${toString interface.priority}-${interface.name}" = {
          matchConfig = {
            # can't use OriginalName here because it sometimes doesn't work
            # https://github.com/systemd/systemd/issues/24975#issuecomment-1276669267
            PermanentMACAddress = interface.macAddress;
          };
          linkConfig = {
            Name = interface.name;
          };
        };
      });
      networks = concatMapWanAttrs (interface: {
        "${toString interface.priority}-${interface.name}" = {
          matchConfig = {
            Name = interface.name;
          };
          networkConfig = {
            IPv6LinkLocalAddressGenerationMode = "stable-privacy";
            DHCP = true;
            # Only allow resolved to use the upstream DNSes directly if it's
            # the terminal resolver and no static nameservers are configured
            DNSDefaultRoute = !config.services.adguardhome.enable;
          };
          dhcpV4Config = {
            UseDNS = config.networking.nameservers == [ ];
          };
          dhcpV6Config = {
            UseDNS = config.networking.nameservers == [ ];
          };
        };
      });
    };
  };
}
