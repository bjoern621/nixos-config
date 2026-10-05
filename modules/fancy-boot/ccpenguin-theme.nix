# Plymouth theme on the script plugin.
# Bar pills match BAR_WIDTH and BAR_HEIGHT in ccpenguin.script.
{
  stdenvNoCC,
  imagemagick,
}:

stdenvNoCC.mkDerivation {
  pname = "plymouth-theme-ccpenguin";
  version = "2.0";

  src = ./ccpenguin;

  nativeBuildInputs = [ imagemagick ];

  installPhase = ''
    themeDir=$out/share/plymouth/themes/ccpenguin
    mkdir -p $themeDir
    cp ccpenguin.plymouth ccpenguin.script watermark.png $themeDir/
    magick -size 280x8 xc:none -fill '#252525' -draw 'roundrectangle 0,0 279,7 4,4' $themeDir/track.png
    magick -size 280x8 xc:none -fill '#ffffff' -draw 'roundrectangle 0,0 279,7 4,4' $themeDir/fill.png
    substituteInPlace $themeDir/ccpenguin.plymouth --subst-var themeDir
  '';
}
