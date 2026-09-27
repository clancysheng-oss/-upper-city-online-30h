import {createClient} from '@supabase/supabase-js';
const url=import.meta.env.VITE_SUPABASE_URL;
const key=import.meta.env.VITE_SUPABASE_ANON_KEY;
export const configured=Boolean(url&&key);
export const client=configured?createClient(url,key,{auth:{persistSession:true,autoRefreshToken:true}}):null;
export async function ensureIdentity(){
 if(!client)throw Error('网站尚未配置公开的 Supabase 连接信息。');
 const {data:{session},error}=await client.auth.getSession(); if(error)throw error;
 if(!session){const result=await client.auth.signInAnonymously();if(result.error)throw result.error;}
}
export async function command(code,action,payload={}){
 await ensureIdentity(); const {data,error}=await client.rpc('party_command',{p_code:code||'',p_action:action,p_payload:payload});
 if(error)throw error; return data;
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
