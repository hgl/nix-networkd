{
  lib,
  config,
  ...
}:
let
  cfg = config.router;
  concatMapWanAttrs = config.router.concatMapInterfaceAttrs ({ type, ... }: type == "wan");
  # TODO: Once multi-wan is supported this should be updated
  concatMapWans = config.router.concatMapInterfaces ({ type, ... }: type == "wan");
  wanNames = concatMapWans ({ name, ... }: [ name ]);
in
{
  config = lib.mkIf cfg.enable {
    networking.nftables.tables =
      config.router.concatMapInterfaceAttrs (interface: interface.quarantine.enable or false)
        (interface: {
          "interface-${interface.name}" = {
            family = "inet";
            content = ''
              chain input {
                type filter hook input priority filter;
                iifname "${interface.name}" jump input-interface
              }
              chain input-interface {
                ct state vmap { established : accept, related : accept }
                fib daddr type { broadcast, multicast } accept
                ip daddr != ${interface.ipv4 { hostId = 1; }} drop
                ip6 daddr & ::ffff:ffff:ffff:ffff:ffff != 0:0:0:${toString interface.subnetId}::1 drop
                meta nfproto ipv4 udp sport 68 udp dport 67 accept comment "Allow DHCP"
                meta nfproto ipv6 udp sport 547 udp dport 546 accept comment "Allow DHCPv6"
                icmp type echo-request accept comment "Allow Ping"
                meta nfproto ipv4 meta l4proto igmp accept comment "Allow IGMP"
                ip6 saddr fe80::/10 icmpv6 type . icmpv6 code { mld-listener-query . 0, mld-listener-report . 0, mld-listener-done . 0, mld2-listener-report . 0 } accept comment "Allow MLD"
                icmpv6 type { destination-unreachable, time-exceeded, echo-request, echo-reply, nd-router-solicit, nd-router-advert } limit rate 1000/second burst 5 packets accept comment "Allow ICMPv6-Input"
                icmpv6 type . icmpv6 code { packet-too-big . 0, parameter-problem . 0, nd-neighbor-solicit . 0, nd-neighbor-advert . 0, parameter-problem . 1 } limit rate 1000/second burst 5 packets accept comment "Allow ICMPv6 Input"
                udp dport 53 accept comment "Allow DNS"
                ${interface.nftables.inputChain}
                drop
              }

              chain forward {
                type filter hook forward priority filter;
                iifname "${interface.name}" jump forward-interface
              }
              chain forward-interface {
                ct state vmap { established : accept, related : accept }
                ${interface.nftables.forwardChain}
                oifname {${lib.concatMapStringsSep "," (n: "\"${n}\"") wanNames}} accept
                drop
              }

              ${lib.optionalString (interface.nftables.srcnatChain != "") ''
                chain srcnat {
                  type nat hook postrouting priority srcnat;
                  oifname "${interface.name}" jump srcnat-interface
                }
                chain srcnat-interface {
                  ${interface.nftables.srcnatChain}
                }
              ''}

              ${lib.optionalString (interface.nftables.dstnatChain != "") ''
                chain dstnat {
                  type nat hook prerouting priority dstnat;
                  iifname "${interface.name}" jump dstnat-interface
                }
                chain dstnat-interface {
                  ${interface.nftables.dstnatChain}
                }
              ''}

              ${interface.nftables.extraConfig}
            '';
          };
        })
      //
        config.router.concatMapInterfaceAttrs (interface: !(interface.quarantine.enable or false))
          (interface: {
            "interface-${interface.name}" = {
              family = "inet";
              content = ''
                ${lib.optionalString (interface.nftables.inputChain != "") ''
                  chain input {
                    type filter hook input priority filter;
                    iifname "${interface.name}" jump input-interface
                  }
                  chain input-interface {
                    ${interface.nftables.inputChain}
                  }
                ''}

                ${lib.optionalString (interface.nftables.forwardChain != "") ''
                  chain forward {
                    type filter hook forward priority filter;
                    iifname "${interface.name}" jump forward-interface
                  }
                  chain forward-interface {
                    ${interface.nftables.forwardChain}
                  }
                ''}

                ${lib.optionalString (interface.nftables.srcnatChain != "") ''
                  chain srcnat {
                    type nat hook postrouting priority srcnat;
                    oifname "${interface.name}" jump srcnat-interface
                  }
                  chain srcnat-interface {
                    ${interface.nftables.srcnatChain}
                  }
                ''}

                ${lib.optionalString (interface.nftables.dstnatChain != "") ''
                  chain dstnat {
                    type nat hook prerouting priority dstnat;
                    iifname "${interface.name}" jump dstnat-interface
                  }
                  chain dstnat-interface {
                    ${interface.nftables.dstnatChain}
                  }
                ''}

                ${interface.nftables.extraConfig}
              '';
            };
          })
      // concatMapWanAttrs (interface: {
        "interface-${interface.name}" = {
          family = "inet";
          content = ''
            chain input {
              type filter hook input priority filter;
              iifname "${interface.name}" jump input-interface
            }
            chain input-interface {
              ct state vmap { established : accept, related : accept }
              meta nfproto ipv4 udp sport 67 udp dport 68 accept comment "Allow DHCP"
              meta nfproto ipv6 udp sport 547 udp dport 546 accept comment "Allow DHCPv6"
              icmp type echo-request accept comment "Allow Ping"
              meta nfproto ipv4 meta l4proto igmp accept comment "Allow IGMP"
              ip6 saddr fe80::/10 icmpv6 type . icmpv6 code { mld-listener-query . no-route, mld-listener-report . no-route, mld-listener-done . no-route, mld2-listener-report . no-route } accept comment "Allow MLD"
              icmpv6 type { destination-unreachable, time-exceeded, echo-request, echo-reply, nd-router-solicit, nd-router-advert } limit rate 1000/second burst 5 packets accept comment "Allow ICMPv6-Input"
              icmpv6 type . icmpv6 code { packet-too-big . no-route, parameter-problem . no-route, nd-neighbor-solicit . no-route, nd-neighbor-advert . no-route, parameter-problem . admin-prohibited } limit rate 1000/second burst 5 packets accept comment "Allow ICMPv6 Input"
              ${interface.nftables.inputChain}
              ct status dnat accept
              drop
            }

            chain forward {
              type filter hook forward priority filter;
              iifname "${interface.name}" jump forward-interface
            }
            chain forward-interface {
              ct state vmap { established : accept, related : accept }
              icmpv6 type { destination-unreachable, time-exceeded, echo-request, echo-reply } limit rate 1000/second burst 5 packets accept comment "Allow ICMPv6 Forward"
              icmpv6 type . icmpv6 code { packet-too-big . no-route, parameter-problem . no-route, parameter-problem . admin-prohibited } limit rate 1000/second burst 5 packets accept comment "Allow ICMPv6 Forward"
              ${interface.nftables.forwardChain}
              ct status dnat accept
              drop
            }

            chain srcnat {
              type nat hook postrouting priority srcnat;
              oifname "${interface.name}" jump srcnat-interface
            }
            chain srcnat-interface {
              ${interface.nftables.srcnatChain}
              meta nfproto ipv4 masquerade
            }

            ${lib.optionalString (interface.nftables.dstnatChain != "") ''
              chain dstnat {
                type nat hook prerouting priority dstnat;
                iifname "${interface.name}" jump dstnat-interface
              }
              chain dstnat-interface {
                ${interface.nftables.dstnatChain}
              }
            ''}

            ${interface.nftables.extraConfig}
          '';
        };
      });
  };
}
