{lib, ...}: {
  perSystem = {self', ...}: {
    checks = let
      packages = lib.mapAttrs' (n: lib.nameValuePair "package-${n}") self'.packages;
    in
      packages;
  };
}
