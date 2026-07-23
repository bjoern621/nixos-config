# Scrolling and the scroll gutter

Every scrollable surface in the shell draws its scrollbar as a `ScrollHandle`
overlaid on the right edge of the content.
The handle floats over the content rather than displacing it, so the content
must give up a strip of width on its right, the *gutter*, or the bar sits on top
of the rightmost pixels of each row.

The gutter is one value, `Spacing.scrollGutter`.
It is the widest bar (neo, 8px) plus breathing room on each side.
Changing it there changes every scrollable surface at once.

The gutter is reserved only while the content actually overflows.
A list short enough to fit needs no bar and no gutter, and gets the full width.

## Two ways to scroll

### ScrollView, automatic gutter

`ScrollView` wraps an internal `Flickable` + `Column` + `ScrollHandle` and
reserves the gutter itself.
Default children fill the internal `Column`, so a `Repeater` of rows drops
straight in.
Use it for menu lists whose rows are cheap to render in full (network, bluetooth
device lists): the `Column` renders every child, with no virtualization.

```qml
ScrollView {
    width: parent.width
    height: Math.min(implicitHeight, 300)   // clamp; implicitHeight is full content

    Repeater {
        model: SomeService.rows
        SomeRow { required property var modelData; data: modelData }
    }
}
```

`implicitHeight` tracks the full content height, so a `Math.min` against a cap
gives a list that grows to its content and then scrolls.
Rows bind their width to `parent.width`, so they shrink with the `Column` when
the gutter appears and never sit under the bar.
The wheel steps by default; `wheelStride` overrides the step size for off-size
rows.
See the Wheel behavior section.

### ListView / GridView, manual gutter

A large model (launcher apps, clipboard entries, emoji) needs the virtualization
of `ListView` or `GridView`, which `ScrollView`'s `Column` does not provide.
There the view reserves the gutter by hand and a sibling `ScrollHandle` overlays
it:

```qml
ListView {
    id: list
    width: parent.width - (scrollable ? Spacing.scrollGutter : 0)
    readonly property bool scrollable: contentHeight > height + 1
    // ...
}
ScrollHandle {
    target: list
    visible: list.scrollable
    anchors { right: parent.right; top: list.top; bottom: list.bottom }
}
```

`LauncherListView` and `LauncherGridView` expose the `scrollable` flag; a bare
`Flickable` computes it inline as above.

A fixed-cell `GridView` drops a whole column when the gutter eats into its width,
so the emoji picker widens its panel by `Spacing.scrollGutter` instead, keeping
all columns beside the bar.

## Choosing between them

`ScrollView` for a bounded list of rows.
`ListView` / `GridView` + sibling `ScrollHandle` for a large or unbounded model,
or for fixed-cell grids.
Both reserve the same `Spacing.scrollGutter`; the difference is who reserves it.

## Wheel behavior

Every scrollable surface scrolls with `StepWheel`: a proportional step of
`rowsPerNotch` rows per mouse notch (default 1.5), with no inertia.
The stepped feel is the shell-wide convention, so a surface must not fall back to
the native `Flickable` wheel, whose momentum reads as inconsistent next to the
stepped surfaces.
`StepWheel` accepts mouse and touchpad; `rowStride` is one row's height, plus the
column spacing when the column has any.

Each container opts in differently:

- `ScrollView`: stepped by default through its internal `StepWheel`, so a plain
  `ScrollView` is already correct. `wheelStride` overrides the step size for rows
  far from the default.
- `ListView` / `GridView` through `LauncherViewBehavior`: the behavior already
  carries a `StepWheel`, so nothing is added.
- A bare `Flickable` or `ListView` without that behavior: add a `StepWheel` child
  whose `target` is the view and whose `rowStride` is the row height, as
  `AppLauncher` and `NotificationList` do.

## Styling

`ScrollHandle` reads its own theme-aware defaults (thin muted bar under blur,
chunky ink bar in neo), so a bare `ScrollHandle { target: view }` looks right in
both themes.
It self-manages visibility (`contentHeight > height + 1`) and self-manages the
drag; the consumer only supplies `target` and the anchors.
