# Zen Shell v7.0.0-beta.1-hf94.4 — Karui (軽い)

Release date: 2026-05-30
Channel: beta · Codename: Karui (軽い)

**THE crash fix — root cause found via the backtrace.** Full vertical
bar restored. Wala tayong babawasan.

---

## Root cause (from report.txt stacktrace)

```
#1 QQmlContextData::initPropertyNames()
#2 … QQmlContextWrapper::getPropertyAndBase
#3 … QQmlContextWrapper::resolveQmlContextPropertyLookupGetter
```

The crash was a **QML context property-lookup recursion / segfault**, and
it was triggered by a change *I* made in `shell.qml`, NOT by the vertical
modules. (The diagnostic build with an empty BarVertical still crashed —
that's what proved the vertical content was innocent.)

In hf90.2 I had converted the bar mount from the original
`Bar { id: bar }` into:

```qml
Loader { id: barLoaderH; sourceComponent: Bar { } }
property var bar: barLoaderH.item     // ← the problem
…
Loader { id: barLoaderV; sourceComponent: BarVertical { } }
```

The bar window is instantiated **per-screen via `Variants`**. Declaring
`property var bar` on that delegate, while other bindings in the file
still resolve `bar` through the QML *context*, made Qt's context
property-name resolution recurse and segfault during scene setup. The
pre-existing `ZenDropdown`/`NetworkPulse` "[undefined]" warnings were
red herrings — unrelated and harmless.

## The fix

Restored the **original** direct mount and dropped the `property var bar`
entirely:

```qml
Bar { id: bar; anchors.fill: parent; visible: PanelState.isHorizontal }
BarVertical { anchors.fill: parent; visible: PanelState.isVertical }
```

- `id: bar` is back (context-resolvable everywhere, exactly as before the
  vertical work) → no context-lookup recursion.
- The horizontal `Bar` simply hides (`visible:false`) on a vertical bar
  instead of being unloaded — the horizontal tree is byte-identical to
  the known-good version.
- `BarVertical` is a plain sibling, shown only when vertical.
- The `bar.contentImplicitWidth/Height` readers are back to their
  original (un-guarded) form since `bar` always exists now.

The full module-loading `BarVertical.qml` (vertical Taskbar / Workspaces
/ Clock / SysRow / tray / music / window) is **restored** — the
diagnostic empty version is gone.

---

## Files touched

```
ZenVersion.qml   → v7.0.0-beta.1-hf94.4
shell.qml        bar mount reverted to direct `id: bar` + visible-gated;
                 BarVertical mounted as a visible-gated sibling;
                 bar.* readers restored to original (un-guarded)
BarVertical.qml  full module-loading version restored
```

Carries forward hf83–hf94.2 (the GridLayout `columns: 32` fix, the
WindowTitle no-rotation vertical, all the vertical module modes). The
horizontal bar matches the known-good pre-hf90 behavior.

> Lesson logged: never shadow a context-scoped `id` with a same-named
> `property` on a `Variants`/Repeater-instantiated delegate — Qt resolves
> the old id-references through the context and the name collision can
> recurse in `initPropertyNames` and segfault. Keep the `id`, gate with
> `visible`, don't reach for a Loader+property.
