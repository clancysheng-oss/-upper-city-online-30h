-- Only authenticated gameplay RPCs are client entry points. Trigger handlers and
-- the internal turn-repair helper must not be exposed as standalone RPCs.
revoke all on function public.campaign_v30_combat(),
 public.campaign_v4_companion_join(),public.campaign_v4_final_start(),
 public.campaign_v4_final_zero(),public.campaign_v4_reputation(),
 public.party_v31_checkpoint(),public.party_v31_next_turn(text,bigint),
 public.party_v31_state() from public,anon,authenticated;
