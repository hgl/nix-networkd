{
  lib,
  nixosRouterLib,
  config,
  ...
}:
let
  lib' = nixosRouterLib;
  inherit (lib) mkOption mkEnableOption types;
  functionType = lib.mkOptionType {
    name = "function";
    description = "function value";
    descriptionClass = "noun";
    check = x: lib.isFunction x;
    merge = lib.options.mergeOneOption;
  };
  # like lib.types.oneOf but instead of a list takes an attrset
  # uses the field "type" to find the correct type in the attrset
  # copied from disko
  oneOfSubmodules =
    submoduleAttrs:
    lib.mkOptionType {
      name = "subType";
      description = "one of ${lib.concatStringsSep "," (lib.attrNames submoduleAttrs)}";
      check = x: lib.isAttrs x;
      merge =
        loc: defs:
        let
          evaled = lib.evalModules {
            modules =
              [
                {
                  freeformType = lib.types.lazyAttrsOf lib.types.raw;
                  options.type = mkOption {
                    type = lib.types.str;
                  };
                }
              ]
              ++ map (
                { value, file }:
                {
                  _file = file;
                  config = value;
                }
              ) defs;
          };
          inherit (evaled.config) type;
        in
        submoduleAttrs.${type}.merge loc defs;
      nestedTypes = submoduleAttrs;
    };
  bridgeType = types.submodule (
    { name, config, ... }:
    {
      options = {
        inherit priority subnetId;
        name = nameOption name;
        type = mkOption {
          type = types.enum [ "bridge" ];
          default = "bridge";
          internal = true;
          description = "Type";
        };
        ports = mkOption {
          type = types.nonEmptyListOf types.nonEmptyStr;
          description = ''
            The ports this interface includes
          '';
        };
        dhcpServer = dhcpServer config;
        ipv6 = ipv6 config;
        ipv4 = ipv4 config;
        inherit quarantine;
      };
    }
  );
  vlanType = types.submodule (
    { name, config, ... }:
    {
      options = {
        inherit priority subnetId;
        name = nameOption name;
        type = mkOption {
          type = types.enum [ "vlan" ];
          default = "vlan";
          internal = true;
          description = "Type";
        };
        ports = mkOption {
          type = types.nonEmptyListOf types.nonEmptyStr;
          description = ''
            The ports this interface includes
          '';
        };
        vlanId = mkOption {
          type = types.ints.between 1 4094;
          description = ''
            VLAN ID
          '';
        };
        dhcpServer = dhcpServer config;
        ipv6 = ipv6 config;
        ipv4 = ipv4 config;
        inherit quarantine;
      };
    }
  );
  xfrmType = types.submodule (
    { name, config, ... }:
    {
      options = {
        inherit priority subnetId;
        name = nameOption name;
        type = mkOption {
          type = types.enum [ "xfrm" ];
          default = "xfrm";
          internal = true;
          description = "Type";
        };
        xfrmId = mkOption {
          type = types.ints.between 1 4294967295;
          description = ''
            XFRM interface ID
          '';
        };
        poolv4 = poolv4 config config.poolv4;
        ipv6 = ipv6 config;
        ipv4 = ipv4 config;
        inherit quarantine;
      };
    }
  );
  wanType = types.submodule (
    { name, config, ... }:
    {
      options = {
        inherit priority;
        name = nameOption name;
        type = mkOption {
          type = types.enum [ "wan" ];
          default = "wan";
          internal = true;
          description = "Type";
        };
        connectionType = mkOption {
          type = types.enum [
            "pppoe"
            "dhcp"
          ];
          description = ''
            The type of connection this WAN interface use to be able to access the internet
          '';
        };
        macAddress = mkOption {
          type = types.nonEmptyStr;
          description = ''
            This WAN interface's MAC address. Used to find the interface
          '';
        };
        prefixDelegationLengthHint = mkOption {
          type = types.ints.between 48 64;
          default = 56;
          description = ''
            DHCPv6 prefix delegation length hint to use
          '';
        };
        pppoeUsername = mkOption {
          type = types.str;
          description = ''
            User name to use for the PPPOE connection
          '';
        };
        pppoePasswordPath = mkOption {
          type = types.path;
          description = ''
            File containing the password to use for the PPPOE connection
          '';
        };
        nftables = {
          inputChain = mkOption {
            type = types.lines;
            default = "";
            description = ''
              Nftable rules for the input chain of this interface
            '';
          };
          forwardChain = mkOption {
            type = types.lines;
            default = "";
            description = ''
              Nftable rules for the forward chain of this interface
            '';
          };
          dstnatChain = mkOption {
            type = types.lines;
            default = "";
            description = ''
              Nftable rules for the dstnat chain of this interface
            '';
          };
          extraConfig = mkOption {
            type = types.lines;
            default = "";
            description = ''
              Extra nftable rules for the table of this interface
            '';
          };
        };
        ddns = mkOption {
          type = types.listOf (
            types.submodule {
              options = {
                enable = mkOption {
                  type = types.enum [
                    true
                    false
                    "ipv4"
                    "ipv6"
                  ];
                  default = true;
                  description = ''
                    Whetehr to enable this DDNS service (or IPv4/IPv6 only)
                  '';
                };
                domains = mkOption {
                  type = types.nonEmptyListOf types.nonEmptyStr;
                  description = ''
                    The domain to update
                  '';
                };
                provider = mkOption {
                  type = types.submodule {
                    freeformType = types.attrsOf types.str;
                    options.type = mkOption {
                      type = types.nonEmptyStr;
                    };
                  };
                  description = ''
                    The DDNS provider to use
                  '';
                };
              };
            }
          );
          default = [ ];
          description = ''
            DDNS to create on this interface
          '';
        };
      };
    }
  );
  ipv6Prefix = lib.elemAt (lib.match "([^/]+)::/.+" config.router.ulaPrefix) 0;
  ipv6 =
    interface:
    mkOption {
      type = functionType;
      internal = true;
      readOnly = true;
      default = args: config.router.ipv6 (args // { inherit (interface) subnetId; });
    };
  ipv4 =
    interface:
    mkOption {
      type = functionType;
      internal = true;
      readOnly = true;
      default = args: config.router.ipv4 (args // { inherit (interface) subnetId; });
    };
  poolv4 = interface: pool: {
    range = mkOption {
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
    startIp = mkOption {
      type = types.str;
      internal = true;
      readOnly = true;
      default = interface.ipv4 { hostId = lib.elemAt pool.range 0; };
    };
    endIp = mkOption {
      type = types.str;
      internal = true;
      readOnly = true;
      default = interface.ipv4 { hostId = lib.elemAt pool.range 1; };
    };
  };
  dhcpServer = interface: {
    enable = mkEnableOption "DHCP server on this interface" // {
      default = true;
    };
    poolv4 = poolv4 interface interface.dhcpServer.poolv4;
    staticLeases = mkOption {
      type = types.attrsOf (
        types.addCheck (types.submodule (
          { name, config, ... }:
          {
            enable = mkEnableOption "this static lease" // {
              default = true;
            };
            hostName = mkOption {
              type = types.nonEmptyStr;
              default = name;
              description = ''
                Client host name to match and assign
              '';
            };
            macAddress = mkOption {
              type = types.nonEmptyStr;
              description = ''
                Client MAC address to match
              '';
            };
            hostId = mkOption {
              type = types.nullOr types.ints.between 2 254;
              default = null;
              description = ''
                Client will be assigned an IPv4 address in format of

                10.''${router.ipv4SubnetId}.''${interface.subnetId}.''${hostId}
              '';
            };
            interfaceId = mkOption {
              type = types.nullOr types.oneOf [
                types.ints.positive
                types.nonEmptyStr
              ];
              default = null;
              description = ''
                Client will be assigned an IPv6 address in format of

                ''${router.ulaPrefix}:''${interface.subnetId}::''${interfaceId}
              '';
            };
          }
        )) (x: x.hostId != null || x.interfaceId != null)
      );
      default = { };
      description = ''
        DHCP static leases to create
      '';
    };
  };
  nameOption =
    name:
    mkOption {
      type = types.nonEmptyStr;
      default = name;
      description = ''
        Interface name
      '';
    };
  priority = mkOption {
    type = types.ints.between 10 69;
    default = 10;
    description = ''
      The number prefix to use when creating systemd network for this interface
    '';
  };
  subnetId = mkOption {
    type = types.ints.between 0 255;
    description = ''
      NixOS router uses this format for each interface's IP addresses:

      IPv4: 10.''${router.ipv4SubnetId}.''${subnetId}.1
      IPv6: ''${router.ulaPrefix}:''${subnetId}::1
    '';
  };
  quarantine = {
    enable = mkEnableOption "qurantine on this interface";
  };
in
{
  options.router = {
    enable = mkEnableOption "NixOS Router";
    ulaPrefix = mkOption {
      type = types.nonEmptyStr;
      description = ''
        [IPv6 ULA Prefix](https://en.wikipedia.org/wiki/Unique_local_address) to use
      '';
    };
    ipv4SubnetId = mkOption {
      type = types.ints.between 0 255;
      description = ''
        NixOS router uses this format for each interface's IPv4 address:

        10.''${ipv4SubnetId}.''${interface.subnetId}.1
      '';
    };
    hostNameAliases = mkOption {
      type = types.listOf types.nonEmptyStr;
      default = [ ];
      description = ''
        Additonal host names that resolve to the interface IPs
      '';
    };
    interfacePortPriority = mkOption {
      type = types.ints.between 1 99;
      default = 10;
      description = ''
        The number prefix to use when creating systemd network for an interface port
      '';
    };
    interfaces = mkOption {
      type = types.attrsOf (oneOfSubmodules {
        bridge = bridgeType;
        vlan = vlanType;
        xfrm = xfrmType;
        wan = wanType;
      });
      description = ''
        Network interfaces to create
      '';
    };
    ipv6 = mkOption {
      type = functionType;
      internal = true;
      readOnly = true;
      default =
        {
          subnetId,
          interfaceId,
          prefixLength ? null,
        }:
        "${ipv6Prefix}${lib.optionalString (subnetId != 0) ":${toString subnetId}"}::${
          lib.optionalString (interfaceId != 0) (toString interfaceId)
        }${lib.optionalString (prefixLength != null) "/${toString prefixLength}"}";
    };
    ipv4 = mkOption {
      type = functionType;
      internal = true;
      readOnly = true;
      default =
        {
          subnetId,
          hostId,
          prefixLength ? null,
        }:
        "10.${toString config.router.ipv4SubnetId}.${toString subnetId}.${toString hostId}${
          lib.optionalString (prefixLength != null) "/${toString prefixLength}"
        }";
    };
    concatMapInterfaceAttrs = mkOption {
      type = functionType;
      internal = true;
      readOnly = true;
      default =
        filter: f:
        lib.concatMapAttrs (
          _: interface: lib.optionalAttrs (filter interface) (f interface)
        ) config.router.interfaces;
    };
    concatMapInterfaces = mkOption {
      type = functionType;
      internal = true;
      readOnly = true;
      default =
        filter: f:
        lib'.concatMapAttrsToList (
          _: interface: lib.optionals (filter interface) (f interface)
        ) config.router.interfaces;
    };
  };
}
