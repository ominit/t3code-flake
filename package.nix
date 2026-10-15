{...}: {
  perSystem = {
    pkgs,
    system,
    ...
  }: let
    sources = builtins.fromJSON (builtins.readFile ./sources.json);

    mkT3code = channel: let
      info = sources.${channel}.${system};

      pname = "t3code";
      version = info.version;

      src = pkgs.fetchurl {
        inherit (info) url hash;
      };

      appimageContents = pkgs.appimageTools.extract {
        inherit version;
        pname = "${pname}-contents";
        inherit src;
      };
    in {
      appimage = pkgs.appimageTools.wrapType2 {
        inherit pname version src;
      };

      native = pkgs.stdenv.mkDerivation {
        inherit pname version;
        dontUnpack = true;
        dontStrip = true;

        nativeBuildInputs = with pkgs; [
          autoPatchelfHook
          makeWrapper
        ];

        buildInputs = with pkgs; [
          alsa-lib
          at-spi2-atk
          at-spi2-core
          atk
          cairo
          cups
          dbus
          expat
          gdk-pixbuf
          glib
          gtk3
          libgbm
          libsecret
          libx11
          libxcb
          libxcomposite
          libxdamage
          libxext
          libxfixes
          libxkbcommon
          libxrandr
          nspr
          nss
          pango
          stdenv.cc.cc.lib
          systemd
        ];

        runtimeDependencies = with pkgs; [
          (lib.getLib systemd)
          libGL
          libnotify
        ];

        installPhase = ''
          runHook preInstall

          appdir="$out/lib/${pname}"
          mkdir -p "$appdir" "$out/share"
          cp -r ${appimageContents}/. "$appdir/"
          chmod -R u+w "$appdir"

          rm -rf \
            "$appdir/.DirIcon" \
            "$appdir/AppRun" \
            "$appdir/t3code.png" \
            "$appdir/usr/lib" \
            "$appdir"/resources/app.asar.unpacked/node_modules/*/*-linux-x64-musl \
            "$appdir"/resources/app.asar.unpacked/node_modules/node-pty/prebuilds/linux-arm64
          mv "$appdir/usr/share/icons" "$out/share/icons"
          install -Dm444 "$appdir/t3code.desktop" "$out/share/applications/t3code.desktop"
          rm -r "$appdir/usr" "$appdir/t3code.desktop"
          substituteInPlace "$out/share/applications/t3code.desktop" \
            --replace-quiet "Exec=AppRun --no-sandbox %U" "Exec=AppRun %U" \
            --replace-fail "Exec=AppRun %U" "Exec=t3code %U"

          makeWrapper "$appdir/t3code" "$out/bin/t3code" \
            --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}"
          makeWrapper "$appdir/t3code" "$out/bin/t3" \
            --set ELECTRON_RUN_AS_NODE 1 \
            --add-flags "$appdir/resources/app.asar/apps/server/dist/bin.mjs"

          runHook postInstall
        '';

        meta = {
          description = "T3 Code desktop app and headless server";
          homepage = "https://t3.codes/";
          mainProgram = "t3code";
          platforms = ["x86_64-linux"];
          sourceProvenance = [pkgs.lib.sourceTypes.binaryNativeCode];
        };
      };
    };

    stable = mkT3code "stable";
    nightly = mkT3code "nightly";
  in {
    packages = {
      t3code = stable.native;
      t3code-appimage = stable.appimage;
      t3code-nightly = nightly.native;
      t3code-nightly-appimage = nightly.appimage;

      default = stable.native;
    };
  };
}
