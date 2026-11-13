# Anti Social addon

The in-game half of the dungeon finder. It cannot reach the internet (no addon can); the companion app does that. The design is in [../DESIGN.md](../DESIGN.md).

## Install

Copy the `AntiSocial` folder into the game's AddOns folder, for example:

```
D:\World of Warcraft\_retail_\Interface\AddOns\AntiSocial
```

Then tick "Anti Social" in the AddOns list on the character select screen.

## What it does

**For the group leader.** Click the minimap button (or type `/as`) to open the window, then paste the code from the companion (Ctrl+V). The addon shows the instance and the players, invites them, and marks each one as they join. "Invite again" re-invites only the players who are still missing.

The minimap button:

| Action | Does |
|---|---|
| Click | Open or close the window |
| Shift-click | Open an empty paste box; one Ctrl+V then invites and the window closes by itself |
| Right-click | Invite whoever is still missing from the current code |
| Drag | Move the button around the minimap |

An addon cannot read the clipboard, so the paste always has to be your own Ctrl+V. When the companion gives a new code (for example after a replacement), shift-click and paste again: players already in your party are skipped.

The addon also appears in the game's addon menu next to the minimap.

| Command | Does |
|---|---|
| `/as` | Open or close the window |
| `/as invite` | Invite whoever is still missing |
| `/as <code>` | Load a code typed or pasted into chat, and invite |
| `/as minimap` | Hide or show the minimap button |
| `/antisocial` | Same as `/as` |

The "Invite as soon as I paste" box is ticked by default. Untick it to review the list and press Invite yourself.

**For everyone.** The addon saves a snapshot of your character so the companion can show real stats instead of typed-in ones. The game only writes addon data to disk on `/reload` or logout, so after levelling or changing gear, press "Save stats now" in the window (it reloads the UI) before you queue.

## Saved data

Both live in `WTF\Account\<account>\SavedVariables\AntiSocial.lua`.

- `AntiSocialExport`: one line per character, read by the companion:

  ```lua
  ["Brakka Ironhide"] = "v1|Brakka Ironhide|horde|Warrior|42|Fury|31.5|1794559247",
  ```

  Fields: version, name, faction, class, level, spec, equipped item level, snapshot time (Unix seconds).

- `AntiSocialDB`: the auto-invite setting, and `lastGroup` (the last code used and who joined), kept for the companion to report joins once that is wired up.

## Bundled libraries

The minimap button uses the libraries most addons share for this, copied unchanged into `AntiSocial/Libs`: LibStub, CallbackHandler-1.0, LibDataBroker-1.1 and LibDBIcon-1.0. They belong to their own authors and keep their own licences. Using them is what makes the button work with addons that collect or restyle minimap buttons, such as Leatrix Plus.

## Not known yet

These depend on the probe (`../PROBE-TESTS.md`), which has not been run in the Forever client:

- Whether the client lets an addon send invites without a key press. If it does not, pasting will not invite by itself and the Invite button is the fallback.
- Whether names need anything added (a realm or region suffix) for invites to reach the right player.
- Whether spec and item level are readable in Forever. If not, those two fields are left empty.
