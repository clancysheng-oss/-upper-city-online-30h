import fs from 'node:fs';
import {dialogues} from '../src/dialogues.js';
import {chapters} from '../src/campaign.js';
const q=s=>`'${String(s).replaceAll("'","''")}'`;
const seed='\n-- Hand-authored novel campaign. Existing room history and characters are preserved.\ninsert into public.campaign_dialogues(chapter_id,speaker,role,beats) values\n'+dialogues.map(d=>`(${d.chapter},${q(d.name)},${q(d.role)},${q(JSON.stringify(d.beats))}::jsonb)`).join(',\n')+'\non conflict(chapter_id) do update set speaker=excluded.speaker,role=excluded.role,beats=excluded.beats;\n'+chapters.map(c=>`update public.campaign_chapters set choices=${q(JSON.stringify(c.choices))}::jsonb where id=${c.id};`).join('\n')+'\n';
fs.writeFileSync('db/037_v50_novel_campaign.sql',fs.readFileSync('scripts/v50-story-engine.sql','utf8')+seed);
