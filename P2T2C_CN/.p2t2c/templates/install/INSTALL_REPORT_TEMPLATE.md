# P2T2C 安装报告 — {install-id}

Source: `{source-path}`
Target: `{target-path}`

---

## 已安装

- {已复制到目标项目的文件}

---

## 未变化

- {已经相同的文件}

## Mode 修复

- {字节相同并按确定性 mode policy 修复的受管文件}

---

## 冲突

现有文件未被覆盖：

- {冲突文件}

建议手动集成：

- 如果 AI 工具只自动读取根级 `AGENTS.md`，在项目自有 `AGENTS.md` 中引用 `P2T2C_AGENTS.md`。
- 如需要，将 P2T2C target 加入项目自有 `Makefile`。
- 保留现有项目 README；如需要，从其中链接 `P2T2C_README.md`。

---

## 跳过的禁止路径

- {install denylist 保护的路径}

---

## 验证

- {验证结果}

## 0.15.0 运行边界

- 安装的工作流资产包含 core SP/design/tasks 模板、Documents Archive、显式 docs-migrate，以及 0.14.x context/evidence/verify/close 兼容引擎。
- 安装没有创建活动 SP/specs、run、cache、冷归档实例或证据；新项目配置显式选择 core-v1，legacy defaults 保持 adaptive-v2。
