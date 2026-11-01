require "SQSF/Resources"
local F=SQSF
local directions={n={0,-1,0,"s"},s={0,1,0,"n"},w={-1,0,0,"e"},e={1,0,0,"w"},u={0,0,1,"d"},d={0,0,-1,"u"}}
local shapes={ne=true,se=true,sw=true,nw=true,ns=true,we=true,nd=true,sd=true,wd=true,ed=true,
    nu=true,su=true,wu=true,eu=true,nsw=true,swe=true,nse=true,nwe=true,nswe=true}
local function steps(pipe,inlet)
    local result={};local shape=pipe.s
    if not shapes[shape] or not string.find(shape,inlet,1,true) then return result end
    for i=1,#shape do
        local port=string.sub(shape,i,i)
        if port~=inlet then
            local d=directions[port]
            result[#result+1]={x=pipe.x+d[1],y=pipe.y+d[2],z=pipe.z+d[3],inlet=d[4]}
        end
    end
    return result
end
local function key(node) return F.coord(node.x,node.y,node.z) end
function F.network()
    local gmd=GetWPModData and GetWPModData() or {}
    local sig,pipes,valves,pumps={},{},{},{}
    for _,p in pairs(gmd.Pipes or {}) do local k=key(p);pipes[k]=p;sig[#sig+1]="p"..k..":"..tostring(p.s) end
    for _,v in pairs(gmd.Valves or {}) do local k=key(v);valves[k]=v;sig[#sig+1]="v"..k..":"..tostring(v.c) end
    for _,p in pairs(gmd.Pumps or {}) do local k=key(p);pumps[k]=p;sig[#sig+1]="m"..k end
    table.sort(sig);sig=table.concat(sig,"|")
    if F.networkCache and F.networkCache.signature==sig then
        F.networkCache.pumps=pumps
        return F.networkCache
    end
    local net={signature=sig,pumps=pumps,reaches={},builds=(F.networkCache and F.networkCache.builds or 0)+1}
    -- Author-written port traversal. Mirrors the installed mod's documented
    -- directed ports, branch valve pruning and immediate downstream valve rule.
    local function openBranch(node,depth,seen)
        while true do
            local k=key(node);local visit=k..":"..node.inlet
            if seen[visit] or pumps[k] then return false end
            seen[visit]=true
            local pipe=pipes[k]
            if not pipe then return true end
            if valves[k] and valves[k].c then return false end
            if depth>10 then return false end
            local nexts=steps(pipe,node.inlet)
            if #nexts==0 then return true end
            if #nexts==1 then node=nexts[1]
            else
                for _,n in ipairs(nexts) do
                    local copy={};for x,v in pairs(seen) do copy[x]=v end
                    if openBranch(n,depth+1,copy) then return true end
                end
                return false
            end
        end
    end
    for pumpKey,pump in pairs(pumps) do
        local visited,reach,queue={},{},{}
        for _,port in ipairs({"n","s","w","e"}) do
            local d=directions[port];queue[#queue+1]={x=pump.x+d[1],y=pump.y+d[2],z=pump.z,inlet=d[4]}
        end
        local index=1
        while index<=#queue do
            local node=queue[index];index=index+1
            local k=key(node);local visit=k..":"..node.inlet;local pipe=pipes[k]
            if pipe and not pumps[k] and not visited[visit] then
                visited[visit]=true
                local nexts=steps(pipe,node.inlet)
                -- Native traversal fills the current sprinkler before consulting
                -- outgoing ports, including a terminal pipe with no valid exit.
                do
                    local blocked=#nexts>0
                    for _,n in ipairs(nexts) do if not (valves[key(n)] and valves[key(n)].c) then blocked=false end end
                    if not blocked then reach[k]=true end
                    if not (valves[k] and valves[k].c) then
                        for _,n in ipairs(nexts) do
                            if #nexts==1 or openBranch(n,0,{}) then queue[#queue+1]=n end
                        end
                    end
                end
            end
        end
        net.reaches[pumpKey]=reach
    end
    F.networkCache=net;return net
end
function F.connectedSources(sprinkler,net)
    net=net or F.networkCache or F.network()
    local db=F.store();local result={};local target=key(sprinkler)
    for pumpKey,reach in pairs(net.reaches) do
        local pump=net.pumps[pumpKey];local id=db.pumpIds[pumpKey];local state=id and db.units[id]
        if reach[target] and state and not state.retired and pump.active
            and (pump.source=="Water" or pump.source=="TaintedWater") and (pump.efficiency or 100)>0 then
            result[#result+1]={state=F.migrate(state),id=id,key=pumpKey}
        end
    end
    table.sort(result,function(a,b)return tonumber(a.id)<tonumber(b.id) end)
    return result
end
function F.chooseSource(localState,sources,kind,cost)
    if localState and localState.projectDisabled and localState.projectDisabled[kind] then return end
    if F.networkEnabled(localState,kind) then
        for _,entry in ipairs(sources) do
            local s=entry.state
            if s.switches[kind] and s.stock[kind]>=cost then return s,"Pump",entry.key end
        end
    end
    if localState and localState.switches[kind] and localState.stock[kind]>=cost then return localState,"Local" end
end
