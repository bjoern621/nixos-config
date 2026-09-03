# Popup geometry

A bar popup's rectangle is read by three consumers, each at a different moment:

- the `HoverHandler` in `widgets/HoverMenu.qml`, which decides `keepOpen`
- the window's input mask, `Region { item: popupItem }` in `windows/Bar.qml`
- the layer surface height, through `popupBottom` in `windows/Bar.qml`

The wrapper every popup sits in is `animations/PopReveal.qml`.
They agree only while the rules below hold.
Where they disagree the popup keeps drawing and stops answering the pointer,
which reads as a dead strip along one edge of a menu that is plainly still there.

## A masked item carries no transform

`Region` follows its item's geometry.
`scale`, `rotation` and `transform` are not geometry:
they change what the item draws without emitting a geometry change,
so a Region sampled during an animated transform holds that rectangle
until some later change to `x`, `y`, `width` or `height` happens to resample it.

`PopReveal` therefore runs its opacity, scale and slide on an inner stage item,
leaving its own rectangle at rest from the first frame.
Anything else that animates a popup animates a child,
leaving the masked item alone.

## A popup declares its implicit size

`Bar.popupBottom` reads `popupItem.y + popupItem.implicitHeight`.
`height` follows the layout and can answer a pass late,
and the value it feeds is latched,
so a popup carries an `implicitWidth` and `implicitHeight`
even where it also sets `width` and `height`.
`SystemTray`'s menu container is the one that sets both.

`Bar.popupBottom` also reads a popup's geometry before testing its visibility.
A short circuit registers no dependency on the size of a popup it skipped,
so a resize that happens while a menu is closed goes unseen.

## Size derives from the model

`childrenRect` measures what a layout settled on, and it answers a pass late.
`HoverMenu` and `ContentSlide` take their size from the one view they hold,
through that view's own `implicitWidth` and `implicitHeight`.

`HoverMenu` offsets its content by `gapHeight` and adds the same `gapHeight`
to its height, so its bottom edge sits flush with the view's.
There is no slack to absorb a late answer.

A view computes its own size from constants and font metrics
rather than from its laid-out children,
so its first evaluation is its final one.
`_heightFor` in `menus/CalendarMenu.qml` is the model for the calendar:
six week rows per month, the most any month takes,
so the card holds one height across years.

## The surface only grows

`Bar.implicitHeight` clears the tallest popup shown since the pill came out,
held in `popupSurfaceBottom` and reset at pill hide.
A shrink while the pill is out makes Hyprland scale the stale buffer
into the smaller box for one frame, squashing the pill to a sliver.
A fixed tall surface costs double-digit fps on the iGPU,
so the height stays dynamic and only ever grows.

## Checking a change

The shell lays out headless, so any of this is measurable without a compositor.
Copy the config, put the menus in a `FloatingWindow`, and run:

```sh
QT_QPA_PLATFORM=offscreen quickshell -p .
```

Call `show()` on each wrapper and sample across the whole reveal, every frame.
Two assertions cover this page:
each wrapper's height stays `view.height + gapHeight`,
and each wrapper's own `scale` stays 1.
