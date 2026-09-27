# Upper City 30H

A multiplayer, original Upper City campaign for 2–5 players. Vite modules separate UI, Supabase transport, campaign content, and the database state machine. Thirty chapters span a prologue, four acts, and a finale. The chapters are a framework for group roleplay with shared choices, clues, combat, and a persistent log; a full 30-hour tabletop experience also depends on the players' roleplay pace.

## Deploy

1. In Supabase Auth settings, enable **anonymous sign-ins**. Apply `db/002_secure_campaign.sql` and then `db/003_encounters.sql` in the SQL editor. This migrates the old demo schema and removes its public write policies. Existing unbound demo players are not imported as authenticated members. After changing `src/encounters.js`, run `npm run campaign:sql` and deploy the generated migration together with the frontend.
2. Set `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` in Vercel. These are **public browser credentials**, not a service role key. Never set a service role key with `VITE_`.
3. Vercel framework preset: Vite; build command `npm run build`; output directory `dist`; install command `npm install`. Deploy the source from the main branch.
4. Open production in two independent browser profiles. The second profile must sign in anonymously with its own Supabase identity. Run the acceptance flow in the request.

## Architecture

- `src/campaign.js`: original chapter and class data. Choice definitions are also seeded server side to prevent a client from fabricating flags or clues.
- `src/encounters.js`, `db/003_encounters.sql`: 60 authored investigation and social beats with server-owned DC, outcomes, clues, and state. Each chapter requires both beats before the branch decision.
- `src/api.js`: anonymous auth, RPC transport, realtime subscriptions, and polling recovery.
- `src/main.js`, `src/style.css`: interface.
- `db/002_secure_campaign.sql`: migration, authenticated membership, atomic RPC commands, host checks, server dice/combat, realtime tables. Direct writes to gameplay tables are revoked.

The room code is an invitation, not authorization. Every joining browser gets its own anonymous Auth user. Local storage keeps only its last room code; the Supabase session persists the identity. A player who clears browser storage cannot recover that anonymous identity automatically. Host succession is explicit on departure and claimable after five minutes without heartbeat. Realtime broadcasts may be missed while offline, so clients also poll every 12 seconds.

## Current scope

The 30 chapters, 60 authored encounters, and shared choices provide campaign structure. Run each act as a group session: discuss NPC motives, roleplay open actions in the party log, investigate both leads, make a shared choice, and let the host advance. Earlier help for the guard reduces the final enemy's HP; discovering the beast's weakness lowers its AC. This is not a complete fifth-edition rules engine or a guaranteed 30 hours of scripted content. Spell slots, leveling, complex equipment effects, enemy AI, more tactical encounters, and deeper branch-specific scenes are future expansions. No production multiplayer run is certified until the connected Supabase project, deployed Vercel app, and two independent browser sessions have been tested.
