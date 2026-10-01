# Upper City 30H

A multiplayer, original Upper City campaign for 2–5 players. Vite modules separate UI, Supabase transport, campaign content, and the database state machine. Thirty chapters span a prologue, four acts, and a finale. The chapters are a framework for group roleplay with shared choices, clues, combat, and a persistent log; a full 30-hour tabletop experience also depends on the players' roleplay pace.

## Deploy

1. In Supabase Auth settings, enable **anonymous sign-ins**. Apply `db/002_secure_campaign.sql`, `db/003_encounters.sql`, `db/004_campaign_battles.sql`, and `db/005_classes_spells.sql`, and `db/006_deeper_campaign.sql` in order. This migrates the old demo schema and removes its public write policies. Existing unbound demo players are not imported as authenticated members. After changing `src/encounters.js`, run `npm run campaign:sql`; after changing `src/battles.js`, run `npm run battles:sql`; after changing `src/powers.js`, run `npm run powers:sql`. For dialogue, battle squads, or merchant changes, run `npm run deeper:sql` and apply the new migration before the matching frontend deployment. Deploy generated SQL before the corresponding frontend.
2. Set `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` in Vercel. These are **public browser credentials**, not a service role key. Never set a service role key with `VITE_`.
3. Vercel framework preset: Vite; build command `npm run build`; output directory `dist`; install command `npm install`. Deploy the source from the main branch.
4. Open production in two independent browser profiles. The second profile must sign in anonymously with its own Supabase identity. Run the acceptance flow in the request.

## Architecture

- `src/campaign.js`: original chapter and class data. Choice definitions are also seeded server side to prevent a client from fabricating flags or clues.
- `src/encounters.js`, `db/003_encounters.sql`: 60 authored investigation and social beats with server-owned DC, outcomes, clues, and state. Each chapter requires both beats before the branch decision.
- `src/battles.js`, `db/004_campaign_battles.sql`: ten original fights distributed across the acts. Enemy numbers, aid from earlier decisions, initiative, attacks, rewards, and camp recovery are calculated in the database.
- `src/powers.js`, `db/005_classes_spells.sql`: seven professions, 44 class powers, milestone levels 1–12, spell circles 1–6, slots, once-per-chapter rest, server-owned damage, healing, wards and debuffs. The paladin's circle 6 is a campaign house rule, not standard D&D 5e.
- `src/api.js`: anonymous auth, RPC transport, realtime subscriptions, and polling recovery.
- `src/main.js`, `src/style.css`: interface.
- `db/002_secure_campaign.sql`: migration, authenticated membership, atomic RPC commands, host checks, server dice/combat, realtime tables. Direct writes to gameplay tables are revoked.

The room code is an invitation, not authorization. Every joining browser gets its own anonymous Auth user. Local storage keeps only its last room code; the Supabase session persists the identity. A player who clears browser storage cannot recover that anonymous identity automatically. Host succession is explicit on departure and claimable after five minutes without heartbeat. Realtime broadcasts may be missed while offline, so clients also poll every 12 seconds.

## Current scope

The 30 original chapters include three primary NPC dialogue decisions, two original investigation checks, an additional named witness with ten authored lines and chapter-specific follow-up and post-investigation dialogue, a hidden-object check, companion interjections at ten pivotal moments, class routes, and a final branch. Ten battles use independent 2–3 enemy squads with server-owned target HP, AC, initiative, enemy retaliation and rewards. Six merchants and 13 items unlock across the acts; weapons change attack and damage, armor changes AC, and an NPC support choice can discount prices. Dialogue choices persist and appear in later scenes. Run each act as a group session: discuss NPC motives, roleplay open actions in the party log, investigate both leads, make a shared choice, and let the host advance. Earlier allies and discovered secrets can change later dialogue, lower enemy AC, or avoid ordinary fights; mandatory boss battles remain. Combat terrain now offers blasts, cover, pushing, and blocked reinforcements. Story milestones raise levels; a completed fight restores surviving allies on advancing, and a host can request one long rest per chapter outside combat. This is a compact original ruleset, not a complete fifth-edition engine or half of Baldur's Gate 3. Grid movement, reaction timing, concentration, detailed enemy AI, subclasses, and party split remain future additions.

## v3.0 migration

Apply `db/012_v30_story_depth.sql` after `db/011_xp_progression.sql`, then `db/013_v30_battle_aftermath.sql`, `db/014_v30_followup_dialogue.sql`, and `db/015_v30_encounter_routes.sql` before deploying the matching frontend. Rebuild both after editing `src/deep-story.js` or `src/battle-aftermath.js` or `src/deep-followups.js` with `npm run v30:sql`. New state is stored in the existing room state JSON; old save slots load with empty defaults. The migrations keep the existing room, player, quest, merchant, chapter and save tables. Battle aftermaths provide one server-owned investigation and unique clue/item plus XP to each player; only the actual victor can collect it once.

## V4.0 continuation checkpoint (2026-09-30)

Recovered from remote `feat/v4-identity-world` at `d9431a5` without reverting the
previous work. The production baseline is `ee09bba` (V3.1). The existing V4 preview
built successfully, but the shared Supabase database still has no V4 functions.
A successful frontend build alone does not enable V4 gameplay.

This continuation integrates racial/feat checks into the ordinary authored
investigations, moves feat damage before turn completion, applies enemy damage
immunity/resistance/vulnerability, starts concentration before immediate enemy
retaliation, cancels advantage against disadvantage, validates missing race and
ancestry values, and enforces camp/jail permissions. The UI exposes all six saving
throw attributes and retains race, ancestry and saving-throw selections during
realtime refresh. Host-only camp controls reflect the server permissions.

Database release order: apply `db/018_v40_identity_rules.sql` through
`db/030_v40_internal_permissions.sql` in ascending order, **once, in a transaction**, then
release the matching frontend. Migrations 018/021/022 rename existing functions;
they must not be replayed. Migration 029 verifies patch anchors and preserves
all existing chapter content and the V3 transport/turn engines. These migrations
change the shared RPC behavior: V3 clients do not expose the camp required for
rest, so do not apply them to the live database while retaining the V3 frontend.
Use an isolated preview database or a coordinated V4 release.

Validation: `npm test` runs nine suites covering V2–V4, including old save slots,
second-player re-entry, server authorization, three-phase finale transitions and
new seeded combat regressions. `npm run build` checks the frontend bundle.
Browser acceptance, a full playthrough of the migrated database, and coordinated
production release remain required. The V4 engine remains the campaign's compact
ruleset; these changes do not claim a complete D&D fifth-edition implementation.

### Production release validation

V4 migrations 018–029 and internal RPC permission migration 030 were applied
on 2026-09-30. Baseline rows and database functions are backed up in the private
`uc_release_backups` schema. All seven pre-existing save slots and all forty-four
characters remained present; existing saved world-state and save-slot JSON were
unchanged. V4 production deployed from merge 56cb654. Browser acceptance passed
creation of a lightning Dragonborn wizard, solo start, two-die advantage with
server modifiers, short/long camp rest and per-chapter limits, manual save, exit,
refresh and character re-entry with race/ancestry retained. The legacy rest
control now opens camp. Trigger handlers and the internal turn-repair helper
are no longer callable as client RPCs.

### V4.1 — action outcomes and Inspiration (2026-09-30)

Apply `db/031_v41_action_checks.sql` after 030. Existing player/world/save rows are preserved. Event receipts are stored in `game_states.state.checks`; points and one-time award receipts are stored in `players.build` and included by existing full-row saves. Main/deeper exploration, regional inspection, quest checks, identity dialogue and world actions use server-owned IDs. Shared events cannot be retried by changing players; personal field/guard/prison events identify their actor. One initial roll and one owner-paid Inspiration reroll are allowed. Failed rolls remain pending until accepted or superseded by a deliberate action; the latter settles consequences once. Scene changes prevent replaying an old event.

Loot pools are authored per area/target, with higher DC and wanted/reputation penalties for valuable targets. Pickpocketing/theft award gold and items; locks award a valuable item and clue; trespassing and keys unlock secret rooms. Each discovered secret passage can bypass one ordinary first-round encounter, excluding side battles and the finale. Persuasion earns real 15% merchant discounts, deception grants goods/access and creates a lie audited on a later chapter transition, intimidation earns money at a reputation cost. Social field checks use the same shared negotiation event; altering skill/DC/mode cannot reset it. Free field investigations have a server-owned DC and a once-per-character/chapter/area opportunity.

Inspiration caps at four and is awarded once for identity routes, deeper discoveries, class-specific solutions, important side-quest completion and milestone story decisions. Capped awards are receipted, so they cannot be reclaimed after spending points. Ordinary combat and repeated crimes award none. UI displays points, concrete outcomes, remaining opportunity, lock status and owner-only reroll/accept buttons. Historical V4 crime/dialogue attempts stay locked; they are not reset to manufacture new rewards.

Validation: all ten test suites plus production build; the V4.1 suite covers real RPC outcomes, two-player shared locks, personal checks, both reroll outcomes, resource rollback, point scarcity/cap, exact discounted purchases, keys/secret bypass, later lie exposure, authored chapter/deeper/regional/quest/identity rerolls, side-quest/story awards, save/reconnect persistence and private-helper privileges.

### V5.0 — novel campaign and dialogue choices (2026-09-30)

All 30 main chapters and 90 conversation beats are hand-authored around erased names, contested consent, and accountability. There are 462 dialogue options (including 42 class-specific approaches), 100 authored skill-check success/failure pairs, and 120 major decisions with matching consequence text. Choices share authenticated room history; checks use real character modifiers, racial rules and server dice. Cooperative or hostile dialogue changes faction reputation and subsequent scene check bonuses (+1/-1). Failed dialogue checks advance with an authored setback and cannot be rerolled by replaying the beat. Existing exploration checks retain their Inspiration rules.

Apply `db/037_v50_novel_campaign.sql` after 036, then `db/038_v50_dialogue_polish.sql`. Rebuild it with `node scripts/build-v50-story-sql.mjs`; the SQL helpers live in `scripts/v50-story-engine.sql`. Pre-release chapter choices, dialogues and command definition are preserved in the private `uc_release_backups` schema. Player, room, checkpoint and combat data are not rewritten. Dialogue supports server-owned variable option counts and enforces class-only routes. Major decisions support four options; new narrative interactions permit proceeding after dialogue without completing both investigations. Skipping evidence does not grant the legacy choice clue. Active combat blocks both story actions. Old room history remains intact.

Two new final制度 outcomes, limited supervised reform and a district covenant, join council rebuilding and underground autonomy. The ending screen has separate authored institutional epilogues and recalls selected earlier promises; new narrative flags do not inflate the legacy ending score. Optional evidence stays available behind a disclosure panel, while main choices appear directly after dialogue. Story and vendor assets are split into separate build chunks.

Validation: eleven suites and production build pass. V5 tests apply the complete migration chain twice for the new migration, reject fabricated/class-forbidden choices, exercise the sixth option and two-player shared dialogue, check authored success/failure replies, optional-clue behavior, persistent decisions, combat guards, internal permissions, and both new server ending outcomes.

Browser acceptance: original save re-entry preserved rooftop victory, HP/XP and loot. A new human bard used the class-specific counting song (D20 11, total 16 success), then failed the deception branch (D20 7, total 11), received the distinct setback, proceeded without investigation and retained an empty clue list. Save/re-entry kept the dialogue and irreversible decision; advancing reached the new copper-box chapter. Display polish removes duplicated objective/decision prose; migration038 makes cooperation bonus reachable from a protective first answer.

### V5.0.1 — multiplayer combat queue (2026-10-01)

Apply `db/039_v50_live_combat_queue.sql` after 038. Active battle snapshots append eligible late arrivals and returning characters to the persistent initiative queue once, preserving its current actor, enemy HP, round and existing order. Departing actors now yield forward to the next eligible teammate instead of resetting to the queue head. NPC turns remain independent of network presence. Returning to a visible game tab immediately renews presence and refreshes the UI. Internal queue helpers remain unavailable to client RPCs. Regression tests reproduce the missing teammate before the fix, verify three full two-player attack cycles with out-of-turn rejection, new guest entry, third-player turn after departure, replay-safe migration and private helper permissions.
