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
check(window.source:getSelected()==1 and window:getRecoveryId()==false,"first opening selects current device")
window.source:clear()
check(window:getRecoveryId()==nil,"transient empty selector is safe")
window:refreshSources()
window.source:setSelected(999)
check(window:getRecoveryId()==nil,"stale out-of-range index is safe")
window:refreshSources()
check(window.source:getSelected()==1 and window:getRecoveryId()==false,"invalid selection falls back to current device")
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
actions={};window:onAction(window.rows[2].toggle);check(actions[1]:complete() and s.switches.Mildew,"window toggle")
actions={};window:onAction(window.network);check(actions[1]:complete() and not s.receiveNetwork,"window network opt out")
actions={}
local getX=player.getX;player.getX=function()return 10 end;window:update()
check(not window.rows[2].load.enable and window.interaction=="TooFar","distance disables UI")
check(not SQSFAction:new(player,o,"toggle","Mildew"):complete(),"distance enforced at completion")
player.getX=getX
-- Retirement collection uses selector; old object cannot clone material.
s.stock.Mildew=19900;local id=o:getModData().SQSFId;F.retire(o)
local new=sprinkler(0,0);F.openManager(player,new);window=F.windows[0]
window.source:selectData(id);window:update();window:prerender()
window:refreshSources();check(window:getRecoveryId()==id,"refresh preserves existing recovery selection")
check(not window.rows[2].load.enable and window.rows[2].refund.enable,"retired selector only recovers")
items={instanceItem("Base.GardeningSprayEmpty")};actions={};window:onAction(window.rows[2].refund)
check(actions[1]:complete() and s.stock.Mildew==0,"retired selector completes recovery")
check(window:getRecoveryId()==false and window.source:getSelected()==1,"removed recovery record resets selection")
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
check(window.source.y+window.source.height<=82,"source selector avoids amount row")
window:close();setTestFontHeight(16)
local po=pump(0,0);F.openManager(player,po);window=F.windows[0]
window:update();window:prerender()
check(window:getRecoveryId()==false and not window.network.visible,"pump window opens with native combo")
window:close()
return summary()
