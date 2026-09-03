# Project Rules and Evidence Routing

## Workspace sources

Discover the active workspace root from the current Codex workspace or ask for it when no workspace is open. Never assume the original author's Windows username, drive letter, or absolute path.

Read these current files before deciding an interface design:

1. `阿里云湖仓一体规范文档.md` — engineering architecture and current normative rules.
2. `领星接口ODS_DWD迁移台账.md` — interface identity, legacy request strategy, target tables, and migration status.
3. `MySQL到OSS到MaxCompute_DataWorks配置操作手册.md` — DataWorks execution sequence and operator instructions.

Use the workspace copies when present because they may be newer than the packaged skill. If a workspace copy is missing, use the bundled baseline under `references/project-standards/` and disclose that fallback. If neither source exists, report the missing source and do not treat remembered content as current.

Read only relevant local Python/SQL samples after identifying the interface.

## Evidence priority by question

### Project engineering rules

1. Latest `阿里云湖仓一体规范文档.md`.
2. Confirmed successful local code and diagnosed corrections.
3. Migration ledger.
4. Operations manual.
5. Legacy Java/Python, for business recovery only.

### Lingxing API request contract

1. Official Lingxing interface documentation.
2. Sanitized response schema and confirmed successful request evidence.
3. Ledger records of legacy request behavior.
4. Read-only MySQL ODS/DWD schema and bounded samples.
5. Legacy Java/Python.

Official requirements and legacy behavior can differ. Record both and stop on a material conflict rather than silently choosing one.

### Step 2 response-field mapping

Field mapping is required because every API has a different response schema; it is not permission to retest the pipeline. Use this fixed sequence:

1. Read confirmed successful code for the exact interface and reuse its response field names, types, and nesting.
2. Consult the official interface document only for fields or nesting absent from that code.
3. If both sources are missing or materially conflict, report the exact schema gap and stop.

Do not copy business fields from a different API. During ordinary Step 2 generation, do not automatically call the real API, inspect OSS objects, query MySQL samples, execute MaxCompute SQL, or create extra runtime tests. Those are separate investigations and require an explicit user request. Reuse a successful comparable EXT DDL only for the shared table skeleton, SerDe, partition, LOCATION, and file-whitelist pattern.

### Existing DWD field contract

1. Confirmed existing MySQL DWD production schema and comments.
2. Confirmed business definitions.
3. Official API fields.
4. Legacy cleansing code.

When a same-name MySQL DWD table exists, preserve its confirmed business field names, order, comments, and equivalent types unless the user approves a migration.

## Pipeline invariants

```text
Lingxing OpenAPI
→ DataWorks PyODPS 3
→ OSS guqiao_ods/{dataset}/dt=YYYY-MM-DD/
→ ext.{dataset}_raw
→ dwd.{dataset}
```

- MaxCompute project: `df_cs_306350`; schemas: `ext`, `dwd`.
- OSS bucket: `gq-lakehouse`; internal endpoint: `oss-cn-shenzhen-internal.aliyuncs.com`.
- Dataset names are lowercase snake_case and remain consistent across Python, OSS, EXT, DWD, and DataWorks nodes.
- Create one local folder per interface: `{workspace}/{dataset}/`.
- Store all interface-specific artifacts in that folder: `{dataset}/{dataset}.py`, `{dataset}/ext_{dataset}_ddl.sql`, `{dataset}/dwd_{dataset}_ddl.sql`, and `{dataset}/dwd_{dataset}_etl.sql`.
- Keep shared standards, ledgers, common resources, and design documents outside interface folders. Multi-table DWD outputs from one interface remain together in the same interface folder.
- EXT maps OSS and contains no business aggregation. MaxCompute internal business tables stop at DWD; DWS and ADS remain in MySQL according to project rules.
- Credentials come only from controlled resources such as `project_config.py`; never emit APP secrets, AK/SK, database passwords, access tokens, or signed URLs.

## DataWorks online shared resources

- `project_config.py` and `lx_sync_engine.py` are maintained as online DataWorks Python resources; they are not expected to exist in the local workspace or inside an interface folder.
- Every generated PyODPS interface node declares both resources at the top:

```python
##@resource_reference{"project_config.py"}
##@resource_reference{"lx_sync_engine.py"}
```

- Continue to import confirmed shared capabilities from `lx_sync_engine.py`, such as `create_clients`, `sync_task`, and the proven `lx_client.fetch_all(...)` / `oss_client.upload_json(...)` call pattern.
- Local absence of either shared resource is never, by itself, a reason to stop, search attachment caches, or ask the user to paste its source.
- **Hard boundary:** an interface node configures and calls the online engine; it never becomes an interface-local replacement for that engine. Do not implement or copy token/credential handling, signing, HTTP retry, generic pagination protection, PyArrow/Parquet writing, OSS client creation or staging, multipart copy/commit, manifest generation, or publication logic in an interface file.
- Interface-local code is limited to resource declarations, dataset/API constants, `get_biz_date()`, confirmed request parameters, genuinely interface-specific batching or validation, the complete task dictionary required by a proven public contract, and the public engine invocation. Importing `requests`, `oss2`, or `pyarrow` in a generated interface node is a stop signal unless confirmed evidence proves that capability is uniquely required by the interface and is absent from the online engine.
- Do not invent an unconfirmed shared function signature. When the user asks to follow an existing successful node structure, adapt the confirmed calls shown by that node and the project documents.
- Function name and positional arguments are not the whole shared-engine contract. Before calling `sync_parquet_task`, copy the complete `task` shape from a confirmed successful Parquet node. The current proven contract requires `req_params_tpl`, `req_body_tpl`, and `field_types`; omitting `field_types` fails before the API request with `KeyError: 'field_types'`.
- `field_types` describes every Parquet output column and includes engine-added `biz_date` and `sync_time`. Treat the project's public Parquet path as flat-scalar-only: a declaration never converts `dict` or `list` values into strings.
- If `sync_parquet_task` raises a missing task-key error for a confirmed flat schema, repair the interface task configuration from a successful-node contract. Do not reimplement PyArrow/OSS publication inside the interface node.

## Storage decision

- Confirmed nested schema (`dict` or `list` anywhere in a record): call the shared `sync_task` and preserve the raw response as compact JSON. This decision does not depend on volume and requires no online engine capability check.
- Confirmed flat scalar schema: use compact one-line JSON only with evidence that the interface is small; otherwise use the online engine's Parquet + Snappy path with a confirmed `field_types` output schema.
- Do not turn nested objects or arrays into JSON text solely to store them in Parquet `string` columns. Parse and expand the raw JSON once in EXT/DWD.
- Unknown schema is a blocker for storage selection. Unknown volume is a blocker only after the schema is confirmed flat; use ledger counts, bounded MySQL counts, or a confirmed comparable task to resolve it.
- JSON envelope fields are `source`, `dataset`, `biz_date`, `record_count`, `sync_time`, and `data`.
- Parquet EXT fields must exactly match the written Parquet schema. Do not invent envelope fields absent from the file.

## Request and pagination

- Confirm HTTP method, query fields, body fields, signature participation, response list path, pagination origin, page size, and termination condition per interface.
- For confirmed POST body contracts, pass business parameters through `lx_client.fetch_all(..., req_body=...)`. Do not assume `sync_task(req_params_tpl=...)` routes or signs them equivalently.
- The adjust-price queue proved that routing its POST parameters through the wrong common path caused Lingxing `code=2001006`; the working call used `req_body`. Apply this fact to that interface and only generalize when the common engine contract is verified.
- Configure the confirmed public engine so its total-change detection, duplicate-page protection, maximum page/offset limits, bounded retries, and all-or-nothing publication remain active. Do not reimplement those generic safeguards in the interface node. Never publish a partial official batch.
- Multi-stage and SID/order batching interfaces must identify the upstream key source, batch size, failure boundary, and real DataWorks dependency.

## Business date

DataWorks configures `biz_date=$[yyyy-mm-dd-1]`. Read in this order:

```text
args['biz_date']
→ args['bizdate'] for legacy compatibility
→ SKYNET_BIZDATE
→ current date only for ordinary development-console Run
```

- Accept `YYYY-MM-DD` and `YYYYMMDD`, normalize to `YYYY-MM-DD`, and reject invalid dates.
- `SKYNET_GMTDATE` is the current date, not the business backfill date; do not use it as a business-date source.
- A request window may be derived from `biz_date`. The OSS directory, envelope, EXT partition, and downstream parameter all retain the same `biz_date` without another day offset.
- A scheduled/backfill/smoke instance must receive a business date and should not silently depend on the ordinary-run fallback.

## DWD and data quality

- Choose latest-state whole-table overwrite versus historical/window partition overwrite from business semantics, not because the task runs daily.
- Define grain, stable business key, parent-child key, deduplication order, and count relationship before DDL/ETL.
- An array position may provide batch traceability but is not a long-term business key unless the business contract proves stability.
- Use explicit columns; never `SELECT *` into DWD.
- Normalize blank text with `NULLIF(TRIM(...), '')`; preserve deliberate distinctions among SQL NULL, empty string, and literal text when the existing contract requires them.
- Protect every overwrite from unexpected empty source, envelope/count mismatch, invalid keys, duplicates, malformed business timestamps, and partial batches.
- Quality output must cover source/target count relation, distinct and null business key, duplicate technical IDs, time bounds, affected partitions, and high-risk business summaries.
- A successful SQL status is not proof of data consistency. Reconcile the same OSS/API snapshot boundary with DWD before downstream MySQL DWS consumption.
