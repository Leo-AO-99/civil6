# 技术来源与确认边界

这些文件用来确认API名称/用法；本项目代码独立编写，没有将Firaxis源码或原版美术打包。资料查阅日期：2026-10-01。

## 原生接口及事件

- [Firaxis NaturalDisasterPopup.lua 镜像](https://github.com/civfanatics/Civ6-UIFiles-Restructured/blob/master/DLC/Expansion2/UI/Additions/NaturalDisasterPopup.lua)：`Events.RandomEventStarted` / `RandomEventOccurred` 参数；河流、风暴、一次性灾害范围API；UI开始事件与伤害的时序注释。**它是UI代码，不足以证明Gameplay同步回调完全同义。**
- [Hemmelfort Lua手册](https://github.com/Hemmelfort/Civ6ModdingNotes/blob/master/%E6%96%87%E6%98%8E6_Lua%E6%89%8B%E5%86%8C.md)：Gameplay `GameRandomEvents.ApplyEvent(kEvent)` 及 `EventType`、`NamedRiver`、`NamedVolcano`、`Location` 示例。**并不证明所有事件都接受相同的强制位置语义。**
- [Sukritact API知识库](https://sukritact.github.io/Civilization-VI-Modding-Knowledge-Base/)：对象/函数索引；部分条目没有完整参数信息。
- [PlayerCulture接口存根](https://github.com/flat-arther/Civ-VI-Accessibility-Integration/blob/main/docs/civ6%20ide%20helpers/Objects/PlayerCulture.lua)：进度、成本、改变当前进度接口；查询API的Gameplay可用性仍有不确定性，因此保留余额并诊断，不凭猜测消费。
- [District接口存根](https://github.com/flat-arther/Civ-VI-Accessibility-Integration/blob/main/docs/civ6%20ide%20helpers/Objects/District.lua)：`SetDamage(defenseType,damage)`、`SetPillaged`。
- [GameClimate接口存根](https://github.com/flat-arther/Civ-VI-Accessibility-Integration/blob/main/docs/civ6%20ide%20helpers/Objects/GameClimate.lua)：原生灾害活动区查询。

## 数据与UI桥接

- [Gameplay数据库结构存根](https://github.com/flat-arther/Civ-VI-Accessibility-Integration/blob/main/docs/civ6%20ide%20helpers/Database/Gameplay.sqlite.lua)：部分数据库字段名。测试用数据库是手写合成夹具，**不是这个文件生成的完整游戏数据库**。
- [BBG UI→Gameplay状态工具](https://github.com/CivilizationVIBetterBalancedGame/BetterBalancedGame/blob/02fe6f5f9d009aad6325d8fae5126c3a206d70c9/scripts/bbg_stateutils.lua)：`UI.RequestPlayerOperation(..., PlayerOperations.EXECUTE_SCRIPT, {OnStart=...})`模式。当前版本只用于单人，不能据此宣称已做完联机安全性验证。
- [Governor数据调整实例](https://github.com/Z-Vanadium/ChineseCiv6Balance/blob/44360fefd4a6ec684e093c838004336895319b02/sql/XP2/Governors.sql)：修改 `Governors.TransitionStrength` 的方式。它是公共表，不能误认为是单文明专属的总督加速。

## 明确没有据此宣称的内容

没有声称：已在真实引擎验证七对原生总督替换与两回合就位、所有灾害绝对免伤、未启用天启也自动拥有彗星事件、永久肥力额外倍增、跨全部森火ID的精确归并、成品自制领袖/单位3D美术、联机兼容、AI会使用施法单位。

## Alpha 2 总督实现依据

- [Expansion2 schema snapshot](https://github.com/tontyoutoure/Civ6_Mod_Power_Multiplier/blob/44f46329039e6e1e559c5c274df699d5eafad2a1/Expansion2_Schema.sql)：`Governors` 的 TraitType/TransitionStrength/美术字段，`GovernorReplaces`、`GovernorPromotionSets`、`Governors_XP2` 及其键。源码仅在本地安装游戏中 SELECT 原版行，不分发这些原版内容。
- [BBG Korea.sql](https://github.com/CivilizationVIBetterBalancedGame/BetterBalancedGame/blob/02fe6f5f9d009aad6325d8fae5126c3a206d70c9/sql/XP1/Korea.sql)：`REQUIREMENT_CITY_HAS_GOVERNOR_WITH_X_TITLES` 的 `Amount` / `Established=1` 用法。
- [GovernorProbe.sql](https://github.com/WrathSK/Specialization-Gameplay-Redesign/blob/0896d59de84508b296317c71e2d26ba0d94c1729/Mod/Data/GovernorProbe.sql)：非永久城市属性加原生总督条件的 SQL→Lua 观测方式。该探针的存在并不替代本 Mod 实际运行验证。
- [Firaxis GovernorPanel.lua 镜像](https://github.com/civfanatics/Civ6-UIFiles-Restructured/blob/1ebc67937a8b285e45c8bed777828e8b677ce529/DLC/Expansion2/UI/Additions/GovernorPanel.lua)：原版面板通过 `CanEverAppointGovernor(governorHash)` 判断可用总督；诊断同样查询原生过滤结果，不自行模拟或覆写原版面板。
- [ModTools 总督说明](https://github.com/SiQi-1/ModTools5.4/blob/d8c7790c795eae5d3eebd0511c706a06f140dac8/skills/01-core-tables/governor.md)：记录250目标2回合，以及500特殊行为和“只取第一条”替换限制。这里只用作实测警示；本 Mod 每个新类型恰有一条替换，仍需验证七个不同新类型是否均被引擎处理。

本轮测试检查：原版完整行不变、七对关系、独立特质、技能关联、图标别名、原生标记消费者、替换失败报警；不包含 TransitionStrength 的引擎计算、不模拟需求系统或多行替换真实语义。


## Alpha 3：闭合肥地池与原生结构防护

核对源码（非实机测试）：

- `Seth9976/Civilopedia_Java`，提交 `8b63eba3706f11d85fa89b431fa7ddd21f259591`，`databases/Civ6GatheringStorm/RandomEvents.json` 与 `RandomEvent_Yields.json`：洪水/火山普通与TRIGGERED版本不同；森林火、雨林火是两个事件；火灾后续回合提供正值产出；SEA_LEVEL定义包含停止洪水/风暴肥沃化和流失肥力标记。
  https://github.com/Seth9976/Civilopedia_Java/blob/8b63eba3706f11d85fa89b431fa7ddd21f259591/databases/Civ6GatheringStorm/RandomEvents.json
  https://github.com/Seth9976/Civilopedia_Java/blob/8b63eba3706f11d85fa89b431fa7ddd21f259591/databases/Civ6GatheringStorm/RandomEvent_Yields.json
- 游戏百科正文，环境效果：暴风雪、沙尘暴、飓风列明可增产，龙卷风未列增产。
  https://www.civilopedia.net/en-US/gathering-storm/concepts/environmental_effects/
- 梁原版效果名的公开使用案例：`Mico27/Civ6-Mario-Mod` 的 `MICO_MARIOPACK/Leader/Leader_UA.sql` 把 `REINFORCED_INFRASTRUCTURE_PREVENET_STRUCTURAL_DAMAGE` 关联到自定义总督晋升。
  https://github.com/Mico27/Civ6-Mario-Mod/blob/076b7d8a3250cfdd181bfe36b5d01fec94b7674c/MICO_MARIOPACK/Leader/Leader_UA.sql
- `GetSeverityForLastSeaLevelEvent` 的社区API记录：
  https://github.com/Sukritact/Civilization-VI-Modding-Knowledge-Base/blob/144f27f5ea28c8a381f72343cad4c5ddbfb7c7b0/Objects/GameClimate/GameClimate.GetSeverityForLastSeaLevelEvent.md

本次实现的判断：把梁效果直接绑定本Mod专属 `GovernorModifiers`，而不是修改共享晋升；保留原来的总督对象上下文。这一具体挂载方式与就位/调任、森林火/火山防护范围仍需实机验证，公开自定义晋升案例不等于本Mod已经通过测试。气候筛选同样属于按公开字段实现的检查，不是已经验证所有版本/气候转换时刻的保证。


## Alpha 4：总督头衔与出生偏好

原作者发布的总督点示例使用原生 `MODIFIER_PLAYER_ADJUST_GOVERNOR_POINTS`、参数 `Delta`、`RunOnce/Permanent`：
https://forums.civfanatics.com/threads/resolved-granting-governor-point-from-pantheon-belief.666023/
本Mod只采用玩家奖励并绑定本领袖，不采用该万神殿示例中的全局绑定。

原生选址入口为 `StartBiasFeatures`；公开起点Mod的源码也展示了火山地貌映射：
https://github.com/d-jackthenarrator/Civ6-BBS/blob/b5096de86216841fa66002238f3149740d13efbb/1958135962/Data/BBS%20Maps/Utility/BBS_AssignStartingPlots.lua
BBS仅作代码参考，不是依赖，不能据此保证默认或所有自定义地图会读取该偏好。此版本只调整数据、未改地图脚本，需实测。

Windows手动Mod安装目录的作者说明：
https://github.com/d-jackthenarrator/Civ6-BBS

以上 Alpha 4 初版记录只包含 SQL 夹具。后续已有用户实机日志与真实 DebugGameplay.sqlite 读取，具体新证据见下文，不能将初版测试说明当成当前所有功能的状态。

## 2026-10-02 本机适配与原版参考

本机游戏版本 1.0.12.68 (1023995)，Expansion2。原版文件优先于跨上下文推测：

- `DLC/Expansion2/UI/Additions/GovernorPanel.lua`：`Refresh` 使用全局 `AddGovernorCandidate` 构建未任命候选；扩展只过滤本领袖的七个原版候选，保留原版面板及已任命总督。
- `DLC/Expansion2/Expansion2.modinfo`：`ReplaceUIScript` 使用 `LuaContext` 与 `LuaReplace` Properties。
- `DLC/BlackDeathScenario/Scripts/BlackDeathScenario.lua`：Gameplay 使用 `GetDistrictLocation(GameInfo.Districts[type].Index)`；位置定位后通过 `GetDistrictAtLocation(x,y)` 取得区域。原版 UI 的 `GetDistrict(string)` 不能直接推定 Gameplay 行为一致。
- `Base/ArtDefs/Districts.artdef`（实际路径 `Base/ArtDefs` 或本机 `Base/ArtDefs` 的大小写等价路径）、`Base/Civ6.dep`：本模组只为特色区域创建原版圣地记录的别名，继续引用原有 Landmark、StrategicView 与 Audio。基础美术 UUID 为 `cb2f71b7-843e-4af3-9ca7-992acda9c195`，与资料片模组依赖 UUID 不混用。
- `DLC/Expansion2/UI/Additions/NaturalDisasterPopup.lua`：原生灾害事件签名含类型、严重性、x/y、减灾、事件 ID 和回放 ID；本局 Gameplay 回调未提供后几个参数，不能假设与 UI 参数完全相同。
- `Debug/Random Events.ltp`：官方 FireTuner 脚本使用 `GameRandomEvents.ApplyEvent`，参数为 `EventType`、`Location`、`NamedRiver`、`NamedVolcano`。该源码支持显式 Location；不能笼统宣称 Location 对普通灾害无效。
- 社区接口表：[CityDistricts](https://sukritact.github.io/Civilization-VI-Modding-Knowledge-Base/CityDistricts)、[GameRandomEvents](https://sukritact.github.io/Civilization-VI-Modding-Knowledge-Base/GameRandomEvents)、[PlayerCulture](https://sukritact.github.io/Civilization-VI-Modding-Knowledge-Base/PlayerCulture)。用来核对 UI/Gameplay 范围，未代替本机测试。

实际日志证据：总督七对数据库记录存在但原版和专属皆可任命；Oracle 的16次请求进入 Gameplay 后被圣所校验拒绝；自动灾害提交一次后未被旧坐标匹配确认；原生自然事件与一笔 0.50 科学/0.50 文化入库已有记录。新美术、候选过滤、购买修复及调度恢复仅完成代码验证和安装，尚无新一局效果证据。
