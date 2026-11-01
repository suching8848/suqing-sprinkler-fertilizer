require "SQSF/Core"
require "TimedActions/ISBaseTimedAction"
require "TimedActions/ISTimedActionQueue"
local F=SQSF
F.windows={}
function F.refreshPackWeights(player)
    if not F.singlePlayer() or not player then return end
    for _,item in ipairs(F.inventoryItems(player)) do
        if F.PACKS[item:getFullType()] then
            -- Old saves may retain custom weight. Recalculate from the current
            -- item definition without altering doses, name or container.
            item:updateWeight()
        end
    end
end
function F.refreshPlayerPackWeights()
    if not F.singlePlayer() then return end
    for i=0,getNumActivePlayers()-1 do F.refreshPackWeights(getSpecificPlayer(i)) end
end
SQSFAction=ISBaseTimedAction:derive("SQSFAction")
function SQSFAction:isValid()
    if not F.singlePlayer() or not F.near(self.character,self.object) or not F.deviceKind(self.object)
        or self.object:getObjectIndex()==-1 then return false end
    if self.mode=="load" then
        return F.canLoad(F.state(self.object,false),self.kind,self.item) and F.holds(self.character,self.item)
    end
    return true
end
function SQSFAction:waitToStart()
    self.character:faceThisObject(self.object);return self.character:shouldBeTurning()
end
function SQSFAction:start()
    self:setActionAnim("Loot");self.character:SetVariable("LootPosition","Low")
end
function SQSFAction:update() self.character:faceThisObject(self.object) end
function SQSFAction:perform() ISBaseTimedAction.perform(self) end
function SQSFAction:complete()
    if not self:isValid() then F.feedback(self.character,self.object,false,"Unavailable");return false end
    local ok,reason,n,fraction
    if self.mode=="load" then ok,reason,n,fraction=F.load(self.character,self.object,self.kind,self.item,self.amount)
    elseif self.mode=="refund" then ok,reason,n,fraction=F.refundKind(self.object,self.character,self.kind,self.retiredId)
    elseif self.mode=="shells" then ok,reason,n=F.claimShells(self.object,self.character,self.retiredId)
    elseif self.mode=="toggle" then ok,reason=F.toggle(self.character,self.object,self.kind)
    elseif self.mode=="supply" then ok,reason=F.toggleNetworkResource(self.character,self.object,self.kind)
    elseif self.mode=="network" then ok,reason=F.toggleNetwork(self.character,self.object) end
    F.feedback(self.character,self.object,ok,reason,n,fraction)
    return ok==true
end
function SQSFAction:new(player,object,mode,kind,item,amount,retiredId)
    local o=ISBaseTimedAction.new(self,player)
    o.object,o.mode,o.kind,o.item,o.amount,o.retiredId=object,mode,kind,item,amount,retiredId
    o.stopOnWalk,o.stopOnRun=true,true;o.maxTime=player:isTimedActionInstant() and 1 or 40
    return o
end
function F.busy(player,object)
    local q=ISTimedActionQueue.getTimedActionQueue(player)
    for _,a in ipairs(q and q.queue or {}) do if a.Type=="SQSFAction" and a.object==object then return true end end
    return false
end
function F.feedback(player,object,ok,reason,n,fraction)
    local window=F.windows[player:getPlayerNum()]
    if window and window.object==object then
        window.message=getText("IGUI_SQSF_Message_"..(reason or "Unavailable"),n or 0,string.format("%.4f",fraction or 0))
        window.messageOK=ok==true;window:refreshSources()
    end
end
function F.queue(player,object,mode,kind,item,amount,retiredId)
    if F.busy(player,object) or not object:getSquare() or not luautils.walkAdj(player,object:getSquare()) then return false end
    if item then ISInventoryPaneContextMenu.transferIfNeeded(player,item) end
    ISTimedActionQueue.add(SQSFAction:new(player,object,mode,kind,item,amount,retiredId));return true
end
function F.queueLoad(player,object,kind,maximum)
    if F.busy(player,object) or not F.near(player,object) then return end
    local state=F.state(object,true)
    local room=F.capacity(state)-state.stock[kind]/F.SCALE
    local remaining=math.min(math.floor(room),math.floor(maximum))
    local planned={}
    for _,item in ipairs(F.findItems(player,kind)) do
        local legacy=F.legacyData(item)
        local count=math.min(F.itemUnits(item)/F.SCALE,remaining)
        if F.canLoad(state,kind,item) and ((not legacy and count>0)
            or (legacy and F.itemUnits(item)/F.SCALE<=remaining)) then
            if legacy then count=F.itemUnits(item)/F.SCALE end
            planned[#planned+1]={item=item,amount=count};remaining=remaining-count
        end
    end
    if #planned==0 then F.feedback(player,object,false,room<1 and "Full" or "NoMaterial");return end
    for _,entry in ipairs(planned) do
        ISInventoryPaneContextMenu.transferIfNeeded(player,entry.item)
        ISTimedActionQueue.add(SQSFAction:new(player,object,"load",kind,entry.item,entry.amount))
    end
end
function F.menu(playerIndex,context,worldobjects,test)
    if test or not F.singlePlayer() or not WPIso then return end
    local player,object=getSpecificPlayer(playerIndex),nil
    for _,candidate in ipairs(worldobjects) do
        local square=candidate:getSquare()
        if square then object=(WPIso.GetPump and WPIso.GetPump(square)) or (WPIso.GetSprinkler and WPIso.GetSprinkler(square)) end
        if object then break end
    end
    if object and player then
        local op=context:addOption(getText("ContextMenu_SQSF_Manage"),player,F.openManager,object)
        op.iconTexture=getTexture("media/textures/Item_SQSF_Irrigation.png")
    end
end
require "SQSF/ManagementWindow"
Events.OnGameStart.Add(F.start)
Events.OnGameStart.Add(F.refreshPlayerPackWeights)
Events.OnFillWorldObjectContextMenu.Add(F.menu)
