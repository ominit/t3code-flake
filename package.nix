{...}: {
  perSystem = {
    inputs',
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

    codex = inputs'.llm-agents.packages.codex;

    withCodex = base:
      pkgs.symlinkJoin {
        name = "${base.name or "${pname}-${version}"}-with-codex";
        paths = [base];
        nativeBuildInputs = [pkgs.makeWrapper];
        postBuild = ''
          if [ -x "$out/bin/${pname}" ]; then
            wrapProgram "$out/bin/${pname}" \
              --prefix PATH : "${pkgs.lib.makeBinPath [codex]}"
          fi
        '';
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

        desktop_file=$(find "$appdir" -maxdepth 3 -type f -name '*.desktop' | head -n1)
        exec_name=""
        icon_name=""
        if [ -n "$desktop_file" ]; then
          exec_name=$(sed -n 's/^Exec=//p' "$desktop_file" | head -n1 | cut -d' ' -f1)
          icon_name=$(sed -n 's/^Icon=//p' "$desktop_file" | head -n1)
        fi

        mkdir -p "$out/bin"
        app_bin=""
        for candidate in \
          "$appdir/t3code" \
          "$appdir/t3-code-desktop"
        do
          if [ -n "$candidate" ] && [ -x "$candidate" ] && [ ! -d "$candidate" ]; then
            app_bin="$candidate"
            break
          fi
        done
        if [ -z "$app_bin" ] && [ -n "$exec_name" ] && [ -x "$appdir/$exec_name" ] && [ ! -d "$appdir/$exec_name" ]; then
          app_bin="$appdir/$exec_name"
        fi
        if [ -z "$app_bin" ] && [ -n "$exec_name" ]; then
          app_bin=$(find "$appdir" -maxdepth 3 -type f -name "$exec_name" -perm -0100 | head -n1)
        fi
        if [ -z "$app_bin" ]; then
          app_bin=$(find "$appdir" -maxdepth 3 -type f \( -name 't3code' -o -name 't3-code-desktop' -o -name 'AppRun' \) -perm -0100 | head -n1)
        fi
        if [ -z "$app_bin" ]; then
          echo "Unable to locate a T3 Code executable in extracted AppImage contents" >&2
          exit 1
        fi
        makeWrapper "$app_bin" "$out/bin/${pname}"

        mkdir -p "$out/share/applications"
        if [ -n "$desktop_file" ]; then
          sed \
            -e 's|^Exec=.*|Exec=t3code %U|' \
            -e 's|^Icon=.*|Icon=t3code|' \
            "$desktop_file" > "$out/share/applications/${pname}.desktop"
        else
          printf '%s\n' \
            '[Desktop Entry]' \
            'Name=T3 Code' \
            'Exec=t3code %U' \
            'Terminal=false' \
            'Type=Application' \
            'Icon=t3code' \
            'Categories=Development;' \
            > "$out/share/applications/${pname}.desktop"
        fi

        icon_file=""
        if [ -n "$icon_name" ]; then
          icon_file=$(find "$appdir" -type f \( -name "$icon_name.png" -o -name "$icon_name.svg" -o -name "$icon_name.xpm" -o -name "$icon_name.ico" \) | sort | tail -n1)
        fi
        if [ -z "$icon_file" ]; then
          icon_file=$(find "$appdir" -type f \( -name 't3code.png' -o -name 't3code.svg' -o -name 't3-code-desktop.png' \) | sort | tail -n1)
        fi
        if [ -n "$icon_file" ]; then
          install -Dm444 "$icon_file" "$out/share/pixmaps/t3code.png"
        fi

        runHook postInstall
      '';
    };

    t3code-with-codex = withCodex t3code;
    t3code-appimage-with-codex = withCodex t3code-appimage;
  in {
    packages = {
      inherit t3code t3code-appimage t3code-with-codex t3code-appimage-with-codex;

      default = t3code;
    };
  };
}
