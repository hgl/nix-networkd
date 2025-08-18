{
  lib,
  nixosRouterLib,
  config,
  pkgs,
  ...
}:
let
  lib' = nixosRouterLib;
  wanInterfaces = lib.filterAttrs (_: interface: interface.type == "wan") config.router.interfaces;
  update-ddns =
    ipVer: domain:
    { zoneIdFile, apiTokenFile, ... }:
    let
      name = "update-ddns-ipv${toString ipVer}-${domain}";
    in
    assert lib.assertMsg (zoneIdFile != null) "zoneIdFile must not be empty";
    lib.getExe (
      pkgs.writeShellApplication {
        inherit name;
        runtimeInputs = with pkgs; [
          coreutils
          curl
          jq
        ];
        text = ''
          first() {
            echo "''${1-}"
          }
          # shellcheck disable=SC2086
          ip=$(first ''${IPV${toString ipVer}_ADDRS-})
          if [[ -z $ip ]]; then
            exit
          fi
          ip=''${ip%/*}
          zoneId=$(< ${zoneIdFile})
          token=$(< ${apiTokenFile})
          recordId=$(
            curl --disable --fail --silent --show-error --location \
              --max-time 10 --retry 10 --retry-delay 3 \
              --request GET \
              --url "https://api.cloudflare.com/client/v4/zones/$zoneId/dns_records" \
              --header 'Content-Type: application/json' \
              --header "Authorization: Bearer $token" |
              jq --raw-output --arg d ${domain} \
              'first(.result[] | select(.type == "${if ipVer == 6 then "AAAA" else "A"}" and .name == $d)).id'
          )
          curl --disable --fail --silent --show-error --location \
            --max-time 10 --retry 10 --retry-delay 3 \
            --request PATCH \
            --url "https://api.cloudflare.com/client/v4/zones/$zoneId/dns_records/$recordId" \
            --header 'Content-Type: application/json' \
            --header "Authorization: Bearer $token" \
            --data "{\"content\": \"$ip\"}"
        '';
      }
    );
in
{
  config = {
    services.networkd-ipmon = {
      enable = wanInterfaces != { };
      rules = lib.concatMapAttrs (
        _: interface:
        lib'.concatMapListToAttrs (
          ddns:
          lib.optionalAttrs (ddns.enable == true || (ddns.enable == "ipv6")) {
            "ddns-ipv6-${lib.elemAt ddns.domains 0}" = {
              interfaces = [ interface.name ];
              properties = [ "IPV6_ADDRS" ];
              script = update-ddns 6 (lib.elemAt ddns.domains 0) ddns.provider;
            };
          }
          // lib.optionalAttrs (ddns.enable == true || (ddns.enable == "ipv4")) {
            "ddns-ipv4-${lib.elemAt ddns.domains 0}" = {
              interfaces = [ interface.name ];
              properties = [ "IPV4_ADDRS" ];
              script = update-ddns 4 (lib.elemAt ddns.domains 0) ddns.provider;
            };
          }
        ) interface.ddns
      ) wanInterfaces;
    };
  };
}
