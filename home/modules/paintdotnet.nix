{ config, pkgs, lib, ... }:

let
  winePrefix = "${config.home.homeDirectory}/.wine-paintdotnet";

  # Paint.NET 3.5.11 — last version that works well under Wine (Silver on WineHQ).
  # Versions 4.x/5.x require .NET Desktop Runtime + Direct2D and are rated Garbage.
  paintdotnetInstaller = pkgs.fetchurl {
    url = "https://archive.org/download/Paint.NET3.5.11/Paint.NET.3.5.11.Install.exe";
    hash = "sha256-p7WhlpQxjuQKolRPVE3tflJIfpFwY+1eeXHYBmFq6AI=";
  };

  wine = pkgs.wineWow64Packages.stable;

  paintdotnet = pkgs.writeShellScriptBin "paintdotnet" ''
    export WINEPREFIX="${winePrefix}"
    export WINEDLLOVERRIDES="winemenubuilder.exe=d"

    PAINTDOTNET_EXE="$WINEPREFIX/drive_c/Program Files/Paint.NET/PaintDotNet.exe"

    if [ ! -f "$PAINTDOTNET_EXE" ]; then
      echo "First run: setting up Paint.NET wine prefix..."

      # Initialize prefix
      ${wine}/bin/wineboot --init 2>/dev/null
      ${wine}/bin/wineserver --wait

      # Set Windows version to XP for best compatibility
      ${wine}/bin/wine reg add "HKCU\\Software\\Wine" /v Version /t REG_SZ /d winxp /f 2>/dev/null
      ${wine}/bin/wineserver --wait

      # Install Paint.NET silently
      ${wine}/bin/wine "${paintdotnetInstaller}" /auto 2>/dev/null
      ${wine}/bin/wineserver --wait

      echo "Paint.NET installation complete."
    fi

    # Launch Paint.NET, passing any file arguments
    exec ${wine}/bin/wine "$PAINTDOTNET_EXE" "$@" 2>/dev/null
  '';
in
{
  home.packages = [
    paintdotnet
    wine
  ];

  xdg.desktopEntries."paintdotnet" = {
    name = "Paint.NET";
    genericName = "Image Editor";
    exec = "paintdotnet %F";
    icon = "applications-graphics";
    terminal = false;
    type = "Application";
    categories = [ "Graphics" "2DGraphics" "RasterGraphics" ];
    mimeType = [
      "image/png"
      "image/jpeg"
      "image/bmp"
      "image/gif"
      "image/tiff"
    ];
  };
}
