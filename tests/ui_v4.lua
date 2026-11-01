local F=SQSF
local empty=ISComboBox:new(0,0,200,30)
check(empty:getSelected()==0 and empty:isEmpty(),"real combo starts empty with index zero")
check(not pcall(function()return empty:getSelectedData()end),"native unsafe accessor reproduces empty-list failure")
check(empty:getOptionData(empty:getSelected())==nil,"native indexed accessor accepts empty list")
wp={Pumps={},Pipes={},Valves={},Sprinklers={}};F.networkCache=nil
local o=sprinkler(0,0);local s=F.state(o,true)
local ctx={options={},addOption=function(self,label,target,callback,object)
 local op={label=label,target=target,callback=callback,object=object};self.options[#self.options+1]=op;return op end}
F.menu(0,ctx,{o},false)
check(#ctx.options==1 and ctx.options[1].callback==F.openManager,"one direct context entry")
F.openManager(player,o);local window=F.windows[0]
check(window and window.added and #window.rows==5,"management window five resource rows")
check(window.page=="device" and window:getRecoveryId()==nil,"first opening manages current device")
check(not window.source.visible and not window.shells.visible,"no empty selector or zero-count old bottle button")
window.source:clear();window.source:setSelected(999)
check(window:getRecoveryId()==nil,"device page ignores stale recovery index")
window:refreshSources()
window:update();window:prerender()
for _,row in ipairs(window.rows)do
 for _,button in ipairs({row.load,row.fill,row.toggle,row.refund})do
  check(button.x>=0 and button.x+button.width<=window.width and button.y+button.height<=window.height,"buttons within window")
 end
end
local first=window
F.openManager(player,o);window=F.windows[0]
check(not first.added and window~=first,"opening again replaces one window")
items={instanceItem("SQSF.MildewPack200")};actions={}
window.quantity.text="50";window:onAction(window.rows[2].load)
check(#actions==1 and actions[1].amount==50,"quantity queues requested dose count")
window:onAction(window.rows[2].load);check(#actions==1,"busy double click cannot duplicate queue")
check(actions[1]:complete() and s.stock.Mildew==500000 and items[1]:getCurrentUses()==150,"queued partial load")
actions={};window:update();window:prerender()
check(window.added,"load leaves management window open")
window:onAction(window.rows[2].fill);check(#actions==1 and actions[1]:complete() and s.stock.Mildew==2000000,"fill reaches exact capacity")
actions={};window:update()
check(not window.rows[2].fill.enable and items[1]:getFullType()=="SQSF.EmptyPack200","full disables load and leaves empty pack")
check(window.message=="IGUI_SQSF_Message_LoadedFull","full feedback")
window:onAction(window.rows[2].refund);check(actions[1]:complete() and s.stock.Mildew==0,"window recovery")
actions={};window:onAction(window.rows[2].toggle);check(actions[1]:complete() and not F.projectEnabled(s,"Mildew") and not s.switches.Mildew,"window project OFF blocks both sources")
actions={};window:onAction(window.rows[2].toggle);check(actions[1]:complete() and F.projectEnabled(s,"Mildew") and s.switches.Mildew,"window project ON enables local backup")
actions={};window:onAction(window.network);check(actions[1]:complete() and not s.receiveNetwork,"window network opt out")
actions={}
local getX=player.getX;player.getX=function()return 10 end;window:update()
check(not window.rows[2].load.enable and window.interaction=="TooFar","distance disables UI")
check(not SQSFAction:new(player,o,"toggle","Mildew"):complete(),"distance enforced at completion")
player.getX=getX
-- Retirement collection uses selector; old object cannot clone material.
s.stock.Mildew=19900;local id=o:getModData().SQSFId;F.retire(o)
local new=sprinkler(0,0);F.openManager(player,new);window=F.windows[0]
window:onAction(window.tabs.recovery);window.source:selectData(id);window:update();window:prerender()
window:refreshSources();check(window:getRecoveryId()==id,"refresh preserves existing recovery selection")
check(not window.rows[2].load.enable and window.rows[2].refund.enable,"retired selector only recovers")
items={instanceItem("Base.GardeningSprayEmpty")};actions={};window:onAction(window.rows[2].refund)
check(actions[1]:complete() and s.stock.Mildew==0,"retired selector completes recovery")
check(window:getRecoveryId()~=id,"removed record cannot remain selected")
window:update();window:prerender()
check(window.added,"window remains usable after last recovery record is removed")
actions={}
-- Batch loading is constrained by capacity even with many packs.
local ns=F.state(new,true);items={instanceItem("SQSF.MildewPack50"),instanceItem("SQSF.MildewPack200"),instanceItem("SQSF.MildewPack200")}
F.queueLoad(player,new,"Mildew",1000)
check(#actions==2 and actions[1].amount==50 and actions[2].amount==150,"batch caps planned transfer")
for _,a in ipairs(actions)do check(a:complete(),"batch completes")end;actions={}
check(ns.stock.Mildew==2000000 and items[2]:getCurrentUses()==200,"batch leaves surplus pack untouched")
-- Cancelled queued actions cannot leave a permanent busy flag.
F.queue(player,new,"toggle","Mildew");check(F.busy(player,new),"busy reflects queue")
actions={};check(not F.busy(player,new),"cancel clears busy by queue inspection")
local oldClient=isClient;isClient=function()return true end
check(not SQSFAction:new(player,new,"toggle","Mildew"):complete(),"multiplayer rejected")
ctx.options={};F.menu(0,ctx,{new},false);check(#ctx.options==0,"multiplayer menu absent")
isClient=oldClient
window:close();check(F.windows[0]==nil,"window closes cleanly")
setTestScreenWidth(2560);setTestFontHeight(30)
F.openManager(player,new);window=F.windows[0];window:update();window:prerender()
check(window.width<=2530 and window.height+30<=1440,"large font fits user display")
check(window.rows[1].load.x>430,"large-font buttons do not overlap stock bar")
check(window.tabs.device.y+window.tabs.device.height<window.controlY,"tabs and controls do not overlap")
window:close();setTestFontHeight(16)
local po=pump(0,0);F.openManager(player,po);window=F.windows[0]
window:update();window:prerender()
check(window:getRecoveryId()==nil and not window.network.visible,"pump window opens in management page")
window:close()
-- Network overview includes off/unconfigured pumps, gates target management by
-- actual distance, and preserves previously connected entries after a break.
wp={Pumps={},Pipes={},Valves={},Sprinklers={}};F.networkCache=nil;F.waterCycle={}
local scene={}
function getCell()return {getGridSquare=function(_,x,y,z)return scene[F.coord(x,y,z)]end}end
local owner=pump(0,0);local ownerState=F.state(owner,true)
scene[F.coord(0,0,0)]=owner:getSquare()
wp.Pumps.p={x=0,y=0,z=0,active=true,source="Water",efficiency=100}
ownerState.stock.Mildew=50000;ownerState.switches.Mildew=true
local devices={}
for i=1,7 do
 local sp=sprinkler(i,0);devices[i]=sp;scene[F.coord(i,0,0)]=sp:getSquare()
 wp.Pipes[i]={x=i,y=0,z=0,s="we"};wp.Sprinklers[i]={x=i,y=0,z=0,w=0,gen=0}
end
local beforeId=F.store().nextId
local view,known,count,net=F.networkView(owner)
check(count==7 and #view==7,"all seven connected sprinklers listed")
check(F.store().nextId==beforeId,"inspection never allocates reservoir IDs")
check(view[1].waterStatus=="PulseUnknown","saved water does not count as an observed cycle")
F.openManager(player,owner);window=F.windows[0]
window:onAction(window.tabs.network);window:update();window:prerender()
check(window.page=="network" and window.connectedCount==7,"network tab lists reachable devices")
check(not window.rows[1].load.visible and not window.rows[1].refund.visible,"network details cannot load or recover remotely")
window:onAction(window.next);check(window.devicePage==2,"network list paginates")
window:onAction(window.deviceButtons[1]);check(window:inspectEntry().x==5,"second page selects correct device")
check(not window.inspectManage.enable,"far device management disabled")
local current=window;window:onAction(window.inspectManage);check(F.windows[0]==current,"far manage cannot bypass distance")
wp.Valves.v={x=2,y=0,z=0,c=true};window:refreshNetwork();window:update();window:prerender()
check(window:inspectEntry().connection=="NodeDisconnected" and #window.deviceEntries==7,"closed valve retains entries with unreachable status")
wp.Valves={};window:refreshNetwork();check(window:inspectEntry().connected,"reopened valve restores reachability")
wp.Pipes[3]=nil;window:refreshNetwork();check(not window:inspectEntry().connected,"broken pipe updates reachability")
wp.Pipes[3]={x=3,y=0,z=0,s="we"};window:refreshNetwork()
local savedSquare=scene[F.coord(5,0,0)];scene[F.coord(5,0,0)]=nil;window:refreshNetwork()
check(not window:inspectEntry().loaded and window:inspectEntry().state==nil,"unloaded device shows unknown stock")
scene[F.coord(5,0,0)]=savedSquare
window:onAction(window.previous);window:onAction(window.deviceButtons[1]);window:refreshNetwork();window:update()
check(window.inspectManage.enable,"near device can be managed")
window:onAction(window.inspectManage);window=F.windows[0]
check(window.object==devices[1] and window.page=="device","manage targets selected nearby device")
window:onAction(window.tabs.network);check(#window.deviceEntries==1 and window:inspectEntry().kind=="Pump","sprinkler shows upstream pump")
wp.Pumps.p.active=false;window:refreshNetwork()
check(window.connectedCount==1 and window:inspectEntry().waterStatus=="PumpStopped","stopped pump remains connected but is not supplying")
wp.Pumps.p.active=true;wp.Pumps.p.source=nil;window:refreshNetwork()
check(window:inspectEntry().waterStatus=="PumpDry","dry pump status is distinct from connection")
wp.Pumps.p.source="Water";window:refreshNetwork()
check(F.viewSource(window:inspectEntry(),"Mildew",window.net)=="SupplyReady","enabled stocked pump shows available supply")
check(F.viewSource(window:inspectEntry(),"Fertilizer",window.net)=="SupplyNone","missing material is not presented as available supply")
wp.Sprinklers[1].w=1;wp.Sprinklers[1].gen=1
SFarmingSystem.instance={getLuaObjectAt=function()end};F.tick()
check(F.pulseViewStatus(wp.Sprinklers[1])=="PulseWet","actual minute records wet cycle")
wp.Sprinklers[1].w=0;F.tick();check(F.pulseViewStatus(wp.Sprinklers[1])=="PulseDry","no new gen still records dry cycle")
window:close()
-- Empty recovery page hides and returns to device management after final claim.
for _,record in pairs(F.store().units)do if record.retired then for _,k in ipairs(F.ORDER)do record.stock[k]=0;record.shells[k]=0 end end end
F.openManager(player,owner);window=F.windows[0]
check(not window.tabs.recovery.visible and not window.source.visible,"empty recovery entry hidden")
local old=sprinkler(8,0);local oldState,oldId=F.state(old,true);oldState.stock.Fertilizer=10000;F.retire(old)
window:refreshSources();window:update();check(window.tabs.recovery.visible,"recovery tab appears for remaining material")
window:onAction(window.tabs.recovery);window.source:selectData(oldId)
check(window:getRecoveryId()==oldId,"recovery selector chooses only archived devices")
actions={};window:onAction(window.rows[1].refund);check(actions[1]:complete(),"last recovery action completes")
actions={};window:update();window:prerender()
check(window.page=="device" and not window.tabs.recovery.visible and window:getRecoveryId()==nil,"last record disappears without empty-option crash")
ownerState.shells.Mildew=1;window:update();check(window.shells.visible,"legacy bottle control appears only with real balance")
window:onAction(window.shells);check(actions[1]:complete(),"legacy bottle claim works")
actions={};window:update();check(not window.shells.visible,"legacy bottle control hides after claim")
window:close()
local oldPack=instanceItem("SQSF.MildewPack200");oldPack.uses=100;oldPack.weight=20.6;oldPack.favorite=true
items={oldPack};F.refreshPackWeights(player)
check(oldPack.uses==100 and oldPack.favorite and math.abs(oldPack.weight-2.6)<0.00001,"old carried pack weight refresh preserves remaining uses and favorite flag")
local ordinary=instanceItem("Base.GardeningSprayMilk");ordinary.weight=99;items={ordinary};F.refreshPackWeights(player)
check(ordinary.weight==99,"weight refresh ignores vanilla medicine")
return summary()
