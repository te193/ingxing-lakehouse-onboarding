# Interface Intake Contract

Complete this contract before production code. Keep it concise but evidence-linked.

## Status values

- `已确认`: directly supported by a named source.
- `有证据的推断`: inferred from specific evidence and safe only where it cannot alter correctness.
- `缺失`: unavailable or conflicting.

Never mark a remembered value as confirmed. Cite the ledger section, official document, database object, or successful local file used.

## Required intake

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

## Blocking facts

The following cannot remain `缺失` when generating the affected executable artifact:

- HTTP method and request/signature placement;
- pagination origin, list path, and termination rule;
- response schema required by OSS and EXT;
- storage format;
- stable business key and DWD grain;
- latest/history/window overwrite strategy;
- expected handling of zero records;
- parent-child relationship for multi-table output.

If only the Python request is independent of a missing DWD fact, it may be delivered after all Python-specific blocking facts are confirmed. Do not upload to a guessed storage format merely to produce “Step 1.”

## Step 0 response shape

```markdown
当前步骤：第0步—接口接入确认

已定位：
- 接口：...
- dataset：...
- API：...
- 方法：...

确认单：
| 分类 | 结论 | 状态 | 证据 |
|---|---|---|---|
| ... | ... | 已确认/有证据的推断/缺失 | ... |

结论：可进入第1步 / 被以下关键缺口阻断。
风险：如果现在生成，将会...
最小问题：只问一个能解除当前阻断的问题。
```

## Name-only behavior

- If the ledger uniquely identifies the interface, continue discovery without asking the user to repeat known facts.
- If multiple entries match, present the candidates and ask the user to choose one.
- If the interface is already completed, inspect existing artifacts first and answer whether the request is a review, correction, or rebuild.
- “Do not ask questions” means return the completed facts and blocker; it never converts missing facts into assumptions.
