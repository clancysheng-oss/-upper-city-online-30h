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
