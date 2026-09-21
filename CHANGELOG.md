# Changelog

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
