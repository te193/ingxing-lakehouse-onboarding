# Output Steps and Checks

Read after the intake contract permits the requested artifact.

## Delivery sequence

```text
Step 0 interface intake
→ Step 1 API-to-OSS PyODPS
→ Step 2 EXT DDL
→ Step 3 DWD DDL
→ Step 4 DWD ETL
→ Step 5 DataWorks configuration and reconciliation
```

Default to one step per user turn. Create `{workspace}/{dataset}/` and save every interface-specific Python and SQL artifact there unless the user specifies another location. Keep shared standards and ledgers at the workspace root.

## Step 1: `{dataset}.py`

- Declare `project_config.py` and `lx_sync_engine.py` resources with `.py` suffix.
- Treat both files as DataWorks online shared resources. Do not require local copies and do not ask the user to provide them merely because they are absent from the workspace.
- Use the shared engine for token, signing, HTTP, retry, pagination safeguards, serialization, Parquet writing, OSS staging/commit, manifests, and publication. Do not duplicate or locally reimplement any of those capabilities.
- Keep the node to resource declarations, interface configuration, `get_biz_date()`, confirmed request parameters or interface-specific batching, and a confirmed public-engine call. Treat interface-local imports or implementations of `requests`, `oss2`, `pyarrow`, staging, multipart copy, or manifest logic as a failed review unless unique interface evidence explicitly requires them.
- Prefer the confirmed call structure from an existing successful interface node when the user asks to follow the old or previously working code structure; do not substitute a guessed shared-engine function.
- For `sync_parquet_task`, verify the full successful-node task contract, not only the function signature. Require `req_params_tpl`, `req_body_tpl`, and `field_types`; include `biz_date` and `sync_time` in `field_types` because the engine writes them.
- Choose storage from the confirmed response schema without probing the online engine: any `dict`/`list` value routes directly to the public `sync_task` raw-JSON path; only an entirely flat scalar schema proceeds to the volume-based JSON/Parquet decision.
- Declaring a nested field as `"string"` does not serialize it. Do not JSON-encode nested values into Parquet string columns and do not add interface-local PyArrow or OSS publishing code.
- Implement the project-standard `get_biz_date()` priority and normalization.
- Derive the confirmed request window from `biz_date`; do not offset the OSS partition date.
- Put confirmed POST business parameters in `req_body`; verify query/signature requirements against the shared engine before using another route.
- Configure the confirmed public call with the real list path/pagination mechanism, page size, total matching, maximum bounds, duplicate-page protection, and interface-specific batching; do not rebuild the engine's generic pagination loop or protections.
- Define zero-record behavior explicitly. Full/latest overwrite must normally fail on unexpected zero; valid transactional empty days may publish an empty batch only when confirmed.
- Select the public-engine path that publishes only after every page and batch succeeds and uses its built-in staging/manifest behavior for multi-part Parquet; do not implement this workflow in the interface node.
- Ensure `source`, dataset, biz_date, record count, schema, and OSS `dt` agree.
- Do not claim runtime success when no real test was authorized.

## Step 2: `ext_{dataset}_ddl.sql`

- Reuse a successful comparable EXT DDL for the common structure only: settings, table naming, `dt` partition, SerDe/storage clause, dataset-root LOCATION, and business-file whitelist.
- Map business fields from confirmed successful code for the exact API. Consult the official interface document only for fields or nesting missing from that code; never copy another API's business fields.
- Treat this as one-time field mapping, not pipeline retesting. Do not automatically call the API, inspect OSS, query database samples, execute SQL, or add runtime tests. If exact-interface code and official documentation are missing or conflict, report the schema gap and stop.
- Start with schema namespace, ODPS2 types, and Hive compatibility when required.
- Name table `ext.{dataset}_raw`; partition by `dt STRING`.
- JSON: match the actual compact envelope and exact nested `data` schema; use JsonSerDe/TEXTFILE and whitelist only business files.
- Parquet: columns and types exactly match PyArrow output; use `STORED AS PARQUET`.
- Point LOCATION to the dataset root, not a single date.
- Keep EXT technical only; no cleansed labels, aggregation, generated IDs, or invented file columns.

## Step 3: `dwd_{dataset}_ddl.sql`

- Header states source, purpose, grain, business key, synchronization, history, partition, and structure evidence.
- Preserve an existing confirmed MySQL DWD field contract when applicable.
- Use explicit MaxCompute types and confirmed Chinese comments.
- Explain every technical field such as `id`, `relate_id`, audit timestamps, and `dt`.
- Partition only when the business/history strategy requires it.
- For one-to-many sources, create each target with its own grain and stable parent-child key.

## Step 4: `dwd_{dataset}_etl.sql`

Order statements as follows:

1. MaxCompute settings.
2. Register `${biz_date}` EXT partition at the exact OSS location.
3. Validate file/envelope existence, `record_count`, and raw element count.
4. Validate business keys, required timestamps, duplicates, and parent-child references before overwrite.
5. Read and expand arrays with `POSEXPLODE` when position is needed for traceability.
6. Clean through explicit columns and conversions.
7. Deduplicate using the confirmed stable key and ordering.
8. `INSERT OVERWRITE` only the confirmed whole table or affected partitions.
9. Return count, distinct/null keys, duplicate IDs, time bounds, and affected partition checks.

MaxCompute ETL quality-output rules:

- Do not combine independent one-row aggregate CTEs with an unhinted `CROSS JOIN`; MaxCompute rejects it with `ODPS-0130252: Cartesian product is not allowed without mapjoin`.
- Prefer `UNION ALL` to stack named quality metrics, then use conditional aggregation to return one summary row without a Cartesian product.
- If a one-row aggregate must be joined to another result, add an explicit small-side hint such as `SELECT /*+ MAPJOIN(target_quality) */ ... FROM source_quality CROSS JOIN target_quality`.
- Do not enable a project- or session-wide Cartesian-product switch merely to make a quality query run. Keep the exception local and bounded with `MAPJOIN`.
- Before delivery, scan the generated ETL and reconciliation SQL for every `CROSS JOIN`; each occurrence must either be removed or have an explicit, valid `MAPJOIN` small-side hint.

Do not add DataWorks special dependency comments with a filename extension as an output object. Configure node outputs/dependencies using valid node identifiers.

## Step 5: DataWorks and reconciliation

- Collection node: PyODPS 3, Python 3.11 validated image, parameter `biz_date=$[yyyy-mm-dd-1]`.
- EXT DDL: one-time initialization, not daily scheduling.
- DWD node: ODPS SQL, same biz_date, real same-cycle dependency on collection and any key-source nodes.
- Publish order: EXT DDL, DWD DDL, collection node, DWD node, then a new smoke/backfill instance with its parameter preview checked.
- Ordinary editor Run does not prove scheduling parameter injection. Use a smoke/backfill instance for the target business date.
- After the user confirms a successful run or asks to detect/reconcile data, automatically execute the comparison against the existing SQL/MySQL ODS or DWD table recorded in the migration ledger. This is not satisfied by generating a reconciliation SQL file.
- Query the new MaxCompute result through the available read-only MaxCompute MCP. Query the existing `opt_lyt` table through its read-only MCP, or through the `opt-lyt-db` skill helper only when the MCP entry is not exposed. If the user supplied an actual MaxCompute result, it may serve as new-side evidence while the existing database is queried automatically.
- Inspect table metadata and indexes before querying large history tables. Prefer the latest indexed batch or a bounded parent-to-child join; do not start with unbounded `MAX`, `COUNT`, or `COUNT(DISTINCT)` scans over the full history.
- Reconcile the same snapshot/window: API or published OSS count, envelope/manifest count, EXT expanded count, DWD valid count, distinct keys, time bounds, and critical business aggregates.
- When MySQL history exists, use read-only bounded comparison with normalized NULL, decimals, timestamps, timezone, and encoding. Explain permitted row-count changes from expansion, filtering, aggregation, or deduplication.
- A generated SQL file is only a fallback when a required read-only connection is unavailable. State the missing connection and leave the reconciliation status unverified instead of asking the user to run SQL and calling the step complete.

## Final static review

- Core names match across files and nodes.
- No secrets or embedded credentials.
- No unconfirmed placeholders in executable artifacts.
- No interface-local reimplementation of online shared-engine capabilities. Missing local shared-resource source is not an exception.
- No JSON-string-in-Parquet workaround for a nested source. Confirmed nested schemas use the public raw-JSON path and downstream parsing occurs once; no online capability confirmation is required.
- Every `sync_parquet_task` task has a confirmed `field_types` mapping, including `biz_date` and `sync_time`; no required task key is inferred from the function name alone.
- No `SELECT *` into DWD.
- Storage and EXT schema match.
- Empty-source and partial-publication protection exist.
- Pagination cannot loop indefinitely.
- DWD column order matches DDL.
- The response distinguishes verified facts, inference, and untested code.
