local F=SQSF
check(F.upstreamMatches(),"installed Water Pipes signature")
F.start()
check(F.ready,"compatible initialization")
local o=sprinkler(0,0)
local s=F.state(o,true)
check(not s.enabled and s.doses==0,"default off")
local bag=instanceItem("Base.Fertilizer");items={bag}
check(F.load(player,o,bag,1) and bag.uses==7 and s.doses==1,"one native dose")
bag.favorite=true
check(not F.load(player,o,bag,8) and s.doses==1,"favorite protected")
bag.favorite=false
check(F.load(player,o,bag,8) and bag.uses==0 and s.doses==8,"partial bag")
F.toggle(player,o)
check(s.enabled and s.skill==4,"owner skill")
local p=plant(0,0)
local farm={getLuaObjectAt=function(_,x,y,z) if x==0 and y==0 then return p end end}
local water={x=0,y=0,z=0,w=1,gen=1}
F.apply(o,water,farm,{})
check(p.fertilizer==1 and p.nextGrowing==60 and p.health==70 and p.bonusYield,"native effect preserved")
check(s.doses==7,"one application one dose")
F.apply(o,water,farm,{})
check(s.doses==7 and p.health==70,"no repeated fertilizer damage")
local other=sprinkler(1,0);local otherState=F.state(other,true);otherState.doses=8;otherState.enabled=true
F.apply(other,water,farm,{})
check(otherState.doses==8,"overlapping sprinklers deduplicated")
p.fertilizer=0;p.nbOfGrow=3
F.apply(o,water,farm,{})
check(p.fertilizer==1 and s.doses==6,"eligible growth reset")
p=plant(0,0);water.w=0
F.apply(o,water,farm,{})
check(p.fertilizer==0 and s.doses==6,"no water")
water.w=1;s.enabled=false
F.apply(o,water,farm,{})
check(p.fertilizer==0,"switch off")
s.enabled=true
actions={{Type="ISFertilizeAction",plant=p}}
F.apply(o,water,farm,F.queuedPlants())
check(p.fertilizer==0 and s.doses==6,"pending manual/batch action protected")
actions={};p:fertilize({skill=4})
F.apply(o,water,farm,{})
check(p.fertilizer==1 and s.doses==6,"manual applied before sprinkler")
p=plant(0,0);season="Winter"
F.apply(o,water,farm,{})
check(p.fertilizer==0,"winter no-effect skipped")
growingSeasons=false;F.apply(o,water,farm,{})
check(p.fertilizer==1,"season sandbox honored")
growingSeasons=true;season="Summer"
for _,state in ipairs({"dead","rotten","destroyed","harvested","plow"}) do
    p=plant(0,0);p.state=state;check(not F.eligible(p),"invalid state "..state)
end
p=plant(0,0,"Unknown");check(not F.eligible(p),"unknown crop skipped")
p=plant(0,0,"ChineseFruit");check(F.eligible(p),"standard API mod crop")
p.fertilize=function()end;check(not F.eligible(p),"custom fertilizer method skipped")
p=plant(5,1);local outside=p
farm.getLuaObjectAt=function(_,x,y) if x==5 and y==1 then return outside end end
F.apply(o,water,farm,{})
check(outside.fertilizer==0,"circular radius boundary")
-- Reload-equivalent reconstruction retains only serializable ledger and object ID.
local id=o:getModData().SQSFId;local copy=sprinkler(0,0);copy:getModData().SQSFId=id
check(F.state(copy,false)==s,"persisted ledger identity")
local before=s.doses;items={};F.refund(copy,player)
local returned=0;for _,it in ipairs(items)do returned=returned+it.uses end
check(returned==before and s.doses==0 and not s.enabled,"exact refund")
F.refund(o,player)
check(#items==1,"copied object ID cannot refund twice")
s.doses=13;s.enabled=true;ground={};F.removed(o)
check(#ground==2 and ground[1].uses==8 and ground[2].uses==5 and s.doses==0,"demolition ground refund")
F.removed(copy);check(#ground==2,"moveable copy no duplicate refund")
local replacement=sprinkler(0,0)
check(F.state(replacement,true).doses==0,"replacement never inherits old balance")
s.doses=63;bag=instanceItem("Base.Fertilizer");items={bag};F.load(player,o,bag,8)
check(s.doses==64 and bag.uses==7,"capacity exact")
s.doses=0;s.enabled=true;p=plant(0,0)
farm.getLuaObjectAt=function(_,x,y) if x==0 and y==0 then return p end end
F.apply(o,water,farm,{})
check(p.fertilizer==0,"empty reservoir")
-- Integration of pulse generation, no stale pulse after a reload.
SFarmingSystem.instance=farm;wp.Sprinklers={a=water};water.gen=4
function getCell()return {getGridSquare=function()return o:getSquare()end}end
s.doses=8;F.start();F.tick()
check(p.fertilizer==0,"loaded stale water ignored")
water.gen=5;F.tick();check(p.fertilizer==1 and s.doses==7,"fresh pulse")
p.fertilizer=0;F.tick();check(p.fertilizer==0,"same pulse ignored")
-- Error reports and disables only this reservoir; no silent free retries.
p.fertilize=SPlantGlobalObject.fertilize;p.saveData=function()error("injected save failure")end
water.gen=6;F.tick()
check(not s.enabled and s.doses==6,"exception disables reservoir")
local savedReader=getModFileReader
function getModFileReader()return nil end
F.start();check(not F.ready,"upstream missing fails closed")
check(not F.toggle(player,o),"cannot enable unsupported code")
items={};F.refund(o,player);check(s.doses==0,"recovery still possible")
getModFileReader=savedReader
return summary()
