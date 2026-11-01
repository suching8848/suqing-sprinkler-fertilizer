-- Controlled UI primitives; actual management-window Lua is executed below.
UIFont={Small="Small"}
local fontHeight=16
function getTextManager()return {getFontHeight=function()return fontHeight end}end
function setTestFontHeight(h)fontHeight=h end
local screenWidth=1920
function getCore()return {getVersion=function()return "42.21.0" end,getScreenWidth=function()return screenWidth end}end
function setTestScreenWidth(w)screenWidth=w end
local testMs=0
function getTimestampMs()return testMs end
function setTestMs(ms)testMs=ms end
function getTexture()return {} end
local function widget(x,y,w,h)
    return {x=x,y=y,width=w,height=h,children={},enable=true,visible=true,
     initialise=function()end,instantiate=function()end,addToUIManager=function(self)self.added=true;self:createChildren()end,
     removeFromUIManager=function(self)self.added=false end,addChild=function(self,c)self.children[#self.children+1]=c end,
     setVisible=function(self,v)self.visible=v end,setEnable=function(self,v)self.enable=v end,
     setTitle=function(self,t)self.title=t end,drawText=function()end,drawTextCentre=function()end,drawRect=function()end,drawTextureScaled=function()end,
     setForceCursorVisible=function(self,v)self.forceCursorVisible=v end,
     setOnlyNumbers=function()end,getText=function(self)return self.text end}
end
ISCollapsableWindow=ISBaseObject:derive("ISCollapsableWindow")
function ISCollapsableWindow:new(x,y,w,h)local o=widget(x,y,w,h);setmetatable(o,self);self.__index=self;return o end
function ISCollapsableWindow:createChildren()end
function ISCollapsableWindow:update()end
function ISCollapsableWindow:prerender()end
ISButton={new=function(_,x,y,w,h,title,target,callback)local o=widget(x,y,w,h);o.title=title;o.target=target;o.callback=callback;return o end}
ISTextEntryBox=ISBaseObject:derive("ISTextEntryBox")
function ISTextEntryBox:new(text,x,y,w,h)local o=widget(x,y,w,h);o.text=text;return o end
-- Load the real ISComboBox next. Only its rendering/base UI boundary is stubbed;
-- constructor, selection, clear and data access must retain native semantics.
ISPanel=ISCollapsableWindow
ISScrollingListBox=ISPanel:derive("ISScrollingListBox")
UITransition={new=function()return {} end}
