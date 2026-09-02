# One-Time Installation Check

Use this procedure only when the user explicitly asks to verify the installation. Normal interface onboarding must not run it again.

## Safety

- Perform read-only discovery and the smallest bounded connectivity probe.
- Use only the identity and credentials already configured by the current user.
- Never inspect configuration values, print credentials, copy credentials, or write them into the skill, workspace, logs, or Git.
- Never execute MaxCompute DDL/DML or MySQL writes during this check.

## Checks

1. Discover whether `maxcompute-mcp` is available. If available, use a read-only identity, project, schema, table-metadata, or similarly bounded query to prove that the configured remote is reachable. Do not infer connectivity from configuration presence alone.
2. Discover whether the `opt-lyt-db` skill is installed. If available, load it and perform its smallest permitted read-only connection or metadata probe against the user's configured MySQL remote. Do not request credentials when the existing connection succeeds.
3. Report each result as one of:
   - `已配置且可访问`;
   - `已安装但连接失败`;
   - `已安装但权限不足`;
   - `未安装或未配置`.
4. For a failure, explain only the missing component or permission and point the user to configuration. Require the user's own least-privilege, read-only account or key.

Normal interface onboarding must not repeat this installation check. Repeat it only when the user explicitly asks to recheck after changing configuration.
