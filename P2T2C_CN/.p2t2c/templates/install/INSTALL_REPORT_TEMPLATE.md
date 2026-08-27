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

## 0.14.1 运行边界

- 安装的工作流资产包含 `p2t2c` context/verify dispatcher、不可变 defaults、阶段 Skill、receipt v2 schema 与受管的 evidence 目录 README。
- 安装没有创建或复制活动 run、checker cache 条目、收口 evidence sidecar、初始 advisory 示例以外的项目配置实例或历史制品。
