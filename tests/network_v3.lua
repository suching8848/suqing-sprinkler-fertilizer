local F=SQSF
local function pipe(x,y,z,shape)return {x=x,y=y,z=z,s=shape}end
local po=pump(0,0);local ps=F.state(po,true)
ps.stock.Mildew=100000;ps.switches.Mildew=true;ps.skills.Mildew=4
local sp=sprinkler(2,0);local ss=F.state(sp,true)
local water={x=2,y=0,z=0,w=1,gen=1}
wp={Pumps={p={x=0,y=0,z=0,active=true,source="Water",efficiency=100}},
 Pipes={a=pipe(1,0,0,"we"),b=pipe(2,0,0,"we"),c=pipe(3,0,0,"we")},Valves={},Sprinklers={s=water}}
local net=F.network();check(#F.connectedSources(water,net)==1,"connected straight line")
local builds=net.builds;check(F.network().builds==builds,"topology cache reused")
local p=plant(2,0);p.mildewLvl=80
local farm={getLuaObjectAt=function(_,x,y)if x==2 and y==0 then return p end end}
F.apply(sp,water,farm,{}, {},F.connectedSources(water,net))
check(p.mildewLvl==66 and ps.stock.Mildew==90000 and ss.stock.Mildew==0,"pump supply works with local switch off")
ss.stock.Mildew=10000;ss.switches.Mildew=true;ss.skills.Mildew=1
local selected=F.chooseSource(ss,F.connectedSources(water,net),"Mildew",10000)
check(selected==ps,"pump precedes local")
ss.receiveNetwork=false;check(F.chooseSource(ss,F.connectedSources(water,net),"Mildew",10000)==ss,"opt out uses enabled local")
ss.receiveNetwork=true;ps.stock.Mildew=0
check(F.chooseSource(ss,F.connectedSources(water,net),"Mildew",10000)==ss,"empty pump falls back to local")
ps.stock.Mildew=100000
wp.Valves.a={x=1,y=0,z=0,c=true};net=F.network();check(#F.connectedSources(water,net)==0 and net.builds>builds,"closed upstream valve invalidates network")
wp.Valves={downstream={x=3,y=0,z=0,c=true}};net=F.network()
check(#F.connectedSources(water,net)==0,"immediate downstream valve blocks sprinkler")
wp.Valves={};wp.Pipes.a=nil;check(#F.connectedSources(water,F.network())==0,"broken pipe stops supply")
wp.Pipes.a=pipe(1,0,0,"ns");check(#F.connectedSources(water,F.network())==0,"wrong inlet direction stops supply")
wp.Pipes.a=pipe(1,0,0,"we");net=F.network()
wp.Pumps.p.active=false;check(#F.connectedSources(water,net)==0,"pump off")
wp.Pumps.p.active=true;wp.Pumps.p.source=nil;check(#F.connectedSources(water,net)==0,"no source")
wp.Pumps.p.source="Petrol";check(#F.connectedSources(water,net)==0,"fuel pump cannot supply plant medicine")
wp.Pumps.p.source="Water"
local other={x=20,y=0,z=0,w=1};check(#F.connectedSources(other,net)==0,"independent pipe network isolated")
-- Vertical ports follow actual inlet/outlet orientation.
wp.Pipes={a=pipe(1,0,0,"wu"),b=pipe(1,0,1,"ed"),c=pipe(2,0,1,"we")}
local upper={x=2,y=0,z=1,w=1};check(#F.connectedSources(upper,F.network())==1,"vertical riser connected")
check(#F.connectedSources(water,F.network())==0,"same XY wrong floor isolated")
-- Branch with all exits closed is pruned like the native water pass.
wp.Pipes={a=pipe(1,0,0,"nwe"),b=pipe(2,0,0,"we"),c=pipe(3,0,0,"we"),d=pipe(1,-1,0,"ns")}
wp.Valves={v={x=3,y=0,z=0,c=true}}
check(#F.connectedSources(water,F.network())==0,"junction closed branch pruned")
wp.Valves={};check(#F.connectedSources(water,F.network())==1,"opened branch restored")
-- Two pumps: deterministic single source; no repeated debit across sprinklers.
local po2=pump(4,0);local ps2=F.state(po2,true);ps2.stock.Mildew=100000;ps2.switches.Mildew=true
wp.Pipes={a=pipe(1,0,0,"we"),b=pipe(2,0,0,"we"),c=pipe(3,0,0,"we")}
wp.Pumps.p2={x=4,y=0,z=0,active=true,source="Water",efficiency=100}
net=F.network();local sources=F.connectedSources(water,net)
check(#sources==2,"two active connected pumps")
ps.stock.Mildew=100000;p=plant(2,0);p.mildewLvl=80;local seen={}
F.apply(sp,water,farm,{},seen,sources);F.apply(sp,water,farm,{},seen,sources)
check(ps.stock.Mildew+ps2.stock.Mildew==190000 and p.mildewLvl==66,"single source and overlap debit")
-- A closed loop cannot hang; signatures use directions and valves.
wp.Pumps.p2=nil
wp.Pipes={a=pipe(1,0,0,"swe"),b=pipe(2,0,0,"sw"),c=pipe(2,1,0,"nw"),d=pipe(1,1,0,"ne")}
net=F.network();check(net~=nil,"closed loop traversal terminates")
-- Tick skips stale generations after startup and only handles new real water pulses.
wp.Pipes={a=pipe(1,0,0,"we"),b=pipe(2,0,0,"we")};wp.Sprinklers={s=water};water.gen=8
function getCell()return {getGridSquare=function(_,x,y,z)if x==2 and y==0 and z==0 then return sp:getSquare() end end}end
SFarmingSystem.instance=farm;p=plant(2,0);p.mildewLvl=80
F.start();F.tick();check(p.mildewLvl==80,"stale pulse on restart skipped")
water.gen=9;F.tick();check(p.mildewLvl==66,"new pulse uses pump")
F.tick();check(p.mildewLvl==66,"generation cannot replay")
F.retire(po);check(#F.connectedSources(water,F.network())==0,"retired pump no longer supplies")
local saved=getModFileReader;getModFileReader=function()return nil end
F.start();check(not F.ready,"upstream guard disables")
getModFileReader=saved;F.start()
return summary()
