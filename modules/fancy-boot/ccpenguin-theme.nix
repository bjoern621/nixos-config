# Plymouth theme on the script plugin.
# Bar images twice bar size on 1840 px tall panel.
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
    magick -size 720x20 xc:none -fill '#252525' -draw 'roundrectangle 0,0 719,19 10,10' $themeDir/track.png
    magick -size 720x20 xc:none -fill '#ffffff' -draw 'roundrectangle 0,0 719,19 10,10' $themeDir/fill.png
    substituteInPlace $themeDir/ccpenguin.plymouth --subst-var themeDir
  '';
}
