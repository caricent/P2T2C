# Tasks 014：分层自治与机器证据

Based on: `spec.md` + `plan.md`

> v0.13 启动证据；动态执行状态与所有权见 `work.md` 和机器 ledger。

## 工作批次

- [x] Task 1：更新双语治理 Truth、ADR、入口、CPK/work/CR 模板、Prompt、Skill 和 Superpowers 来源说明。
- [x] Task 2：实现 Truth digest/ownership/legacy contract、exploration/re_review/完整 repair wire、path mapping、advisory completeness/warnings、remaining-risk ref 与 atomic close。
- [x] Task 3：让 checker、installer、upgrader、checksum 共用 `.p2t2c/managed-files.txt`，manifest 仅指针。
- [x] Task 4：建立确定性 fixture 与 adaptive-v2 行为 eval 场景。
- [x] Task 5：W1/W2/W3 各做 batch review，再做 global/specialist；修复用 re_review；同一 final tree full+governance 后原子自动 CR。

## 批次级验收

- 根 `make check` 与双发行根检查通过。
- 安装/升级/回滚/checksum smoke 通过。
- 确定性负向 fixture 能拒绝非法路由/spike close、缺证、失败验证、陈旧 SHA/digest、同一 reviewer、缺失角色、非零 finding 和缺失 full+governance；它不替代行为 eval。
- 真实 Agent eval 只在实际运行后报告；当前任务只交付场景集，不能宣称 KPI 达标或推广 required。

## 批次边界

- 不包含：Superpowers 运行时依赖、历史 013 改写、五轮修复或统一人工批准门。
