---
name: p2t2c-root-cause-debugging
description: 在 P2T2C 自主修复前诊断失败，并以原 implementer 完成最多两轮 scoped repair。
---

# 根因调试

首次修复前保留完整失败，稳定复现，检查相关 diff 与可工作模式，把失败输入/状态追溯到来源，并写出一个可证伪根因假设。通过最小修改验证该假设，不捆绑猜测性改动。

- 两轮修复均恢复 CPK `implementer` 与其文件式 brief/diff/evidence；不要为每轮重建新的实现上下文。
- 每轮 `repair` 精确记录 `repair_round`、`hypothesis_digest`、`implementer`、`failure_digest`、`fix_base_sha`、`fix_head_sha`、`fix_diff_digest`。复审用 `review_role: re_review` 与原 batch/scope。
- 明确环境性失败允许一次原样重试，但不占代码修复轮。
- 同一失败两轮后仍存在时停线，返回架构、Truth、范围或外部环境评估。

不得通过改写 Truth、削弱测试、删除覆盖或更换实现者来隐藏失败。
