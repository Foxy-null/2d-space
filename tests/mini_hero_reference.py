"""正本4-1.htmlの処理を実行してGodot比較値を生成する。原本の式は変更しない。"""
import json
import subprocess
from pathlib import Path

root = Path(__file__).resolve().parents[1]
source = (root / 'games/mini_hero/source/4-1.html').read_text().split('<script>', 1)[1].split('</script>', 1)[0]
prefix = source.split("document.querySelectorAll('.diff label')", 1)[0]
probe = r'''
let roll=.5, calls=0, stamp=0, logs=[];
Math.random=()=>{calls++;return roll}; Date.now=()=>++stamp;
log=(text,color='')=>logs.push({text,color});
showBanner=()=>{};fxText=()=>{};addAnim=()=>{};shake=()=>{};wash=()=>{};victoryFx=()=>{};
enemyCard=()=>null;allyCard=()=>null;
update=()=>{tgtE();cur()};
function eqView(e){return {id:e.id,baseId:e.baseId||'',name:e.name,slot:e.slot,jobs:e.jobs,rarity:e.rarity,stats:e.stats,effects:e.effects,affix:e.affix||''}}
function state(){return C({party,enemies,lastEnemies,equipDefs,equips,items,materials,quest,stats,bestiary,wave,active,selE,selA,busy,finished,preparing,route,routeChosen,curDiff,skillMode,eventHtml:$('eventArea').innerHTML,stamp,logs})}
function snapshot(){
 const s=state(), ids=Object.fromEntries(equipDefs.map((e,i)=>[e.id,e.baseId?'eq:'+i:e.id]));
 s.party.forEach(m=>{m.charge=m.charge||0;for(const k in m.equip)m.equip[k]=ids[m.equip[k]]||null});
 s.enemies.forEach(e=>{delete e.intentFlash;for(const k of ['enraged','shielded'])e[k]=!!e[k]});
 s.equipDefs=equipDefs.map(e=>({...eqView(e),id:ids[e.id]}));
 s.equips=Object.fromEntries(Object.entries(equips).map(([id,n])=>[ids[id],n]));
 s.phase=finished?(preparing?'won':'lost'):'party';
 s.event_kind=s.eventHtml.includes('冒険者への支給品')?'starter':s.eventHtml.includes('泉イベント')?'spring':s.eventHtml.includes('宝箱')?'treasure':s.eventHtml.includes('小さな祠')?'shrine':'';
 for(const k of ['lastEnemies','finished','curDiff','eventHtml','stamp'])delete s[k];
 s.calls=calls;
 return s;
}
const cases=[];
async function test(kind,id,setup,run,r=.5){
 roll=r; stamp=0; logs=[];restart();logs=logs.slice(-1);setup?.();
 const initial=state();calls=0;const result=await run();
 cases.push({kind,id,roll:r,initial,expected:snapshot(),result:result!==false});
}
function boosted(role,enhanced=false){
 party.forEach(m=>{m.level=8;m.mp=100;m.maxMp=100;m.hp-=7;m.limit=100;m.poison=2;m.equip={weapon:null,armor:null,accessory:null};m.talents={};
 if(enhanced)(talentDefs[m.role]||[]).forEach(t=>m.talents[t.id]=true)});
 if(enhanced){party[0].equip={weapon:'flameSword',armor:'ironArmor',accessory:null};party[1].equip={weapon:'flameStaff',armor:'magicRobe',accessory:null};party[2].equip={weapon:'prayerStaff',armor:'saintRobe',accessory:null}}
 active=members.findIndex(m=>m.role===role);selA=0;selE=0;
 enemies.forEach(e=>{e.hp=1000;e.maxHp=1000;e.reflect=enhanced});
}
(async()=>{
 for(const diff of Object.keys(diffs))await test('start',diff,()=>{curDiff=diff},()=>{restart();logs=logs.slice(-1)});
 for(const r of [.5,.05,.95]){
  for(const enhanced of [false,true]){
   for(const cmd of ['attack','guard','fire','spark','heal'])await test('command',cmd,()=>boosted('hero',enhanced),()=>({attack,guard,fire,spark,heal})[cmd](),r);
   for(const role of Object.keys(skills))for(const sk of skillList({role}))await test('skill',sk.id,()=>{boosted(role,enhanced);if(sk.id==='revive')party[0].hp=0},()=>useSkill(sk.id),r);
   for(const role of Object.keys(skills))for(const li of limitList({role}))await test('limit',li.id,()=>{boosted(role,enhanced);if(role!=='hero')party[0].hp=0},()=>useLimit(li.id),r);
  }
  for(const id of Object.keys(itemNames))await test('item',id,()=>{boosted('mage');items[id]=2;if(id==='reviveStone')party[0].hp=0},()=>useItem(id),r);
  for(const e of [...enemyBase,...bossBase])await test('enemy',e.type,()=>{boosted('hero');Object.assign(enemies[0],e,{hp:10,maxHp:100,intent:{kind:'skill'},stun:0,guarded:false,reflect:false,howled:false});wave=9},()=>executeIntent(enemies[0]),r);
  for(const pat of ['powerHit','snipe','lifeDrain','enemyHeal','shieldAll','enrage','curse','bossCharge','bossSmash'])await test('pattern',pat,()=>{boosted('hero');enemies[0].intent={kind:'pattern',pattern:pat};enemies[0].hp=30;party[2].hp=5;wave=9},()=>executeIntent(enemies[0]),r);
  for(const q of qDef())await test('quest',q.id,()=>{quest={};for(const def of qDef()){if(def.id!==q.id)quest[def.id]=true;for(const m of qDef.toString().matchAll(/stats\.(\w+)/g))stats[m[1]]=100}wave=30;Object.keys(materials).forEach(k=>materials[k]=30)},()=>claimQuest(q.id),r);
  for(const id of ['safe','danger','mine','dragon','forest','ruins','treasure','shrine','storm','crystal'])await test('route',id,()=>{finished=true;preparing=true;enemies.forEach(e=>e.hp=0)},()=>chooseRoute(id),r);
  for(const floor of [1,3,4,5,19,20])await test('win',''+floor,()=>{wave=floor;boosted('hero');enemies.forEach(e=>e.hp=0);party[0].level=1;party[0].exp=0;party[0].mp=1;party[0].hp=5},()=>win(),r);
  await test('next','floor',()=>{finished=true;preparing=true;routeChosen=true;wave=4;enemies.forEach(e=>e.hp=0)},()=>nextBattle(),r);
  for(const id of ['herb','mana','sp','craft'])await test('starter',id,()=>{wave=1;finished=true;preparing=true;starterRewardChoice()},()=>chooseStarterReward(id),r);
 }
 for(const role of Object.keys(talentDefs))for(const t of talentDefs[role])await test('talent',t.id,()=>{selA=members.findIndex(m=>m.role===role);party[selA].sp=20;if(t.require)party[selA].talents[t.require]=true},()=>learnTalent(selA,t.id));
 for(const recipe of recipes)await test('craft',recipe.id,()=>Object.keys(materials).forEach(k=>materials[k]=30),()=>craft(recipe.id));
 for(const recipe of equipRecipes)await test('craftEq',recipe.id,()=>Object.keys(materials).forEach(k=>materials[k]=30),()=>craftEq(recipe.id));
 for(const id of ['bronzeSword','ironArmor','lifeRing']){
  await test('equip',id,()=>{addEq(id);party[0].hp=30},()=>equip(0,equipDefs.find(e=>e.baseId===id).id));
  await test('unequip',id,()=>{addEq(id);equip(0,equipDefs.find(e=>e.baseId===id).id)},()=>unequip(0,eDef(id).slot));
 }
 for(const r of [.05,.5,.95])for(const cmd of ['attack','guard','fire','spark','heal'])await test('turn',cmd,()=>{boosted('priest');party[0].hp=38;party[1].hp=28;party[2].hp=40},()=>turn(()=>({attack,guard,fire,spark,heal})[cmd]()),r);
 await test('turn','noMP',()=>party[0].mp=0,()=>turn(fire));
 await test('item','noRevive',()=>items.reviveStone=1,()=>useItem('reviveStone'));
 await test('skill','noRevive',()=>{active=2;party[2].mp=50},()=>useSkill('revive'));
 await test('turn','lose',()=>{party[0].hp=1;party[0].poison=3;party[1].hp=0;party[2].hp=0},()=>turn(guard));
 // 正本の最終生存者への二連撃は2撃目の対象がundefinedになり停止する。
 restart();party.forEach(m=>m.hp=0);party[0].hp=1;
 Object.assign(enemies[0],{skill:'doubleAttack',attack:99,stun:0});
 let doubleAttackFault=false;
 try{await enemySkill(enemies[0])}catch(e){doubleAttackFault=e instanceof TypeError && /undefined/.test(e.message)}
 if(!doubleAttackFault)throw Error('Expected source doubleAttack target fault');
 console.log(JSON.stringify(cases));
})();
'''
runner = r'''const vm=require('vm');let source='';process.stdin.setEncoding('utf8');process.stdin.on('data',s=>source+=s);process.stdin.on('end',async()=>{const nodes={};const context={document:{getElementById:id=>nodes[id]||(nodes[id]={innerHTML:'',textContent:'',style:{},children:[],classList:{add(){},remove(){},contains(){return false}},appendChild(){}})},setTimeout:fn=>{fn();return 0},console};try{new vm.Script(source);await vm.runInNewContext(source,context,{timeout:10000})}catch(e){console.error(e);process.exitCode=1}});'''
result = subprocess.run(['node','-e',runner], input=prefix+probe, text=True, capture_output=True)
if result.returncode:
    raise RuntimeError(result.stderr)
cases=json.loads(result.stdout)
def delta(base, value, path=()):
    if isinstance(base, dict) and isinstance(value, dict):
        out = [["remove", list(path)+( [key] )] for key in base.keys()-value.keys()]
        for key in value:
            out += delta(base[key],value[key],path+(key,)) if key in base else [["set",list(path+(key,)),value[key]]]
        return out
    if isinstance(base,list) and isinstance(value,list):
        out=[]
        for i in range(min(len(base),len(value))): out+=delta(base[i],value[i],path+(i,))
        for i in range(len(base),len(value)): out.append(["set",list(path+(i,)),value[i]])
        for i in range(len(base)-1,len(value)-1,-1): out.append(["remove",list(path+(i,))])
        return out
    return [] if base==value else [["set",list(path),value]]
initial_base=cases[0]['initial']
expected_base=cases[0]['expected']
for case in cases:
    case['initial']=delta(initial_base,case['initial'])
    case['expected']=delta(expected_base,case['expected'])
payload={'initial_base':initial_base,'expected_base':expected_base,'cases':cases}
(root/'tests/mini_hero_reference.json').write_text(json.dumps(payload,ensure_ascii=False,separators=(',',':'))+'\n')
print(f'正本の比較ケースを生成: {len(cases)}')
