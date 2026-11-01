local F=SQSF
check(F.upstreamMatches(),"live upstream checksum")
F.start();check(F.ready,"startup")
local function fresh()
    local o=sprinkler(0,0)
    return o,F.state(o,true)
end
local p=plant(0,0)
local farm={getLuaObjectAt=function(_,x,y) if x==0 and y==0 then return p end end}
local water={x=0,y=0,z=0,w=1,gen=1}
local function apply(o,seen) F.apply(o,water,farm,F.queuedPlants(),seen or {}) end
check(instanceItem("Base.Fertilizer"):getCurrentUses()==8,"native integer dose model")
local rounded=instanceItem("Base.Fertilizer");rounded:setUsedDelta(0.00125);check(rounded:getCurrentUses()==0,"native setUsedDelta rounds fractional uses")
local old={doses=7,enabled=true,skill=5}
F.migrate(old)
check(old.stock.Fertilizer==70000 and old.switches.Fertilizer and old.skills.Fertilizer==5,"old balance/switch/skill")
for _,k in ipairs(F.ORDER) do
    if k~="Fertilizer" then check(old.stock[k]==0 and not old.switches[k],"new treatment default off "..k) end
end
F.migrate(old);check(old.stock.Fertilizer==70000,"migration once")
for _,k in ipairs(F.ORDER) do
    local spec=F.RESOURCES[k]
    check(F.cost(k)==10000,"default 1 "..k)
    for _,rate in ipairs({0.01,0.5,1,2}) do
        SandboxVars.SuQingSprinklerFertilizer[spec.option]=rate
        local o,s=fresh();s.stock[k]=10000;s.switches[k]=true;s.skills[k]=4
        local expected=math.floor(1/rate)
        for i=1,expected do
            p=plant(0,0)
            if spec.field then p[spec.field]=80 end
            apply(o)
            check(s.stock[k]==10000-i*F.cost(k),"exact debit "..k.." "..rate.." #"..i)
            if spec.field then check(p[spec.field]==66,"native cure 10+skill "..k)
            else check(p.fertilizer==1 and p.nextGrowing==60 and p.health==70,"native fertilizer") end
        end
        p=plant(0,0);if spec.field then p[spec.field]=80 end
        local before=s.stock[k];apply(o)
        check(s.stock[k]==before,"insufficient balance "..k.." "..rate)
        if spec.field then check(p[spec.field]==80,"no free cure") else check(p.fertilizer==0,"no free fertilize") end
        if rate==2 then
            s.stock[k]=20000;apply(o)
            check(s.stock[k]==0,"two-dose rate works")
            check(spec.field and p[spec.field]==66 or (not spec.field and p.fertilizer==1),"two-dose rate same strength")
        end
    end
    SandboxVars.SuQingSprinklerFertilizer[spec.option]=0
    check(F.cost(k)==100,"clamp minimum")
    SandboxVars.SuQingSprinklerFertilizer[spec.option]=3
    check(F.cost(k)==20000,"clamp maximum")
    SandboxVars.SuQingSprinklerFertilizer[spec.option]="invalid"
    check(F.cost(k)==10000,"invalid fallback")
    SandboxVars.SuQingSprinklerFertilizer[spec.option]=1
end
local o,s=fresh()
local bag=instanceItem("Base.Fertilizer");items={bag}
check(F.load(player,o,"Fertilizer",bag,1) and s.stock.Fertilizer==10000 and F.itemUnits(bag)==70000,"deposit native dose")
bag.favorite=true;check(not F.load(player,o,"Fertilizer",bag,1),"favorite protected");bag.favorite=false
s.switches.Fertilizer=true;p=plant(0,0);apply(o)
check(p.fertilizer==1,"fertilizer works")
s.stock.Fertilizer=10000;apply(o);check(s.stock.Fertilizer==10000,"already fertilized skipped")
p.fertilizer=0;p.nbOfGrow=3;apply(o);check(s.stock.Fertilizer==0,"new growth eligible")
-- Fractional residue is returned without relying on native integer drainables.
s.stock.Fertilizer=100;items={};F.refundKind(o,player,"Fertilizer")
check(#items==1 and items[1]:getFullType()=="SQSF.CareResidue" and F.itemUnits(items[1])==100,"fractional refund")
check(F.load(player,o,"Fertilizer",items[1],1) and s.stock.Fertilizer==100 and #items==0,"fractional redeposit")
for _,k in ipairs({"Mildew","Flies","Aphids"}) do
    o,s=fresh();local spec=F.RESOURCES[k];local bottle=instanceItem(spec.item);items={bottle}
    check(F.load(player,o,k,bottle,10) and #items==0 and s.shells[k]==1 and s.stock[k]==100000,"bottle escrow "..k)
    s.stock[k]=99900
    F.refundKind(o,player,k)
    check(#items==2 and F.itemUnits(items[1])==90000 and F.itemUnits(items[2])==9900 and s.shells[k]==0,"fractional bottle recovery "..k)
    local filled,residue=items[1],items[2]
    check(F.load(player,o,k,filled,10) and F.load(player,o,k,residue,10) and #items==0 and s.stock[k]==99900,"bottle and residue redeposit")
    local second=instanceItem(spec.item);items={second};F.load(player,o,k,second,10)
    s.stock[k]=70000;items={};F.refundKind(o,player,k)
    check(#items==2 and F.itemUnits(items[1])==70000 and items[2]:getFullType()=="Base.GardeningSprayEmpty","content and empty shell conserved")
    local count=#items;F.refundKind(o,player,k);check(#items==count,"no duplicate refund")
    o,s=fresh();bottle=instanceItem(spec.item);items={bottle};F.load(player,o,k,bottle,10);s.stock[k]=0
    F.refundKind(o,player,k);check(#items==1 and items[1]:getFullType()=="Base.GardeningSprayEmpty","fully used bottle returned")
    o,s=fresh();s.stock[k]=600000;bottle=instanceItem(spec.item);items={bottle}
    check(not F.load(player,o,k,bottle,10) and #items==1 and s.stock[k]==600000,"whole-bottle room required")
end
o,s=fresh();bag=instanceItem("Base.SlugRepellent");items={bag}
check(F.load(player,o,"Slugs",bag,1) and s.stock.Slugs==10000 and F.itemUnits(bag)==90000,"slug single dose")
s.stock.Slugs=10;items={};F.refundKind(o,player,"Slugs")
check(F.itemUnits(items[1])==10,"tiny slug fraction exact")
check(not F.load(player,o,"Mildew",items[1],10),"wrong medicine rejected")
-- All categories coexist; health and disease effect remain native.
o,s=fresh();p=plant(0,0)
for _,k in ipairs(F.ORDER) do
    s.stock[k]=30000;s.switches[k]=true;s.skills[k]=4
    if F.RESOURCES[k].field then p[F.RESOURCES[k].field]=80 end
end
apply(o)
for _,k in ipairs(F.ORDER) do check(s.stock[k]==20000,"combined independent debit "..k) end
local other,os=fresh()
for _,k in ipairs(F.ORDER) do os.stock[k]=10000;os.switches[k]=true end
p=plant(0,0);p.mildewLvl=80;local seen={};apply(o,seen);apply(other,seen)
check(p.mildewLvl==66 and os.stock.Mildew==10000,"overlap one treatment per pulse")
apply(other,{})
check(p.mildewLvl==56 and os.stock.Mildew==0,"next pulse can continue treatment")
-- Queue, no disease, missing drug, switches, water, invalid crop, winter.
o,s=fresh();s.stock.Mildew=20000;s.switches.Mildew=true;s.skills.Mildew=4
p=plant(0,0);apply(o);check(s.stock.Mildew==20000,"healthy plant no waste")
p.mildewLvl=1;apply(o);check(p.mildewLvl==0 and s.stock.Mildew==10000,"small disease stops at zero")
apply(o);check(s.stock.Mildew==10000,"zero disease no further debit")
p.mildewLvl=80;s.switches.Mildew=false;apply(o);check(p.mildewLvl==80,"off")
s.switches.Mildew=true;water.w=0;apply(o);check(p.mildewLvl==80,"no water");water.w=1
actions={{Type="ISCurePlantAction",plant=p}};apply(o);check(p.mildewLvl==80,"queued native/batch cure skipped")
actions={{Type="ISFertilizeAction",plant=p}};apply(o);check(p.mildewLvl==80,"queued fertilizer skipped");actions={}
for _,state in ipairs({"dead","rotten","destroyed","harvested","plow"}) do
    p.state=state;check(not F.eligible(p,"Mildew"),"invalid crop "..state)
end
p=plant(0,0,"Unknown");check(not F.eligible(p,"Mildew"),"unknown crop")
p=plant(0,0,"ChineseFruit");p.mildewLvl=20;check(F.eligible(p,"Mildew"),"standard mod crop")
p.cureMildew=function()end;check(not F.eligible(p,"Mildew"),"custom API skipped")
p=plant(0,0);p.mildewLvl=20;season="Winter"
check(not F.eligible(p,"Fertilizer") and F.eligible(p,"Mildew"),"winter distinct from fertilizer")
season="Summer"
-- Removing duplicated/copied device IDs cannot duplicate stocks or bottle shells.
o,s=fresh();s.stock.Mildew=50000;s.shells.Mildew=2;s.stock.Fertilizer=100
local copied=sprinkler(0,0);copied:getModData().SQSFId=o:getModData().SQSFId
ground={};F.removed(o);check(#ground==3,"remove refunds all kinds and empty bottle")
F.removed(copied);check(#ground==3,"copied ID cannot duplicate")
local replacement,rs=fresh();check(rs.stock.Fertilizer==0 and rs.stock.Mildew==0,"replacement clean")
-- Timer startup skips stale water and deduplicates real pulse across devices.
o,s=fresh();other,os=fresh();p=plant(0,0);p.mildewLvl=80
s.stock.Mildew=20000;s.switches.Mildew=true;s.skills.Mildew=4
os.stock.Mildew=20000;os.switches.Mildew=true;os.skills.Mildew=4
wp.Sprinklers={a={x=0,y=0,z=0,w=1,gen=8},b={x=1,y=0,z=0,w=1,gen=8}}
function getCell()return {getGridSquare=function(_,x) return (x==0 and o or other):getSquare()end}end
SFarmingSystem.instance=farm
F.start();F.tick();check(p.mildewLvl==80,"stale pulse skipped")
wp.Sprinklers.a.gen=9;wp.Sprinklers.b.gen=9;F.tick()
check(p.mildewLvl==66 and s.stock.Mildew+os.stock.Mildew==30000,"actual tick overlap")
F.tick();check(p.mildewLvl==66,"same gen not repeated")
-- Radius boundary.
p=plant(5,1);p.mildewLvl=80
local oldFarm=farm.getLuaObjectAt;farm.getLuaObjectAt=function(_,x,y) if x==5 and y==1 then return p end end
apply(o);check(p.mildewLvl==80,"outside circular radius")
farm.getLuaObjectAt=oldFarm
-- Source errors fail closed while recovery remains usable.
local savedReader=getModFileReader
function getModFileReader()return nil end
F.start();check(not F.ready,"source guard disables automation")
s.switches.Mildew=false;check(not F.toggle(player,o,"Mildew"),"cannot enable unsupported")
s.stock.Mildew=1;s.shells.Mildew=1;items={};F.refundKind(o,player,"Mildew")
check(F.itemUnits(items[1])==1,"guard still permits residual recovery")
getModFileReader=savedReader
F.start()
-- Live native sandbox editor changes affect the next operation and no stock.
o,s=fresh();s.stock.Mildew=123456
nativeOptions[F.KEY..".MildewCost"]=0.01
check(F.cost("Mildew")==100 and s.stock.Mildew==123456,"native editor immediate low rate, balance unchanged")
nativeOptions[F.KEY..".MildewCost"]=2
check(F.cost("Mildew")==20000 and s.stock.Mildew==123456,"native editor immediate high rate, balance unchanged")
nativeOptions={}
-- A residue package without its original bottle remains fully recoverable.
s.stock.Mildew=23456;items={};F.refundKind(o,player,"Mildew")
check(#items==1 and items[1]:getFullType()=="SQSF.CareResidue" and F.itemUnits(items[1])==23456,"shell-free residue recovery")
local packet=items[1]
check(F.load(player,o,"Mildew",packet,64) and s.stock.Mildew==23456 and s.shells.Mildew==0,"residue never creates shell")
items={};F.refundKind(o,player,"Mildew")
check(F.itemUnits(items[1])==23456 and #items==1,"repeated residue roundtrip")
packet=items[1];packet:getModData().SQSFResidue.units=0.5
check(not F.kindOf(packet) and not F.load(player,o,"Mildew",packet,64),"malformed residue rejected")
-- Fractional remaining space never rounds a native dose upward.
o,s=fresh();s.stock.Fertilizer=635000;bag=instanceItem("Base.Fertilizer");items={bag}
check(not F.load(player,o,"Fertilizer",bag,8) and F.itemUnits(bag)==80000,"half-dose room keeps native bag intact")
s.stock.Fertilizer=625000
check(F.load(player,o,"Fertilizer",bag,8) and s.stock.Fertilizer==635000 and F.itemUnits(bag)==70000,"partial capacity consumes whole native doses only")
-- Failed placement must retain the unplaced material and bottle.
o,s=fresh();s.stock.Mildew=100;s.shells.Mildew=1
local add=inventory.AddItem;inventory.AddItem=function()return nil end
local ok=pcall(F.refundKind,o,player,"Mildew")
check(not ok and s.stock.Mildew==100 and s.shells.Mildew==1,"failed refund preserves material and shell")
inventory.AddItem=add
return summary()
