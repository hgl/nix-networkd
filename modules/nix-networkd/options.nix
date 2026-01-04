{
  lib,
  nixNetworkdLib,
  config,
  ...
}:
let
  lib' = nixNetworkdLib;
  inherit (lib) types;
  functionType = lib.mkOptionType {
    name = "function";
    description = "function value";
    descriptionClass = "noun";
    check = x: lib.isFunction x;
    merge = lib.options.mergeOneOption;
  };
  bridgeType = types.submodule (
    { name, config, ... }:
    {
      options = {
        inherit
          priority
          subnetId
          dns
          nftables
          ports
          quarantine
          ;
        name = nameOption name;
        type = interfaceType "bridge";
        dhcpServer = dhcpServer config;
        ipv6 = ipv6 config;
        ipv4 = ipv4 config;
      };
    }
  );
  vlanType = types.submodule (
    { name, config, ... }:
    {
      options = {
        inherit
          priority
          subnetId
          dns
          nftables
          ports
          quarantine
          ;
        name = nameOption name;
        type = interfaceType "vlan";
        vlanId = lib.mkOption {
          type = types.ints.between 1 4094;
          description = ''
            VLAN ID
          '';
        };
        dhcpServer = dhcpServer config;
        ipv6 = ipv6 config;
        ipv4 = ipv4 config;
      };
    }
  );
  xfrmType = types.submodule (
    { name, config, ... }:
    {
      options = {
        inherit
          priority
          subnetId
          dns
          nftables
          quarantine
          ;
        name = nameOption name;
        type = interfaceType "xfrm";
        xfrmId = lib.mkOption {
          type = types.ints.between 1 4294967295;
          description = ''
            XFRM interface ID
          '';
        };
        poolv4 = poolv4 config config.poolv4;
        ipv6 = ipv6 config;
        ipv4 = ipv4 config;
      };
    }
  );
  sitType = types.submodule (
    { name, config, ... }:
    {
      options = {
        inherit
          priority
          subnetId
          dns
          nftables
          quarantine
          ;
        name = nameOption name;
        type = interfaceType "sit";
        mtu = lib.mkOption {
          type = types.oneOf [
            types.ints.positive
            types.nonEmptyStr
          ];
          default = 1480;
        };
        ttl = lib.mkOption {
          type = types.nullOr (types.ints.between 1 255);
          default = null;
        };
        local = lib.mkOption {
          type = types.nonEmptyStr;
        };
        remote = lib.mkOption {
          type = types.nonEmptyStr;
        };
        addresses = lib.mkOption {
          type = types.nonEmptyListOf types.nonEmptyStr;
        };
        gateway = lib.mkOption {
          type = types.either types.nonEmptyStr (types.nonEmptyListOf types.nonEmptyStr);
        };
        ipv6 = ipv6 config;
        ipv4 = ipv4 config;
      };
    }
  );
  wanType = types.submodule (
    { name, config, ... }:
    {
      options = {
        inherit priority nftables;
        name = nameOption name;
        type = interfaceType "wan";
        connectionType = lib.mkOption {
          type = types.enum [
            "pppoe"
            "dhcp"
          ];
          description = ''
            The type of connection this WAN interface use to be able to access the internet
          '';
        };
        port = lib.mkOption {
          type = types.nonEmptyStr;
          description = ''
            The WAN interface's port to use for PPPoE
          '';
        };
        macAddress = lib.mkOption {
          type = types.nonEmptyStr;
          description = ''
            This WAN interface's MAC address. Used to find the interface
          '';
        };
        prefixDelegationLengthHint = lib.mkOption {
          type = types.ints.between 48 64;
          default = 56;
          description = ''
            DHCPv6 prefix delegation length hint to use
          '';
        };
        pppoeUsername = lib.mkOption {
          type = types.str;
          description = ''
            User name to use for the PPPOE connection
          '';
        };
        pppoePasswordPath = lib.mkOption {
          type = types.path;
          description = ''
            File containing the password to use for the PPPOE connection
          '';
        };
      };
    }
  );
  ipv6 =
    interface:
    lib.mkOption {
      type = functionType;
      internal = true;
      readOnly = true;
      default = args: config.networkd.ipv6 (args // { inherit (interface) subnetId; });
    };
  ipv4 =
    interface:
    lib.mkOption {
      type = functionType;
      internal = true;
      readOnly = true;
      default = args: config.networkd.ipv4 (args // { inherit (interface) subnetId; });
    };
  poolv4 = interface: pool: {
    range = lib.mkOption {
      type = types.addCheck (types.listOf (types.ints.between 1 254)) (
        x: lib.length x == 2 && lib.elemAt x 0 <= lib.elemAt x 1
      );
      default = [
        100
        250
      ];
      description = ''
        start and end hostId for the IPv4 DHCP pool
      '';
    };
    startIp = lib.mkOption {
      type = types.str;
      internal = true;
      readOnly = true;
      default = interface.ipv4 { hostId = lib.elemAt pool.range 0; };
    };
    endIp = lib.mkOption {
      type = types.str;
      internal = true;
      readOnly = true;
      default = interface.ipv4 { hostId = lib.elemAt pool.range 1; };
    };
  };
  dns = {
    enable = lib.mkEnableOption "DNS resolver on this interface" // {
      default = true;
    };
  };
  dhcpServer = interface: {
    enable = lib.mkEnableOption "DHCP server on this interface" // {
      default = true;
    };
    poolv4 = poolv4 interface interface.dhcpServer.poolv4;
    staticLeases = lib.mkOption {
      type = types.attrsOf (
        types.submodule (
          { name, config, ... }:
          {
            options = {
              enable = lib.mkEnableOption "this static lease" // {
                default = true;
              };
              hostName = lib.mkOption {
                type = types.nonEmptyStr;
                default = name;
                description = ''
                  Client host name to match and assign
                '';
              };
              macAddress = lib.mkOption {
                type = types.nonEmptyStr;
                description = ''
                  Client MAC address to match
                '';
              };
              hostId = lib.mkOption {
                type = types.ints.between 2 254;
                description = ''
                  Client will be assigned an IPv4 address in format of

                  ''${ipv4Prefix}.''${interface.subnetId}.''${hostId}
                '';
              };
            };
          }
        )
      );
      default = { };
      description = ''
        DHCP static leases to create
      '';
    };
  };
  nameOption =
    name:
    lib.mkOption {
      type = types.nonEmptyStr;
      default = name;
      description = ''
        Interface name
      '';
    };
  interfaceType =
    type:
    lib.mkOption {
      type = types.enum [ type ];
      default = type;
      internal = true;
      description = ''
        Interface type
      '';
    };
  priority = lib.mkOption {
    type = types.ints.between 10 69;
    default = 10;
    description = ''
      The number prefix to use when creating systemd network for this interface
    '';
  };
  subnetId = lib.mkOption {
    type = types.ints.between 0 255;
    description = ''
      Each interface takes an IP address like this:

      IPv6: ''${ulaPrefix}:''${toHex subnetId}::1
      IPv4: ''${ipv4Prefix}.''${subnetId}.1
    '';
  };
  nftables = {
    chains = {
      filter = {
        ingress = hook "filter" "ingress";
        prerouting = hook "filter" "prerouting";
        forwardIn = hook "filter" "forward";
        forwardOut = hook "filter" "forward";
        input = hook "filter" "input";
        output = hook "filter" "output";
        postrouting = hook "filter" "postrouting";
      };
      nat = {
        prerouting = hook "nat" "prerouting";
        input = hook "nat" "input";
        output = hook "nat" "output";
        postrouting = hook "nat" "postrouting";
      };
      route = {
        output = hook "route" "output";
      };
    };
    extraConfig = lib.mkOption {
      type = types.lines;
      default = "";
      description = ''
        Extra nftable rules for the table of this interface
      '';
    };
  };
  hook =
    chainType: hookType:
    lib.genAttrs
      (
        [
          "raw"
          "mangle"
          "filter"
          "security"
        ]
        ++ lib.optional (hookType == "prerouting") "dstnat"
        ++ lib.optional (hookType == "postrouting") "srcnat"
      )
      (
        priority:
        lib.mkOption {
          type = types.lines;
          default = "";
          description = ''
            Nftable rules for the ${chainType} chain and the ${hookType} hook with priority ${priority} for this interface
          '';
        }
      );
  ports = lib.mkOption {
    type = types.nonEmptyListOf types.nonEmptyStr;
    description = ''
      The ports this interface includes
    '';
  };
  quarantine = {
    enable = lib.mkEnableOption "qurantine on this interface";
  };
in
{
  options.networkd = {
    ulaPrefix = lib.mkOption {
      type = types.nonEmptyStr;
      description = ''
        [IPv6 ULA Prefix](https://en.wikipedia.org/wiki/Unique_local_address) to use

        Each interface takes an IP address like this:

        ''${lib.removeSuffix "::/48" ulaPrefix}.''${interface.subnetId}.1
      '';
    };
    ipv4Prefix = lib.mkOption {
      type = types.addCheck types.nonEmptyStr (s: lib.match "[0-9]{1,3}\\.0-9]{1,3}\\.0\\.0/16" != null);
      description = ''
        Each interface takes an IP address like this:

        ''${lib.removeSuffix ".0.0/16" ipv4Prefix}.''${interface.subnetId}.1
      '';
    };
    hostNameAliases = lib.mkOption {
      type = types.listOf types.nonEmptyStr;
      default = [ ];
      description = ''
        Additonal host names that resolve to the interface IPs
      '';
    };
    interfacePortPriority = lib.mkOption {
      type = types.ints.between 1 99;
      default = 10;
      description = ''
        The number prefix to use when creating systemd network for an interface port
      '';
    };
    interfaces = lib.mkOption {
      type = types.attrsOf (
        lib'.types.taggedSubmodule {
          bridge = bridgeType;
          vlan = vlanType;
          xfrm = xfrmType;
          wan = wanType;
          sit = sitType;
        }
      );
      description = ''
        Network interfaces to create
      '';
      default = { };
    };
    ipv6 = lib.mkOption {
      type = functionType;
      internal = true;
      readOnly = true;
      default =
        let
          ipv6Prefix = lib.removeSuffix "::/48" config.networkd.ulaPrefix;
        in
        {
          subnetId,
          interfaceId,
          prefixLength ? null,
        }:
        let
          interfaceIdString = if lib.isString interfaceId then interfaceId else lib'.decToHex interfaceId;
          sep =
            if
              lib.isString interfaceId
              && (
                lib.hasInfix "::" interfaceId
                || lib.match "[a-fA-F0-9]{1,4}(:[a-fA-F0-9]{1,4}){4}" interfaceId != null
              )
            then
              ":"
            else
              "::";
        in
        "${ipv6Prefix}${lib.optionalString (subnetId != 0) ":${lib'.decToHex subnetId}"}${sep}${
          lib.optionalString (interfaceIdString != "0") interfaceIdString
        }${lib.optionalString (prefixLength != null) "/${toString prefixLength}"}";
    };
    ipv4 = lib.mkOption {
      type = functionType;
      internal = true;
      readOnly = true;
      default =
        let
          ipv4Prefix = lib.removeSuffix ".0.0/16" config.networkd.ipv4Prefix;
        in
        {
          subnetId,
          hostId,
          prefixLength ? null,
        }:
        "${ipv4Prefix}.${toString subnetId}.${toString hostId}${
          lib.optionalString (prefixLength != null) "/${toString prefixLength}"
        }";
    };
  };
}
