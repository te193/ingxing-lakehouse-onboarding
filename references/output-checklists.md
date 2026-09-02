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
- Use the shared client for token, signing, HTTP, retry, and OSS access; do not duplicate credentials.
- Prefer the confirmed call structure from an existing successful interface node when the user asks to follow the old or previously working code structure; do not substitute a guessed shared-engine function.
- Implement the project-standard `get_biz_date()` priority and normalization.
- Derive the confirmed request window from `biz_date`; do not offset the OSS partition date.
- Put confirmed POST business parameters in `req_body`; verify query/signature requirements against the shared engine before using another route.
- Configure the real list path/pagination mechanism, page size, total matching, maximum bounds, duplicate-page protection, and batching.
- Define zero-record behavior explicitly. Full/latest overwrite must normally fail on unexpected zero; valid transactional empty days may publish an empty batch only when confirmed.
- Publish only after every page and batch succeeds. Use staging/manifest for multi-part Parquet.
- Ensure `source`, dataset, biz_date, record count, schema, and OSS `dt` agree.
- Do not claim runtime success when no real test was authorized.

## Step 2: `ext_{dataset}_ddl.sql`

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
- Reconcile the same snapshot/window: API or published OSS count, envelope/manifest count, EXT expanded count, DWD valid count, distinct keys, time bounds, and critical business aggregates.
- When MySQL history exists, use read-only bounded comparison with normalized NULL, decimals, timestamps, timezone, and encoding. Explain permitted row-count changes from expansion, filtering, aggregation, or deduplication.

## Final static review

- Core names match across files and nodes.
- No secrets or embedded credentials.
- No unconfirmed placeholders in executable artifacts.
- No `SELECT *` into DWD.
- Storage and EXT schema match.
- Empty-source and partial-publication protection exist.
- Pagination cannot loop indefinitely.
- DWD column order matches DDL.
- The response distinguishes verified facts, inference, and untested code.
