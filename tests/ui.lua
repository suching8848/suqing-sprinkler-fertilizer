SQSF.start()
local o=sprinkler(0,0); local bag=instanceItem("Base.Fertilizer");items={bag}
local function context()
    return {options={},addOption=function(self,label,target,callback,...)
        local option={label=label,target=target,callback=callback,args={...}}
        self.options[#self.options+1]=option;return option
    end,addSubMenu=function(_,option,sub) option.sub=sub end}
end
ISContextMenu={getNew=function()return context()end}
local ctx=context()
SQSF.menu(0,ctx,{o},false)
check(#ctx.options==1 and #ctx.options[1].sub.options==5,"context menu shape")
local sub=ctx.options[1].sub
check(not sub.options[2].notAvailable,"load option enabled")
local action=SQSFAction:new(player,o,"load",bag,1)
check(action:isValid() and action:complete(),"timed action completes")
check(SQSF.state(o,false).doses==1 and bag.uses==7,"timed action precise amount")
local toggle=SQSFAction:new(player,o,"toggle")
check(toggle:complete() and SQSF.state(o,false).enabled,"timed switch")
local remote=sprinkler(10,10)
check(not SQSFAction:new(player,remote,"load",bag,1):complete(),"remote action blocked")
local multiplayer=isClient
isClient=function()return true end
check(not action:complete(),"multiplayer mutations blocked")
ctx=context();SQSF.menu(0,ctx,{o},false);check(#ctx.options==0,"multiplayer menu absent")
isClient=multiplayer
SQSF.ready=false;ctx=context();SQSF.menu(0,ctx,{o},false)
check(ctx.options[1].sub.options[3].notAvailable,"failed compatibility load unavailable")
check(SQSFAction:new(player,o,"refund"):complete(),"failed compatibility refund action")
return summary()
