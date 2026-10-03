# civil6

《文明 VI》Mod 合集。每个 Mod 独立放在 `mods/<名称>/` 中，互不共享玩法配置，后续可以继续增加子文件夹。

| Mod | 内容 | 状态 | 改数值 |
|---|---|---|---|
| [米诺斯天灾文明](mods/minoan/README.md) | 半价特色圣地、总督庇护、信仰转科文、祈灾与彗星祭司 | 单人开发测试版；未在实际游戏内验证 | [`mods/minoan/Config/Balance.sql`](mods/minoan/Config/Balance.sql) |

## 目录

```text
mods/minoan/     本次 Mod，可单独复制安装
  Config/       集中数值
  Data/         文明、领袖、区域与前端数据库
  Gameplay/     Lua 规则、灾害、奖励与保护
  UI/           购买/施法面板
  Text/         中文和英文描述
  docs/         测试、限制和来源
 tools/         检查与打包脚本（不需要第三方 Python 包）
 tests/         纯逻辑和模拟游戏接口测试
```

## 验证和打包

在仓库根目录：

```sh
python3 tools/validate.py --require-lua
python3 tools/package.py
```

验证需要 Python 3.9+ 和 Lua 5.3/5.4（或 `texlua`）。打包仅需 Python；输出 `dist/MinoanDisasters-alpha.zip`。
这些检查不运行《文明 VI》，不能替代进游戏测试。

## 交付说明

本版本最初在独立工作目录中生成。尝试写入 `Leo-AO-99/civil6` 时，GitHub 连接返回 `403 Resource not accessible by integration`，因此这份代码**没有被自动推送，也没有创建 PR**。

将本目录内容复制到你本地的 `civil6` 仓库后，检查差异再提交：

```sh
git add README.md .gitignore mods/minoan tools tests
git commit -m "feat: add experimental Minoan disaster civilization"
git push origin main
```

请先确认当前终端使用的是有该仓库写入权限的 GitHub 账号；不要把个人访问令牌写进仓库。具体安装与当前实现差异，见 Mod 自己的 README。


## 此前更新：米诺斯专属总督（Alpha 2）

七位总督继续使用原版名字、肖像和晋升；仅米诺斯领袖使用独立内部ID和原生加速参数。删除旧的全局加速与“庇护提前两回合”计时替代方案，庇护改读原生已就位状态。需要新开档进行游戏内验收。

调参：`mods/minoan/Config/Balance.sql` → `MinoanGovernorTransitionStrength`，默认 `250`（目标两回合，不是直接填回合数）。

验证：`python tools/validate.py --require-lua`（Python 3 与 Lua 5.3/5.4 或 TeX Lua；游戏运行不需要它们）。测试不是游戏引擎验收。


## 此前更新：只召肥地灾害、原生防灾（Alpha 3）

自动召灾与神谕祭司共用12条原生肥地事件白名单，排除陨石、彗星、龙卷风、干旱和永久毁图事件。找不到目标就跳过，不用其他灾害兜底；末日先知仍是独立手动对敌彗星。森林火与雨林火分别匹配正确事件；实际收益数据与晚期气候也参与过滤。

七位专属总督绑定梁的原生结构防护，删除结构快照/自动修复；Lua只补实际受灾且仍受庇护城市的人口。代码/SQL契约与模拟测试通过不代表引擎免伤已验证。

调参仍在 `mods/minoan/Config/Balance.sql`。本版共107项测试通过，未运行真实游戏。请替换旧Mod整目录并新开测试档。


## 最近更新：开局总督点与火山倾向（Alpha 4）

开局默认额外1个可分配总督头衔，使用原生一次性奖励；火山出生偏好Tier 1，泛滥平原Tier 3。没有造火山/移动开拓者逻辑，不保证地图必定满足偏好，尚未实机验证。

配置：`mods/minoan/Config/Balance.sql` 中的 `StartingGovernorTitles`、`VolcanoStartBiasTier`、`FloodplainStartBiasTier`；0关闭对应项。

### Windows 使用

退出游戏，解压安装包，将 `MinoanDisasters` 文件夹放进实际文档目录的 `My Games/Sid Meier's Civilization VI/Mods`。`Win+R` 输入 `shell:Personal` 可打开实际文档位置。确认 `Mods/MinoanDisasters/MinoanDisasters.modinfo` 存在，不要多嵌套一层，旧版请移出Mods。

“额外内容 → 模组”启用本Mod，单人新建风云变幻游戏并选米诺斯。运行Mod不需要Python/Lua命令行或ModBuddy。完整安装、调参、日志说明见 [Mod README](mods/minoan/README.md#安装)。
