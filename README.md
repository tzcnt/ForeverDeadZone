# Forever Dead Zone

A hunter range indicator for **WoW: Forever**. One small bar that tells you, for your
current target, which of four places you are standing in:

| Bar | Meaning |
|---|---|
| **IN RANGE** (green) | 8 to 35 yards. Auto Shot works. |
| **DEAD ZONE** (red) | Too close to shoot, and melee is not landing. You can do neither: move. |
| **MELEE** (blue) | Your melee swings are landing. |
| **TOO FAR** (grey) | Past 35 yards. |

It also shows a distance bracket, such as `IN RANGE  8-28 yd`.

Forever uses the vanilla hunter rule: Auto Shot has a **minimum** range of 8 yards as well
as a maximum of 35, and melee reaches about 5. The few yards in between are the dead zone.
Nothing in the default UI tells you that you are standing in it.

Hunters only. On any other class the addon does nothing at all.

## Commands

`/dz` or `/deadzone`

| Command | What it does |
|---|---|
| `/dz unlock` / `/dz lock` | Drag the bar where you want it |
| `/dz scale 2` | Size, 0.5 to 4 (default 1.5) |
| `/dz distance` | Show or hide the distance bracket |
| `/dz sound` | A warning sound when you enter the dead zone (off by default) |
| `/dz always` | Show the bar even with no target |
| `/dz keep on` / `off` | Keep your settings in a macro (see below) |
| `/dz reset` | Default position and size |
| `/dz probe` | Show which range checks the client answers for your target |

## Your settings and the beta client

The Forever beta client currently saves addon settings to disk but does not load them again,
so every addon starts from its defaults each time the game restarts. That is a Blizzard bug,
and it affects this bar's position and size like anything else.

Macros are stored with your account and do come back. `/dz keep on` copies this addon's few
settings into one general macro and reads it at login. It is opt-in because it uses one of
your macro slots; `/dz keep off` removes it. If Blizzard fixes the client, your normally
saved settings take priority and the macro is simply ignored.

## How it works, and what it cannot do

Everything here was measured on the beta client (build 1.60.1.69913), in and out of combat.

- **Can I shoot?** comes from the game's own range check on Auto Shot. On this client that
  answer stays readable in combat.
- **Too close or too far?** When Auto Shot says no, the 28 yard "follow" check says which.
- **Melee or dead zone?** This is the hard part. Nothing an addon can ask separates the
  first 8 yards: melee abilities report "in range" at any distance, and Forever's new
  swing-timer range function does not answer addons. So the addon watches the game's event
  for each of your auto attacks. A main-hand swing in the last swing-and-a-bit means melee
  is landing, and the bar shows MELEE. **The catch:** when something first reaches you, the
  bar reads DEAD ZONE until your first swing lands, about one swing later. It errs on the
  side of the warning.
- **Distance** is a bracket, not a number. The game does not tell addons how far away an
  enemy is. It will only answer "is the target within N yards?" for a handful of values of
  N, so the bar shows the gap between the nearest "no" and the nearest "yes". How tight that
  is depends on how many of those checks this client answers; `/dz probe` lists them.

No libraries, no dependencies, no combat log. It polls ten times a second, and only does any
work while you have an attackable target.

## Install

Copy the `ForeverDeadZone` folder into `World of Warcraft\_classic_beta_\Interface\AddOns`
(or install it with the CurseForge app), then log in. A brand new addon needs a full relog,
not just `/reload`.

## Licence

MIT. Written by Thunderz.
