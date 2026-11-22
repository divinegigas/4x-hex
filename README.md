# Dark Fantasy Hex 4X

A turn-based dark fantasy 4X strategy game for Android, built in Godot 4.3.
Every round is a season; food, logistics, stamina and morale decide wars.

- Design: [`docs/design.md`](docs/design.md)
- Architecture and conventions: [`CLAUDE.md`](CLAUDE.md)

## Running

Install Godot 4.3+ (on Fedora: the official binary from godotengine.org, or `flatpak install flathub org.godotengine.Godot`).

```sh
godot --path .                                         # play
godot --headless --import && godot --headless --script res://tests/run_tests.gd   # tests
```

Controls: drag to pan, pinch or mouse wheel to zoom, tap a hex to inspect it,
**End round** to advance the season.

## Android export

In the editor: Editor → Manage Export Templates (install 4.3 templates), set the
Android SDK and debug keystore under Editor Settings → Export → Android, then
Project → Export → Add Android preset. `export_presets.cfg` is git-ignored because
it can contain keystore credentials.
