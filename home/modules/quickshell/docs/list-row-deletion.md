# Deleting a single list row

A list with per-row delete buttons must drop one row without disturbing the rest:
the scroll position holds, and only the deleted row's delegate is torn down.
Which of the two model shapes backs the view decides whether that is possible.

## A plain-array model resets the whole view

A `ListView` bound to a plain JavaScript array (`model: someArray`) cannot remove one element.
The array is opaque to the view; the only way to change what it shows is to assign a new array.
Assigning a new array to `ListView.model` is a full model reset: every delegate is destroyed and recreated, and `contentY` snaps to `0`.

Two symptoms follow a delete done this way:

- The list jumps to the top, from the `contentY` snap.
- It flickers for one frame, because the entire visible set rebuilds and images re-source.

Restoring `contentY` after the reset hides the jump but not the flicker, since the rebuild still happens.
QML does no diffing on array models, so there is no incremental path here.

## A ListModel deletes incrementally

A `ListModel` supports `remove(index)`.
The view treats that as an incremental change: rows below the removed one shift up, `contentY` is preserved, and only the one delegate is destroyed.
No jump, no flicker, no `contentY` bookkeeping.

The delegate reads model roles as required properties, the same whether the view is a `ListView` or a `Repeater`:

```qml
delegate: Item {
    required property int index
    required property string clipId
    // one required property per role the row exposes
}
```

Delete finds the row by a stable key and removes it:

```qml
for (let i = 0; i < model.count; i++) {
    if (model.get(i).clipId === id) {
        model.remove(i);
        break;
    }
}
```

`NotificationList` applies this over a `Repeater`; `ClipboardHistory` applies it over a `LauncherListView`.

## Filtering is a reset; deleting is not

A search or filter changes every row and legitimately resets scroll to the top, so rebuilding the model wholesale (`clear()`, then `append()` per result) is correct there.
The clipboard keeps its filter source as a plain array (`allEntries`) and rebuilds `clipModel` from it on every keystroke.
A delete removes one known row and must leave the rest in place, so it takes the incremental `remove(index)` path and never rebuilds.

## Rule

Never reassign an array model to drop one row.
A view that supports row deletion is backed by a `ListModel`, and the delete calls `remove(index)`.
