require "ISUI/ISCollapsableWindow"
require "ISUI/ISButton"
require "ISUI/ISTextEntryBox"
require "ISUI/ISComboBox"
require "SQSF/DeviceView"
local F=SQSF
SQSFWindow=ISCollapsableWindow:derive("SQSFWindow")
local function label(key,...)return getText("IGUI_SQSF_"..key,...)end
local function setShown(widget,visible,enabled)
    widget:setVisible(visible);widget:setEnable(visible and enabled==true)
end
function SQSFWindow:new(x,y,player,object)
    local h=getTextManager():getFontHeight(UIFont.Small)
    local row=h*2+38
    local tabsY=40+h*2+18
    local controlY=tabsY+h+20
    local rowStart=controlY+h+18
    local bottom=rowStart+5*row+10
    local width=math.min(math.max(1000,h*50),getCore():getScreenWidth()-30)
    local o=ISCollapsableWindow.new(self,x,y,width,bottom+h*3+45)
    o.player,o.object,o.rowH,o.fontH=player,object,row,h
    o.tabsY,o.controlY,o.rowStart,o.bottom=tabsY,controlY,rowStart,bottom
    o.page="device";o.devicePage=1;o.knownDevices={};o.deviceEntries={};o.recoveryEntries={}
    o.backgroundColor={r=0.06,g=0.07,b=0.11,a=0.98};o.borderColor={r=0.48,g=0.38,b=0.65,a=1}
    o.resizable=false;o.title=label("WindowTitle");o.message=label("Ready");o.messageOK=true
    o:setForceCursorVisible(player:getPlayerNum()==0)
    return o
end
function SQSFWindow:addButton(x,y,w,title,action,kind)
    local b=ISButton:new(x,y,w,self.fontH+10,title,self,self.onAction)
    b.action,b.kind=action,kind;b:initialise();self:addChild(b);return b
end
function SQSFWindow:createChildren()
    ISCollapsableWindow.createChildren(self)
    local h=self.fontH;local tw=math.max(170,h*9)
    self.tabs={}
    self.tabs.device=self:addButton(15,self.tabsY,tw,label("TabDevice"),"page","device")
    self.tabs.network=self:addButton(21+tw,self.tabsY,tw,label("TabNetwork",0),"page","network")
    self.tabs.recovery=self:addButton(27+tw*2,self.tabsY,math.max(250,h*12),label("TabRecovery",0),"page","recovery")
    self.source=ISComboBox:new(15+h*9,self.controlY,self.width-45-h*9,h+10,self,self.onSource)
    self.source:initialise();self:addChild(self.source)
    local nw=math.max(225,h*12)
    self.network=self:addButton(self.width-nw-15,self.controlY,nw,label("ReceiveOn"),"network")
    self.quantity=ISTextEntryBox:new("10",15+h*5,self.controlY,80,h+10)
    self.quantity:initialise();self.quantity:instantiate();self.quantity:setOnlyNumbers(true);self:addChild(self.quantity)
    self.rows={}
    local bw=math.max(78,h*5);local gap=6
    for index,kind in ipairs(F.ORDER) do
        local y=self.rowStart+(index-1)*self.rowH
        local x=self.width-15-5*(bw+gap)+gap
        local row={kind=kind,y=y}
        row.load=self:addButton(x,y+h+18,bw,label("Load"),"load",kind)
        row.fill=self:addButton(x+bw+gap,y+h+18,bw,label("Fill"),"fill",kind)
        row.toggle=self:addButton(x+2*(bw+gap),y+h+18,bw,label("Enable"),"toggle",kind)
        row.supply=self:addButton(x+3*(bw+gap),y+h+18,bw,label("SupplyOn"),"supply",kind)
        row.refund=self:addButton(x+4*(bw+gap),y+h+18,bw,label("Recover"),"refund",kind)
        self.rows[#self.rows+1]=row
    end
    self.shells=self:addButton(15,self.bottom,math.max(240,h*14),label("ClaimShells"),"shells")
    self.listWidth=math.max(280,h*15);self.listSlots=4;self.deviceButtons={}
    self.listRowH=(self.bottom-self.rowStart-h-22)/self.listSlots
    for i=1,self.listSlots do
        self.deviceButtons[i]=self:addButton(15,self.rowStart+(i-1)*self.listRowH,self.listWidth,"","inspect",i)
    end
    local pw=math.max(85,h*4);local py=self.bottom-h-14
    self.previous=self:addButton(15,py,pw,label("Previous"),"previous")
    self.next=self:addButton(15+self.listWidth-pw,py,pw,label("Next"),"next")
    self.inspectManage=self:addButton(15,self.bottom,math.max(260,h*13),label("InspectManage"),"manage")
    self.remoteRows={}
    local rw=math.max(105,h*6)
    for i,kind in ipairs(F.ORDER) do
        local y=self.rowStart+2*h+24+(i-1)*(2*h+16)+h+2
        self.remoteRows[i]={
            project=self:addButton(self.width-21-rw*2,y,rw,"","remoteProject",kind),
            supply=self:addButton(self.width-15-rw,y,rw,"","remoteSupply",kind)}
    end
    self:refreshSources();self:refreshNetwork();self:update()
end
function SQSFWindow:getRecoveryId()
    if self.page=="recovery" and self.source then
        return self.source:getOptionData(self.source:getSelected())
    end
end
function SQSFWindow:refreshSources()
    if not self.source then return end
    local selected=self.source:getOptionData(self.source:getSelected())
    self.recoveryEntries=F.retiredUnits();self.source:clear();self.source:setSelected(0)
    for _,entry in ipairs(self.recoveryEntries) do
        local s=entry.state
        self.source:addOptionWithData(label("RemovedDevice",entry.id,F.coord(s.x,s.y,s.z)),entry.id)
    end
    if #self.recoveryEntries>0 then
        self.source:setSelected(1)
        if selected then self.source:selectData(selected) end
    elseif self.page=="recovery" then self.page="device" end
end
function SQSFWindow:refreshNetwork()
    if not self.object:getSquare() then return end
    self.deviceEntries,self.knownDevices,self.connectedCount,self.net=F.networkView(self.object,self.knownDevices)
    if not self.selectedDevice and self.deviceEntries[1] then self.selectedDevice=self.deviceEntries[1].id end
    self.devicePage=math.max(1,math.min(self.devicePage,math.max(1,math.ceil(#self.deviceEntries/self.listSlots))))
end
function SQSFWindow:inspectEntry()
    for _,entry in ipairs(self.deviceEntries) do if entry.id==self.selectedDevice then return entry end end
end
function SQSFWindow:onSource()self.message=label("Ready")end
function SQSFWindow:getState()
    if self.page=="recovery" then
        local id=self:getRecoveryId();return id and F.store().units[id],id
    end
    return F.state(self.object,false)
end
function SQSFWindow:onAction(button)
    if button.action=="page" then
        self:refreshSources();self:refreshNetwork()
        if button.kind~="recovery" or #self.recoveryEntries>0 then self.page=button.kind end
        self:update();return
    elseif button.action=="inspect" then
        local entry=self.deviceEntries[(self.devicePage-1)*self.listSlots+button.kind]
        if entry then self.selectedDevice=entry.id end
        self:update();return
    elseif button.action=="previous" or button.action=="next" then
        self.devicePage=self.devicePage+(button.action=="previous" and -1 or 1)
        self:refreshNetwork();self:update();return
    elseif button.action=="remoteProject" or button.action=="remoteSupply" then
        if self.page~="network" then return end
        self:refreshNetwork();local entry=self:inspectEntry()
        local ok,reason=F.controlFromPump(self.player,self.object,entry and entry.object,
            button.action=="remoteProject" and "project" or "supply",button.kind)
        F.feedback(self.player,self.object,ok,reason)
        self:refreshNetwork();self:update();return
    elseif button.action=="manage" then
        self:refreshNetwork();local entry=self:inspectEntry()
        if entry and entry.object and entry.exists and F.near(self.player,entry.object)
            and not F.busy(self.player,self.object) and not F.busy(self.player,entry.object) then
            F.openManager(self.player,entry.object)
        end
        return
    end
    if self.page=="network" or not F.near(self.player,self.object) or F.busy(self.player,self.object) then return end
    local retiredId=self:getRecoveryId()
    if self.page=="recovery" and not retiredId then return end
    if retiredId and button.action~="refund" and button.action~="shells" then return end
    if button.action=="load" or button.action=="fill" then
        local n=button.action=="fill" and 1000 or math.max(1,math.floor(tonumber(self.quantity:getText()) or 1))
        F.queueLoad(self.player,self.object,button.kind,n)
    else F.queue(self.player,self.object,button.action,button.kind,nil,nil,retiredId) end
end
function SQSFWindow:update()
    ISCollapsableWindow.update(self)
    if not self.rows then return end
    if not F.singlePlayer() or not self.object:getSquare() or self.object:getObjectIndex()==-1 then self:close();return end
    local now=getTimestampMs()
    if not self.nextRefresh or now>=self.nextRefresh then
        self:refreshNetwork();self:refreshSources();self.nextRefresh=now+750
    end
    local device=self.page=="device";local recovery=self.page=="recovery";local inspect=self.page=="network"
    local state=self:getState();local retired=self:getRecoveryId()
    local near=F.near(self.player,self.object);local busy=F.busy(self.player,self.object)
    local available=near and not busy;local pump=F.deviceKind(self.object)=="Pump"
    for page,b in pairs(self.tabs) do
        b:setVisible(page~="recovery" or #self.recoveryEntries>0)
        b.backgroundColor=page==self.page and {r=0.27,g=0.20,b=0.38,a=1} or {r=0.1,g=0.1,b=0.13,a=1}
    end
    self.tabs.network:setTitle(label("TabNetwork",self.connectedCount or 0))
    self.tabs.recovery:setTitle(label("TabRecovery",#self.recoveryEntries))
    self.source:setVisible(recovery);self.source:setEnabled(recovery and not busy)
    self.quantity:setVisible(device)
    self.network:setTitle(label(state and state.receiveNetwork==false and "ReceiveOff" or "ReceiveOn"))
    setShown(self.network,device and not pump,available and F.ready)
    local shells=0
    if state then for _,k in ipairs(F.ORDER) do shells=shells+state.shells[k] end end
    setShown(self.shells,not inspect and shells>0,available)
    self.shells:setTitle(label("ClaimShellsCount",shells));self.hasShells=shells>0
    for _,row in ipairs(self.rows) do
        local stock=state and state.stock[row.kind] or 0
        local cap=state and F.capacity(state) or (pump and F.PUMP_CAPACITY or F.CAPACITY)
        local can=available and F.ready and stock<cap*F.SCALE
        setShown(row.load,device,can);setShown(row.fill,device,can)
        local on=F.projectEnabled(state,row.kind)
        setShown(row.toggle,device,available and (F.ready or on))
        row.toggle:setTitle(label(pump and (on and "Disable" or "Enable") or (on and "ProjectOn" or "ProjectOff")))
        setShown(row.supply,device and not pump,available and (F.ready or F.networkEnabled(state,row.kind)))
        row.supply:setTitle(label(F.networkEnabled(state,row.kind) and "SupplyOn" or "SupplyOff"))
        row.toggle.tooltip=label(pump and "PumpHint" or "ProjectTip");row.supply.tooltip=label("SupplyTip")
        setShown(row.refund,not inspect,available and stock>0 and (device or retired~=nil))
        row.refund.tooltip=label("Rounding",math.floor(stock/F.SCALE),string.format("%.4f",stock%F.SCALE/F.SCALE))
    end
    for i,b in ipairs(self.deviceButtons) do
        local entry=self.deviceEntries[(self.devicePage-1)*self.listSlots+i]
        setShown(b,inspect and entry~=nil,entry~=nil)
        if entry then
            b:setTitle(label("DeviceEntry",label(entry.kind),entry.key))
            b.backgroundColor=entry.id==self.selectedDevice and {r=0.27,g=0.20,b=0.38,a=1} or {r=0.1,g=0.1,b=0.13,a=1}
        end
    end
    local pages=math.max(1,math.ceil(#self.deviceEntries/self.listSlots))
    setShown(self.previous,inspect and #self.deviceEntries>0,self.devicePage>1)
    setShown(self.next,inspect and #self.deviceEntries>0,self.devicePage<pages)
    local entry=self:inspectEntry()
    local remote=inspect and pump and entry and entry.kind=="Sprinkler"
    -- Paint from the 750 ms snapshot; the click path independently rechecks the
    -- live topology. Avoid sorting the entire pipe network on every UI frame.
    local canRemote=remote and entry.connected and entry.exists and entry.object
        and near and not busy and not F.busy(self.player,entry.object)
    for i,controls in ipairs(self.remoteRows) do
        local k=F.ORDER[i];local s=entry and entry.state
        local project=F.projectEnabled(s,k);local supply=F.networkEnabled(s,k)
        setShown(controls.project,remote==true,canRemote and (F.ready or project))
        setShown(controls.supply,remote==true,canRemote and (F.ready or supply))
        controls.project:setTitle(label(entry and entry.object and (project and "ProjectOn" or "ProjectOff") or "SettingUnknown"))
        controls.supply:setTitle(label(entry and entry.object and (supply and "SupplyOn" or "SupplyOff") or "SettingUnknown"))
        controls.project.tooltip=label("ProjectTip");controls.supply.tooltip=label("SupplyTip")
    end
    local manage=entry and entry.object and entry.exists and F.near(self.player,entry.object) and not busy and not F.busy(self.player,entry.object)
    setShown(self.inspectManage,inspect and entry~=nil,manage)
    self.inspectManage:setTitle(label(manage and "InspectManage" or "InspectFar"))
    self.interaction=not near and "TooFar" or (busy and "Busy" or nil)
end
function SQSFWindow:drawHeader()
    local sq=self.object:getSquare();local kind=F.deviceKind(self.object);local k=F.coord(sq:getX(),sq:getY(),sq:getZ())
    self:drawText(label("DeviceHeader",label(kind),k),15,40,0.93,0.88,1,1,UIFont.Small)
    self:drawText(label("Capacity",kind=="Pump" and F.PUMP_CAPACITY or F.CAPACITY),self.width-math.max(260,self.fontH*13),40,0.85,0.88,0.95,1,UIFont.Small)
    local status=kind=="Pump" and F.pumpViewStatus(self.net and self.net.pumps[k]) or F.pulseViewStatus({x=sq:getX(),y=sq:getY(),z=sq:getZ()})
    self:drawText(label("NetworkSummary",self.connectedCount or 0,label(status)),15,46+self.fontH,0.65,0.82,0.78,1,UIFont.Small)
end
function SQSFWindow:drawResources()
    local state=self:getState();local retired=self:getRecoveryId();local pump=F.deviceKind(self.object)=="Pump"
    if self.page=="device" then
        self:drawText(label("Amount"),15,self.controlY+4,0.85,0.85,0.92,1,UIFont.Small)
    else self:drawText(label("RecoverySelect"),15,self.controlY+4,0.85,0.85,0.92,1,UIFont.Small) end
    local sq=self.object:getSquare()
    local sources=not pump and F.connectedSources({x=sq:getX(),y=sq:getY(),z=sq:getZ()},self.net) or {}
    for _,row in ipairs(self.rows) do
        local k,y=row.kind,row.y;local stock=state and state.stock[k] or 0;local cost=F.cost(k)
        local cap=state and F.capacity(state) or (pump and F.PUMP_CAPACITY or F.CAPACITY)
        self:drawRect(10,y,self.width-20,self.rowH-5,0.6,0.15,0.13,0.22)
        local texture=k=="Fertilizer" and getTexture("Item_Fertilizer") or getTexture("media/textures/Item_SQSF_"..k..".png")
        if texture then self:drawTextureScaled(texture,18,y+8,40,40,1,1,1,1) end
        self:drawText(label(k),68,y+4,0.92,0.87,1,1,UIFont.Small)
        self:drawText(label("Stock",string.format("%.4f",stock/F.SCALE),cap),230,y+4,0.9,0.9,0.9,1,UIFont.Small)
        self:drawText(label("Cost",string.format("%.4f",cost/F.SCALE),math.floor(stock/cost)),self.width-math.max(345,self.fontH*20),y+4,0.72,0.86,0.95,1,UIFont.Small)
        self:drawRect(230,y+self.fontH+8,200,5,0.7,0.12,0.12,0.16)
        self:drawRect(230,y+self.fontH+8,200*math.min(1,stock/(cap*F.SCALE)),5,0.9,0.55,0.45,0.85)
        local text
        if retired then text=label("RetiredHint")
        elseif pump then text=label(state and state.switches[k] and "PumpResourceOn" or "PumpResourceOff")
        elseif not F.projectEnabled(state,k) then text=label("ProjectStopped")
        else
            local provider,mode,source=F.chooseSource(state,sources,k,cost)
            text=provider and label(mode=="Pump" and "SourcePump" or "SourceLocal",source or "") or label("NoSource")
        end
        self:drawText(text,68,y+self.fontH+23,0.65,0.78,0.75,1,UIFont.Small)
    end
end
function SQSFWindow:drawInspection()
    local h=self.fontH
    self:drawText(label("InspectHint"),15,self.controlY+4,0.75,0.82,0.9,1,UIFont.Small)
    if #self.deviceEntries==0 then
        self:drawText(label("NetworkEmpty"),20,self.rowStart+20,0.85,0.85,0.9,1,UIFont.Small);return
    end
    for i=1,self.listSlots do
        local entry=self.deviceEntries[(self.devicePage-1)*self.listSlots+i]
        if entry then
            local y=self.rowStart+(i-1)*self.listRowH
            self:drawText(label(entry.connection),20,y+h+13,entry.connected and 0.6 or 1,0.82,0.7,1,UIFont.Small)
            self:drawText(label(entry.waterStatus),20,y+h*2+16,0.75,0.78,0.85,1,UIFont.Small)
        end
    end
    local pages=math.max(1,math.ceil(#self.deviceEntries/self.listSlots))
    self:drawTextCentre(label("Page",self.devicePage,pages),15+self.listWidth/2,self.bottom-h-10,0.8,0.8,0.85,1,UIFont.Small)
    local entry=self:inspectEntry();if not entry then return end
    local x=self.listWidth+35;local width=self.width-x-15;local y=self.rowStart
    self:drawText(label("DeviceEntry",label(entry.kind),entry.key),x,y,0.92,0.87,1,1,UIFont.Small)
    local state=entry.state
    local detail=not entry.object and (entry.loaded and "NodeRemoved" or "NodeUnloaded")
        or (entry.kind=="Sprinkler" and (state and state.receiveNetwork==false and "ReceiveNo" or "ReceiveYes") or entry.waterStatus)
    self:drawText(label(detail),x,y+h+8,0.72,0.85,0.8,1,UIFont.Small)
    for i,k in ipairs(F.ORDER) do
        local ry=y+2*h+24+(i-1)*(2*h+16)
        self:drawRect(x,ry,width,2*h+12,0.6,0.15,0.13,0.22)
        self:drawText(label(k),x+8,ry+2,0.9,0.87,1,1,UIFont.Small)
        local stock=entry.object and label("Stock",string.format("%.4f",state and state.stock[k]/F.SCALE or 0),entry.kind=="Pump" and F.PUMP_CAPACITY or F.CAPACITY) or label("StockUnknown")
        self:drawText(stock,x+math.max(160,h*7),ry+2,0.88,0.88,0.9,1,UIFont.Small)
        if entry.kind=="Pump" then
            self:drawText(label(state and state.switches[k] and "On" or "Off"),self.width-15-math.max(65,h*3),ry+2,0.75,0.85,0.8,1,UIFont.Small)
        end
        local status,arg=F.viewSource(entry,k,self.net)
        -- Remote controls share this line. Keep the source summary compact;
        -- the selected pump/sprinkler coordinates remain in the headers.
        if entry.kind=="Sprinkler" then
            if status=="SourcePump" then status="SourcePumpShort";arg=nil
            elseif status=="NoSource" then status="SourceNoneShort" end
        end
        self:drawText(label(status,arg or ""),x+8,ry+h+6,0.65,0.78,0.75,1,UIFont.Small)
    end
end
function SQSFWindow:prerender()
    ISCollapsableWindow.prerender(self)
    if not self.rows or not self.object:getSquare() then return end
    self:drawHeader()
    if self.page=="network" then self:drawInspection() else self:drawResources() end
    if self.page~="network" then
        self:drawText(label("RecoveryHint"),self.hasShells and self.shells.width+30 or 15,self.bottom+5,0.75,0.75,0.8,1,UIFont.Small)
    end
    local message=not F.ready and label("Guard") or (self.interaction and label(self.interaction) or self.message)
    self:drawText(message or "",15,self.bottom+self.fontH+16,self.messageOK and 0.65 or 1,0.82,0.7,1,UIFont.Small)
    self:drawText(label("RecipeHint"),15,self.bottom+self.fontH*2+23,0.66,0.66,0.76,1,UIFont.Small)
end
function SQSFWindow:close()
    self:removeFromUIManager()
    if F.windows[self.player:getPlayerNum()]==self then F.windows[self.player:getPlayerNum()]=nil end
end
function F.openManager(player,object)
    if not F.singlePlayer() or not F.deviceKind(object) then return end
    F.refreshPackWeights(player)
    local previous=F.windows[player:getPlayerNum()]
    if previous then previous:close() end
    local window=SQSFWindow:new(20,30,player,object)
    window:initialise();window:addToUIManager();F.windows[player:getPlayerNum()]=window
end
