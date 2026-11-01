-- All reservoirs use integer 1/10000 dose units. Only recovery rounds down.
SQSF = SQSF or {}
local F = SQSF
F.VERSION, F.KEY = "0.3.2-rc.1", "SuQingSprinklerFertilizer"
F.SCALE, F.CAPACITY, F.PUMP_CAPACITY, F.RADIUS = 10000, 200, 1000, 5
F.ORDER = {"Fertilizer", "Mildew", "Flies", "Aphids", "Slugs"}
F.RESOURCES = {
    Fertilizer={item="Base.Fertilizer",option="FertilizerCost",method="fertilize",capacity=8},
    Mildew={item="Base.GardeningSprayMilk",option="MildewCost",method="cureMildew",field="mildewLvl",capacity=10,shell=true},
    Flies={item="Base.GardeningSprayCigarettes",option="FliesCost",method="cureFlies",field="fliesLvl",capacity=10,shell=true},
    Aphids={item="Base.GardeningSprayAphids",option="AphidsCost",method="cureAphids",field="aphidLvl",capacity=10,shell=true},
    Slugs={item="Base.SlugRepellent",option="SlugsCost",method="cureSlugs",field="slugsLvl",capacity=10},
}
F.PACKS, F.EMPTY_PACKS = {}, { ["SQSF.EmptyPack50"]=50, ["SQSF.EmptyPack200"]=200 }
for _,k in ipairs(F.ORDER) do
    if k ~= "Fertilizer" then
        for _,n in ipairs({50,200}) do F.PACKS["SQSF."..k.."Pack"..n]={kind=k,capacity=n} end
    end
end
function F.singlePlayer() return not isClient() and not isServer() end
function F.cost(kind)
    local vars=SandboxVars and SandboxVars.SuQingSprinklerFertilizer
    local n=vars and vars[F.RESOURCES[kind].option] or 1
    local options=getSandboxOptions and getSandboxOptions()
    local option=options and options:getOptionByName(F.KEY.."."..F.RESOURCES[kind].option)
    if option then n=option:getValue() end
    if type(n)~="number" or n~=n then n=1 end
    return math.floor(math.max(0.01,math.min(2,n))*F.SCALE+0.5)
end
function F.deviceKind(object)
    if not object or not WPIso then return end
    if WPIso.IsPump and WPIso.IsPump(object) then return "Pump" end
    if WPIso.IsSprinkler(object) then return "Sprinkler" end
end
function F.coord(x,y,z) return tostring(x)..":"..tostring(y)..":"..tostring(z) end
function F.store()
    local db=ModData.getOrCreate(F.KEY)
    db.version,db.nextId,db.units,db.pumpIds=3,db.nextId or 0,db.units or {},db.pumpIds or {}
    return db
end
function F.migrate(s)
    if s.schema==nil then
        s.stock={Fertilizer=math.floor((s.doses or 0)*F.SCALE+0.5)}
        s.switches={Fertilizer=s.enabled==true};s.skills={Fertilizer=s.skill or 0};s.shells={}
        s.doses,s.enabled,s.skill=nil,nil,nil;s.schema=2
    end
    if s.schema==2 then s.schema=3;s.receiveNetwork=true end
    if s.schema~=3 then error("[SQSF] Unsupported reservoir schema") end
    for _,k in ipairs(F.ORDER) do
        s.stock[k]=s.stock[k] or 0;s.switches[k]=s.switches[k]==true
        s.skills[k]=s.skills[k] or 0;s.shells[k]=s.shells[k] or 0
    end
    s.kind=s.kind or "Sprinkler"
    return s
end
function F.capacity(s) return s and s.kind=="Pump" and F.PUMP_CAPACITY or F.CAPACITY end
function F.state(object,create)
    local kind=F.deviceKind(object)
    if not kind or not object:getSquare() then return end
    local md,db=object:getModData(),F.store()
    local id=md.SQSFId
    if id and db.units[id] and db.units[id].retired then
        if not create then return end
        id=nil
    end
    if not id and create then
        db.nextId=db.nextId+1;id=tostring(db.nextId);md.SQSFId=id;object:transmitModData()
    end
    if not id then return end
    if not db.units[id] and create then db.units[id]={} end
    if not db.units[id] then return end
    local s=F.migrate(db.units[id]);local sq=object:getSquare()
    s.kind,s.x,s.y,s.z=kind,sq:getX(),sq:getY(),sq:getZ()
    if kind=="Pump" then db.pumpIds[F.coord(s.x,s.y,s.z)]=id end
    return s,id
end
function F.legacyData(item)
    if not item or item:getFullType()~="SQSF.CareResidue" then return end
    local d=item:getModData().SQSFResidue
    if type(d)=="table" and d.schema==1 and F.RESOURCES[d.kind] and type(d.units)=="number"
        and d.units>0 and d.units<=640000 and d.units==math.floor(d.units) then return d end
end
function F.itemUnits(item)
    local legacy=F.legacyData(item)
    if legacy then return math.floor(legacy.units/F.SCALE)*F.SCALE end
    if not item or not instanceof(item,"DrainableComboItem") then return 0 end
    return math.max(0,item:getCurrentUses())*F.SCALE
end
function F.kindOf(item)
    if not item or item:isFavorite() then return end
    local legacy=F.legacyData(item);if legacy then return legacy.kind end
    if F.itemUnits(item)<=0 then return end
    local spec=F.PACKS[item:getFullType()];if spec then return spec.kind end
    for _,k in ipairs(F.ORDER) do if item:getFullType()==F.RESOURCES[k].item then return k end end
end
function F.namePack(item)
    local spec=F.PACKS[item:getFullType()]
    if spec then
        item:setName(getText("IGUI_SQSF_PackName",getText("IGUI_SQSF_"..spec.kind),item:getCurrentUses(),spec.capacity))
        item:setCustomName(true)
    end
end
function F.inventoryItems(player)
    local out={}
    local function collect(container)
        local list=container:getItems()
        for i=0,list:size()-1 do
            local item=list:get(i);out[#out+1]=item
            if instanceof(item,"InventoryContainer") then collect(item:getInventory()) end
        end
    end
    collect(player:getInventory());return out
end
function F.findItems(player,kind)
    local out={}
    for _,item in ipairs(F.inventoryItems(player)) do if F.kindOf(item)==kind then out[#out+1]=item end end
    return out
end
function F.findItem(player,kind) return F.findItems(player,kind)[1] end
function F.near(player,object)
    local sq=object and object:getSquare()
    return sq and player and not player:isDead() and player:getZ()==sq:getZ()
        and math.abs(player:getX()-sq:getX())<2 and math.abs(player:getY()-sq:getY())<2
end
function F.holds(player,item)
    for _,candidate in ipairs(F.inventoryItems(player)) do if candidate==item then return true end end
    return false
end
function F.canLoad(s,kind,item)
    if not F.ready or F.kindOf(item)~=kind then return false end
    local room=F.capacity(s)*F.SCALE-(s and s.stock[kind] or 0)
    local legacy=F.legacyData(item)
    if legacy then return room>=F.itemUnits(item) end
    return room>=F.SCALE
end
local function removeItem(player,item)
    local container=item:getContainer()
    if not container then error("[SQSF] Missing source container") end
    player:removeFromHands(item);container:Remove(item);sendRemoveItemFromContainer(container,item)
end
local function give(player,item)
    if not item or not player:getInventory():AddItem(item) then error("[SQSF] Cannot place recovered item; remaining balance retained") end
end
function F.load(player,object,kind,item,maximum)
    if not F.singlePlayer() or not F.near(player,object) or not F.holds(player,item) then return false,"Unavailable" end
    local s=F.state(object,true)
    if not s or not F.canLoad(s,kind,item) then return false,"Full" end
    local available=F.itemUnits(item);local legacy=F.legacyData(item)
    if legacy then
        removeItem(player,item);s.stock[kind]=s.stock[kind]+available
        return true,"Migrated",available/F.SCALE,(legacy.units-available)/F.SCALE
    end
    local n=math.floor(math.min(available/F.SCALE,maximum,F.capacity(s)-s.stock[kind]/F.SCALE))
    if n<=0 then return false,"Full" end
    local left=item:getCurrentUses()-n
    item:setCurrentUses(left)
    -- Native depletion returns GardeningSprayEmpty / EmptyPack and preserves count.
    if left==0 then item:UseAndSync() else F.namePack(item);syncItemFields(player,item) end
    s.stock[kind]=s.stock[kind]+n*F.SCALE
    return true,s.stock[kind]>=F.capacity(s)*F.SCALE and "LoadedFull" or "Loaded",n
end
function F.refundPlan(s,player,kind)
    local whole=math.floor(s.stock[kind]/F.SCALE);local remaining=whole;local plans={}
    if kind=="Fertilizer" then
        while remaining>0 do
            local amount=math.min(remaining,F.RESOURCES[kind].capacity)
            plans[#plans+1]={type=F.RESOURCES[kind].item,amount=amount};remaining=remaining-amount
        end
    else
        local empty={}
        for _,item in ipairs(F.inventoryItems(player)) do
            if not item:isFavorite() then
                local cap=F.EMPTY_PACKS[item:getFullType()]
                if cap then empty[#empty+1]={item=item,capacity=cap,type="SQSF."..kind.."Pack"..cap}
                elseif F.RESOURCES[kind].shell and item:getFullType()=="Base.GardeningSprayEmpty" then
                    empty[#empty+1]={item=item,capacity=10,type=F.RESOURCES[kind].item}
                end
            end
        end
        table.sort(empty,function(a,b)return a.capacity>b.capacity end)
        for _,entry in ipairs(empty) do
            if remaining<=0 then break end
            entry.amount=math.min(remaining,entry.capacity);plans[#plans+1]=entry;remaining=remaining-entry.amount
        end
        if not F.RESOURCES[kind].shell then
            while remaining>0 do
                local n=math.min(remaining,F.RESOURCES[kind].capacity)
                plans[#plans+1]={type=F.RESOURCES[kind].item,amount=n};remaining=remaining-n
            end
        end
        for i=1,s.shells[kind] do
            if remaining<=0 then break end
            local n=math.min(remaining,10);plans[#plans+1]={type=F.RESOURCES[kind].item,amount=n,legacyShell=true};remaining=remaining-n
        end
    end
    return remaining==0 and plans or nil,whole,(s.stock[kind]%F.SCALE)/F.SCALE
end
function F.refundState(s,player,kind)
    local plans,whole,fraction=F.refundPlan(s,player,kind)
    if not plans then return false,"NeedEmpty" end
    for _,plan in ipairs(plans) do
        local item=instanceItem(plan.type)
        if not item then error("[SQSF] Missing recovery item "..plan.type) end
        item:setCurrentUses(plan.amount)
        F.namePack(item)
        give(player,item)
        if plan.item then removeItem(player,plan.item) end
        if plan.legacyShell then s.shells[kind]=s.shells[kind]-1 end
        s.stock[kind]=s.stock[kind]-plan.amount*F.SCALE
    end
    s.stock[kind]=0;s.switches[kind]=false
    return true,"Recovered",whole,fraction
end
function F.refundKind(object,player,kind,retiredId)
    if not F.singlePlayer() or not F.near(player,object) then return false,"Unavailable" end
    local s
    if retiredId then
        s=F.store().units[retiredId]
        if not s or not s.retired then return false,"Unavailable" end
        s=F.migrate(s)
    else s=F.state(object,false) end
    if not s then return false,"Unavailable" end
    return F.refundState(s,player,kind)
end
function F.claimShells(object,player,retiredId)
    if not F.singlePlayer() or not F.near(player,object) then return false,"Unavailable" end
    local s=retiredId and F.store().units[retiredId] or F.state(object,false)
    if not s or (retiredId and not s.retired) then return false,"Unavailable" end
    local n=0
    for _,k in ipairs(F.ORDER) do
        while s.shells[k]>0 do give(player,instanceItem("Base.GardeningSprayEmpty"));s.shells[k]=s.shells[k]-1;n=n+1 end
    end
    return true,"ShellsClaimed",n
end
function F.networkEnabled(s,kind)
    return not s or (s.receiveNetwork~=false and not (s.networkDisabled and s.networkDisabled[kind]))
end
function F.projectEnabled(s,kind)
    if s and s.kind=="Pump" then return s.switches[kind]==true end
    if s and s.projectDisabled and s.projectDisabled[kind] then return false end
    return not s or s.switches[kind]==true or F.networkEnabled(s,kind)
end
-- Missing optional flags retain the exact pre-upgrade supply behavior. Explicit
-- project changes govern both sources; network changes affect only pump input.
function F.changeSetting(player,s,mode,kind)
    if not s or not F.RESOURCES[kind] then return false,"Unavailable" end
    if mode=="project" then
        local enable=not F.projectEnabled(s,kind)
        if enable and not F.ready then return false,"Unavailable" end
        if s.kind=="Sprinkler" then
            s.projectDisabled=s.projectDisabled or {};s.projectDisabled[kind]=not enable
        end
        s.switches[kind]=enable;s.skills[kind]=player:getPerkLevel(Perks.Farming)
    elseif mode=="supply" and s.kind=="Sprinkler" then
        local enable=not F.networkEnabled(s,kind)
        if enable and not F.ready then return false,"Unavailable" end
        -- The first explicit use of the new controls adopts their unified
        -- project semantics. A legacy network-only sprinkler must not lose an
        -- enabled project merely because its pump input was turned off.
        if F.ready and F.projectEnabled(s,kind) then
            s.switches[kind]=true;s.skills[kind]=player:getPerkLevel(Perks.Farming)
        end
        s.networkDisabled=s.networkDisabled or {}
        -- Preserve all other OFF settings when opening one item after the old
        -- whole-device network switch was disabled.
        if s.receiveNetwork==false then
            for _,k in ipairs(F.ORDER) do s.networkDisabled[k]=true end
            s.receiveNetwork=true
        end
        s.networkDisabled[kind]=not enable
    else return false,"Unavailable" end
    return true,"Changed"
end
function F.toggle(player,object,kind)
    if not F.singlePlayer() or not F.near(player,object) then return false,"Unavailable" end
    return F.changeSetting(player,F.state(object,true),"project",kind)
end
function F.toggleNetworkResource(player,object,kind)
    if not F.singlePlayer() or not F.near(player,object) then return false,"Unavailable" end
    return F.changeSetting(player,F.state(object,true),"supply",kind)
end
function F.toggleNetwork(player,object)
    if not F.singlePlayer() or not F.near(player,object) then return false,"Unavailable" end
    local s=F.state(object,true)
    if not s or s.kind~="Sprinkler" then return false,"Unavailable" end
    s.receiveNetwork=not s.receiveNetwork
    return true,"Changed"
end
function F.retiredUnits()
    local result={}
    for id,s in pairs(F.store().units) do
        if s.retired then
            local any=false
            for _,k in ipairs(F.ORDER) do if s.stock[k]>0 or s.shells[k]>0 then any=true end end
            if any then result[#result+1]={id=id,state=s} end
        end
    end
    table.sort(result,function(a,b)return tonumber(a.id)<tonumber(b.id) end)
    return result
end
function F.retire(object)
    if not F.singlePlayer() or not object or not object:getSquare() or object:getModData().silentRemove then return end
    local s,id=F.state(object,false)
    if not s then return end
    for _,k in ipairs(F.ORDER) do s.stock[k]=math.floor(s.stock[k]/F.SCALE)*F.SCALE;s.switches[k]=false end
    s.retired=true
    local key=F.coord(s.x,s.y,s.z)
    if F.store().pumpIds[key]==id then F.store().pumpIds[key]=nil end
    print("[SQSF] Removed device "..id.." retained whole doses for collection in management window")
end
