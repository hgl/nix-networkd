{
  lib,
  config,
  ...
}:
let
  concatMapWanAttrs = config.router.concatMapInterfaceAttrs (
    interface: interface.type == "wan" && interface.connectionType == "pppoe"
  );
  concatMapWans = config.router.concatMapInterfaces (
    interface: interface.type == "wan" && interface.connectionType == "pppoe"
  );
in
{
  config = lib.mkIf config.router.enable {
    systemd.network = {
      networks = concatMapWanAttrs (interface: {
        # This is required to bring the interface up
        "${toString config.router.interfacePortPriority}-${interface.port}" = {
          matchConfig = {
            Name = interface.port;
          };
          networkConfig = {
            LinkLocalAddressing = false;
          };
        };
        "${toString interface.priority}-${interface.name}" = {
          matchConfig = {
            Name = interface.name;
          };
          networkConfig = {
            IPv6LinkLocalAddressGenerationMode = "stable-privacy";
            DHCP = "ipv6";
            IPv6AcceptRA = true;
            IPv6SendRA = false;
            # Only allow resolved to use the upstream DNS directly if it's
            # the terminal resolver and no static nameservers are configured
            DNSDefaultRoute = !config.services.adguardhome.enable;
          };
          dhcpV6Config = {
            PrefixDelegationHint = "::/${toString interface.prefixDelegationLengthHint}";
            SendHostname = false;
            WithoutRA = "solicit";
            UseDNS = config.networking.nameservers == [ ];
          };
          dhcpPrefixDelegationConfig = {
            UplinkInterface = ":self";
          };
          ipv6AcceptRAConfig = {
            DHCPv6Client = "always";
          };
        };
      });
    };

    services.pppd = {
      enable = true;
      peers = concatMapWanAttrs (interface: {
        "interface-${interface.name}".config = ''
          plugin pppoe.so
          nic-${interface.port}
          +ipv6
          nodetach
          ifname ${interface.name}
          usepeerdns
          defaultroute
          persist
          maxfail 0
          lcp-echo-interval 1
          lcp-echo-failure 5
          lcp-echo-adaptive
          up_sdnotify
          name ${interface.pppoeUsername}
        '';
      });
    };
    systemd.services = concatMapWanAttrs (interface: {
      "pppd-interface-${interface.name}".serviceConfig.Type = "notify";
    });
    environment.etc."ppp/pap-secrets" = {
      mode = "0600";
      text = lib.concatLines (
        concatMapWans (interface: [ "${interface.pppoeUsername} * @${interface.pppoePasswordPath} *" ])
      );
    };
  };
}
