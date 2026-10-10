"""受領したJSの個別処理から比較値を生成。HTML全体の動作確認ではない。"""
import json
import subprocess
from pathlib import Path

root = Path(__file__).resolve().parents[1]
source = (root / "games/mini_hero/source/4.html").read_text().split("<script>", 1)[1]
# 原本は変更しない。途中で切れたログと関数終端だけを比較用に閉じる。
source = source[:source.rfind(",'blue'...")] + ",'blue');}skillMode=false;return true;}"
probe = r"""
const cases=[];
Math.random=()=>roll;
log=()=>{};fxText=()=>{};addAnim=()=>{};shake=()=>{};wash=()=>{};
enemyCard=()=>null;allyCard=()=>null;
function needMp(a,n){return a.mp>=n}
function view(){return {party:party.map(m=>({hp:m.hp,mp:m.mp,limit:m.limit,guarding:m.guarding,charge:m.charge||0})),enemies:enemies.map(e=>({hp:e.hp,stun:e.stun,reflect:e.reflect,guarded:e.guarded,enraged:!!e.enraged,shielded:!!e.shielded}))}}
let roll=.5;
for(const enhanced of [false,true]){
 for(const command of ['attack','guard','fire','spark','heal',...skills.hero.map(s=>s[0]),...skills.mage.slice(0,8).map(s=>s[0])]){
  roll=enhanced?.05:.5;
  resetEquipDefs();party=members.map(C);stats={};skillMode=false;
  party.forEach(m=>{m.level=8;m.mp=100;m.maxMp=100;m.hp-=7;m.limit=20;m.equip={};m.talents={};
   if(enhanced)(talentDefs[m.role]||[]).forEach(t=>m.talents[t.id]=true)});
  if(enhanced){party[0].equip={weapon:'flameSword',armor:'ironArmor'};party[1].equip={weapon:'flameStaff',armor:'magicRobe'};party[2].equip={weapon:'prayerStaff',armor:'saintRobe'}}
  active=skills.mage.some(s=>s[0]===command)?1:0;selE=0;selA=0;wave=1;curDiff='normal';enemies=[];
  enemies=makeEnemies();enemies.forEach(e=>{e.hp=1000;e.maxHp=1000;e.reflect=enhanced});
  const initial={party:C(party),enemies:C(enemies),active,roll};
  if(['attack','guard','fire','spark','heal'].includes(command))({attack,guard,fire,spark,heal})[command]();
  else useSkill(command);
  cases.push({command,enhanced,initial,expected:view()});
 }
}
JSON.stringify(cases)
"""
runner = """const vm=require('node:vm');let s='';process.stdin.setEncoding('utf8');process.stdin.on('data',x=>s+=x);process.stdin.on('end',()=>console.log(vm.runInNewContext(s,{}, {timeout:3000})));"""
result = subprocess.run(["node", "-e", runner], input=source + probe, text=True, capture_output=True, check=True)
cases = json.loads(result.stdout)
(root / "tests/mini_hero_reference.json").write_text(json.dumps(cases, ensure_ascii=False, indent=2) + "\n")
print(f"原資料から比較ケースを生成: {len(cases)}")
