{ lib, lib' }:
{
  forAllSystems = lib.genAttrs lib.systems.flakeExposed;
  mapListToAttrs = f: list: lib.listToAttrs (map f list);
  concatMapAttrsToList = f: attrs: lib.concatLists (lib.mapAttrsToList f attrs);
  concatMapListToAttrs = f: list: lib.zipAttrsWith (name: values: lib.last values) (map f list);
  addressPortString =
    {
      address ? "",
      port ? null,
    }:
    "${if lib.hasInfix ":" address then "[${address}]" else address}${
      lib.optionalString (port != null) ":${toString port}"
    }";
  decToHex =
    let
      intToHex = [
        "0"
        "1"
        "2"
        "3"
        "4"
        "5"
        "6"
        "7"
        "8"
        "9"
        "a"
        "b"
        "c"
        "d"
        "e"
        "f"
      ];
      toHex' = q: a: if q > 0 then (toHex' (q / 16) ((lib.elemAt intToHex (lib.mod q 16)) + a)) else a;
    in
    v: toHex' v "";
}
