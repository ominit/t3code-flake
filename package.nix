{...}: {
  perSystem = {
    pkgs,
    system,
    ...
  }: let
    info = (builtins.fromJSON (builtins.readFile ./sources.json)).${system};

    pname = "t3code";
    version = info.version;

    src = pkgs.fetchurl {
      url = info.appimage_url;
      hash = info.appimage_sha256;
    };

    appimageContents = pkgs.appimageTools.extractType2 {
      inherit version;
      pname = "${pname}-contents";
      inherit src;
    };

    t3code-appimage = pkgs.appimageTools.wrapType2 {
      inherit pname version src;
    };

    t3code = pkgs.stdenv.mkDerivation {
      inherit pname version;
      dontUnpack = true;

      nativeBuildInputs = with pkgs; [
        makeWrapper
      ];

      installPhase = ''
        runHook preInstall

        appdir="$out/lib/${pname}"
        mkdir -p "$appdir"
        cp -r ${appimageContents}/* "$appdir/"
        chmod -R u+w "$appdir"

        mkdir -p "$out/bin"
        app_bin=$(find "$appdir" -maxdepth 2 -type f -name 't3-code-desktop' | head -n1)
        if [ -z "$app_bin" ]; then
          echo "t3-code-desktop not found in extracted AppImage contents" >&2
          exit 1
        fi
        makeWrapper "$app_bin" "$out/bin/${pname}"

        mkdir -p "$out/share/applications"
        cat > "$out/share/applications/${pname}.desktop" <<EOF
        [Desktop Entry]
        Name=T3 Code
        Exec=t3code %U
        Terminal=false
        Type=Application
        Icon=t3code
        Categories=Development;
        EOF

        icon_file=$(find "$appdir" -type f -name 't3-code-desktop.png' | head -n1)
        if [ -n "$icon_file" ]; then
          install -Dm444 "$icon_file" "$out/share/pixmaps/t3code.png"
        fi

        runHook postInstall
      '';
    };
  in {
    packages = {
      inherit t3code t3code-appimage;

      default = t3code;
    };
  };
}
