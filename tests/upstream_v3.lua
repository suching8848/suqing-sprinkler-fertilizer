-- Execute the installed, unmodified Water Pipes minute callback. Only its
-- scene/virtual-fluid boundary is substituted; no upstream code ships here.
local F=SQSF
local nativeTick=Events.EveryOneMinute.list[#Events.EveryOneMinute.list]
SandboxVars.Plumbing={PumpMaxWater=100,PumpEfficiencyLoss=0,PumpFilterUsage=0}
WPIso.SyncPump=function()end;WPIso.SyncBarrel=function()end
function TransmitWPModData()end
function sendServerCommand()end
SFarmingSystem.instance={getLuaObjectAt=function()end}
WPVirtual={SprinklerPourIn=function(x,y,z,amount)
 local s=wp.Sprinklers[WPUtils.Coords2Id(x,y,z)]
 local n=math.min(1,math.max(0,amount));s.w=s.w+n;return n
end}
local function point(x,y,z,shape)return {x=x,y=y,z=z,s=shape,w=0}end
local function compare(name,pipes,valves,sprinklers)
 wp={Pipes={},Valves={},Pumps={},Sprinklers={},Barrels={},Buildings={},Flowmeters={}}
 for _,p in ipairs(pipes)do wp.Pipes[WPUtils.Coords2Id(p.x,p.y,p.z)]=p end
 for _,v in ipairs(valves)do v.c=true;wp.Valves[WPUtils.Coords2Id(v.x,v.y,v.z)]=v end
 for _,s in ipairs(sprinklers)do wp.Sprinklers[WPUtils.Coords2Id(s.x,s.y,s.z)]=s end
 wp.Pumps[WPUtils.Coords2Id(0,0,0)]={x=0,y=0,z=0,active=true,source="Water",efficiency=100,filter=0}
 local net=F.network();nativeTick()
 local reach=net.reaches[F.coord(0,0,0)]
 for _,s in ipairs(sprinklers)do
  check((reach[F.coord(s.x,s.y,s.z)]==true)==(s.w>0),"native water reach: "..name.." "..F.coord(s.x,s.y,s.z))
 end
end
local function line()return {point(1,0,0,"we"),point(2,0,0,"we"),point(3,0,0,"we")}end
local function outlets()return {point(1,0,0),point(2,0,0),point(3,0,0),point(10,0,0)}end
compare("straight",line(),{},outlets())
compare("closed upstream",line(),{point(1,0,0)},outlets())
compare("closed downstream",line(),{point(3,0,0)},outlets())
local p=line();p[1].s="ns";compare("wrong inlet terminal",p,{},outlets())
p=line();p[2].s="nwe";p[#p+1]=point(2,-1,0,"ns")
compare("junction",p,{},outlets())
compare("closed junction branch",p,{point(3,0,0)},outlets())
compare("vertical",{point(1,0,0,"wu"),point(1,0,1,"ed"),point(2,0,1,"we")},{},{point(1,0,0),point(1,0,1),point(2,0,1),point(2,0,0)})
return summary()
