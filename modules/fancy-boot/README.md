# Fancy Boot

Silent boot behind a Plymouth splash showing ccpenguin, the ancestor of Tux, above a thin rounded progress bar.

The `ccpenguin` theme runs on Plymouth's `script` plugin.
`ccpenguin/ccpenguin.script` sizes the picture, the bar and the gap between them as fractions of each display's height.
Every monitor shows the same layout, whatever its resolution.
`plymouth.force-scale=1` on the kernel command line keeps Plymouth from doubling the images on the laptop panel after the script has sized them.
The bar shows during boot.
Shutdown and reboot show the picture alone.
A LUKS passphrase prompt appears below the bar, one `*` per typed character.

The bar images come from ImageMagick at build time, in `ccpenguin-theme.nix`.

## Picture

`ccpenguin/watermark.png` comes from [File:Ccpenguin, the ancestor of Tux.jpg](https://en.wikipedia.org/wiki/File:Ccpenguin,_the_ancestor_of_Tux.jpg) on the English Wikipedia, which hosts it as a non-free file under fair use.
The script scales it to 28 % of the display height, which upscales it on every panel taller than 1028 px.

## Preview

From a text console (Ctrl+Alt+F3), since Plymouth needs the display the compositor holds:

```
sudo plymouthd
sudo plymouth show-splash
sleep 5
sudo plymouth quit
```
