// Client projections only; the server owns IDs, dice, outcomes and resource spending.
export function actionCheckKey(action, d, state, player) {
 const area=state.current_area||'city',chapter=state.chapter||0;
 if(action==='v4_check'&&['说服','欺骗','威吓'].includes(d.skill)&&!d.save)return `social:${area}`;
 if(action==='v4_check')return `field:${chapter}:${area}:${player.id}`;
 if(action==='v4_dialogue')return `identity:${d.route}`;
 if(action==='explore')return `chapter:${chapter}:explore:${d.index}`;
 if(action==='area_inspect')return `area:${area}:inspect:${d.place}`;
 if(action==='area_quest')return `quest:${d.quest}:${state.side_quests?.[d.quest]?.step||0}:${d.option??'continue'}`;
 if(action==='deep_inspect'||action==='deep_route'&&d.choice!=='1')return `deep:${chapter}:${action.slice(5)}`;
 if(action==='v4_world'){
  if(d.kind==='crime')return `crime:${area}:${d.choice}`;
  if(d.kind==='social')return `social:${area}`;
  if(d.kind==='guard'&&['说服','欺骗','威吓','逃跑'].includes(d.choice))return `guard:${chapter}:${player.id}`;
  if(d.kind==='prison'&&['游说守卫','欺骗守卫','寻找钥匙','撬锁','秘密出口'].includes(d.choice))return `prison:${player.id}:${player.conditions?.prison_visit||0}:${d.choice}`;
 }
 return null;
}
export function itemPrice(item, player, state, area=state.current_area||'city'){
 const earned=state.v41_discounts?.[`${player.id}:${area}`]||0;
 const base=(state.flags||[]).includes(`support_${state.chapter}_stay`)?Math.ceil(item.price*.9):item.price;
 const reputation=(player.reputation?.merchant||0)>=25||item.merchant==='wonders'&&(player.reputation?.gond||0)>=25;
 const price=base+(reputation?-Math.ceil(item.price*.1):(player.reputation?.merchant||0)<=-25?Math.ceil(item.price*.1):0);
 return earned?Math.min(price,item.price-Math.ceil(item.price*earned/100)):price;
}
export const inspiration=player=>player?.build?.inspiration||0;
export function canReroll(record,player){return record&&!record.resolved&&!record.reroll_used&&!record.result.success&&record.attempted_by===player?.id&&inspiration(player)>0;}

export function actionError(error){
 const messages={CHECK_ALREADY_ATTEMPTED:'本事件的检定机会已用尽。可在检定记录中使用执行者的激励点，或选择其他路线。',REROLL_UNAVAILABLE:'本检定已经结算或用过重投，不能再次尝试。',NO_INSPIRATION:'激励点不足。探索秘密、完成身份事件或重要支线可获得激励点。',CHECK_OWNER_ONLY:'只有原检定执行者可以使用自己的激励点或接受结果。',CHECK_CONTEXT_CHANGED:'场景已经改变，不能重投旧事件。',KEY_UNAVAILABLE:'当前区域没有可使用的钥匙，或隐藏房间已打开。',SECRET_ROUTE_UNAVAILABLE:'本场冲突不能使用这条暗路。'};
 return Object.entries(messages).find(([key])=>error.message.includes(key))?.[1]||error.message;
}
