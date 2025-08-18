{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    networkd-ipmon = {
      url = "github:hgl/networkd-ipmon";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs =
    {
      self,
      nixpkgs,
      networkd-ipmon,
      ...
    }:
    let
      inherit (nixpkgs) lib;
      lib' = import ./lib {
        inherit lib lib';
      };
    in
    {
      lib = lib';
      nixosModules = {
        default = self.nixosModules.nix-networkd;
        nix-networkd = import ./modules/nix-networkd {
          inherit networkd-ipmon;
        };
      };
      devShells = lib'.forAllSystems (system: {
        default =
          let
            pkgs = nixpkgs.legacyPackages.${system};
            packages = with pkgs; [
              nil
              nixfmt-rfc-style
            ];
          in
          derivation {
            name = "shell";
            inherit system packages;
            builder = "${pkgs.bash}/bin/bash";
            outputs = [ "out" ];
            stdenv = pkgs.writeTextDir "setup" ''
              set -e

              for p in $packages; do
                PATH=$p/bin:$PATH
              done
            '';
          };
      });
    };
}
