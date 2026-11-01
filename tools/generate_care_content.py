"""Generate authored B42 items, recipes and CN/CH/EN labels."""
from pathlib import Path
import json
root=Path(__file__).resolve().parent.parent
media=root/'mods/SuQingSprinklerFertilizer/42/media'
names={'Mildew':('霉菌药剂','Mildew treatment'),'Flies':('虫害药剂','Fly treatment'),'Aphids':('蚜虫药剂','Aphid treatment'),'Slugs':('蛞蝓药剂','Slug treatment')}
items=['module SQSF\n{']
for size in (50,200):
 items.append(f'''    item EmptyPack{size}
    {{
        ItemType = base:normal,
        DisplayCategory = Gardening,
        Weight = {0.3 if size==50 else 0.6},
        Icon = SQSF_Empty,
        WorldStaticModel = Paperbag_Ground,
        Tooltip = Tooltip_SQSF_Empty,
    }}''')
 for kind in names:
  items.append(f'''    item {kind}Pack{size}
    {{
        ItemType = base:drainable,
        DisplayCategory = Gardening,
        Weight = {1.3 if size==50 else 4.6},
        UseDelta = {1/size:.3f},
        ReplaceOnDeplete = SQSF.EmptyPack{size},
        UseWhileEquipped = false,
        Icon = SQSF_{kind},
        WorldStaticModel = Paperbag_Ground,
        Tooltip = Tooltip_SQSF_Pack,
    }}''')
items.append('''    item CareResidue
    {
        ItemType = base:normal,
        DisplayCategory = Gardening,
        Weight = 0.01,
        Icon = Paperbag,
        WorldStaticModel = Paperbag_Ground,
        Tooltip = Tooltip_SQSF_Legacy,
    }
}''')
(media/'scripts/SQSF_Items.txt').write_text('\n'.join(items)+'\n',encoding='utf-8')
recipes=['module SQSF\n{'];recipe_labels={'CN':{},'CH':{},'EN':{}};recipe_data=[]
for size in (50,200):
 scale=1 if size==50 else 4
 water=1 if size==50 else 4
 for kind in names:
  variants=['Cigarettes','Tobacco','Chewing'] if kind=='Flies' else ['']
  for variant in variants:
   for refill in (False,True):
    rid=('Refill' if refill else 'Make')+kind+'Pack'+str(size)+variant
    inputs=[f'item 1 [SQSF.EmptyPack{size}] mode:destroy flags[ItemCount],' if refill else f'item {1 if size==50 else 2} [Base.Plank] mode:destroy flags[ItemCount],']
    if kind=='Mildew': inputs+=['item 1 [*],',f'-fluid {float(scale)} [CowMilk;SheepMilk;AnimalMilk],']
    else: inputs+=['item 1 [*],',f'-fluid {float(water)} [Water],']
    if kind=='Aphids': inputs+=['item 1 [*],',f'-fluid {0.2*scale:.1f} [RubbingAlcohol],']
    if kind=='Slugs': inputs+=[f'item {scale} [Base.Salt] mode:destroy flags[ItemCount],']
    if kind=='Flies':
     if variant=='Cigarettes': inputs+=[f'item {5*scale} [Base.CigaretteSingle] flags[ItemCount],']
     elif variant=='Tobacco': inputs+=[f'item {8*scale} tags[base:tobacco],']
     else: inputs+=[f'item {5*scale}.0 [Base.TobaccoChewing],']
    recipes.append(f'''    craftRecipe {rid}
    {{
        Icon = Item_SQSF_{kind},
        timedAction = Making,
        Time = {60 if size==50 else 100},
        NeedToBeLearn = false,
        Tags = InHandCraft;Farming,
        category = SuQingIrrigation,
        inputs
        {{
            '''+'\n            '.join(inputs)+f'''
        }}
        outputs
        {{
            item 1 SQSF.{kind}Pack{size},
        }}
    }}''')
    variant_cn={'Cigarettes':'香烟','Tobacco':'散烟草','Chewing':'嚼烟','':''}[variant]
    cn=('重新装填' if refill else '制作')+names[kind][0]+f'包（{size}份）'+(' · '+variant_cn if variant else '')
    en=('Refill ' if refill else 'Make ')+names[kind][1]+f' pack ({size} doses)'+(' - '+variant if variant else '')
    for lang in ('CN','CH','EN'):recipe_labels[lang][rid]=en if lang=='EN' else cn
    recipe_data.append({'id':rid,'size':size,'kind':kind,'refill':refill,'material_multiplier':scale,'water':water if kind!='Mildew' else 0,'inputs':inputs})
recipes.append('}')
(media/'scripts/SQSF_Recipes.txt').write_text('\n'.join(recipes)+'\n',encoding='utf-8')
(root/'docs/recipe-data.json').write_text(json.dumps(recipe_data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
cn={
'WindowTitle':'蘇清 · 水泵灌溉养护管理','Pump':'水泵','Sprinkler':'喷洒器',
'ThisDevice':'当前设备：%1','RemovedDevice':'待回收设备 #%1（%2）','Ready':'选择耗材后加料、开启或回收；操作完成后窗口保持打开。',
'Amount':'加入份数：','Load':'加入','Fill':'装满','Enable':'开启','Disable':'关闭','Recover':'取回',
'ReceiveOn':'接收管网药肥：开启','ReceiveOff':'接收管网药肥：关闭',
'Fertilizer':'化肥','Mildew':'霉菌药剂','Flies':'虫害药剂','Aphids':'蚜虫药剂','Slugs':'蛞蝓药剂',
'Stock':'%1 / %2 份','Cost':'每次 %1 · 本机可用 %2 次',
'PumpHint':'每类容量1000；开启后向畅通管网供料。','SprinklerHint':'每类容量200；管网优先，本机开启后备用。',
'Guard':'接口发生变化，自动功能停用；仍可回收材料。','Connected':'连接喷洒器：%1 台',
'SourcePump':'来源：水泵 %1','SourceLocal':'来源：本机库存','NoSource':'无可用供料：检查开关、库存和连接。',
'RetiredHint':'已拆除设备的库存，可在此领取。','ClaimShells':'领取旧版喷壶','ClaimShellsCount':'领取旧版喷壶（%1）',
'Rounding':'回收 %1 份；舍弃小数 %2 份。药剂需足量空包或空喷壶。',
'RecoveryHint':'取回时舍弃小数；喷雾需空药剂包或空喷壶。',
'RecipeHint':'制作分类：蘇清的水泵灌溉器升级 · 50份/200份药剂包，用空后可重新装填。',
'TooFar':'请走近设备后操作。','Busy':'正在处理加料/回收队列，请稍候。',
'Message_Unavailable':'操作条件已变化，请靠近设备后重试。','Message_Full':'容量已满或不足一整份；未扣除物品。',
'Message_Loaded':'已加入 %1 份。','Message_LoadedFull':'已加入 %1 份，当前耗材容量已满。',
'Message_Migrated':'旧余料已转换：加入 %1 份，舍弃 %2 份小数。',
'Message_NeedEmpty':'空包装容量不足。请携带空药剂包或空喷壶，库存保持原样。',
'Message_Recovered':'已取回 %1 份，舍弃 %2 份小数。','Message_ShellsClaimed':'已领取 %1 个旧版存放的空喷壶。',
'Message_Changed':'设置已更新。','Message_NoMaterial':'背包中没有可加入的对应材料，收藏物品不会使用。',
'PackUses':'药剂剩余：%1 / %2 份','PackName':'%1包〔剩余 %2 / %3 份〕',
}
en={
'WindowTitle':'SuQing Irrigation Care','Pump':'Pump','Sprinkler':'Sprinkler','ThisDevice':'This device: %1',
'RemovedDevice':'Recovery #%1 (%2)','Ready':'Load, enable or recover a resource. This window stays open.',
'Amount':'Load doses:','Load':'Load','Fill':'Fill','Enable':'Enable','Disable':'Disable','Recover':'Recover',
'ReceiveOn':'Network supply: ON','ReceiveOff':'Network supply: OFF',
'Fertilizer':'Fertilizer','Mildew':'Mildew','Flies':'Flies','Aphids':'Aphids','Slugs':'Slugs',
'Stock':'%1 / %2 doses','Cost':'Cost %1 · Local uses %2','PumpHint':'1000 per resource. Enable to supply connected pipes.',
'SprinklerHint':'200 per resource. Network first; enabled local stock is backup.',
'Guard':'API changed. Automation disabled; recovery remains available.',
'Connected':'Connected sprinklers: %1','SourcePump':'Source: pump %1','SourceLocal':'Source: local stock',
'NoSource':'No supply: check switches, stock and pipes.','RetiredHint':'Removed device: collect stored materials here.',
'ClaimShells':'Collect old spray bottles','ClaimShellsCount':'Collect old bottles (%1)',
'Rounding':'Recover %1 doses; discard %2 fractional doses. Sprays require enough empty packs/bottles.',
'RecoveryHint':'Recovery rounds down. Sprays need empty packs or bottles.',
'RecipeHint':'Crafting: SuQing Irrigation Upgrade · 50/200-dose packs leave reusable empties.',
'TooFar':'Move closer to operate this device.','Busy':'Processing queued actions. Please wait.',
'Message_Unavailable':'Conditions changed. Move closer and try again.','Message_Full':'Full, or less than one dose of space. Item unchanged.',
'Message_Loaded':'Loaded %1 doses.','Message_LoadedFull':'Loaded %1 doses. This resource is now FULL.',
'Message_Migrated':'Legacy material: loaded %1 doses; discarded %2 fractional doses.',
'Message_NeedEmpty':'Not enough empty pack/bottle capacity. Stock unchanged.',
'Message_Recovered':'Recovered %1 doses; discarded %2 fractional doses.',
'Message_ShellsClaimed':'Collected %1 previously stored spray bottles.',
'Message_Changed':'Setting updated.','Message_NoMaterial':'No matching material in inventory. Favorites are excluded.',
'PackUses':'Remaining doses: %1 / %2','PackName':'%1 pack [%2 / %3 doses]',
}
cn.update({
'TabDevice':'设备管理','TabNetwork':'管网设备（%1）','TabRecovery':'拆除余料回收（%1）',
'DeviceHeader':'当前设备：%1（%2）','Capacity':'每类容量：%1份',
'NetworkSummary':'管网可达：%1台 · %2','PumpRunning':'水泵运行／水源可用','PumpStopped':'水泵停机','PumpDry':'无可用水源',
'PulseWet':'最近供水周期：收到水','PulseDry':'最近供水周期：未收到水','PulseUnknown':'最近供水周期：尚无记录',
'NodeConnected':'管路连通','NodeDisconnected':'曾连接／当前不可达','NodeRemoved':'设备已移除','NodeUnloaded':'区域未加载，库存未知',
'DeviceEntry':'%1（%2）','ReceiveYes':'接收管网：开启','ReceiveNo':'接收管网：关闭',
'NetworkEmpty':'尚未发现可达设备；请检查管路和阀门。','RecoveryEmpty':'没有待回收材料。',
'InspectHint':'水泵旁可分项控制喷洒器；加料和取回需靠近目标。','InspectManage':'管理此设备','InspectFar':'靠近后可管理',
'StockUnknown':'库存未知','On':'开启','Off':'关闭','SupplyReady':'有可用供料，按作物需求消耗','SupplyNone':'无可用药肥：检查库存与开关',
'Previous':'上一页','Next':'下一页','Page':'第%1 / %2页','RecoverySelect':'选择拆除记录：',
'PumpResourceOn':'供料已开启','PumpResourceOff':'供料已关闭','ViewOnly':'管网查看：请走近目标设备进行加料或取回。',
})
en.update({
'TabDevice':'Device','TabNetwork':'Network (%1)','TabRecovery':'Recovery (%1)',
'DeviceHeader':'Current: %1 (%2)','Capacity':'Capacity: %1 per resource',
'NetworkSummary':'Reachable: %1 devices - %2','PumpRunning':'Pump on / water available','PumpStopped':'Pump off','PumpDry':'No usable water source',
'PulseWet':'Latest water cycle: received water','PulseDry':'Latest water cycle: no water','PulseUnknown':'Latest water cycle: not observed',
'NodeConnected':'Pipe connected','NodeDisconnected':'Previously connected / unreachable','NodeRemoved':'Device removed','NodeUnloaded':'Area unloaded; stock unknown',
'DeviceEntry':'%1 (%2)','ReceiveYes':'Network supply: ON','ReceiveNo':'Network supply: OFF',
'NetworkEmpty':'No reachable devices. Check pipes and valves.','RecoveryEmpty':'No materials awaiting recovery.',
'InspectHint':'Control connected sprinklers at the pump. Load/recover at the target.','InspectManage':'Manage this device','InspectFar':'Move closer to manage',
'StockUnknown':'Stock unknown','On':'ON','Off':'OFF','SupplyReady':'Supply available; used when crops need care','SupplyNone':'No care supply: check stock and switches',
'Previous':'Previous','Next':'Next','Page':'Page %1 / %2','RecoverySelect':'Removed device:',
'PumpResourceOn':'Supply enabled','PumpResourceOff':'Supply disabled','ViewOnly':'Network view: move close to the target to load or recover.',
})
cn.update({
'ProjectOn':'项目：开','ProjectOff':'项目：关','SupplyOn':'泵供：开','SupplyOff':'泵供：关',
'ProjectStopped':'该项已停用','SourcePumpShort':'使用水泵','SourceNoneShort':'暂无供料','SettingUnknown':'未知',
'ProjectTip':'控制该喷洒器的此项养护；关闭后水泵与本机库存都不使用。',
'SupplyTip':'只控制此项是否接收水泵药肥；关闭后仍可使用已开启的本机库存。项目总开关关闭时不会养护。',
'ViewOnly':'水泵旁可分别控制项目和泵供；加料/取回请走近目标。',
'ReceiveOn':'管网总接收：开','ReceiveOff':'管网总接收：关',
})
en.update({
'ProjectOn':'Care: ON','ProjectOff':'Care: OFF','SupplyOn':'Pump: ON','SupplyOff':'Pump: OFF',
'ProjectStopped':'Care disabled','SourcePumpShort':'From pump','SourceNoneShort':'No supply','SettingUnknown':'Unknown',
'ProjectTip':'Controls this care project on the sprinkler. OFF blocks both pump and local stock.',
'SupplyTip':'Controls pump supply for this resource only. Local stock can still work. Care OFF always prevents treatment.',
'ViewOnly':'Control care and pump input at the pump; load/recover at the target.',
'ReceiveOn':'All network input: ON','ReceiveOff':'All network input: OFF',
})
assert cn.keys()==en.keys()
for lang in ('CN','CH','EN'):
 folder=media/'lua/shared/Translate'/lang;folder.mkdir(parents=True,exist_ok=True)
 def dump(name,data): (folder/name).write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 chinese=lang!='EN';labels=cn if chinese else en
 ui={'IGUI_SQSF_'+k:v for k,v in labels.items()}
 ui['IGUI_CraftingCategories_SuQingIrrigation']='蘇清的水泵灌溉器升级' if chinese else 'SuQing Irrigation Upgrade'
 dump('IG_UI.json',ui)
 dump('ContextMenu.json',{'ContextMenu_SQSF_Manage':'管理水泵／喷洒器养护' if chinese else 'Manage irrigation care'})
 itemnames={'SQSF.CareResidue':'旧版余料包（仅供转换）' if chinese else 'Legacy residue (conversion only)'}
 for size in (50,200):
  itemnames[f'SQSF.EmptyPack{size}']=f'空药剂包（{size}份容量）' if chinese else f'Empty care pack ({size} doses)'
  for kind in names:itemnames[f'SQSF.{kind}Pack{size}']=(names[kind][0]+f'包（{size}份）') if chinese else names[kind][1]+f' pack ({size} doses)'
 dump('ItemName.json',itemnames)
 dump('Recipes.json',recipe_labels[lang])
 dump('Tooltip.json',{
  'Tooltip_SQSF_Pack':'在养护管理页加入设备。用尽后留下同规格空包；取回药剂时也可使用空包。' if chinese else 'Load through irrigation management. Depletion leaves a reusable empty pack; empty packs also recover medicine.',
  'Tooltip_SQSF_Empty':'同规格空包可重新装填任一种养护药剂，无需再次消耗木板。也可取回设备中的药剂。' if chinese else 'Refill with any care medicine of this size without more planks, or use it to recover stored medicine.',
  'Tooltip_SQSF_Legacy':'旧版兼容物品：在设备管理页加入，整数入库，小数舍弃。不再生成此物品。' if chinese else 'Legacy conversion only: load into a device to retain whole doses and discard fractions. No new residue is generated.',
 })
print('Generated 11 items,',len(recipe_data),'recipes and translated management labels.')
