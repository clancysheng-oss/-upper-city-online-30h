import {novelChapters} from './novel-story.js';
export const dialogues=novelChapters.map(c=>({chapter:c.id,name:c.speaker,role:c.mode,beats:c.beats}));
