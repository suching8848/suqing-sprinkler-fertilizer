function require() return true end
function isClient() return false end
function isServer() return false end
Events = setmetatable({}, {__index=function(t,k)
    local list = {}
    local e = {list=list, Add=function(f) list[#list+1]=f end,
        Remove=function(f) for i=#list,1,-1 do if list[i]==f then table.remove(list,i) end end end}
    rawset(t,k,e); return e
end})
local db = {}
ModData = {getOrCreate=function(k) db[k]=db[k] or {}; return db[k] end}
function instanceof(o, class) return o and o.class==class end
Perks = {Farming="Farming"}
season, growingSeasons = "Summer", true
function getClimateManager() return {getSeasonName=function() return season end} end
nativeOptions = {}
function getSandboxOptions() return {getOptionByName=function(_,name)
    if name == "PlantGrowingSeasons" then return {getValue=function() return growingSeasons end} end
    if nativeOptions[name] ~= nil then return {getValue=function() return nativeOptions[name] end} end
end} end
function getCore() return {getVersion=function() return "42.21.0" end} end
function getText(key, ...) return key end
function ZombRand() return 0 end
farming_vegetableconf = {props={Carrots={harvestLevel=6}, ChineseFruit={harvestLevel=8}}}
SFarmingSystem = {instance={hoursElapsed=100}}
WPIso = {IsSprinkler=function(o) return o and o.sprinkler end,
    GetSprinkler=function(sq) return sq.object end}
wp = {Sprinklers={}}
function GetWPModData() return wp end
function getNumActivePlayers() return 1 end
function getSpecificPlayer() return player end
ISTimedActionQueue = {getTimedActionQueue=function() return {queue=actions} end,
    add=function(a) actions[#actions+1]=a end}
actions = {}
items, ground = {}, {}
function instanceItem(name)
    local delta = name == "Base.Fertilizer" and 0.125 or 0.1
    local empty = name == "Base.GardeningSprayEmpty" or name == "SQSF.CareResidue"
    local item={class=empty and "InventoryItem" or "DrainableComboItem", uses=math.floor(1/delta+0.001), fullType=name, data={}}
    function item:getFullType() return self.fullType end
    function item:getUseDelta() return delta end
    function item:getCurrentUsesFloat() return self.uses*delta end
    function item:getCurrentUses() return self.uses end
    function item:setUsedDelta(n) self.uses=math.floor(n/delta+0.5) end
    function item:setCurrentUses(n) assert(n==math.floor(n));self.uses=n end
    function item:getModData() return self.data end
    function item:setName(n) self.name=n end
    function item:setCustomName()end
    function item:getActualWeight() return name=="Base.Fertilizer" and 5 or 1 end
    function item:setActualWeight(n) self.weight=n end
    function item:setWeight(n) self.weight=n end
    function item:setCustomWeight()end
    function item:UseAndSync() self.uses=math.max(0,self.uses-1); if self.uses==0 then inventory:Remove(self) end end
    function item:isFavorite() return self.favorite end
    return item
end
inventory = {contains=function(_,it) for _,v in ipairs(items) do if v==it then return true end end return false end,
    AddItem=function(_,it) items[#items+1]=it;return it end,
    Remove=function(_,it) for i=#items,1,-1 do if items[i]==it then table.remove(items,i) end end end,
    getFirstEvalRecurse=function(_,fn) for _,v in ipairs(items) do if fn(v) then return v end end end}
player={getInventory=function() return inventory end,getX=function()return 0 end,getY=function()return 0 end,
    getZ=function()return 0 end,isDead=function()return false end,getPerkLevel=function()return 4 end,
    isTimedActionInstant=function()return false end,removeFromHands=function()end}
function sendRemoveItemFromContainer()end
function syncItemFields()end
SandboxVars={SuQingSprinklerFertilizer={}}

function square(x,y,z)
    return {getX=function() return x end,getY=function() return y end,getZ=function() return z end,
        AddWorldInventoryItem=function(_,it) ground[#ground+1]=it;return it end}
end
function sprinkler(x,y)
    local sq=square(x,y,0);local md={}
    local o={sprinkler=true,getSquare=function()return sq end,getModData=function()return md end,
        transmitModData=function()end}
    sq.object=o;return o
end
function plant(x,y,seed)
    local p={x=x,y=y,z=0,state="seeded",typeOfSeed=seed or "Carrots",fertilizer=0,
        health=60,mildewLvl=0,fliesLvl=0,aphidLvl=0,slugsLvl=0,nextGrowing=100,nbOfGrow=2,waterNeeded=50,waterLvl=20,
        getSquare=function() return nil end,saveData=function(self) self.saves=(self.saves or 0)+1 end}
    return setmetatable(p,{__index=SPlantGlobalObject})
end
local checks=0
function check(ok,msg) checks=checks+1; if not ok then error("FAIL "..tostring(msg)) end end
function summary() return checks end

-- V3 fixtures: native integer uses and replacement containers, nested inventories.
function inventory:getItems()return {size=function()return #items end,get=function(_,i)return items[i+1]end}end
local oldAdd=inventory.AddItem
function inventory:AddItem(it)it.container=self;return oldAdd(self,it)end
local originalItem=instanceItem
function instanceItem(name)
    local item=originalItem(name)
    local cap=tonumber(string.match(name,"Pack(%d+)$"))
    local empty=string.find(name,"EmptyPack",1,true) or name=="Base.GardeningSprayEmpty" or name=="SQSF.CareResidue"
    if cap then item.uses=cap end
    if empty then item.class="InventoryItem" end
    function item:getContainer()return self.container or inventory end
    function item:getUseDelta()return cap and 1/cap or (name=="Base.Fertilizer" and 0.125 or 0.1)end
    function item:getCurrentUsesFloat()return self.uses*self:getUseDelta()end
    function item:updateWeight()
        if cap then self.weight=(cap==50 and 0.3 or 0.6)+(cap==50 and 1 or 4)*self:getCurrentUsesFloat() end
    end
    function item:UseAndSync()
        self.uses=math.max(0,self.uses-1)
        if self.uses==0 then
            local parent=self:getContainer();parent:Remove(self)
            local replacement=cap and ("SQSF.EmptyPack"..cap)
            if string.find(name,"Base.GardeningSpray",1,true) and not empty then replacement="Base.GardeningSprayEmpty" end
            if replacement then parent:AddItem(instanceItem(replacement)) end
        end
    end
    return item
end
function player:getPlayerNum()return 0 end
function player:faceThisObject()end
function player:shouldBeTurning()return false end
function player:SetVariable()end
local oldSprinkler=sprinkler
function sprinkler(x,y)
    local o=oldSprinkler(x,y)
    function o:getObjectIndex()return self.removed and -1 or 0 end
    return o
end
function pump(x,y)
    local o=sprinkler(x,y);o.sprinkler=false;o.pump=true;return o
end
WPIso.IsPump=function(o)return o and o.pump end
WPIso.GetPump=function(sq)return sq.object and sq.object.pump and sq.object end
WPIso.GetSprinkler=function(sq)return sq.object and sq.object.sprinkler and sq.object end
luautils={walkAdj=function()return true end}
ISInventoryPaneContextMenu={transferIfNeeded=function()end}
