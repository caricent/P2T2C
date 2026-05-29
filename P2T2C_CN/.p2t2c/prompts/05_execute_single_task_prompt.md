# Prompt 05 — 执行单个任务

目标：一次只执行 `tasks.md` 中的一个 task。

先读取 `P2T2C_AGENTS.md`，并按其中的 Required Reading 完成基础读取。

治理阅读（RULE-GOV-012）：本阶段 phase token 为 `single_task`。只读取 `.p2t2c/generated/phase_rules.txt` 中 `single_task:` 行列出的治理 Rule Block，不通读 `P2T2C_GOVERNANCE.md` 全文，也不读 `P2T2C_GOVERNANCE_HISTORY.md`。

本阶段额外读取：

- feature `spec.md`
- feature `plan.md`
- feature `tasks.md`
- 相关项目 SoT、ADR

处理规则：

- 只执行用户指定或 tasks 中下一个未完成 task。
- 编码必须符合 SoT、spec 和 plan。
- 如果发现 plan 假设失效，必须暂停。
- 如果需要 Truth 未定义的新业务规则或边界，必须暂停。
- task 完成前必须运行该 task 的验收命令或步骤。
- 验收失败不得标记完成。
- 完成后填写 Actual results。

禁止：

- 不要顺手执行多个 task。
- 不要重排未授权的 scope。
- 不要通过测试或代码注释引入业务规则。
- 不要静默修改 Truth。

完成后报告：

- 执行的 task ID。
- 修改的文件。
- 验收命令与结果。
- tasks.md 中的 Actual results 更新。

---

## Task 链路合并 acceptance（0.11.0 R1）

适用：single_task 阶段；这是工作流执行纪律，不是业务规则。

当同 spec 内连续若干 task 同时满足以下条件时，允许把完整 Acceptance 命令合并到链路终点 task 一次执行，中间 task 以编译通过和该 task 的最小局部验证作为 acceptance：

- 同 spec，不得跨 spec。
- 同领域对象，例如同一个 Repository、Executor、Calculator、ViewModel、Service 或 Module。
- 测试 suite 同源，且终点 task 的 suite 覆盖中间 task 的断言。

每个 task 完成报告必须显式声明合并范围：

- `Acceptance scope: single`（默认；不合并）。
- `Acceptance scope: chain-midpoint`（中间 task；只跑编译和最小局部验证）。
- `Acceptance scope: chain-endpoint covering NNN.x-NNN.y`（终点 task；一次跑全链路 suite）。

边界：

- 合并只减少命令调用次数，不改变 tasks.md 中 Acceptance 命令字面的覆盖断言。
- 不得跨 spec、不得跨领域对象。
- 任何疑义按 `single` 处理。

---

## 失败分类与重试纪律（0.11.0 R2）

适用：自动化测试、构建、lint 或 governance check 失败处理。

环境性失败关键字白名单由项目栈扩展，扩展位置是项目自有 `AGENTS.md` 或等价 AI 入口。常见示例（非闭集）：

- 模拟器/设备：`CoreSimulator service was invalidated`、`Could not attach to pid`、`No devices are booted`、`Lost connection to testmanagerd`、`Could not find a destination`。
- 容器/运行时：`Cannot connect to the Docker daemon`、`OCI runtime exec failed`、`container is not running`。
- 进程/端口：`address already in use`、`bind: address already in use`、`port is already allocated`。
- 文件系统/权限：`Cache permission denied`、`Read-only file system`、`EACCES`、`Failed to open`。
- 网络：`Connection refused`、`EOF when reading from connection`、`network is unreachable`、`dial tcp:`、`getaddrinfo ENOTFOUND`。

处置：

- 命中白名单：最多重试 1 次；仍失败则停线问人，不得连环重试。
- 不得通过修改 production code 掩盖环境性失败。
- 未命中白名单的失败按 R3 triage 处理。

---

## Test triage（0.11.0 R3）

任意测试、构建、lint 或 governance check 失败后的第一动作是 triage。

Step 1：如项目提供 triage 工具，先调用项目工具；工具路径由项目自有 `AGENTS.md` 或等价入口声明。无工具时直接进入 Step 2。

Step 2：归类为以下四类之一：

- `compile_error`：编译或 type-check 阶段报错，无单测断言失败行。
- `unit_assertion`：单测断言失败，例如 `XCTAssert*`、`expect()`、`assert*`。
- `sandbox_environment`：命中 R2 环境关键字白名单。
- `runtime_crash`：被测程序或 runner 崩溃、hang 或 OOM。

Step 3：按分类处置：

- `compile_error`：修代码并重跑该 task 的最小 suite。
- `unit_assertion`：修代码或修测试断言，并重跑该 task 的最小 suite。修测试断言必须注明依据（SoT、spec 或 Truth 来源），不得为绕过失败而改断言。
- `sandbox_environment`：走 R2 单次重试或停线。
- `runtime_crash`：停线问人；不得重启 runner 后链式重测。

Step 4：记录到 task Actual，必须包含 triage 标签和重试次数，例如：

```text
Actual: Fail (unit_assertion, retries: 1) -> fixed by adjusting accumulator init; re-ran make test-one; Pass
Actual: Fail (sandbox_environment, retries: 1) -> re-ran make test-one; Pass
Actual: Fail (runtime_crash, retries: 0) -> paused, human review requested
```
