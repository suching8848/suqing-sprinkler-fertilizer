# 离线工具 | Offline tools

这些工具只读显式提供的游戏/Water Pipes 源码，输出到本仓库 `validation/` 或 `releases/`；不会启动游戏客户端、进入世界、安装模组、修改存档或上传工坊。

These tools read explicitly supplied game/Water Pipes sources and write only repository validation/release outputs. They do not start the game client, open a world, install a mod, edit saves or upload to Workshop.

## 校验与打包 | Validation and packaging

```sh
python tools/validate_package.py
python tools/build_release.py
```

`generate_care_content.py` 会重新生成本仓库的物品、配方、翻译与配方数据，不属于只读检查，修改前先阅读并复核输出；打包不会部署。

`generate_care_content.py` rewrites repository item, recipe, translation and recipe-data files. Review it before regeneration; it is not a read-only check. Packaging never deploys the archive.

## Kahlua 与原生 API | Kahlua and native API checks

需要 Python 3、兼容游戏运行时版本的 JDK，以及自己的合法游戏安装和 Water Pipes。Java 辅助源码由本项目维护，不包含游戏源码；编译输出被 Git 忽略。

Requires Python 3, a JDK compatible with the game's runtime, and your own game/Water Pipes installation. The project-owned Java helpers contain no bundled game source; compiled output is ignored by Git.

```sh
javac -d validation tools/KahluaValidation.java tools/NativeValidation.java
python tools/run_tests.py --game "<game-directory>" --water-pipes "<Waterpipes-version-directory>"
```

测试使用 Java 的 `KahluaValidation` / `NativeValidation` 入口，不调用游戏启动器。本次 Git 整理期间可使用已存在的本地辅助 class；如未重新编译，应在结果中说明，不能声称完成了 fresh compile。

Tests invoke the Java `KahluaValidation` / `NativeValidation` helpers, not the game launcher. Existing local helper classes may be used during source synchronization; report that limitation instead of claiming a fresh compilation.
