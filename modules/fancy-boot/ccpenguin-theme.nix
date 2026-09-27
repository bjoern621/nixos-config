# Plymouth theme on the built-in two-step plugin.
# Password dialog images come from plymouth's own spinner theme.
{
  stdenvNoCC,
  plymouth,
}:

stdenvNoCC.mkDerivation {
  pname = "plymouth-theme-ccpenguin";
  version = "1.0";

  src = ./ccpenguin;

  installPhase = ''
    themeDir=$out/share/plymouth/themes/ccpenguin
    mkdir -p $themeDir
    cp ccpenguin.plymouth watermark.png $themeDir/
    cp ${plymouth}/share/plymouth/themes/spinner/{bullet,capslock,entry,keyboard,keymap-render,lock}.png $themeDir/
    substituteInPlace $themeDir/ccpenguin.plymouth --subst-var themeDir
  '';
}
