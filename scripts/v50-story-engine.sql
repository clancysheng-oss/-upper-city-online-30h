-- Preserve pre-release authored content for rollback without touching player saves.
create schema if not exists uc_release_backups;
revoke all on schema uc_release_backups from public,anon,authenticated;
create table if not exists uc_release_backups.v50_dialogues as select * from public.campaign_dialogues;
create table if not exists uc_release_backups.v50_chapter_choices as select id,choices from public.campaign_chapters;
create table if not exists uc_release_backups.v50_command_core as select pg_get_functiondef('public.party_command_v30_core(text,text,jsonb)'::regprocedure) as definition;
-- v5.0: server-owned dialogue checks, social consequences, four decisions, optional evidence.
create or replace function public.campaign_novel_dialogue(p_actor bigint,p_state jsonb,p_choice jsonb,p_step int)
returns jsonb language plpgsql set search_path=public,pg_temp as $$
declare s jsonb:=p_state; c jsonb:=p_choice; r jsonb; p public.players%rowtype;
 chapter text:=p_state->>'chapter'; stance text:=p_choice->>'stance'; score int; delta int; rep int;
 n jsonb:=coalesce(p_state->'narrative','{}'); relation jsonb; agency jsonb; skill text:=p_choice->>'skill';
begin
 select * into p from public.players where id=p_actor and user_id=auth.uid();
 if not found then raise exception 'INVALID_ACTOR'; end if;
 if c->>'class' is not null and c->>'class'<>p.class_name then raise exception 'CLASS_DIALOGUE_ONLY'; end if;
 if coalesce((s#>>'{combat,hp}')::int,0)>0 then raise exception 'COMBAT_ACTIVE'; end if;
 relation:=coalesce(n->'relationships','{}'); agency:=coalesce(n->'stances','{}');
 score:=coalesce((relation->>chapter)::int,0);
 if skill is not null then
  r:=public.campaign_v41_dice_core(p_actor,skill,(c->>'dc')::int,'normal',case when score>=3 then 1 when score<=-2 then -1 else 0 end,false)
    ||jsonb_build_object('actor',p.name,'actor_id',p.id,'at',clock_timestamp(),'scope','novel','resolved',true);
  s:=jsonb_set(s,'{last_roll}',r,true);
  if not (r->>'success')::boolean then
   c:=jsonb_set(c,'{reply}',coalesce(c->'failure',to_jsonb('对方没有接受这项要求，但交谈仍可继续。'::text)));
   c:=c||jsonb_build_object('reaction','检定失败：这项要求未被接受，故事继续。','roll',r);
  else
   s:=jsonb_set(s,'{flags}',coalesce(s->'flags','[]')||to_jsonb('n5_pass_'||chapter||'_'||p_step),true);
   c:=c||jsonb_build_object('reaction','检定成功：这项交涉得到回应。','roll',r);
  end if;
 end if;
 delta:=case stance when 'care' then 2 when 'solidarity' then 2 when 'honesty' then 1 when 'public' then 1 when 'humor' then 1 when 'skeptic' then -1 when 'threat' then -2 when 'ruthless' then -2 else 0 end;
 if skill is not null and not (r->>'success')::boolean then delta:=least(delta,0)-1; end if;
 relation:=relation||jsonb_build_object(chapter,greatest(-10,least(10,score+delta)));
 agency:=agency||jsonb_build_object(stance,coalesce((agency->>stance)::int,0)+1);
 n:=n||jsonb_build_object('relationships',relation,'stances',agency);
 s:=s||jsonb_build_object('story_version',5,'narrative',n);
 rep:=case when delta>0 then 1 when delta<0 then -1 else 0 end;
 if rep<>0 then update public.players set reputation=coalesce(reputation,'{}')||jsonb_build_object(c->>'faction',greatest(-100,least(100,coalesce((reputation->>(c->>'faction'))::int,0)+rep))) where id=p_actor; end if;
 if c->>'reaction' is null then c:=c||jsonb_build_object('reaction',case when score+delta>=3 then '合作关系：本场后续交涉检定 +1。' when score+delta<=-2 then '戒备关系：本场后续交涉检定 -1。' else '立场已记入人物关系与派系声望。' end); end if;
 return jsonb_build_object('state',s,'choice',c);
end $$;
revoke all on function public.campaign_novel_dialogue(bigint,jsonb,jsonb,int) from public,anon,authenticated;

create or replace function public.campaign_novel_decision(p_state jsonb,p_choice jsonb,p_index int)
returns jsonb language plpgsql set search_path=public,pg_temp as $$
declare s jsonb:=p_state; c jsonb:=p_choice; ch text:=p_state->>'chapter'; n jsonb:=coalesce(s->'narrative','{}');
begin
 if coalesce((s#>>'{combat,hp}')::int,0)>0 then raise exception 'COMBAT_ACTIVE'; end if;
 -- Legacy clue rewards are not evidence when the optional investigation was skipped.
 if not (coalesce(s->'explored','[]') ? (ch||':0') and coalesce(s->'explored','[]') ? (ch||':1')) then c:=c-'clue'; end if;
 n:=n||jsonb_build_object('decisions',coalesce(n->'decisions','{}')||jsonb_build_object(ch,jsonb_build_object('index',p_index,'label',c->>'label','outcome',c->>'outcome')));
 s:=s||jsonb_build_object('story_version',5,'narrative',n,'last_choice_reply',c->>'outcome');
 return jsonb_build_object('state',s,'choice',c);
end $$;
revoke all on function public.campaign_novel_decision(jsonb,jsonb,int) from public,anon,authenticated;

-- Patch the existing authenticated engine, keeping all combat, rest and retry fixes intact.
do $patch$
declare src text; before text;
begin
 select pg_get_functiondef('public.party_command_v30_core(text,text,jsonb)'::regprocedure) into src;
 if position('campaign_novel_dialogue' in src)=0 then
  before:=src;
  src:=replace(src,'if v_idx not in (0,1) then raise exception ''INVALID_DIALOGUE_CHOICE''; end if;',
   'if v_idx<0 or v_idx>=jsonb_array_length(v_beat->''options'') then raise exception ''INVALID_DIALOGUE_CHOICE''; end if;');
  if src=before then raise exception 'NOVEL_DIALOGUE_PATCH_MISSING'; end if;
  src:=replace(src,'v_choice:=v_beat->''options''->v_idx;',
   'v_choice:=v_beat->''options''->v_idx; v_dialogue:=public.campaign_novel_dialogue(v_id,v_state,v_choice,v_step); v_state:=v_dialogue->''state''; v_choice:=v_dialogue->''choice'';');
  src:=replace(src,'jsonb_build_object(''choice'',v_choice->>''label'',''reply'',v_choice->>''reply'')',
   'jsonb_build_object(''choice'',v_choice->>''label'',''reply'',v_choice->>''reply'',''reaction'',v_choice->>''reaction'',''roll'',v_choice->''roll'')');
  src:=replace(src,'if not (coalesce(v_state->''explored'',''[]''::jsonb) ? ((v_state->>''chapter'')||'':0'')) or not (coalesce(v_state->''explored'',''[]''::jsonb) ? ((v_state->>''chapter'')||'':1'')) then raise exception ''EXPLORE_BEFORE_CHOICE''; end if;',
   'if coalesce((v_state->>''story_version'')::int,0)>=5 then if coalesce((v_state#>>''{dialogue,chapter}'')::int,-1)<>(v_state->>''chapter'')::int or coalesce((v_state#>>''{dialogue,step}'')::int,0)<3 then raise exception ''DIALOGUE_FIRST''; end if; else if not (coalesce(v_state->''explored'',''[]''::jsonb) ? ((v_state->>''chapter'')||'':0'')) or not (coalesce(v_state->''explored'',''[]''::jsonb) ? ((v_state->>''chapter'')||'':1'')) then raise exception ''EXPLORE_BEFORE_CHOICE''; end if; end if;');
  src:=replace(src,'if v_idx<0 or v_idx>1 then raise exception ''INVALID_CHOICE''; end if;','if v_idx<0 then raise exception ''INVALID_CHOICE''; end if;');
  src:=replace(src,'if p_payload is null then raise exception ''INVALID_CHOICE''; end if;',
   'if p_payload is null then raise exception ''INVALID_CHOICE''; end if; v_dialogue:=public.campaign_novel_decision(v_state,p_payload,v_idx); v_state:=v_dialogue->''state''; p_payload:=v_dialogue->''choice'';');
  src:=replace(src,'case when (v_state->''flags'') ? ''council'' then',
   'case when (v_state->''flags'') ? ''n5_choice_28_2'' then ''限期监督改革'' when (v_state->''flags'') ? ''n5_choice_28_3'' then ''各区共同新约'' when (v_state->''flags'') ? ''council'' then');
  src:=replace(src,'f not like ''voice_%'' and','f not like ''n5_%'' and f not like ''voice_%'' and');
  execute src;
 end if;
end $patch$;
