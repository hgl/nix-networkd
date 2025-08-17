{
  lib,
  config,
  ...
}:
let
  wanInterfaces = lib.filterAttrs (
    _: interface: interface.type == "wan" && interface.connectionType == "pppoe"
  ) config.router.interfaces;
in
{
  config = lib.mkIf config.router.enable {
    systemd.network = {
      networks = lib.concatMapAttrs (_: interface: {
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
            UseDNS = config.networking.nameservers == [ ];
          };
        };
      }) wanInterfaces;
    };

    services.pppd = {
      enable = true;
      peers = lib.concatMapAttrs (_: interface: {
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
      }) wanInterfaces;
    };
    systemd.services = lib.concatMapAttrs (_: interface: {
      "pppd-interface-${interface.name}".serviceConfig.Type = "notify";
    }) wanInterfaces;
    environment.etc."ppp/pap-secrets" = {
      mode = "0600";
      text = lib.concatLines (
        lib.mapAttrsToList (
          _: interface: "${interface.pppoeUsername} * @${interface.pppoePasswordPath} *"
        ) wanInterfaces
      );
    };
  };
}
