import {createClient} from '@supabase/supabase-js';
const url=import.meta.env.VITE_SUPABASE_URL;
const key=import.meta.env.VITE_SUPABASE_ANON_KEY;
export const configured=Boolean(url&&key);
export const client=configured?createClient(url,key,{auth:{persistSession:true,autoRefreshToken:true}}):null;
let presenceToken='';
export async function ensureIdentity(){
 if(!client)throw Error('网站尚未配置公开的 Supabase 连接信息。');
 const {data:{session},error}=await client.auth.getSession(); if(error)throw error;
 if(!session){const result=await client.auth.signInAnonymously();if(result.error)throw result.error;presenceToken=result.data.session?.access_token||'';}
 else presenceToken=session.access_token;
}
export async function command(code,action,payload={}){
 await ensureIdentity(); const {data,error}=await client.rpc('party_command',{p_code:code||'',p_action:action,p_payload:payload});
 if(error)throw error; return data;
}
export async function usePower(code,id,target,slot){
 await ensureIdentity();const {data,error}=await client.rpc('party_power',{p_code:code,p_id:id,p_target:target,p_slot:slot});
 if(error)throw error;return data;
}
export async function snapshot(code){
 await ensureIdentity();const {data,error}=await client.rpc('party_snapshot',{p_code:code});if(error)throw error;return data;
}
export function subscribe(code,onChange){
 let timer;
 const channel=client.channel(`room-${code}-${Math.random().toString(36).slice(2)}`)
 .on('postgres_changes',{event:'*',schema:'public',table:'players',filter:`room_code=eq.${code}`},()=>onChange())
 .on('postgres_changes',{event:'*',schema:'public',table:'game_states',filter:`room_code=eq.${code}`},()=>onChange())
 .on('postgres_changes',{event:'*',schema:'public',table:'messages',filter:`room_code=eq.${code}`},()=>onChange())
 .subscribe();
 // Polling catches missed realtime events after sleep/reconnection.
 timer=setInterval(onChange,12000);
 return ()=>{clearInterval(timer);client.removeChannel(channel)};
}

export async function areaCommand(code,action,payload={}){await ensureIdentity();const {data,error}=await client.rpc('party_area',{p_code:code,p_action:action,p_payload:payload});if(error)throw error;return data;}
export async function racialCommand(code,action,target=0){await ensureIdentity();const {data,error}=await client.rpc('party_v4_racial',{p_code:code,p_action:action,p_target:target});if(error)throw error;return data;}
export async function companionCommand(code,id,action,target=null){await ensureIdentity();const {data,error}=await client.rpc('party_v4_companion',{p_code:code,p_companion:id,p_action:action,p_target:target});if(error)throw error;return data;}
export async function identityDialogue(code,route){await ensureIdentity();const {data,error}=await client.rpc('party_v4_dialogue',{p_code:code,p_route:route});if(error)throw error;return data;}
export async function saveSlot(action,slot=null,room=null,name=null,cls=null){
 await ensureIdentity();const {data,error}=await client.rpc('party_save_slot',{p_action:action,p_slot:slot,p_room:room,p_name:name,p_class:cls});
 if(error)throw error;return data;
}
export async function listSlots(){await ensureIdentity();const {data,error}=await client.rpc('party_v31_slots');if(error)throw error;return data;}
export async function enterSlot(slot){await ensureIdentity();const {data,error}=await client.rpc('party_enter_slot',{p_slot:slot});if(error)throw error;return data;}
export async function deleteSlot(slot){await ensureIdentity();const {data,error}=await client.rpc('party_delete_slot',{p_slot:slot});if(error)throw error;return data;}
export async function continueExploring(code){await ensureIdentity();const {data,error}=await client.rpc('party_v31_explore',{p_code:code});if(error)throw error;return data;}
export function signalDeparture(code){
 if(!client||!code||!presenceToken)return;
 fetch(`${url}/rest/v1/rpc/party_command`,{method:'POST',keepalive:true,headers:{'Content-Type':'application/json',apikey:key,Authorization:`Bearer ${presenceToken}`},body:JSON.stringify({p_code:code,p_action:'leave',p_payload:{}})}).catch(()=>{});
}
export async function enterRegion(code,area){await ensureIdentity();const {data,error}=await client.rpc('party_region',{p_code:code,p_area:area});if(error)throw error;return data;}
export async function deepCommand(code,action,payload={}){await ensureIdentity();const {data,error}=await client.rpc('party_deep',{p_code:code,p_action:action,p_payload:payload});if(error)throw error;return data;}
export async function identityCommand(code,action,payload={}){await ensureIdentity();const {data,error}=await client.rpc('party_v4_identity',{p_code:code,p_action:action,p_payload:payload});if(error)throw error;return data;}
export async function worldCommand(code,action,payload={}){await ensureIdentity();const {data,error}=await client.rpc('party_v4_world',{p_code:code,p_action:action,p_payload:payload});if(error)throw error;return data;}
