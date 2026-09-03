# Interface Intake Contract

Use progressive intake. The normal Step 0 is a small routing gate, not a requirement to complete the entire end-to-end contract before any code. Collect and confirm each fact when its owning step needs it.

## Status values

- `已确认`: directly supported by a named source.
- `有证据的推断`: inferred from specific evidence and safe only where it cannot alter correctness.
- `缺失`: unavailable or conflicting.

Never mark a remembered value as confirmed. Cite the ledger section, official document, database object, or successful local file used.

## Normal Step 0 minimum

| Category | Required facts |
|---|---|
| Identity | Chinese name, unique dataset, API path, GET/POST, current migration status |
| Evidence | matching ledger entry, exact-interface successful code or existing artifacts |
| Intent | start, review, repair, rebuild, or continue; next requested step |
| Gate | only the blocking facts required by that next step |

Do not ask the user to repeat facts already established by the ledger or successful code. Do not investigate or confirm downstream decisions merely to make Step 0 look complete.

## Fact ownership by step

| Step | Facts confirmed at this step |
|---|---|
| Step 1 API to OSS | request fields and placement, pagination, biz_date/request window, synchronization mode, zero-result behavior, nested/flat storage route, public-engine call contract |
| Step 2 EXT DDL | complete response fields, types, nesting, nullability evidence, actual JSON/Parquet file schema |
| Step 3 DWD DDL | existing MySQL field contract, target grain, stable business/parent-child keys, technical fields, history and partition strategy |
| Step 4 DWD ETL | array expansion, conversions, dimension joins, deduplication order, overwrite scope, pre-overwrite checks and quality output |
| Step 5 configuration/reconciliation | node dependencies, publish/smoke setup, comparable snapshot boundary, indexed legacy-table query path, reconciliation measures |

## Expanded intake

Use this full contract only when the interface is new or missing from the ledger, multiple candidates match, evidence materially conflicts, or the user requests an end-to-end design review.

| Category | Required facts |
|---|---|
| Identity | Chinese name, unique dataset, API path, GET/POST, current migration status |
| Request | fixed fields, date fields, query/body placement, signature participation, upstream IDs and batch size |
| Pagination | offset/page/cursor type, origin, size, response list path, total behavior, termination and safety bounds |
| Time | meaning of biz_date, request window, source business timestamp, timezone if relevant |
| Sync | full/incremental/window, latest/history, overwrite scope, rerun idempotency, empty-result semantics |
| Storage | measured/confirmed volume, JSON or Parquet, OSS prefix, file naming, staging/publication rule |
| Schema | complete response fields and types, nested structs/arrays, null examples, source schema evidence |
| DWD | target tables, grain per table, stable business key, technical IDs, partitions, dedup order |
| Dependencies | upstream data/key nodes, same-cycle output, downstream tables/nodes |
| Acceptance | source-to-OSS-to-EXT-to-DWD count relation, key checks, time bounds, field/hash reconciliation |

## Blocking facts by affected artifact

The following cannot remain `缺失` when generating the executable artifact that depends on them:

- HTTP method and request/signature placement;
- pagination origin, list path, and termination rule;
- response schema required by OSS and EXT;
- storage format;
- stable business key and DWD grain;
- latest/history/window overwrite strategy;
- expected handling of zero records;
- parent-child relationship for multi-table output.

Missing downstream facts do not block an earlier independent artifact. For example, Step 1 may be delivered after all Python-specific blocking facts are confirmed even when DWD grain is still unknown. Do not upload to a guessed storage format merely to produce Step 1.

## Step 0 response shape

```markdown
当前步骤：第0步—接口定位与下一步准入

已定位：
- 接口：...
- dataset：...
- API：...
- 方法：...

已有证据：台账/成功代码/现有产物
当前目标：开始/检查/修复/继续到第N步
当前步骤阻塞项：无 / ...

结论：可进入第N步 / 当前步骤被以下关键缺口阻断。
风险：如果现在生成，将会...
最小问题：只问一个能解除当前阻断的问题。
```

## Name-only behavior

- If the ledger uniquely identifies the interface, continue discovery without asking the user to repeat known facts.
- If multiple entries match, present the candidates and ask the user to choose one.
- If the interface is already completed, inspect existing artifacts first and answer whether the request is a review, correction, or rebuild.
- Do not produce the expanded intake table for an ordinary uniquely matched interface unless a later step actually needs those facts.
- “Do not ask questions” means return the completed facts and blocker; it never converts missing facts into assumptions.
