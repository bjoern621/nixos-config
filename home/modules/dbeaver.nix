{ pkgs, ... }:

{
  home.packages = [
    # The first-run "Product Configuration" wizard pins the UI thread at 100 %
    # under XWayland and never finishes, so it comes back on every launch
    # and the main window never opens. product.config.disable skips it.
    (pkgs.dbeaver-bin.overrideAttrs (old: {
      postInstall = (old.postInstall or "") + ''
        echo "-Dproduct.config.disable=true" >> $out/opt/dbeaver/dbeaver.ini
      '';
    }))
  ];
}
