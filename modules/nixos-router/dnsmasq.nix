{
  lib,
  nixosRouterLib,
  pkgs,
  config,
  ...
}:
let
  lib' = nixosRouterLib;
  cfg = config.services.dnsmasq;
  stateDir = "/var/lib/dnsmasq";
  settingsFormat = pkgs.formats.keyValue {
    mkKeyValue =
      name: value:
      if value == true then
        name
      else if value == false then
        "# setting `${name}` explicitly set to false"
      else
        lib.generators.mkKeyValueDefault { } "=" name value;
    listsAsDuplicateKeys = true;
  };
  conf = settingsFormat.generate "dnsmasq.conf" cfg.settings;
  concatMapDnsInterfaces = config.router.concatMapInterfaces (
    interface: interface.dns.enable or false
  );
in
{
  config = lib.mkIf config.router.enable {
    services.dnsmasq.enable = lib.mkForce false;
    services.dnsmasq.settings = {
      dhcp-leasefile = "${stateDir}/dnsmasq.leases";
      bind-interfaces = true;
      dhcp-authoritative = true;
      no-resolv = true;
      localise-queries = true;
      expand-hosts = true;
      bogus-priv = true;
      enable-dbus = true;
      stop-dns-rebind = true;
      rebind-localhost-ok = true;
      dns-forward-max = 1000;
      enable-ra = true;
      server = [ "127.0.0.53" ];
      interface = concatMapDnsInterfaces (interface: [ interface.name ]);
      no-dhcp-interface = concatMapDnsInterfaces (
        interface: lib.optional (!(interface.dhcpServer.enable or false)) interface.name
      );
      dhcp-range = concatMapDnsInterfaces (
        interface:
        lib.optionals (interface.dhcpServer.enable or false) [
          "::,constructor:${interface.name},slaac,7d"
          (lib.concatStringsSep "," [
            interface.dhcpServer.poolv4.startIp
            interface.dhcpServer.poolv4.endIp
          ])
        ]
      );
      interface-name = concatMapDnsInterfaces (
        interface:
        lib.optionals (!(interface.quarantine.enable or false)) (
          map (domain: "${domain},${interface.name}") (
            [
              config.networking.hostName
              config.networking.fqdn
            ]
            ++ config.router.hostNameAliases
          )
        )
      );
      dhcp-host = concatMapDnsInterfaces (
        interface:
        lib'.concatMapAttrsToList (
          _: lease:
          lib.optional lease.enable "${lease.hostName},${lease.macAddress},${
            interface.ipv4 { inherit (lease) hostId; }
          }"
        ) interface.dhcpServer.staticLeases or { }
      );
    };
    services.dbus.packages = [ cfg.package ];
    users.users.dnsmasq = {
      isSystemUser = true;
      group = "dnsmasq";
      description = "Dnsmasq daemon user";
    };
    users.groups.dnsmasq = { };
    systemd.services.dnsmasq = {
      description = "Dnsmasq Daemon";
      after = [
        "network.target"
        "systemd-resolved.service"
      ];
      wantedBy = [ "multi-user.target" ];
      path = [ cfg.package ];
      preStart = ''
        dnsmasq --test -C ${conf}
      '';
      serviceConfig = {
        Type = "dbus";
        BusName = "uk.org.thekelleys.dnsmasq";
        ExecStart = "${cfg.package}/bin/dnsmasq -k --enable-dbus --user=dnsmasq -C ${conf}";
        ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
        PrivateTmp = true;
        ProtectSystem = true;
        ProtectHome = true;
        Restart = "on-failure";
      };
      restartTriggers = [ config.environment.etc.hosts.source ];
    };

    systemd.tmpfiles.rules = [
      "d ${stateDir} - ${config.users.users.dnsmasq.name} ${config.users.users.dnsmasq.group}"
      "f ${stateDir}/dnsmasq.leases - ${config.users.users.dnsmasq.name} ${config.users.users.dnsmasq.group}"
    ];

    # resolved set this file with default override priority, set it one less
    # so it's still overridable with mkForce
    environment.etc."resolv.conf".text = lib.mkOverride (lib.modules.defaultOverridePriority - 1) ''
      ${lib.optionalString config.networking.enableIPv6 "nameserver ::1"}
      nameserver 127.0.0.1
      options edns0 trust-ad
    '';
  };
}
