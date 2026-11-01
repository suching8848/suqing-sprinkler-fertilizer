require "SQSF/Network"
local F = SQSF
F.ready = false
function F.upstreamMatches()
    local signatures = {
        { "media/lua/server/WPServer.lua", 1608318257 },
        { "media/lua/shared/WPIso.lua", 3158132023 },
    }
    for _, entry in ipairs(signatures) do
        local reader = getModFileReader("Waterpipes", entry[1], false)
        if not reader then return false end
        local lines = {}
        while true do
            local line = reader:readLine()
            if line == nil then break end
            lines[#lines + 1] = line
        end
        reader:close()
        local text = table.concat(lines, "\n")
        local a, b = 1, 0
        for i = 1, #text do
            local byte = string.byte(text, i)
            if byte < 128 then
                a = (a + byte) % 65521
                b = (b + a) % 65521
            end
        end
        if b * 65536 + a ~= entry[2] then return false end
    end
    return true
end

function F.eligible(plant, kind)
    local spec = F.RESOURCES[kind]
    if not plant or not SPlantGlobalObject or plant[spec.method] ~= SPlantGlobalObject[spec.method]
        or type(plant.isAlive) ~= "function" or not plant:isAlive() or plant.state ~= "seeded"
        or type(plant.health) ~= "number" or plant.health <= 0 then return false end
    local prop = farming_vegetableconf and farming_vegetableconf.props[plant.typeOfSeed]
    if not prop then return false end
    if kind ~= "Fertilizer" then return type(plant[spec.field]) == "number" and plant[spec.field] > 0 end
    if type(plant.fertilizer) ~= "number" or plant.fertilizer ~= 0
        or type(plant.nextGrowing) ~= "number" or plant.nextGrowing <= 1
        or type(plant.nbOfGrow) ~= "number" then return false end
    if getSandboxOptions():getOptionByName("PlantGrowingSeasons"):getValue()
        and getClimateManager():getSeasonName() == "Winter" then return false end
    return true
end
function F.positionKey(x,y,z)
    return tostring(x)..":"..tostring(y)..":"..tostring(z)
end
function F.queuedPlants()
    local blocked = {}
    for i=0,getNumActivePlayers()-1 do
        local player = getSpecificPlayer(i)
        local queue = player and ISTimedActionQueue.getTimedActionQueue(player)
        if queue and queue.queue then
            for _,action in ipairs(queue.queue) do
                if (action.Type == "ISFertilizeAction" or action.Type == "ISCurePlantAction") and action.plant then
                    local p=action.plant
                    blocked[F.positionKey(p.x,p.y,p.z)] = true
                end
            end
        end
    end
    return blocked
end
function F.apply(object,sprinkler,farming,blocked,processed,sources)
    if type(sprinkler.w)~="number" or sprinkler.w<=0 then return end
    local state=F.state(object,false)
    sources=sources or F.connectedSources(sprinkler)
    local active,costs=false,{}
    for _,k in ipairs(F.ORDER) do
        costs[k]=F.cost(k)
        if F.chooseSource(state,sources,k,costs[k]) then active=true end
    end
    if not active then return end
    for dx=-F.RADIUS,F.RADIUS do
        for dy=-F.RADIUS,F.RADIUS do
            if dx*dx+dy*dy<=F.RADIUS*F.RADIUS then
                local x,y,z=sprinkler.x+dx,sprinkler.y+dy,sprinkler.z
                local pos=F.positionKey(x,y,z)
                if not blocked[pos] then
                    local plant=farming:getLuaObjectAt(x,y,z)
                    for _,k in ipairs(F.ORDER) do
                        local key=pos..":"..k
                        local supply=F.chooseSource(state,sources,k,costs[k])
                        if supply and not processed[key] and F.eligible(plant,k) then
                            processed[key]=true;supply.stock[k]=supply.stock[k]-costs[k]
                            local ok,err=pcall(function()
                                if k=="Fertilizer" then plant:fertilize({compost=false,skill=supply.skills[k]})
                                else plant[F.RESOURCES[k].method](plant,nil,1,supply.skills[k]) end
                            end)
                            if not ok then
                                for _,kind in ipairs(F.ORDER) do supply.switches[kind]=false end
                                error(err)
                            end
                        end
                    end
                end
            end
        end
    end
end
F.lastGen={}
F.waterCycle={}
function F.tick()
    if not F.ready or not F.singlePlayer() then return end
    local farming=SFarmingSystem and SFarmingSystem.instance
    local wp=GetWPModData and GetWPModData()
    if not farming or not wp or type(wp.Sprinklers) ~= "table" then return end
    local blocked,processed=F.queuedPlants(),{}
    local net=F.network()
    for id,sprinkler in pairs(wp.Sprinklers) do
        -- Read-only UI observation, after the upstream minute pass. Do not
        -- interpret a saved w/gen value as a newly observed watering cycle.
        F.waterCycle[F.coord(sprinkler.x,sprinkler.y,sprinkler.z)]={received=(sprinkler.w or 0)>0}
        if type(sprinkler.gen) == "number" and F.lastGen[id] ~= sprinkler.gen then
            F.lastGen[id]=sprinkler.gen
            local sq=getCell():getGridSquare(sprinkler.x,sprinkler.y,sprinkler.z)
            local object=sq and WPIso.GetSprinkler(sq)
            if object then
                local ok,err=pcall(F.apply,object,sprinkler,farming,blocked,processed,F.connectedSources(sprinkler,net))
                if not ok then
                    local s=F.state(object,false)
                    if s then for _,k in ipairs(F.ORDER) do s.switches[k]=false end end
                    print("[SQSF] Automation stopped for "..tostring(id)..": "..tostring(err))
                end
            end
        end
    end
end
F.removed=F.retire
function F.start()
    F.ready=false
    Events.EveryOneMinute.Remove(F.tick)
    if not F.singlePlayer() then return end
    Events.OnObjectAboutToBeRemoved.Remove(F.removed)
    Events.OnObjectAboutToBeRemoved.Add(F.removed)
    if not string.match(getCore():getVersion(),"^42%.21%.") or not WPIso
        or not WPIso.GetSprinkler or not GetWPModData or not SPlantGlobalObject then
        print("[SQSF] Unsupported game/Water Pipes API; automation disabled")
        return
    end
    local ok,matches=pcall(F.upstreamMatches)
    if not ok or not matches then
        print("[SQSF] Water Pipes source changed/unreadable; automation disabled, recovery available")
        return
    end
    for _,spec in pairs(F.RESOURCES) do
        if type(SPlantGlobalObject[spec.method]) ~= "function" then
            print("[SQSF] Missing plant method "..spec.method.."; automation disabled")
            return
        end
    end
    F.ready=true
    F.lastGen={};F.waterCycle={}
    local wp=GetWPModData()
    for id,s in pairs(wp.Sprinklers or {}) do F.lastGen[id]=s.gen end
    Events.EveryOneMinute.Add(F.tick)
    print("[SQSF] "..F.VERSION.." ready (single player)")
end
