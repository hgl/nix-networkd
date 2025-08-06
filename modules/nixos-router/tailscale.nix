{
  lib,
  config,
  ...
}:
{
  config = lib.mkIf (config.router.enable && config.services.tailscale.enable) {
    services.dnsmasq.settings = {
      server = [ "/ts.net/100.100.100.100" ];
    };
    services.tailscale.extraSetFlags = [ "--accept-dns=false" ];
  };
}
