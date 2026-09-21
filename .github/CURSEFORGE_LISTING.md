# CurseForge listing: Forever Dead Zone

Paste these into the "Create Project" form. Logo: `.github/logo.png` (1024x1024).

**Name:** Forever Dead Zone

**Summary** (one line):
Hunter range bar for WoW: Forever. Shows when you can shoot, when you are in melee, and when you are stuck in the dead zone between them.

**Game:** World of Warcraft
**Class / type:** Addons
**Main category:** Hunter  (under Class)
**Extra categories:** Combat; Unit Frames is NOT a fit. If a second one is wanted: "HUD" or "Miscellaneous".
**Game version:** the "forever" / 1.60.1 version (same as ForeverCDM)
**Licence:** MIT License
**Source URL:** https://github.com/Thunderz96/ForeverDeadZone
**Issues URL:** https://github.com/Thunderz96/ForeverDeadZone/issues

---

## Description (paste into the description box)

**Forever Dead Zone** is a small range bar for hunters in WoW: Forever.

Forever uses the vanilla hunter rule. Auto Shot reaches from **8 to 35 yards**, and melee reaches about 5. In the few yards between them you can neither shoot nor swing. That gap is the dead zone, and nothing in the default UI tells you when you are standing in it.

This addon does. For your current target, one bar shows:

- **IN RANGE** (green): 8 to 35 yards, Auto Shot works
- **DEAD ZONE** (red): too close to shoot and your melee is not landing. Move.
- **MELEE** (blue): your melee swings are landing
- **TOO FAR** (grey): past 35 yards

It also shows a distance bracket such as "8-28 yd".

### Commands
`/dz` lists everything. The main ones:
- `/dz unlock` and `/dz lock` to move the bar
- `/dz scale 2` for size
- `/dz distance` to show or hide the distance
- `/dz sound` for an optional warning sound when you enter the dead zone
- `/dz keep on` to keep your settings in a macro

### About saved settings on the beta
The Forever beta client does not currently load saved addon settings, so every addon resets when the game restarts. `/dz keep on` stores this addon's few settings in one general macro and reads them back at login. It is optional, and `/dz keep off` removes the macro.

### Good to know
- Hunters only. It does nothing on other classes.
- The game does not tell addons the exact distance to an enemy, so the distance is a bracket, not a single number.
- The game also gives addons no way to tell melee range from the dead zone directly. The addon works it out from your own auto attacks, so when an enemy first reaches you the bar shows DEAD ZONE until your first swing lands.
- No libraries and no dependencies. It only does any work while you have an attackable target.

Everything it relies on was measured on the live beta client. The README on GitHub explains how.
