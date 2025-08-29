{ lib, lib' }:
{
  # like lib.types.oneOf but instead of a list takes an attrset
  # uses the field "type" to find the correct type in the attrset
  # copied from disko
  taggedSubmodule =
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
                  options.type = lib.mkOption {
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
}
