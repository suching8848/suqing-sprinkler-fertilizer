local F=SQSF
F.start()
local o=sprinkler(0,0);local bag=instanceItem("Base.Fertilizer");items={bag}
local function context()
    return {options={},addOption=function(self,label,target,callback,...)
        local op={label=label,target=target,callback=callback,args={...}}
        self.options[#self.options+1]=op;return op
    end,addSubMenu=function(_,op,sub)op.sub=sub end}
end
ISContextMenu={getNew=function()return context()end}
local ctx=context();F.menu(0,ctx,{o},false)
check(#ctx.options==1 and #ctx.options[1].sub.options==6,"five resource submenus plus recovery")
local function option(menu,label)
    for _,op in ipairs(menu.options)do if op.label==label then return op end end
end
local sub=ctx.options[1].sub.options[1].sub
check(not option(sub,"ContextMenu_SQSF_LoadOne").notAvailable,"fertilizer load available")
local a=SQSFAction:new(player,o,"load","Fertilizer",bag,1)
check(a:isValid() and a:complete() and F.state(o,false).stock.Fertilizer==10000,"timed load")
check(SQSFAction:new(player,o,"toggle","Fertilizer"):complete(),"timed switch")
local bottle=instanceItem("Base.GardeningSprayMilk");items={bottle}
a=SQSFAction:new(player,o,"load","Mildew",bottle,10)
check(a:complete() and #items==0 and F.state(o,false).shells.Mildew==1,"timed medicine load")
check(SQSFAction:new(player,o,"refund","Mildew"):complete() and #items==1,"timed medicine recovery")
local remote=sprinkler(10,10)
check(not SQSFAction:new(player,remote,"toggle","Flies"):complete(),"remote actions rejected")
local sp=isClient;isClient=function()return true end
check(not SQSFAction:new(player,o,"refundAll"):complete(),"multiplayer mutations rejected")
ctx=context();F.menu(0,ctx,{o},false);check(#ctx.options==0,"multiplayer menu absent")
isClient=sp
F.ready=false;items={instanceItem("Base.Fertilizer")};ctx=context();F.menu(0,ctx,{o},false)
sub=ctx.options[1].sub.options[2].sub
check(option(sub,"ContextMenu_SQSF_LoadOne").notAvailable,"guard disables menu load")
check(SQSFAction:new(player,o,"refundAll"):complete(),"guard permits all recovery")
return summary()
