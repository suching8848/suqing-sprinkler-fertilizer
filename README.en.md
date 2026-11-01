# SuQing’s Irrigation Care Mod / 蘇清的灌溉养护模组

[中文](README.md) | English

![Irrigation Care cover](publishing/preview.png)

A single-player Water Pipes add-on with pump-fed fertilizer and disease treatments, sprinkler reservoirs, a management window and refillable care packs. Current version: **1.0.0**, for **Project Zomboid Build 42.21 single-player**. The user reported normal play with the current version; local stable-release preparation is complete. The Workshop item has not been uploaded yet.

## Dependencies and companion patches

- Required: [Water Pipes](https://steamcommunity.com/sharedfiles/filedetails/?id=3546314080), Workshop ID `3546314080`, Mod ID `Waterpipes`. Load this add-on after Waterpipes.
- This add-on's fixed Mod ID is `SuQingSprinklerFertilizer`. Batch Farming, Neat Crafting and other SuQing mods are not required. The Neat Crafting category icon is an optional UI integration.
- [SuQing's Patch Collection](https://github.com/suching8848/suqing-project-zomboid-patches/) contains separate optional mods. Its `SuQingBatchFarmingMenu_4221` only filters Batch Farming menus; it is relevant when using Batch Farming and does not supply this add-on's pump, resource or crop-care logic.

## Installation and upgrading

1. Fully exit the game and back up the target save before changing an installed version.
2. Copy `mods/SuQingSprinklerFertilizer` into your user `Zomboid/mods` directory. Enable `Waterpipes` and this add-on in the intended single-player save, with this add-on after Waterpipes. Retain the existing Mod ID when upgrading, and install only one copy of that ID.
3. Restart the game. The mod migrates 0.1/0.2 stock, switches, Farming levels and stored old spray bottles. New resource switches default to off; sprinkler network reception defaults to on.

The crafting category is **SuQing Irrigation Upgrades**. Existing pumps and sprinklers can be managed directly; no physical upgrade component is required.

## Device management and crop care

Right-click a pump or sprinkler and open its care-management window. It shows five resource stocks, capacity, per-use cost, switches and available sources. Enter a quantity, fill to capacity or reclaim stock without closing the window. Loading uses non-favorited items in the main inventory and carried bags.

Each resource holds **200 doses per sprinkler** or **1000 per pump**. Fertilizer, mildew, flies, aphids and slugs have independent stocks and switches. Vanilla fertilizer and corresponding treatments are accepted. Three vanilla sprays immediately return their empty bottle when exhausted; partial loading keeps the remaining contents. Old deposited spray bottles are reclaimable while their balance remains.

Network supply is consumed only when a sprinkler actually waters crops. It follows pipe ports, floors, branches and valves. A pump with no water, a stopped pump or a disconnected route cannot supply care; only water and tainted-water sources qualify. Network stock has priority, then enabled local stock. Multiple pumps are considered in stable device-ID order; one operation is not split across insufficient sources.

Care affects a same-floor circle with radius 5. Fertilizer is used only on eligible living crops with vanilla fertilizer state zero. Treatment requires the corresponding disease and uses the original farming effects, normally reducing it by 10 plus the supplier's Farming level. Later watering cycles may treat it again. The add-on grants no extra experience and does not change vanilla watering, yields or manual farming. Healthy crops, missing water and missing stock consume nothing. Overlapping sprinklers process each crop/resource once per cycle and avoid queued manual or batch care actions.

## Network view and per-project controls

The window shows the current device, capacity and network summary. The network page lists reachable sprinklers from a pump, or connected pumps from a sprinkler, with stocks and switches. It refreshes connections every 0.75 seconds while open. Stopped or dry devices remain visible as connected; supply availability is shown separately. Devices disconnected during this window session remain listed with an unreachable marker; removed devices and unloaded areas are identified. Closing the window clears that temporary view history.

The latest watering cycle is based on callbacks observed in the current game session; saved water levels are not presented as a newly observed cycle. Available supply is conditional, and consumption still requires actual watering and crop demand.

From a nearby pump, select a sprinkler in the network page to change each project's overall care switch and pump-input switch:

- Project off: that sprinkler performs no care of that type, from either pump or local stock.
- Project on, pump input on: use pump stock first, then enabled local stock.
- Project on, pump input off: use local stock only. The first pump-input adjustment enables local fallback for an already-enabled project.
- Disabling overall network reception disables all pump inputs; re-enabling one input restores only that resource.

Pump supply switches remain independent. Remote actions change settings only; they cannot remotely load or reclaim stock. Each click checks player proximity to the pump, current connectivity, loaded devices, device identity and queued actions. Dry or stopped connected devices can be configured in advance. Walk to a target to open its local management page.

The ledger remains schema 3. Optional `projectDisabled` and `networkDisabled` fields record new settings; untouched switches retain their previous behavior. Dismantled-stock recovery appears only when records exist, and disappears when the last record is reclaimed.

## Care-pack recipes

**50-dose packs use the vanilla ingredient amount; 200-dose packs use four times that amount.**

| Treatment | 50 doses | 200 doses |
| --- | --- | --- |
| Mildew | 1 L milk, no extra water | 4 L milk, no extra water |
| Flies: cigarettes | 1 L water + 5 single cigarettes | 4 L water + 20 single cigarettes |
| Flies: loose tobacco | 1 L water + 8 tobacco uses | 4 L water + 32 tobacco uses |
| Flies: chewing tobacco | 1 L water + 5 chewing-tobacco uses | 4 L water + 20 uses |
| Aphids | 1 L water + 0.2 L rubbing alcohol | 4 L water + 0.8 L rubbing alcohol |
| Slugs: added recipe | 1 L water + 1 salt item | 4 L water + 4 salt items |

Initial crafting also consumes 1/2 planks for the small/large pack. Refilling uses one matching empty pack instead of planks. The slug salt recipe is an addition because vanilla has no corresponding craft recipe. Salt is consumed as whole items; tobacco and chewing tobacco are counted in uses.

There are 24 recipes across four treatment types, two sizes, the three flies-treatment ingredient routes and refilling. No extra spray bottle, bucket, pot, tool or recipe magazine is required. Fluids come from available fluid items without consuming their containers and may be combined across containers by vanilla crafting.

Packs work with this add-on's devices, not as direct replacements for manual sprays. An exhausted pack becomes a same-size empty pack that can be refilled with any treatment. Partial packs retain their doses and show the remaining amount in the name. Full weights are 1.3/4.6; empty weights are 0.3/0.6. Old carried packs are reweighed when entering the game or opening management without losing doses; retrieve stored old packs and open management to refresh them.

## Costs, recovery and saves

The sandbox page has five independent consumption multipliers, default **1**, range **0.01–2**. They change consumption only, not effects or existing stock. One dose is represented by 10,000 integer units. The next operation reads updated sandbox values; upgrading does not edit the save's sandbox file. A personal save may use a value such as 0.05 (0.05 doses per operation); personal settings do not change release defaults.

**Only reclamation or dismantling discards a fraction below one dose.** Reclaiming 12.75 doses returns 12 and discards 0.75; normal automatic consumption retains fractions. Treatment reclamation needs enough empty packs; the three sprays also accept empty spray bottles. Without sufficient packaging, no stock is reclaimed or deducted. Fertilizer and vanilla slug treatment need no empty spray bottle. Reclamation switches off that resource's local supply.

New residue packs are no longer created. The old `SQSF.CareResidue` item remains solely for conversion: loading it transfers whole doses, discards the fraction and removes the old item.

An independent ledger prevents copying stock by copying or moving objects. Normal dismantling puts whole-dose stock into the recovery page, reclaimable at another pump/sprinkler with packaging. Replaced devices start empty. Water Pipes' internal `silentRemove` replacements do not trigger refunds. The acceptance checklist retains focused moving and save/reload checks for future regression passes.

## Validation and removal

Offline tests run the installed game's Kahlua VM, real `SPlantGlobalObject` methods and the installed Water Pipes watering callback with controlled scene, inventory and UI fixtures. Native Java checks cover loading 24 recipes, doses and serialization. Executing window Lua does not validate its in-game appearance. On 2026-11-02 the user reported normal single-player play. This is overall play feedback rather than a record that every test branch was individually exercised. See the [1.0.0 release notes](docs/RELEASE_1.0.0.md), [focused acceptance checklist](docs/TESTING_0.3.2.md), [development notes](docs/DEVELOPMENT.md) and [offline tool instructions](tools/README.md).

Changes to audited upstream source disable automatic operation while preserving recovery access. Crops using vanilla farming methods are supported; compost and multiplayer are not. This is not a claim of compatibility with every modded fruit tree.

Before disabling, switch off care, reclaim device and pending recovery stocks, and handle the custom full/empty packs. **Do not overwrite a save that has stored 0.3 data with 0.2:** schema 3 needs conversion or a verified pre-upgrade full-save restore, which would roll back later progress.

The repository retains mod files, tools, tests, docs, generated icon prompts and publishing metadata. Local validation outputs, release ZIPs, compiler caches and private settings are excluded from Git. Six transparent 128×128 icons were generated with image_gen from the user's reference concept and the other SuQing mods' style; [prompts](art/icon-prompts.json) are retained.

Thanks to Water Pipes author Slayer. This independent add-on does not bundle game, Water Pipes or Batch Farming source code or artwork. No open-source license has been assigned. The existing Git history is retained for the 1.0.0 release preparation; Workshop upload and public visibility are separate publishing actions.

## Related projects and setup snapshot

[All eight mod and patch repositories](docs/project-index.md) · [Current 205-ID enabled order](docs/current-single-player-modlist.md) · [Author’s Steam collection](https://steamcommunity.com/sharedfiles/filedetails/?id=3823981387)

The source index covers 37 Mod IDs. The Steam collection does not include separately installed local patches; select entries using each project’s requirements and conditional integration notes. Enabled state does not establish in-game acceptance of every project or new version.
