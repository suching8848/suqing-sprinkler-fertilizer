# 开发、验收与发布要求

2026-11-02，当前 0.3.2-rc.1。沿用其他蘇清模组的独立目录、固定 ID、多语言和版本化发布资料做法。

## 维护约定

- 固定 Mod ID SuQingSprinklerFertilizer、账本键和 SQSFId。schema 3 迁移旧库存、开关、技能及旧容器；保留 SQSF.CareResidue 仅供转换，不再创建。
- 每资源容量喷洒器 200、水泵 1000。1 份 = 10000 整数单位；五项沙盒 double 默认 1、范围 0.01～2，原生 SandboxOptions 优先。
- 正常消耗保留小数，仅回收/拆除向下取整。原版物品用 setCurrentUses 保存整数次数，禁止用 setUsedDelta 保存小数。
- 空喷壶/空包通过原生 UseAndSync 返还。取回先验证包装总容量，放置成功后扣账；不额外生成喷壶/空包，不删除旧寄存容器。
- tools/generate_care_content.py 生成物品、24个配方及翻译。50份药材1倍，200份4倍，木板1/2，重新装填用同尺寸空包。
- Network.lua 缓存拓扑，遵循真实端口、分支阀门规则，实际供水触发养护；稳定ID选供料源，同株同类同轮去重。
- 独立事件与 SQSF namespace，不改 Workshop 原件及原版农业方法，仅单人。异常打印具体错误并停用出错供料源。
- 更新上游签名前复核 WPServer.lua/WPIso.lua 的 gen/w、调用顺序及移除语义。测试直接读取本机上游，禁止提交或打包上游源码。
- CN/CH/EN 键与占位符一致。版本同步到 mod.info、Resources.lua、README、CHANGELOG、安装README、publishing。
- 不在公开Git放个人路径、存档、备份、账号日志、上游源码或反编译文件。

## 离线检查

在仓库根目录运行：
```powershell
javac -d validation tools/KahluaValidation.java tools/NativeValidation.java
python tools/run_tests.py --game '<游戏目录>' --water-pipes '<当前WaterPipes版本目录>'
python tools/validate_package.py
python tools/build_release.py
```

当前测试入口为 prelude_v3、resources_v3、network_v3、ui_fixture_v3、ui_v4 和 upstream_v3。执行真实农业方法、上游供水回调和窗口 Lua，场景/库存/UI 边界为受控替身。Java检查真实ScriptParser、CraftRecipe.Load、DrainableComboItem和Kahlua表序列化；不创建世界或游戏界面。

B42.21 CraftRecipeManager 的液体消耗使用累计 fluidConsumed。液体父输入不带 ItemCount，因此可以合计多个容器；实际制作及水容器保留纳入游戏验收。

六个透明图标由内置 image_gen 生成，导出128×128。完整提示词在 art/icon-prompts.json，最终资产在 media/textures；参考图和大图仅留本地任务资料。

## 游戏验收与回退

0.2 全部功能用户已反馈通过；0.3 制作、装填、窗口、管网、返还、搬移及保存重进待实测，参见 TESTING_0.3.md。离线通过不能称作游戏通过。

部署前确认游戏退出，完整备份并逐文件核验，仅覆盖独立模组目录；保留名单顺序及差异，不改 map_sand.bin 或上游原件。

未加载保存0.3的档可按收据恢复旧模组；已写入schema 3的档不能只换回0.2，需转换或恢复完整快照。先保护当前进度，再核实恢复时间和范围。

## 发布

Git 可先保留当前候选版源码及验证边界；创意工坊发布时再核对游戏验收、许可证、512×512封面和可见性。工坊采用Contents/mods，前置3546314080，标签Build 42/Farming/QoL，明确单人限制。由 Steam 分配首次 Workshop ID，以后更新同条目，Mod ID和物品ID保持不变。

构建与验证工具只准备本地候选包和检查结果，不创建远程、不push、不上传工坊；Git 远程同步由维护者另行执行。

0.3.1-rc.1：下拉框必须直接加载原版ISComboBox测试，禁止用宽松的空值处理替身覆盖其选择语义。clear保留旧索引、selectData找不到值不自动回退，刷新前安全读取，重建后先设定默认选项。

0.3.1补充：DeviceView只用于查看，不分配新设备ID；管网操作仍遵循实际距离。Core.waterCycle为会话内只读观察，重进清空，不写入账本。每0.75秒刷新当前窗口拓扑并保留该窗口刚失联设备；不会修改供水拓扑或原自动消耗规则。本次schema仍为3。50/200包用水1/4L、重量1.3/4.6。

## 0.3.2 控制与界面约定

- projectDisabled[kind] 是项目总停用门禁；networkDisabled[kind] 是分项水泵输入门禁。缺失标记保持旧源选择顺序及旧本机开关；不按缺料或水泵停机改变开关状态。F.chooseSource 在任何扣料前统一检查。
- 水泵远程控制仅允许 project/supply 两种设置操作，检查玩家距离、存活、单人模式、两端实体、注册记录、当前连通与排队动作；不允许 load/refund。未加载区域不写库存账本。UI 用750ms视图快照，点击重新构建/检查管网，避免每帧排序全部管路。
- 单人保存由已有 ModData 路径完成；实际保存重进仍需用户验收。降级至0.3.1会忽略新增禁用标记，需要重新核对开关和供料；不能当作完整机制回滚。
- Neat Crafting 真实 NC_CategoryList_Slot:getCategoryIcon 按内部分类名读 media/ui/CategoryIcon/SuQingIrrigation.png。文件复用 Item_SQSF_Irrigation.png 原始字节，不修改 Neat Crafting。
- tests/controls_v5.lua 覆盖实际停止扣料、独立输入、本机回退、断管/移除/换物体/卸载/距离/动作并发和布局。
