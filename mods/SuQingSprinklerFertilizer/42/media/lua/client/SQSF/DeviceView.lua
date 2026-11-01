require "SQSF/Network"
local F=SQSF
local function key(node)return F.coord(node.x,node.y,node.z)end
function F.viewDevice(node,kind)
    local cell=getCell and getCell()
    local sq=cell and cell:getGridSquare(node.x,node.y,node.z)
    local getter=kind=="Pump" and WPIso.GetPump or WPIso.GetSprinkler
    local object=sq and getter and getter(sq)
    if object and object:getObjectIndex()==-1 then object=nil end
    local state=object and F.state(object,false)
    return object,state,sq~=nil
end
function F.pumpViewStatus(pump)
    if not pump or not pump.active or (pump.efficiency or 100)<=0 then return "PumpStopped" end
    if pump.source~="Water" and pump.source~="TaintedWater" then return "PumpDry" end
    return "PumpRunning"
end
function F.pulseViewStatus(node)
    local observation=F.waterCycle and F.waterCycle[key(node)]
    if not observation then return "PulseUnknown" end
    return observation.received and "PulseWet" or "PulseDry"
end
function F.networkView(object,previous)
    local sq=object:getSquare();local origin=F.coord(sq:getX(),sq:getY(),sq:getZ())
    local kind=F.deviceKind(object);local net=F.network();local wp=GetWPModData()
    local current={};local linked={};local known={}
    for _,node in pairs(wp.Sprinklers or {}) do current["Sprinkler:"..key(node)]=node end
    for _,node in pairs(wp.Pumps or {}) do current["Pump:"..key(node)]=node end
    for id,entry in pairs(previous or {}) do known[id]={kind=entry.kind,x=entry.x,y=entry.y,z=entry.z,key=entry.key} end
    for id,node in pairs(current) do
        local otherKind=string.sub(id,1,4)=="Pump" and "Pump" or "Sprinkler"
        local reach=kind=="Pump" and net.reaches[origin] or net.reaches[key(node)]
        if otherKind~=kind and reach and reach[kind=="Pump" and key(node) or origin] then
            linked[id]=true;known[id]={kind=otherKind,x=node.x,y=node.y,z=node.z,key=key(node)}
        end
    end
    local result={};local count=0
    for id,entry in pairs(known) do
        local node=current[id];entry.id=id;entry.node=node;entry.exists=node~=nil;entry.connected=linked[id]==true
        entry.object,entry.state,entry.loaded=F.viewDevice(entry,entry.kind)
        entry.connection=not node and "NodeRemoved" or (entry.connected and "NodeConnected" or "NodeDisconnected")
        entry.waterStatus=entry.kind=="Pump" and F.pumpViewStatus(node) or F.pulseViewStatus(entry)
        if entry.connected then count=count+1 end
        result[#result+1]=entry
    end
    table.sort(result,function(a,b)return a.id<b.id end)
    return result,known,count,net
end
function F.viewSource(entry,kind,net)
    if not entry or not entry.object then return "StockUnknown" end
    local state=entry.state
    if entry.kind=="Pump" then
        if F.pumpViewStatus(entry.node)~="PumpRunning" then return F.pumpViewStatus(entry.node) end
        return state and state.switches[kind] and state.stock[kind]>=F.cost(kind) and "SupplyReady" or "SupplyNone"
    end
    if not F.projectEnabled(state,kind) then return "ProjectStopped" end
    local provider,mode,source=F.chooseSource(state,F.connectedSources(entry,net),kind,F.cost(kind))
    if not provider then return "NoSource" end
    return mode=="Pump" and "SourcePump" or "SourceLocal",source or ""
end
function F.canControlFromPump(player,pump,target)
    if not F.singlePlayer() or F.deviceKind(pump)~="Pump" or F.deviceKind(target)~="Sprinkler"
        or not F.near(player,pump) or pump:getObjectIndex()==-1 or target:getObjectIndex()==-1
        or F.busy(player,pump) or F.busy(player,target) then return false end
    local sq=target:getSquare();local psq=pump:getSquare()
    if not sq or not psq then return false end
    local node={x=sq:getX(),y=sq:getY(),z=sq:getZ()}
    if F.viewDevice(node,"Sprinkler")~=target then return false end
    local net=F.network();local pk=F.coord(psq:getX(),psq:getY(),psq:getZ())
    local reach=net.reaches[pk]
    if not net.pumps[pk] or not reach or not reach[key(node)] then return false end
    for _,registered in pairs(GetWPModData().Sprinklers or {}) do
        if key(registered)==key(node) then return true end
    end
    return false
end
function F.controlFromPump(player,pump,target,mode,kind)
    if (mode~="project" and mode~="supply") or not F.RESOURCES[kind]
        or not F.canControlFromPump(player,pump,target) then return false,"Unavailable" end
    return F.changeSetting(player,F.state(target,true),mode,kind)
end
