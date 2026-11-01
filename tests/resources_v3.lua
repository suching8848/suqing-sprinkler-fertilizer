local F=SQSF
F.start();check(F.ready,"compatible source startup")
local function fresh(isPump)
    local o=isPump and pump(0,0) or sprinkler(0,0)
    return o,F.state(o,true)
end
local old={schema=2,stock={Fertilizer=123456,Mildew=99900},switches={Fertilizer=true},skills={Fertilizer=7},shells={Mildew=2}}
F.migrate(old);F.migrate(old)
check(old.schema==3 and old.stock.Fertilizer==123456 and old.shells.Mildew==2 and old.receiveNetwork,"idempotent v2 migration")
check(old.switches.Fertilizer and old.skills.Fertilizer==7 and not old.switches.Mildew,"old switches preserved")
local v1={doses=7,enabled=true,skill=5};F.migrate(v1)
check(v1.schema==3 and v1.stock.Fertilizer==70000 and v1.switches.Fertilizer,"v1 migration")
local o,s=fresh();check(F.capacity(s)==200,"sprinkler 200")
local po,ps=fresh(true);check(F.capacity(ps)==1000,"pump 1000")
local p=plant(0,0)
local farm={getLuaObjectAt=function(_,x,y)if x==0 and y==0 then return p end end}
local water={x=0,y=0,z=0,w=1,gen=1}
for _,k in ipairs(F.ORDER) do
 local spec=F.RESOURCES[k]
 check(F.cost(k)==10000,"default rate "..k)
 for _,rate in ipairs({0.01,0.5,1,2}) do
  SandboxVars.SuQingSprinklerFertilizer[spec.option]=rate
  o,s=fresh();s.stock[k]=20000;s.switches[k]=true;s.skills[k]=4
  for n=1,math.floor(2/rate) do
   p=plant(0,0);if spec.field then p[spec.field]=80 end
   F.apply(o,water,farm,{}, {},{})
   check(s.stock[k]==20000-n*F.cost(k),"exact balance "..k.." "..rate.." "..n)
   check(spec.field and p[spec.field]==66 or not spec.field and p.fertilizer==1,"native effect "..k)
  end
  p=plant(0,0);if spec.field then p[spec.field]=80 end
  F.apply(o,water,farm,{}, {},{})
  check(s.stock[k]==0 and (spec.field and p[spec.field]==80 or not spec.field and p.fertilizer==0),"insufficient skips")
 end
 SandboxVars.SuQingSprinklerFertilizer[spec.option]=1
end
nativeOptions[F.KEY..".MildewCost"]=0.01;check(F.cost("Mildew")==100,"live native options")
nativeOptions[F.KEY..".MildewCost"]=10;check(F.cost("Mildew")==20000,"clamp high")
nativeOptions[F.KEY..".MildewCost"]=0;check(F.cost("Mildew")==100,"clamp low");nativeOptions={}
-- Native bottles immediately leave a single empty shell. Partial deposits keep medicine.
for _,k in ipairs({"Mildew","Flies","Aphids"}) do
 o,s=fresh();local bottle=instanceItem(F.RESOURCES[k].item);items={bottle}
 check(F.load(player,o,k,bottle,3) and bottle:getCurrentUses()==7 and #items==1,"partial bottle "..k)
 check(F.load(player,o,k,bottle,50) and #items==1 and items[1]:getFullType()=="Base.GardeningSprayEmpty","immediate empty bottle "..k)
 check(s.stock[k]==100000 and s.shells[k]==0,"no bottle escrow "..k)
 s.stock[k]=99900;check(F.refundKind(o,player,k),"recover bottle")
 check(#items==1 and items[1]:getFullType()==F.RESOURCES[k].item and items[1]:getCurrentUses()==9 and s.stock[k]==0,"bottle recovery drops fraction")
 local count=#items;F.refundKind(o,player,k);check(#items==count,"no duplicate recovery")
end
-- Both package sizes deplete to one reusable empty and reload exact integer doses.
for _,k in ipairs({"Mildew","Flies","Aphids","Slugs"}) do
 for _,size in ipairs({50,200}) do
  o,s=fresh();local pack=instanceItem("SQSF."..k.."Pack"..size);items={pack}
  check(F.load(player,o,k,pack,30) and pack:getCurrentUses()==size-30,"partial pack "..k..size)
  check(F.load(player,o,k,pack,1000) and #items==1 and items[1]:getFullType()=="SQSF.EmptyPack"..size,"pack reusable empty")
  check(s.stock[k]==size*F.SCALE,"pack dose count")
  s.stock[k]=s.stock[k]-100
  check(F.refundKind(o,player,k),"recover into empty pack")
  check(#items==1 and items[1]:getFullType()=="SQSF."..k.."Pack"..size and items[1]:getCurrentUses()==size-1,"recover pack no new packaging")
 end
end
o,s=fresh(true);s.stock.Mildew=9950000;local pack=instanceItem("SQSF.MildewPack200");items={pack}
local ok,reason=F.load(player,o,"Mildew",pack,1000)
check(ok and reason=="LoadedFull" and s.stock.Mildew==10000000 and pack:getCurrentUses()==195,"pump fills to 1000 and preserves partial pack")
check(not F.load(player,o,"Mildew",pack,1) and pack:getCurrentUses()==195,"full cannot eat material")
o,s=fresh();s.stock.Mildew=1995000;items={pack}
check(not F.load(player,o,"Mildew",pack,1),"sub-dose free space cannot round upward")
s.stock.Mildew=0;pack.favorite=true;check(not F.load(player,o,"Mildew",pack,10),"favorite remains protected");pack.favorite=false
-- Whole recovery is preflighted; no rounding/disabling on failed packaging check.
s.stock.Mildew=799900;s.switches.Mildew=true;items={instanceItem("SQSF.EmptyPack50")}
check(not F.refundKind(o,player,"Mildew") and s.stock.Mildew==799900 and s.switches.Mildew and #items==1,"insufficient packaging is atomic")
items={instanceItem("SQSF.EmptyPack200")};check(F.refundKind(o,player,"Mildew") and items[1]:getCurrentUses()==79,"79.99 recovers 79")
s.stock.Mildew=9900;items={};check(F.refundKind(o,player,"Mildew") and s.stock.Mildew==0 and #items==0,"sub-dose recovery discards only")
s.stock.Fertilizer=19900;items={};F.refundKind(o,player,"Fertilizer")
check(#items==1 and items[1]:getFullType()=="Base.Fertilizer" and items[1]:getCurrentUses()==1,"fertilizer integer recovery")
-- A failed placement does not eat the empty pack or dose balance.
s.stock.Mildew=90000;items={instanceItem("SQSF.EmptyPack50")}
local add=inventory.AddItem;inventory.AddItem=function()return nil end
ok=pcall(F.refundKind,o,player,"Mildew")
check(not ok and s.stock.Mildew==90000 and #items==1,"failed placement retains material/pack");inventory.AddItem=add
-- Old residue conversion never creates another residue item.
local legacy=instanceItem("SQSF.CareResidue");legacy:getModData().SQSFResidue={schema=1,kind="Mildew",units=29900}
items={legacy};s.stock.Mildew=0
check(F.load(player,o,"Mildew",legacy,200) and s.stock.Mildew==20000 and #items==0,"legacy 2.99 becomes 2")
legacy=instanceItem("SQSF.CareResidue");legacy:getModData().SQSFResidue={schema=1,kind="Mildew",units=100}
items={legacy};check(F.load(player,o,"Mildew",legacy,200) and s.stock.Mildew==20000 and #items==0,"legacy 0.01 clears")
s.shells.Mildew=2;items={};F.claimShells(o,player);F.claimShells(o,player)
check(#items==2 and s.shells.Mildew==0,"old shells collectible once without removing medicine")
-- Retirement preserves whole stocks centrally without manufacturing packaging.
s.stock.Mildew=19900;s.switches.Mildew=true;local id=o:getModData().SQSFId
items={};F.retire(o);F.retire(o)
check(s.retired and s.stock.Mildew==10000 and #items==0,"remove floors once and defers collection")
local replacement=fresh();items={instanceItem("Base.GardeningSprayEmpty")}
check(F.refundKind(replacement,player,"Mildew",id) and items[1]:getCurrentUses()==1,"collect retired device with real empty")
local moved=sprinkler(0,0);moved:getModData().SQSFId=id
check(F.state(moved,true).stock.Mildew==0 and moved:getModData().SQSFId~=id,"moved/copied device cannot clone retired ledger")
-- Healthy/no water/queued/dead/custom crops and overlap retain established protections.
o,s=fresh();s.stock.Mildew=100000;s.switches.Mildew=true;s.skills.Mildew=4
p=plant(0,0);F.apply(o,water,farm,{}, {},{});check(s.stock.Mildew==100000,"healthy no waste")
p.mildewLvl=80;water.w=0;F.apply(o,water,farm,{}, {},{});check(p.mildewLvl==80,"dry no care");water.w=1
actions={{Type="ISCurePlantAction",plant=p}};F.apply(o,water,farm,F.queuedPlants(),{},{});check(p.mildewLvl==80,"queued care skipped");actions={}
local seen={};F.apply(o,water,farm,{},seen,{});F.apply(o,water,farm,{},seen,{})
check(p.mildewLvl==66 and s.stock.Mildew==90000,"overlap deduplicated")
p.state="dead";check(not F.eligible(p,"Mildew"),"dead skip")
p=plant(0,0,"Unknown");check(not F.eligible(p,"Mildew"),"unknown crop skip")
p=plant(0,0);p.cureMildew=function()end;check(not F.eligible(p,"Mildew"),"custom cure API skip")
season="Winter";p=plant(0,0);check(not F.eligible(p,"Fertilizer"),"winter fertilizer skip");season="Summer"
return summary()
