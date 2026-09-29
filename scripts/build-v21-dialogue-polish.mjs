import fs from 'node:fs';
import {dialogues} from '../src/dialogues.js';
const q=s=>`'${String(s).replaceAll("'","''")}'`;
const sql='-- Dialogue revisions after browser reading; no active room history is rewritten.\ninsert into public.campaign_dialogues(chapter_id,speaker,role,beats) values\n'+dialogues.map(d=>`(${d.chapter},${q(d.name)},${q(d.role)},${q(JSON.stringify(d.beats))}::jsonb)`).join(',\n')+'\non conflict(chapter_id) do update set speaker=excluded.speaker,role=excluded.role,beats=excluded.beats;\n';
fs.writeFileSync('db/009_v21_dialogue_polish.sql',sql);
