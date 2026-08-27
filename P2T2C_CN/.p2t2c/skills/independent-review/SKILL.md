---
name: p2t2c-independent-review
description: 按风险与 execution shape 审查 R1 生产代码和 R2 工作，并把结论绑定 base/head SHA。
---

# 独立审查

reviewer 必须独立于 implementer，只读取 Truth/ADR、CPK、适用 work、文件式 brief、base/head diff 和机器验证证据。一次审查同时给出 Truth/CPK 合规与代码质量/安全结论，避免机械重复读取。

- bounded R1 生产代码：一次 `batch` 审查，`batch_id: none`。
- architectural R1 与所有 R2：CPK 每个唯一 ownership batch ID 都有 `batch` 审查，再做 `global`。
- `specialist_review_required: true`：增加 `specialist` reviewer。
- 同形微任务批次：逐项核对 brief 与文件，防止批处理漏做。

reviewer 身份必须不同于 CPK implementer。记录 `review_role: batch|global|specialist|re_review`、batch ID、base/head、scope/contract digest、finding 和 verdict。re_review 必须回链原 review batch/scope。

任一必需 review 的 Critical、Important 或 Minor 非零都阻断 CLOSE。修复由 CPK implementer 完成；scoped re-review 只检查原 finding 与 fix diff，随后确认 final-tree evidence 仍新鲜。
