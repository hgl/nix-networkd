{
  lib,
  nixosRouterLib,
  config,
  ...
}:
let
  lib' = nixosRouterLib;
  inherit (config.services.adguardhome.settings.dns) bind_hosts port;
  upstream = "${lib'.addressPortString {
    address = lib.elemAt bind_hosts 0;
    inherit port;
  }}";
in
{
  config = lib.mkIf config.router.enable {
    services.resolved =
      {
        llmnr = "false";
        extraConfig = ''
          Cache=false
        '';
      }
      // lib.optionalAttrs config.services.adguardhome.enable {
        dns = [ upstream ];
      };
  };
}
