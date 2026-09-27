# Fancy Boot

Silent boot behind a Plymouth splash showing ccpenguin, the ancestor of Tux, above a thin progress bar.

The `ccpenguin` theme runs on Plymouth's built-in `two-step` plugin and carries no script.
Plymouth draws the picture and the bar on every connected monitor and scales both on HiDPI panels.
The bar shows during boot.
Shutdown and reboot show the picture alone.

## Picture

`ccpenguin/watermark.png` comes from [File:Ccpenguin, the ancestor of Tux.jpg](https://en.wikipedia.org/wiki/File:Ccpenguin,_the_ancestor_of_Tux.jpg) on the English Wikipedia, which hosts it as a non-free file under fair use.
The file measures 288 px tall.
Plymouth doubles that on a scale-2 panel.

A replacement picture of a different height needs `WatermarkVerticalAlignment` and `ProgressBarVerticalAlignment` in `ccpenguin/ccpenguin.plymouth` moved to match.

## Preview

From a text console (Ctrl+Alt+F3), since Plymouth needs the display the compositor holds:

```
sudo plymouthd
sudo plymouth show-splash
sleep 5
sudo plymouth quit
```
