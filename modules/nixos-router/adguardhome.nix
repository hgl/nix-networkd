{
  lib,
  config,
  ...
}:
{
  services.adguardhome = {
    mutableSettings = false;
    host = "[::1]";
    port = 5380;
    settings = {
      dns = {
        bind_hosts = [ "::1" ];
        port = 1053;
        cache_size = 0;
        upstream_dns = lib.mkDefault config.networking.nameservers;
        bootstrap_dns = [ ];
        hostsfile_enabled = true;
      };
    };
  };
  # TODO: at runtime, extract upstream DNS servers from systemd DBus and assign
  # them to upstream_dns if networking.nameservers is empty
}
