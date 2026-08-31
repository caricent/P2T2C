# Tasks 013：Superpowers 方法层

Based on: `spec.md` + `plan.md`

## 工作批次

- [x] Task 1：新增原生双语方法技能和来源说明。
- [x] Task 2：更新治理、入口、Prompt、模板和项目配置。
- [x] Task 3：新增 schema-aware 强制执行、迁移和受管安装/升级路径。
- [x] Task 4：重新生成 checksum 并运行发行与 smoke-test 验证。

## 批次级验收

| 命令或步骤 | 预期结果 |
|---|---|
| `make check` | 两个发行根和一致性检查通过。 |
| `make checksums` | 两个 checksum manifest 重生成并通过校验。 |
| 安装/升级 smoke test | 新文件安全交付；历史配置保持 advisory。 |

## 批次方法检查点

- RED 证据或豁免：配置/文档行为使用负向 checker fixture 和 smoke test 验证。
- 发生修复时必须记录根因。
- 是否需要独立审查：是

## 批次边界

- 不包含：上游 Superpowers 插件依赖和实际并行代理执行。
- 发现新的语义边界、Truth 冲突或高风险事项时返回意图准入阶段。
