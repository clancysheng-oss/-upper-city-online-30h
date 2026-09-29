// These thresholds mirror campaign_xp_bonus in db/011_xp_progression.sql.
export const bonusThresholds=[50,150,300];
export function experienceProgress(level,xp=0){
 if(level>=12)return '已达等级上限';
 const next=bonusThresholds.find(n=>xp<n);
 return next?`距下一次经验升级 ${next-xp} XP（目标 ${next}）`:'经验加速已达上限，继续主线可升级';
}
