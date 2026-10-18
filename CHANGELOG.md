# Changelog

## v0.3.3

- Use the Attack toggle for an earlier melee estimate when the five-yard item check is unavailable. Enable the game's Auto Attack / Auto Shot switching for this inference.
- Prioritize Auto Shot range when backing out, even if Attack remains active briefly.
- Refresh Attack state from toggle events and show its status in `/dz probe`.
- Retain per-frame range updates from the local v0.3.2 change.

## 0.3.1
- Fixed: settings were saved to the macro but not restored at login. The client returns the macro text with trailing whitespace, which the reader did not allow for.
- `/dz keep` now says what happened at login: restored, not needed, or unreadable (and why).

## 0.3.0
First public version.

- One bar, four states for a hunter's current target: IN RANGE (8-35 yd), DEAD ZONE, MELEE, TOO FAR.
- Distance bracket on the bar, built from every range check the client answers.
- Melee is inferred from your own auto attack swings, because no range call an addon can
  make separates melee from the dead zone on this client.
- `/dz keep on`: optional settings macro, since the Forever beta client does not load saved
  addon settings. Never writes before it has read, never touches macros in combat.
- Warning sound on entering the dead zone, off by default.
- Drag to move, `/dz scale` to size. Does nothing on non-hunters.
