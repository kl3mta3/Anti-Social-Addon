# AntiSocial LFG

<img src="https://lfgforever.org/img/icon.png" width="96" align="right" alt="">

**A dungeon finder for World of Warcraft: Forever.**

Pick a dungeon and a role, keep playing, and get pulled into a full group. No chat spam, no whispering strangers.

**[Get it at lfgforever.org](https://lfgforever.org)**

![The AntiSocial LFG window in game](https://lfgforever.org/img/addon.png)

## How it works

1. **Queue.** Choose Tank, Healer or DPS and the dungeons you want, then carry on playing.
2. **Ready check.** When five players match, everyone gets 60 seconds to accept. Anyone who doesn't answer is replaced.
3. **Invites.** One player is the leader. They paste a short code into this addon and it invites everyone.
4. **Run it, then rate your group.** Thumbs up or down for each player. Future groups see the totals.

It forms the group. It does not teleport you, so you travel to the dungeon the usual way.

## What you need

- World of Warcraft: Forever
- This addon
- The free **LFG Forever companion app** for Windows 10 or 11, from [lfgforever.org](https://lfgforever.org)

You need both. Addons cannot connect to the internet, so the app finds your group and the addon sends the invites.

## Install

**The easy way**

1. Download and run the companion app.
2. Open its Settings and press **Install or update the addon**.
3. Start the game, or type `/reload` if it is already running.

**By hand**

1. Download the zip from the [latest release](https://github.com/kl3mta3/Anti-Social-Addon/releases/latest).
2. Unzip it into `Interface\AddOns` inside your game folder.
3. On the character select screen, open AddOns and tick **AntiSocial LFG**.

You should see a new button on your minimap.

## How to use it

### First time

1. Log in to your character with the addon installed.
2. Click the minimap button and press **Save stats now**.
3. Pick that character in the companion app.

That's all the setup there is.

### When you get a group

**If you are the leader**, the companion shows a code with a **Copy** button.

1. Press **Copy**.
2. In game, **shift-click the minimap button**.
3. Press **Ctrl+V**.

Everyone is invited and the window closes by itself.

**If you are not the leader**, accept the party invite when it arrives. There is nothing else to do.

### If someone is missing

- **Someone didn't get their invite, or declined by mistake:** right-click the minimap button. It invites only the players who are still missing.
- **Someone was replaced:** the companion gives the leader a new code. Paste it the same way. Players already in the party are skipped.

### After you level up or change gear

Open the addon window and press **Save stats now** before you queue. This updates the level and item level the companion shows for you. (The game only saves addon data when the interface reloads, so the button does a quick reload.)

## The minimap button

| Do this | And it |
|---|---|
| Click | Opens or closes the window |
| Shift-click | Gets ready for a paste: press Ctrl+V and everyone is invited |
| Right-click | Invites whoever is still missing |
| Drag | Moves the button around the minimap |

## Chat commands

| Type | And it |
|---|---|
| `/as` | Opens or closes the window |
| `/as invite` | Invites whoever is still missing |
| `/as minimap` | Hides or shows the minimap button |

## Troubleshooting

**The addon isn't in my AddOns list.**
Check the folder. It should be `Interface\AddOns\AntiSocial`, with `AntiSocial.toc` directly inside it. If you see `AntiSocial\AntiSocial`, move the inner folder up one level.

**I can't see the minimap button.**
Type `/as minimap` to bring it back. If you use an addon that tidies minimap buttons, look in its collection.

**Nothing happens when I paste.**
Shift-click the minimap button first, then press Ctrl+V. If you opened the window with a normal click, click inside the box before pasting. Copy the code again with the companion's Copy button to make sure you have all of it.

**It says only the party leader can invite.**
You are already in a party that someone else leads. Leave it, or ask for lead, then paste again.

**The companion doesn't list my character, or shows an old level.**
Log in to that character, open the addon window and press **Save stats now**.

## Is it safe?

- The invites are ordinary party invites. The addon only uses functions every addon is allowed to use.
- It does not read your chat, automate your character, or talk to other players' addons.
- The only thing it saves is your character's name, faction, class, level, spec and item level, so the companion can fill them in for you.
- There are no accounts and no passwords.

This is a fan project, not an official Blizzard feature. Blizzard could change what addons are allowed to do, and parts of this could stop working if they do.

## Links

- Website and companion download: [lfgforever.org](https://lfgforever.org)
- Companion app source: [kl3mta3/Anti-Social-App](https://github.com/kl3mta3/Anti-Social-App)
- Found a bug or have an idea? [Open an issue](https://github.com/kl3mta3/Anti-Social-Addon/issues)

## Credits

The minimap button uses LibStub, CallbackHandler-1.0, LibDataBroker-1.1 and LibDBIcon-1.0, which belong to their own authors.

---

World of Warcraft is a trademark of Blizzard Entertainment, Inc. AntiSocial LFG is a fan project and is not affiliated with, endorsed by or sponsored by Blizzard Entertainment.
