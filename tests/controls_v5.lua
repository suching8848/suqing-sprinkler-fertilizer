local F=SQSF
wp={Pumps={},Pipes={},Valves={},Sprinklers={}};F.networkCache=nil;actions={}
local scene={}
function getCell()return {getGridSquare=function(_,x,y,z)return scene[F.coord(x,y,z)]end}end
local owner=pump(0,0);local os=F.state(owner,true);scene["0:0:0"]=owner:getSquare()
wp.Pumps.p={x=0,y=0,z=0,active=true,source="Water",efficiency=100}
local target=sprinkler(5,0);scene["5:0:0"]=target:getSquare()
for i=1,5 do wp.Pipes[i]={x=i,y=0,z=0,s="we"} end
local water={x=5,y=0,z=0,w=1,gen=1};wp.Sprinklers.s=water
for _,k in ipairs(F.ORDER)do os.stock[k]=100000;os.switches[k]=true end
local sources=F.connectedSources(water,F.network())
check(F.state(target,false)==nil and F.chooseSource(nil,sources,"Mildew",10000)==os,"unconfigured old sprinkler still accepts network")
check(F.canControlFromPump(player,owner,target) and not F.near(player,target),"connected distant target controlled from pump")
local initial=F.state(target,true);initial.stock.Aphids=100000
check(not initial.switches.Aphids and F.projectEnabled(initial,"Aphids"),"legacy network-only project starts enabled")
F.controlFromPump(player,owner,target,"supply","Aphids")
check(F.projectEnabled(initial,"Aphids") and F.chooseSource(initial,sources,"Aphids",10000)==initial,"first pump-OFF edit keeps active project using local stock")
F.openManager(player,owner);local w=F.windows[0];w:onAction(w.tabs.network)
check(w.remoteRows[2].project.visible and w.remoteRows[2].project.enable,"per-project remote buttons available")
check(w.remoteRows[2].supply.visible and w.remoteRows[2].supply.enable,"per-resource pump input buttons available")
w:onAction(w.remoteRows[2].project)
local s=F.state(target,false)
check(s and not F.projectEnabled(s,"Mildew") and not F.chooseSource(s,sources,"Mildew",10000),"remote OFF blocks pump")
s.stock.Mildew=100000;s.switches.Mildew=true
check(not F.chooseSource(s,sources,"Mildew",10000),"explicit project OFF also blocks local despite local flag")
local p=plant(5,0);p.mildewLvl=80;p.fliesLvl=80
local farm={getLuaObjectAt=function(_,x,y)if x==5 and y==0 then return p end end}
F.apply(target,water,farm,{}, {},sources)
check(p.mildewLvl==80 and s.stock.Mildew==100000 and os.stock.Mildew==100000,"disabled treatment never cures or debits either stock")
check(p.fliesLvl<80 and os.stock.Flies==90000,"another care project continues independently")
w:onAction(w.remoteRows[2].project)
check(F.projectEnabled(s,"Mildew") and F.chooseSource(s,sources,"Mildew",10000)==os,"remote ON restores project with network priority")
w:onAction(w.remoteRows[2].supply)
check(not F.networkEnabled(s,"Mildew") and F.networkEnabled(s,"Flies"),"pump input switches independent")
check(F.chooseSource(s,sources,"Mildew",10000)==s,"pump input OFF permits enabled local backup")
p.mildewLvl=80;F.apply(target,water,farm,{}, {},sources)
check(p.mildewLvl<80 and s.stock.Mildew==90000 and os.stock.Mildew==100000,"only local inventory consumed when pump input disabled")
w:onAction(w.remoteRows[2].project);w:onAction(w.remoteRows[2].supply)
check(F.networkEnabled(s,"Mildew") and not F.projectEnabled(s,"Mildew") and not F.chooseSource(s,sources,"Mildew",10000),"pump input cannot bypass project OFF")
local migrated=F.migrate(s)
check(migrated==s and migrated.projectDisabled.Mildew and not migrated.networkDisabled.Mildew,"optional saved flags survive migration unchanged")
w:onAction(w.remoteRows[2].project)
-- The old whole-device opt-out remains effective. Opening one item cannot open others.
s.receiveNetwork=false;F.changeSetting(player,s,"supply","Mildew")
check(F.networkEnabled(s,"Mildew") and not F.networkEnabled(s,"Fertilizer") and not F.networkEnabled(s,"Slugs"),"legacy global OFF converted without enabling other inputs")
local oldX=player.getX;player.getX=function()return 20 end
check(not F.controlFromPump(player,owner,target,"project","Mildew"),"cannot control after moving away from pump")
player.getX=oldX
wp.Valves.v={x=2,y=0,z=0,c=true};w:refreshNetwork();w:update()
check(not w.remoteRows[2].project.enable and not F.controlFromPump(player,owner,target,"project","Mildew"),"closed valve blocks stale UI and direct action")
wp.Valves={};wp.Pipes[3]=nil
check(not F.controlFromPump(player,owner,target,"supply","Mildew"),"broken pipe rejects controls")
wp.Pipes[3]={x=3,y=0,z=0,s="we"}
local sq=scene["5:0:0"];scene["5:0:0"]=nil
check(not F.controlFromPump(player,owner,target,"project","Mildew"),"unloaded target rejected")
scene["5:0:0"]=sprinkler(5,0):getSquare()
check(not F.controlFromPump(player,owner,target,"project","Mildew"),"replaced entity rejected even at same coordinate")
scene["5:0:0"]=sq;target.removed=true
check(not F.controlFromPump(player,owner,target,"project","Mildew"),"removed target rejected")
target.removed=false;actions={{Type="SQSFAction",object=target}}
check(not F.controlFromPump(player,owner,target,"project","Mildew"),"queued target action blocks competing control")
actions={{Type="SQSFAction",object=owner}}
check(not F.controlFromPump(player,owner,target,"project","Mildew"),"queued pump action blocks competing control")
actions={};check(not F.controlFromPump(player,owner,target,"load","Mildew"),"remote API cannot transfer inventory")
check(not F.controlFromPump(player,owner,target,"project","Bogus"),"unknown resource rejected")
local oldClient=isClient;isClient=function()return true end
check(not F.controlFromPump(player,owner,target,"project","Mildew"),"remote multiplayer rejected")
isClient=oldClient
wp.Pumps.p.active=false;wp.Pumps.p.source=nil
check(F.controlFromPump(player,owner,target,"supply","Mildew"),"settings can be prepared while a connected pump is stopped")
wp.Pumps.p.active=true;wp.Pumps.p.source="Water"
w:update();w:prerender();w:close()
-- Direct sprinkler controls show the same flags; all new buttons fit both fonts.
for _,h in ipairs({16,24,30})do
 setTestFontHeight(h);setTestScreenWidth(2560);F.openManager(player,target);w=F.windows[0]
 for _,row in ipairs(w.rows)do
  check(row.supply.visible and row.supply.x+row.supply.width<w.width,"direct per-resource input button fits")
  check(row.toggle.x+row.toggle.width<row.supply.x,"project and input buttons do not overlap")
 end
 w:close();F.openManager(player,owner);w=F.windows[0];w:onAction(w.tabs.network)
 for _,row in ipairs(w.remoteRows)do
  check(row.project.x>w.listWidth+35 and row.supply.x+row.supply.width<w.width,"remote buttons fit detail panel")
 end
 w:prerender();w:close()
end
setTestFontHeight(16)
return summary()
