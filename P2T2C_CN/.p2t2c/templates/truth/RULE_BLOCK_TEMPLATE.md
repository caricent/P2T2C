### RULE-{AREA}-{NNN}: {规则名称}

Status: Draft | Active | Superseded | Deprecated
Applies to: {模块、层或工作流}
Source: {SP、ADR 或 human decision}
Supersedes: {RULE-ID or None}
Superseded by: {RULE-ID or None}
Migration required: Yes 或 No

规则:

{一条清晰、可执行、可验证的规则。}

理由:

{为什么存在这条规则。}

验证:

- {自动化测试、手动验收、治理检查或 Code Review checklist}

下游投射:

- Spec: {哪些 spec 应引用}
- Tests: {哪些测试应覆盖}
- Code: {哪些模块应实现}

代码锚点 (RULE-GOV-010):

- 实现代码携带仅含指针的注释，如 `Implements: RULE-{AREA}-{NNN}`。
- 锚点只记录指针；规则文本留在本 SoT，绝不写入代码注释。

停线条件:

- {什么情况下必须暂停找人确认}
