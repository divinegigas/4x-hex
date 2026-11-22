# Dark Fantasy Hex 4X — Game Design Outline

> Snapshot of the living design doc (Claude Docs). The live doc is the source of truth; refresh this copy when it changes.

2026-11-21 · Arlo

## 1. Overview

A turn-based, dark fantasy 4X strategy game for Android, played on a hex map where every round is a season. The depth lives in management: food, logistics, stamina and morale decide wars more than unit variety does.

**Platform and engine:** Android, built in Godot (develops natively on Fedora, exports to Android).

**Design pillars**

1. **Logistics wins wars.** Armies live and die by supply lines that can be seen, drawn, raided and starved.
2. **Seasons drive planning.** Food, movement, morale and XP all swing with the season; winter is a decision, not a pause.
3. **Stack the multipliers.** Morale, unit type, tier and commanders multiply together. Mastery is rewarded with huge swings, and the math is always shown.
4. **A living, hostile world.** City states, mercenaries and savages act on their own, and rebellion feeds those factions.
5. **Simple units, deep management.** Few unit types; complexity comes from economy, supply and command.

**Scope for version 1:** Humans only. All other races are designed as data so they slot in later (see section 5).

## 2. Turns, rounds and seasons

Every faction takes one turn per round, and each round is one season: spring, summer, fall, winter.

**Turn order:** set each round by the faction leader's Leader stat, highest first.

**Round flow**

1. Season flips: every tile swaps to its seasonal art and stats.
2. Each faction takes its turn in Leader-stat order (players, city states, mercenaries, savages).
3. End of round: food production and consumption resolve, stamina and morale update, supply connectivity is checked, starvation applies.

**Seasonal effects**

| Effect | Spring | Summer | Fall | Winter |
|---|---|---|---|---|
| Farm output | ×0.5 | ×1 (baseline) | ×2 | Almost none |
| Movement cost | Normal | ×0.5 | Normal | ×2 |
| Morale drift | Gain | — | — | Loss |
| XP gain | Normal | Normal | Normal | ×2 |
| Commander pool | Grows | — | — | — |

**Season-only content:** some resources or events can only be found in a specific season.

Winter is deliberately harsh (slow, hungry, demoralising) but doubles XP. That turns a winter campaign into a real gamble instead of a dead season. Possible extra winter upside: frozen rivers and lakes become passable (open question).

## 3. Map

The world is a hex tile map. Each tile has four seasonal states, each with its own art and stats.

- **Tile data:** terrain type, owner, improvement (district, farm, mine, camp, road), resource yields, movement cost, and a stat block per season.
- **Seasonal art:** four versions of every terrain type. Art source still to decide: asset packs, AI-generated art or simple stylised tiles.
- **Savage spawn tiles:** caves, swamps and similar terrain where savages appear. How many there are is set in game setup.
- **Ravaged tiles:** pillaged or ravaged land loses yield for a period (length to be decided).
- **Season-only features:** resources or sites that only appear in one season.

**Game setup options (so far):** number of savage spawn tiles. Likely more: map size, number of players and city states, victory conditions enabled.

## 4. Factions in play

Four categories of faction share the map. Only players found new cities; the other three exist to trade with, hire, fight or fear.

| Category | Who controls it | Role | Behaviour |
|---|---|---|---|
| Players | Human or AI | Full civilisations | Found cities, research, build armies, pursue victory |
| City states | AI (mini) | Neutral towns that grow into cities | Expand and grow like players but never found new cities; there to trade with or conquer |
| Mercenary bands | AI | Bounty hunters and raiders | Set up war camps; attack players and city states for bounties or resources |
| Savages | AI | Hostile monsters | Barbarians, werewolves, goblins, ogres; cannot be reasoned with; spawn from lair tiles |

### Rebellion lifecycle

Units, towns or parts of a population can rebel when morale falls below 50.

1. **Rebels become savages** for a set number of turns (x).
2. **They then become a mercenary band**, available for bounties and hire.

Rebellion feeds the neutral factions instead of being a plain penalty.

### AI build note

City-state AI is player AI minus founding cities and diplomacy. Build it first as a stepping stone to the full rival AI.

## 5. Races

Version 1 ships with Humans only. Every race is defined as data (stat modifiers, unit list, starting setup, resource rules), so adding one means adding a config file, not new code.

| Race | Status | Play style |
|---|---|---|
| Humans | Version 1 (baseline) | The standard ruleset everything else is measured against |
| Elves | Planned | Close to baseline, slight advantages and disadvantages (to be designed) |
| Orcs | Planned | Close to baseline, slight advantages and disadvantages (to be designed) |
| Dwarves | Planned | Close to baseline, slight advantages and disadvantages (to be designed) |
| Grey Aliens | Planned | Asymmetric; breaks the core loop on purpose |

### Race template

Fill one of these per race:

- **Starting setup:** starting city or other start, starting units
- **Stat modifiers:** economy, combat, morale, stamina, movement
- **Unit roster changes:** renamed, replaced or unique units per tier
- **Resource rules:** which resources they use and need
- **Seasonal quirks:** any changes to seasonal effects
- **Unique mechanic:** one thing that makes them play differently

### Humans (baseline)

Use every rule in this document as written. No modifiers.

### Elves

*To be designed using the template.*

### Orcs

*To be designed using the template.*

### Dwarves

*To be designed using the template.*

### Grey Aliens

Very weak start, strongest late game. Their aim is to stay unnoticed until they gain momentum.

- **Starting setup:** a crashed mothership (instead of a city), 1 builder, 2 squads of tier 5 ranged units.
- **Tech:** start at tier 1 technologies while they repair the mothership.
- **Units:** cannot replace their starting units. Cannot build units below tier 3; until tier 3 is unlocked and the infrastructure built, they can only build scouts and engineers.
- **Resources:** no food. They use building materials, gold and biomass. Biomass is gathered from any battlefield and from winning any fight, so they cannot expand without carnage.
- **Morale:** none. No morale bonuses or penalties, which also means no 4× stacking.
- **Early game:** preying on savage lairs gives biomass without alerting other players.

| Tier | Unit theme |
|---|---|
| 3 | Constructed horrors (Frankenstein-style stitched monsters) |
| 4 | Mutant monsters |
| 5 | "Perfect clones": true Grey Aliens with ray guns and plasma swords |

Their tier progression doubles as a reveal: other players see corpse-horrors first and only meet actual Greys late in the game.

## 6. Cities and districts

A city starts on one tile and grows outward: every district, farm, mine and military camp must sit on a tile adjoining the city or its existing development.

**Per turn, each city can do all of these at once:**

- Train a unit
- Upgrade a city tile
- Construct a new district

Resources are the limit, not action slots.

**Tile types (so far)**

| Tile | Purpose |
|---|---|
| City centre | Starting tile; upgradable |
| District | Specialised buildings (e.g. entertainment) |
| Farm | Food; output swings with the seasons |
| Mine | Stone and other materials |
| Military camp | Unit production and support |

**Example district: Entertainment.** Increases stamina and morale recovery at the cost of gold and food production.

**Engineers:** civilian engineers build civilian infrastructure. Whether cities can build districts, farms and mines without engineers is still open (see section 16).

*Full district list: to be designed.*

## 7. Resources and economy

Five resources, with food as the one that drives everything else.

| Resource | Main use |
|---|---|
| Manpower | Labour and recruits; scaled by stamina and pace |
| Food | Feeds population and armies; stored up to a cap |
| Wood | Building material |
| Stone | Building material |
| Gold | Upkeep, districts, bounties, ransoms |

Grey Aliens replace food with **biomass** (section 5).

### Food balance

Each turn, a city's food stock changes by production minus consumption.

```latex
\text{Food}_{next} = \min\left(\text{Cap},\ \text{Food}_{now} + \text{Production} - \text{Consumption}\right)
```

- **Production** depends on farms and the season (spring ×0.5, fall ×2, winter almost none).
- **Consumption** depends on population, armies fed from the city, and ration level.
- **Storage cap** limits stockpiling; raising it is a likely tech and district goal.

### When a city's food hits zero

- Stamina can no longer recover from food.
- Morale drops.
- Population shrinks, which lowers manpower and food demand. Rate still to set (suggested starting point: 10% per turn).

## 8. Health, stamina and morale

Cities and armies both have three stats: health, stamina and morale. Stamina scales output; morale multiplies it.

### Stamina

- **Effect:** manpower is multiplied by stamina. At 80% stamina, all manpower is ×0.8 for the turn.
- **Recovery:** set by the previous turn's activity (pace and rations), plus districts, technology and actions.

### Morale (0–200)

```latex
\text{Morale multiplier} = \frac{\text{Morale}}{100}
```

- 200 = ×2 to damage, productivity, or whatever that unit or city does. 100 = ×1. 50 = ×0.5.
- **Below 50:** risk of the unit, town or part of the population rebelling (suggested: 1% chance per turn for every point below 50).
- Whether 0 morale means 0 output, or there is a floor, is still open.

### Pace and rations

Two separate controls per city or army. Normal pace and normal rations change nothing.

| Setting | Output | Food use | Stamina | Morale |
|---|---|---|---|---|
| Low pace | Lower | — | Gain | — |
| Normal pace | ×1 | — | 0 | — |
| High pace | Higher | — | Loss | — |
| Half rations | — | ×0.5 | Loss | Loss |
| Normal rations | — | ×1 | 0 | 0 |
| Extra rations | — | ×2 | Faster recovery | Gain |

Example combo: high pace plus extra rations gives more output with stamina held steady, at double food cost. Exact numbers are still to tune (suggested starting values: pace ×0.75 / ×1 / ×1.25 output, stamina +10 / 0 / −10).

### What moves morale

| Raises morale | Lowers morale |
|---|---|
| Winning battles | Casualties |
| Extra rations | Half rations and starvation |
| Spring | Winter |
| Ravaging a captured city (huge bonus) | Moving more than x tiles in a turn |
| Executing a captured commander | Staying stationary outside a city for more than x turns |
| Entertainment districts, techs, commander skills | Supply lines being cut |

### Stamina costs

- Movement costs x stamina per tile.
- High pace and half rations drain stamina.

## 9. Logistics and supply lines

Armies can only operate fully inside a supply radius, and food reaches them through a physical network of roads and camps that can be raided.

### How the network works

1. **City radius:** a city can extend supply lines up to its radius (example: 10 tiles) in any direction.
2. **Supply camps:** built by engineers inside the radius. Each camp has its own radius (example: 8 tiles), so an army can push 8 tiles further and build the next camp.
3. **Lines:** roads connecting cities and camps are built in a logistics overlay menu, so there is a visible line from producers to consumers.
4. **Operating zone:** an army operates fully on any tile inside any connected camp's or city's radius.
5. **Tech** increases radii and the maximum number of camps in a chain away from a city.

### Delivery (version 1)

Food is delivered instantly anywhere on a connected network each turn. Each turn the game checks which camps and armies are still connected to a producing city. Capacity limits and transit time can be added later.

### Splitting lines

Lines can split as much as you like, but every branch draws from the same limited production. Feeding several armies from one line means one daring raid can collapse them all.

### Camps

- Cost resources to build, and more to fortify.
- Built and repaired by engineers or combat engineers (section 10).
- Store food. A cut-off camp keeps feeding its armies until the stock runs out: about 1–2 turns by default, more with investment.
- Suggested: storage is a fixed amount, so a camp feeding three armies runs dry three times faster than one feeding a single army.

### Breaking lines

- **Pillage a line:** move an army onto a road tile and pillage it.
- **Raid a camp:** attack it and steal its stored resources. Baseline loss is 20% of stored food, reduced by tech and investment.
- Repairing pillaged roads: done by engineers or combat engineers.

### Starving armies

- Morale drops.
- Troops die.
- Stamina cannot recover.
- Armies can pillage the land for food to soften this, with trade-offs (suggested: tile ravaged for 2–4 seasons, grievance from the owner and nearby city states).

### Visuals

Roads shown as auto-connecting road tiles, with carts moving along them. Routes are drawn by tapping hex to hex (better on touchscreens than dragging).

## 10. Units and combat

Six unit types at five tiers each. Battles are auto-resolved: armies are made of units, Total War style, but the player does not control the fight.

### Roster (Humans)

| Type | Role | Combat |
|---|---|---|
| Engineer | Builds civilian infrastructure; builds and repairs supply camps and lines | None |
| Combat engineer | Builds military infrastructure; builds and repairs supply camps and lines | Some |
| Infantry | Line troops | Beats cavalry |
| Cavalry | Mobile strike | Beats ranged |
| Ranged | Archers | Beats infantry |
| Siege | Breaks fortifications | Placement in the triangle still open |

Tiers 1–5 for every combat type. Suggested for siege: strong against cities, camps and fortifications, weak against all units, so it always needs an escort.

### Damage formula

```latex
\text{Damage} = \text{Base}_{tier} \times \text{Type} \times \frac{\text{Morale}}{100} \times \text{Stamina} \times \text{Commander} \times \text{Season} \times \text{RNG}
```

- **Type:** ×2 against the type it counters, otherwise ×1.
- **Tier:** higher tiers have higher base stats, so a tier 3 infantry still beats a tier 1 archer in a normal fight.
- **RNG:** ±15% on the final result.
- **Stacking is rewarded on purpose.** A tier 1 ranged unit at 200 morale gets ×4 against infantry and can smash low-morale tier 3 infantry.

### Battle preview

Before any attack, show the full math and the damage range (e.g. "expected 340–460"). Hidden values show as "?": some commanders have skills that hide their army's morale or stamina.

### Unit XP (veterancy)

- Units gain XP from every fight, more from wins, doubled in winter.
- A unit with enough XP rises a tier, if that tier's tech is unlocked.

### After a battle

The winner chooses what to do with a defeated army's commander:

- **Ransom** for gold
- **Execute** for morale
- **Interrogate** for information or technology

## 11. Commanders and officers

Every army is led by a commander whose bonus grows with level. Officers chain beneath them, and the bonuses stack, so one army can become legendary but also one starved supply line from disaster.

### Commanders

- Drawn from a limited **commander pool** that grows every spring.
- Have XP, rank and level.
- Each has one bonus type, which grows as they level. Examples: a unit type, attacking cities, defending cities, economy, morale.
- Some have skills that hide their army's morale or stamina from enemy battle previews.

### Officer chain

1. A commander reaching level 5 gains an officer.
2. That officer reaching level 5 gains their own officer.
3. And so on down the chain. All bonuses stack.

It is a chain, not a tree. A long chain puts all your eggs in one basket.

**Splitting:** officers can be split off to lead separate armies, spreading risk at the cost of the stacked bonus.

### XP

- Small amount every turn.
- Every fight gives XP; wins give more.
- All XP gains doubled in winter.

### Risk

- When an army is defeated, the winner can ransom, execute or interrogate its commander (section 10).
- Killing commanders is a primary bounty target (section 12).

## 12. Bounty purse

Players pay gold into a shared bounty purse and name targets. Anyone who kills those targets claims a payout: other players, AI, mercenaries, even city states.

### Rules

- **Targets:** armies, cities, players, or specific commanders (commanders are a primary target).
- **Payouts:** per kill and per district destroyed. Damage alone pays nothing; only casualties count.
- **Tier scaling:** killing higher-tier units pays a higher percentage of the purse.
- **Purse size:** the fuller the purse, the more each bounty pays and the harder it is pursued.
- **Funders cannot claim** their own bounties.
- **Funders are public** by default. A "sneaky" tech path makes them anonymous.

### Interactions

- Mercenaries hunt the richest bounties.
- Executing a high-level commander could raise bounties against you (open question).
- Ravaging cities could anger city states into funding bounties (open question).

## 13. Tech tree

Research advances every turn along a Civ-style tree. Branches are known from the systems above; specific techs are still to be designed.

| Branch | What it unlocks (so far) |
|---|---|
| Military | Unit tiers 2–5 for each type |
| Logistics | Larger city and camp radii; more camps per chain; cheaper or tougher camps; lower raid losses; bigger camp stores |
| Economy | Food storage cap; farm and mine output; districts |
| Morale and society | Recovery bonuses; entertainment and similar districts |
| Espionage | Anonymous bounty funding; revealing hidden morale and stamina (suggested) |
| Transcendence | The gateway project for the science-style victory |

Race-specific branches can be added per race through the race template (section 5).

## 14. Victory conditions

Three confirmed routes to victory, with room for more. Which ones are enabled is likely set in game setup.

| Victory | How you win | Status |
|---|---|---|
| Conquest | Defeat all other players' armies | Confirmed |
| Transcendence | Build a gateway to transcend reality (like Civ 5's spaceship) | Confirmed |
| Diplomacy | Be declared world leader | Confirmed; mechanics to design |
| Purge | Destroy every savage lair on the map | Suggested |

## 15. Technical architecture and build order

Build in playable layers, committing to git after each one works, and keep all tunable numbers in data files.

### Architecture principles

- **Engine:** Godot, exporting to Android.
- **Data-driven:** races, units, tiers, districts, techs, seasonal multipliers and balance numbers live in config files, not code.
- **Simulation separate from display:** game rules run without the UI, which makes AI-vs-AI testing and balance simulations possible.
- **Debug mode:** reveal all values, skip turns, spawn units, and run AI-vs-AI games for balance testing.
- **Project memory for Claude Code:** keep this doc plus a CLAUDE.md with architecture and conventions in the repo.
- **Mobile UI planned early:** a 4X game has a lot of information to fit on a phone screen.

### Build order

1. Hex map, tile data and season flipping
2. One city: resources, food balance, storage cap
3. Pace, rations, stamina and morale for cities
4. City expansion: adjacent districts, farms, mines, camps
5. Units, engineers and movement
6. Supply network: radius, camps, roads overlay, connectivity check, starvation
7. Auto-resolved combat with the battle preview
8. Commanders, officers and XP
9. Savages and lair spawning
10. Mercenaries and the bounty purse
11. City states (mini-AI)
12. Rival player AI
13. Tech tree depth and victory conditions
14. Art, audio and polish
15. Additional races, then Grey Aliens

### Biggest risks

- **Rival AI:** the hardest part by far. Start dumb-but-functional and improve over time.
- **Balance:** many multipliers stacking. Lean on simulations and playtesting.
- **Art volume:** four seasonal versions of every terrain.

## 16. Open questions

Tick these off as they are decided.

**Economy and cities**

- [ ] Do cities build districts, farms and mines directly, or do they need civilian engineers?
- [ ] Population shrink rate when food hits zero (suggested 10% per turn)
- [ ] Full district list and costs
- [ ] Starting resources and storage caps

**Stamina and morale**

- [ ] Exact pace and ration numbers
- [ ] Does 0 morale mean 0 output, or is there a floor?
- [ ] Rebellion chance formula below 50 morale
- [ ] Values of x: tiles moved before morale cost, turns stationary before morale loss, stamina per tile

**Logistics**

- [ ] Camp build and fortify costs
- [ ] Camp storage amounts
- [ ] Do pillaged roads need rebuilding or recover on their own?
- [ ] Pillage trade-offs (ravaged duration, grievances)
- [ ] Later: road capacity and transit time?

**Combat and commanders**

- [ ] Siege unit's place in the rock-paper-scissors
- [ ] Base stats per tier
- [ ] Commander bonus list and growth per level
- [ ] Commander pool size and spring growth
- [ ] Does executing a commander raise bounties against you?

**Factions**

- [ ] Rebellion: how many turns as savages before becoming mercenaries? Do rebels keep their units and tiers? Can the original owner reclaim them?
- [ ] Can players hire mercenaries directly?
- [ ] City-state diplomacy and trade rules
- [ ] Do savage spawns change with the seasons (e.g. werewolves in winter)?

**Seasons and victory**

- [ ] Winter upside: frozen rivers and lakes passable?
- [ ] Which resources or events are season-only?
- [ ] Diplomacy victory mechanics
- [ ] Add Purge victory?

**Races**

- [ ] Design Elves, Orcs and Dwarves using the race template
- [ ] Grey Aliens: biomass amounts, build costs, mothership repair path
