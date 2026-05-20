# Prompt 01 — 初始化项目仓库

目标：把当前项目接入 P2T2C。本阶段不要实现业务功能。

先读取 `P2T2C_AGENTS.md`，并按其中的 Required Reading 完成基础读取。

本阶段额外读取：

- `P2T2C_README.md`
- 项目自有 `README.md`（如果存在）
- `.p2t2c/project_config.yaml` 或 `.p2t2c/templates/project_config.example.yaml`
- `docs/sot/manifest.yaml`

本阶段允许：

- 建立工程目录骨架。
- 接入 P2T2C 文档目录。
- 接入检查脚本。
- 创建最小可运行空壳。
- 在确有项目需要时写项目自有 README、Makefile、TODO；不得把这些文件作为 P2T2C 受管入口创建。

本阶段禁止：

- 实现业务功能。
- 新增 SoT 未定义的业务规则。
- 根据历史 reference 自行推断当前规则。
- 修改 ADR 或接受关键决策。

完成后报告：

- 创建了哪些目录。
- 每个目录对应什么职责。
- 哪些只是空壳。
- 下一步建议创建哪个 CP 或 spec。
- `bash .p2t2c/bin/check_p2t2c.sh` 是否通过。
