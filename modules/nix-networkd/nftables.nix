{
  lib,
  nixNetworkdLib,
  config,
  ...
}:
let
  lib' = nixNetworkdLib;
  wanInterfaces = lib.filterAttrs (_: interface: interface.type == "wan") config.networkd.interfaces;
  quarantineInterfaces = lib.filterAttrs (
    _: interface: interface.quarantine.enable or false
  ) config.networkd.interfaces;
  table =
    {
      useIfname ? false,
    }:
    interface:
    let
      iif = if useIfname then "iifname" else "iif";
      oif = if useIfname then "oifname" else "oif";
    in
    lib.nameValuePair "interface-${interface.name}" {
      family = "inet";
      content = lib.concatLines (
        lib'.concatMapAttrsToList (
          chainType: hooks:
          lib'.concatMapAttrsToList
            (
              hookType: chain:
              lib'.concatMapAttrsToList (
                priority: rules:
                if hookType == "forward" then
                  lib.optional (rules.inRules != "" || rules.outRules != "") ''
                    chain ${chainType}-${hookType}-${priority} {
                      type ${chainType} hook ${hookType} priority ${priority};
                      ${lib.concatLines (
                        lib.optional (rules.inRules != "") ''
                          ${iif} "${interface.name}" jump ${chainType}-forwardIn-${priority}-interface
                        ''
                        ++ lib.optional (rules.outRules != "") ''
                          ${oif} "${interface.name}" jump ${chainType}-forwardOut-${priority}-interface
                        ''
                      )}
                    }
                    ${lib.concatLines (
                      lib.optional (rules.inRules != "") ''
                        chain ${chainType}-forwardIn-${priority}-interface {
                          ${rules.inRules}
                        }
                      ''
                      ++ lib.optional (rules.outRules != "") ''
                        chain ${chainType}-forwardOut-${priority}-interface {
                          ${rules.outRules}
                        }
                      ''
                    )}
                  ''
                else
                  lib.optional (rules != "") ''
                    chain ${chainType}-${hookType}-${priority} {
                      type ${chainType} hook ${hookType} priority ${priority};
                      ${
                        {
                          ingress = iif;
                          prerouting = iif;
                          input = iif;
                          output = oif;
                          postrouting = oif;
                        }
                        .${hookType}
                      } ${interface.name} jump ${chainType}-${hookType}-${priority}-interface
                    }
                    chain ${chainType}-${hookType}-${priority}-interface {
                      ${rules}
                    }
                  ''
              ) chain
            )
            (
              # push down in and out to rules
              lib.removeAttrs hooks [
                "forwardIn"
                "forwardOut"
              ]
              // lib.optionalAttrs (hooks ? forwardIn) {
                forward = lib.mapAttrs (priority: rules: {
                  inRules = rules;
                  outRules = hooks.forwardOut.${priority};
                }) hooks.forwardIn;
              }
            )
        ) interface.nftables.chains
        ++ [ interface.nftables.extraConfig ]
      );
    };
in
{
  config = {
    networking.nftables.tables =
      lib.mapAttrs' (
        _: interface:
        table { } (
          lib.updateManyAttrsByPath [
            {
              path = [
                "nftables"
                "chains"
                "filter"
                "input"
                "filter"
              ];
              update = rules: ''
                ct state vmap { established : accept, related : accept }
                fib daddr type { broadcast, multicast } accept
                ip daddr != ${interface.ipv4 { hostId = 1; }} drop
                ip6 daddr & ::ffff:ffff:ffff:ffff:ffff != 0:0:0:${lib'.decToHex interface.subnetId}::1 drop
                meta nfproto ipv4 udp sport 68 udp dport 67 accept comment "Allow DHCP"
                meta nfproto ipv6 udp sport 547 udp dport 546 accept comment "Allow DHCPv6"
                icmp type echo-request accept comment "Allow Ping"
                meta nfproto ipv4 meta l4proto igmp accept comment "Allow IGMP"
                ip6 saddr fe80::/10 icmpv6 type . icmpv6 code { mld-listener-query . 0, mld-listener-report . 0, mld-listener-done . 0, mld2-listener-report . 0 } accept comment "Allow MLD"
                icmpv6 type { destination-unreachable, time-exceeded, echo-request, echo-reply, nd-router-solicit, nd-router-advert } limit rate 1000/second burst 5 packets accept comment "Allow ICMPv6-Input"
                icmpv6 type . icmpv6 code { packet-too-big . 0, parameter-problem . 0, nd-neighbor-solicit . 0, nd-neighbor-advert . 0, parameter-problem . 1 } limit rate 1000/second burst 5 packets accept comment "Allow ICMPv6 Input"
                udp dport 53 accept comment "Allow DNS"
                ${rules}
                drop
              '';
            }
            {
              path = [
                "nftables"
                "chains"
                "filter"
                "forwardIn"
                "filter"
              ];
              update = rules: ''
                ct state vmap { established : accept, related : accept }
                oifname {${
                  lib.concatStringsSep "," (lib.mapAttrsToList (_: interface: "\"${interface.name}\"") wanInterfaces)
                }} accept
                ${rules}
                drop
              '';
            }
          ] interface
        )
      ) quarantineInterfaces
      // lib.mapAttrs' (
        _: interface:
        table
          {
            useIfname = interface.connectionType == "pppoe";
          }
          (
            lib.updateManyAttrsByPath [
              {
                path = [
                  "nftables"
                  "chains"
                  "filter"
                  "input"
                  "filter"
                ];
                update = rules: ''
                  ct state vmap { established : accept, related : accept }
                  meta nfproto ipv4 udp sport 67 udp dport 68 accept comment "Allow DHCP"
                  meta nfproto ipv6 udp sport 547 udp dport 546 accept comment "Allow DHCPv6"
                  icmp type echo-request accept comment "Allow Ping"
                  meta nfproto ipv4 meta l4proto igmp accept comment "Allow IGMP"
                  ip6 saddr fe80::/10 icmpv6 type . icmpv6 code { mld-listener-query . no-route, mld-listener-report . no-route, mld-listener-done . no-route, mld2-listener-report . no-route } accept comment "Allow MLD"
                  icmpv6 type { destination-unreachable, time-exceeded, echo-request, echo-reply, nd-router-solicit, nd-router-advert } limit rate 1000/second burst 5 packets accept comment "Allow ICMPv6-Input"
                  icmpv6 type . icmpv6 code { packet-too-big . no-route, parameter-problem . no-route, nd-neighbor-solicit . no-route, nd-neighbor-advert . no-route, parameter-problem . admin-prohibited } limit rate 1000/second burst 5 packets accept comment "Allow ICMPv6 Input"
                  ${rules}
                  ct status dnat accept
                  drop
                '';
              }
              {
                path = [
                  "nftables"
                  "chains"
                  "filter"
                  "forwardOut"
                  "mangle"
                ];
                update = rules: ''
                  tcp flags syn tcp option maxseg size set rt mtu
                  ${rules}
                '';
              }
              {
                path = [
                  "nftables"
                  "chains"
                  "filter"
                  "output"
                  "mangle"
                ];
                update = rules: ''
                  tcp flags syn tcp option maxseg size set rt mtu
                  ${rules}
                '';
              }
              {
                path = [
                  "nftables"
                  "chains"
                  "nat"
                  "postrouting"
                  "srcnat"
                ];
                update = rules: ''
                  meta nfproto ipv4 masquerade
                  ${rules}
                '';
              }
            ] interface
          )
      ) wanInterfaces;
  };
}
