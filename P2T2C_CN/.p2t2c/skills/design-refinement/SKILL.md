---
name: p2t2c-design-refinement
description: 在 P2T2C 准入+路由循环中澄清会改变结果的歧义，不创建竞争性 Truth。
---

# 设计澄清

仅当歧义会改变验收结果、风险等级、execution shape 或安全/权限/数据边界时使用。

1. 读取入口、配置、相关 Truth/ADR 和实现证据，先区分可发现事实与真正偏好。
2. 写明目标、非目标、可观察验收和未决定的准确问题。
3. 给出互斥可行选项、推荐项，以及对 Truth、风险、shape 和验证的影响。
4. 决定记录在当前指令、可选 SP 或 R2 CPK；改变当前行为必须经过 Gate A 与 Truth Patch。
5. Gate A pending 时只记录安全只读 `exploration`，不写实现/Truth 或 close。决定后由同一 controller 恢复路由；风险/shape 改变写 `route`。

本方法只澄清意图。任何输出都不能成为业务规则的唯一来源。
