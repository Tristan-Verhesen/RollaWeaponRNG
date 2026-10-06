# Roll a Weapon ⚔

A medieval-fantasy RNG game for Roblox. Roll for weapons from a rusty dagger (1 in 2) to
Excalibur (1 in 1,000,000), find relics across five zones, rise from Peasant to King, then swear
an Oath and begin again stronger.

Built with **Rojo** and **strict Luau**. Every script is `--!strict` and type-checks cleanly with
`luau-lsp`. The game rules live in pure modules with 67 unit tests that run outside Roblox.

---

## Quick start (Windows, into `C:\Roblox\RollaWeaponRNG`)

1. **Install the tools (one time)**
   - [Git for Windows](https://git-scm.com/download/win)
   - [Rokit](https://github.com/rojo-rbx/rokit#installation): download `rokit-…-windows-x86_64.zip`
     from the releases page, unzip it, and run `.\rokit.exe self-install`. Restart your terminal
     afterwards.
   - [Roblox Studio](https://create.roblox.com/)
   - Recommended: [VS Code](https://code.visualstudio.com/). The repo suggests the luau-lsp,
     StyLua, Selene and Rojo extensions when you open it.

2. **Get the code** (PowerShell):

   ```powershell
   git clone -b claude/clever-cerf-iyubla https://github.com/Tristan-Verhesen/RollaWeaponRNG.git C:\Roblox\RollaWeaponRNG
   cd C:\Roblox\RollaWeaponRNG
   rokit install      # rojo, wally, selene, stylua, lune, luau-lsp (pinned in rokit.toml)
   wally install      # downloads ProfileStore into ServerPackages/
   ```

3. **Connect Studio**

   ```powershell
   rojo plugin install   # once; installs the Rojo plugin into Studio
   rojo serve
   ```

   In Studio, create a new **Baseplate** place, open the **Rojo** plugin tab and click **Connect**.

4. **Enable saving.** Publish the place (File > Publish to Roblox), then go to Game Settings >
   Security and turn on **Enable Studio Access to API Services**. Without this, ProfileStore uses
   temporary mock data and nothing is saved.

5. **Press Play.** A placeholder world is generated automatically: five floating zone islands,
   joined by bridges and sealed by gates.

### Controls

| Action | Keyboard | UI |
| --- | --- | --- |
| Roll | `R` | Big **ROLL** button |
| Toggle Auto-Roll (gamepass) | `T` | **Auto** button |
| Armory / Relics / Chivalry / Market | none | Left-side menu |

---

## How the game works

### Rolling
- Every weapon has its own **"1 in N"** odds. Its rarity tier (Common through Exalted), color and
  reveal cutscene are derived from N.
- A roll walks the current zone's pool **rarest first**. Each weapon gets an independent check
  at `luck / N`, and the first hit wins. If nothing hits, you get the zone's most common weapon.
  More luck divides every N, and once luck exceeds a weapon's N, more common items stop dropping.
- **Blessed Roll:** every 10th roll gets ×2 luck. The HUD counts down to it.
- **Bad-luck protection (pity):** go 150 rolls without a Rare (1,500 for Epic, 20,000 for
  Legendary) and the next roll is upgraded to one. Pity only ever upgrades a roll, never
  downgrades it.
- **Rare announcements:** server-wide banner and chat line at 1 in 10,000+, and realm-wide
  across all servers (MessagingService) at 1 in 250,000+.

### Luck

```
luck = (1 + rank + zone + equipped weapon + equipped relics + relic set bonuses)
       × oath multiplier × Blessing of Fortune pass × luck potions
       (× 2 on a Blessed Roll)
```

The **Luck breakdown** button on the HUD lists every source and your pity counters.

### Zones (physical)
| Zone | Opens at | Luck | Gold × |
| --- | --- | --- | --- |
| Hamlet Outskirts | Peasant | +0% | 1 |
| Darkwood Forest | Squire | +10% | 1.5 |
| Barrow Crypts | Knight | +20% | 2.5 |
| Dragonspine Peaks | Baron | +35% | 4 |
| The Fallen Citadel | Duke | +50% | 6 |

You roll from the pool of the zone you're standing in, or the last one you stood in. Gates are
solid for everyone, but each player's client opens the gates they have unlocked. The server also
returns anyone found inside a locked zone to their spawn.

### Relics
Each zone has 4 relics. Every roll also makes an independent relic check, using
`luck ^ 0.5` so stacked luck doesn't trivialize them. Equipped relics grant luck, gold or roll
speed. Finding all four relics of a zone grants a permanent **set bonus**. Duplicate relics are
melted down for gold.

### Chivalry (ranks and Oaths)
Peasant → Serf → Squire → Man-at-Arms → Knight → Knight-Banneret → Baron → Earl → Duke → King.
Rising a rank needs rolls and gold, and grants luck, relic slots and new zones. A King may swear an
**Oath**: rank, gold and rolls-this-oath reset, and you gain a permanent luck multiplier (×1.5,
×2, …). Your armory, relics and opened zones are kept.

### Economy
Sell duplicates for gold: `N^0.75 × zone gold multiplier × your gold bonus`. You can set
auto-sell (Off, or up to Epic) in the Armory. When the armory is full, duplicates are auto-sold,
but never Legendary or rarer, and never your first copy.

### Monetization (placeholders)
Every id in [`src/shared/Config/Products.luau`](src/shared/Config/Products.luau) is `0`. Create
the items on the Creator Dashboard and paste in the ids; no other code changes are needed.

- Gamepasses: **Blessing of Fortune** (×2 luck), **Squire's Diligence** (Auto-Roll), **Swift
  Hands** (40% faster rolls), **Royal Armory** (+1,200 storage).
- Developer products: **Potion of Fortune** (×2 luck, 10 min), **Elixir of Kings** (×3 luck,
  5 min), **Draught of Haste** (+35% speed, 10 min). Bought potions go into a satchel and are
  drunk from the Market. Timers only tick while you're online.

Receipts follow ProfileStore's recommended pattern: each `PurchaseId` is granted once and only
reported as granted after it has been saved.

---

## Making it yours

| I want to… | Edit |
| --- | --- |
| Add or rebalance weapons | `src/shared/Config/Weapons.luau` (then run the simulator) |
| Add relics or change bonuses | `src/shared/Config/Relics.luau` |
| Change zones | `src/shared/Config/Zones.luau` |
| Change rank costs or rewards | `src/shared/Config/Ranks.luau` |
| Tune cooldowns, pity, Blessed Roll, announcements, Oaths | `src/shared/Config/GameConfig.luau` |
| Set gamepass and product ids | `src/shared/Config/Products.luau` |
| Restyle the UI | `src/client/UI/Theme.luau` |

**Custom weapon models.** Put a Model (with a PrimaryPart or a part named `Handle`) or a single
part in `ReplicatedStorage.Assets.WeaponModels`, named after the weapon id (e.g.
`citadel_excalibur`). It replaces the procedural model both in-hand and in the Armory preview.

**Your own map.** The placeholder world is only built when nothing is tagged `Zone`. To use
your own:
1. Cover each zone with an invisible, anchored, non-colliding part. Tag it `Zone` and add a
   string attribute `ZoneId` (`Hamlet`, `Darkwood`, `Crypts`, `Dragonspine`, `Citadel`).
2. Optionally tag gate parts `ZoneGate` and spawn pads `ZoneSpawn`, both with a `ZoneId`.

---

## Project layout

```
src/
├── shared/                  → ReplicatedStorage.Shared
│   ├── Config/              content and tuning (weapons, relics, zones, ranks, products, rules)
│   ├── Logic/               pure game rules: RollMath, RollEngine, Stats, Economy, Progression
│   ├── Types.luau           every shared type (PlayerData, Snapshot, RollResult, ...)
│   ├── Net.luau             remote definitions
│   ├── DataTemplate.luau    default save data
│   └── WeaponModels.luau    procedural or custom weapon models
├── server/                  → ServerScriptService.Server
│   ├── init.server.luau     boots services (init, then start)
│   ├── Services/            Data, Pass, Zone, State, Character, Announcement, Roll,
│   │                        Inventory, Rank, Boost, MapBuilder
│   └── Util/                Remote (rate-limited handlers), RateLimiter, Validate
└── client/                  → StarterPlayerScripts.Client
    ├── Controllers/         State mirror, Roll/auto-roll, Zone gates
    └── UI/                  HUD, roll reveal, toasts, zone titles, windows
tests/                       Lune test runner + specs (logic runs outside Roblox)
scripts/
├── check.luau               runs every CI check locally
└── simulate.luau            progression/balance simulator
```

**Server-authoritative by design.** The client only *asks*. Every remote is rate-limited and
validates its arguments (types, ranges, NaN, ownership), and the server rolls with its own RNG
and enforces the cooldown. The server never invokes the client.

---

## Development

```powershell
lune run scripts/check            # format check, lint, tests, strict type check, build
lune run scripts/check -- --fix   # same, but formats files instead of checking
lune run tests/run                # unit tests only (filter: lune run tests/run -- rollengine)
lune run scripts/simulate         # balance sim: time to each rank, first of each rarity
lune run scripts/simulate -- 7 2 LuckyBlessing QuickRoll   # seed, oaths, owned passes
```

Sample simulator output (default seed, no passes, auto-rolling):

```
Rank             Rolls      Played     Luck
Squire           125        2:05       x1.27
Knight           1K         16:37      x1.63
Baron            4K         1:04:17    x2.17
King             16.4K      4:29:51    x3.41
```

CI (`.github/workflows/ci.yml`) runs the same checks on every push and uploads a built `.rbxl`.
