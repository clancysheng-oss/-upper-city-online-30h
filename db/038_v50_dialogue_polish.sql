-- One protective answer earns +2 relationship; make cooperation reachable before beat two.
do $$
declare src text;
begin
 select pg_get_functiondef('public.campaign_novel_dialogue(bigint,jsonb,jsonb,int)'::regprocedure) into src;
 if position('score>=3' in src)>0 then
  src:=replace(replace(src,'score>=3','score>=2'),'score+delta>=3','score+delta>=2');
  execute src;
 elsif position('score>=2' in src)=0 then raise exception 'NOVEL_RELATION_PATCH_MISSING'; end if;
end $$;
-- UI carries the chapter objective already; metadata need not repeat it.
update public.campaign_dialogues set role=split_part(role,' · ',1) where role like '% · %';
