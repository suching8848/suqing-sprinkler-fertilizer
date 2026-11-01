# 1.0.0 正式版发布记录 / Stable release notes

日期：2026-11-02（北京时间）。状态：本地1.0.0正式版准备完成；尚未创建或上传Steam创意工坊条目。

## 发布内容

- 名称：蘇清的灌溉养护模组 / SuQing’s Irrigation Care Mod。
- 版本：1.0.0。源码继续使用既有仓库 `https://github.com/suching8848/suqing-sprinkler-fertilizer`，不新建重复仓库。
- 固定Mod ID：`SuQingSprinklerFertilizer`；账本键、物品ID及schema 3保持不变。
- 适用：Project Zomboid Build 42.21单人。唯一必需前置为Water Pipes，Workshop ID `3546314080`、Mod ID `Waterpipes`。
- 整合0.3.2现有功能：水泵集中供肥供药，五项养护及独立泵供控制，喷洒器200/水泵1000每类容量，管理窗口、余料回收和24个50/200份药剂包制作/装填配方。
- 本次提升正式版本并整理封面、文档和发布资料，不新增玩法或存档机制。

## 验收记录与边界

用户在2026-11-02反馈“我玩着没什么问题了”，并授权准备v1.0.0正式版。该记录表示用户对当前单人游玩体验的整体反馈；不据此声称所有模组作物、迁移、搬移、保存重进、联机或全部菜单分支均逐项实测。

2026-11-02以1.0.0源码复跑通过：2405项Kahlua断言、85项原生接口检查，以及18份翻译、5项沙盒参数、24个配方、11个物品和6个透明图标的包校验。离线检查使用真实农业方法、当前已安装Water Pipes回调和原生接口，部分地图、库存与UI边界使用受控替身。复用了本机已有Java辅助class，未重新编译Java；全部模组Lua由本次游戏Kahlua重新编译执行。具体输出及源码哈希见`validation/test-result.json`和`validation/test-output.txt`，这些本机输出不提交到Git。该轮未启动游戏或进入世界。

[单人复查清单](TESTING_0.3.2.md)继续保留供后续更新回归，历史候选版清单和变更记录不改写为逐项通过。

## 消耗设置与个人存档

发行五项消耗倍率仍默认1、范围0.01～2。用户个人单人档的五项0.05属于存档配置，表示每次对应养护消耗0.05份，不改变发行默认；不将个人存档、`map_sand.bin`、启用名单或备份放入模组发布包。药效、容量、药剂包配方和库存数值不因提升正式版本而改变。

## 封面与发布资料

采用用户最终提供的温室养护图，去除游戏版本与模组版本数字；适用游戏版本放在mod.info和本发布说明中。封面仅保留名称及单人标识，可用于后续适配版本。

`publishing/workshop.json`保留`workshop_id: null`，准备阶段可见性为private；实际首次上传后才记录Steam分配的ID。确认已有条目时更新原条目，不创建重复条目。发布资料和本地上传目录不等于已经公开发布。当前未新增开源许可证。

完整成图保存于`art/cover-source.png`，最终编辑提示词见`art/cover-provenance.json`。交付预览`publishing/preview.png`与模组`42/poster.png`字节相同，512×512 PNG、738365字节；仅从完成图导出尺寸，没有重新设计封面。

运行`python tools/build_release.py`生成安装ZIP，运行`python tools/build_workshop.py`生成`releases/Workshop/SuQingSprinklerFertilizer-1.0.0`，其中包含`Contents/mods`、封面、工坊说明、更新记录和SHA-256清单。两者均逐文件读回核验，不包含个人存档或配置；打包不会安装、推送Git或上传Steam。首次上传后应在Steam实际必需品中核对添加Water Pipes，JSON依赖记录不等于线上必需品已设置。

## 升级与停用

退出游戏后覆盖同一个Mod ID的安装目录，保留原启用顺序；同ID本地/工坊副本只保留一个来源。由0.3.2升级不改变schema；早期库存迁移继续沿用现有逻辑。

停用前回收设备和拆除待回收库存，处理自定义满包与空包。已保存schema 3的存档不能仅通过替换代码直接退回0.2。回退0.3.1时新增禁用标记会被忽略，须重新核对开关和供料；完整世界恢复会回退进度，应按相应备份收据执行。

## Release summary

Version 1.0.0 packages the existing 0.3.2 gameplay with stable release metadata, bilingual documentation and selected cover artwork. The user reported normal single-player play; this is overall feedback, not a claim of exhaustive branch testing. Mod ID, item IDs and schema 3 stay unchanged. B42.21 single-player; Water Pipes is required. Release costs remain 1 by default (0.01–2), regardless of a personal save using 0.05. Git/Workshop publication is a separate action from local release preparation.
