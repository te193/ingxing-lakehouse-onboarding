-- 领星FBA货件 MaxCompute验收与对账SQL
-- 使用方式：在DataWorks ODPS SQL节点中配置 biz_date=$[yyyy-mm-dd-1] 后只读执行。
-- 本文件只查询EXT和DWD，不修改分区或业务数据。

SET odps.namespace.schema = true;
SET odps.sql.type.system.odps2 = true;
SET odps.sql.hive.compatible = true;

-- 1. JSON信封：正常情况下envelope_row_count=1，record_count=data_array_count。
SELECT
    COUNT(*) AS envelope_row_count,
    MIN(source) AS source,
    MIN(dataset) AS dataset,
    MIN(biz_date) AS envelope_biz_date,
    COALESCE(SUM(record_count), 0) AS declared_record_count,
    COALESCE(SUM(SIZE(data)), 0) AS data_array_count,
    MIN(sync_time) AS earliest_sync_time,
    MAX(sync_time) AS latest_sync_time
FROM ext.lx_fba_shipment_raw
WHERE dt = '${biz_date}';

-- 2. 展开关系：源展开行数应等于DWD行数，源货件数应等于DWD货件数。
WITH source_expanded AS
(
    SELECT
        shipment.id AS shipment_record_id,
        item_pos,
        CASE
            WHEN item_pos IS NULL THEN 0 - shipment.id
            ELSE item.id
        END AS technical_id
    FROM ext.lx_fba_shipment_raw raw
    LATERAL VIEW EXPLODE(raw.data) shipment_view AS shipment
    LATERAL VIEW OUTER POSEXPLODE(shipment.item_list) item_view AS item_pos, item
    WHERE raw.dt = '${biz_date}'
      AND raw.source = 'lingxing'
      AND raw.dataset = 'lx_fba_shipment'
      AND raw.biz_date = '${biz_date}'
),
quality_metrics AS
(
    SELECT 'source_expanded_count' AS metric_name, COUNT(*) AS metric_value
    FROM source_expanded

    UNION ALL

    SELECT 'source_shipment_count' AS metric_name, COUNT(DISTINCT shipment_record_id) AS metric_value
    FROM source_expanded

    UNION ALL

    SELECT 'source_distinct_id_count' AS metric_name, COUNT(DISTINCT technical_id) AS metric_value
    FROM source_expanded

    UNION ALL

    SELECT 'source_empty_item_shipment_count' AS metric_name,
           SUM(CASE WHEN item_pos IS NULL THEN 1 ELSE 0 END) AS metric_value
    FROM source_expanded

    UNION ALL

    SELECT 'target_row_count' AS metric_name, COUNT(*) AS metric_value
    FROM dwd.lx_fba_shipment
    WHERE dt = '${biz_date}'

    UNION ALL

    SELECT 'target_shipment_count' AS metric_name, COUNT(DISTINCT relate_id) AS metric_value
    FROM dwd.lx_fba_shipment
    WHERE dt = '${biz_date}'

    UNION ALL

    SELECT 'target_distinct_id_count' AS metric_name, COUNT(DISTINCT id) AS metric_value
    FROM dwd.lx_fba_shipment
    WHERE dt = '${biz_date}'
),
quality_summary AS
(
    SELECT
        MAX(CASE WHEN metric_name = 'source_expanded_count' THEN metric_value END) AS source_expanded_count,
        MAX(CASE WHEN metric_name = 'target_row_count' THEN metric_value END) AS target_row_count,
        MAX(CASE WHEN metric_name = 'source_shipment_count' THEN metric_value END) AS source_shipment_count,
        MAX(CASE WHEN metric_name = 'target_shipment_count' THEN metric_value END) AS target_shipment_count,
        MAX(CASE WHEN metric_name = 'source_distinct_id_count' THEN metric_value END) AS source_distinct_id_count,
        MAX(CASE WHEN metric_name = 'target_distinct_id_count' THEN metric_value END) AS target_distinct_id_count,
        MAX(CASE WHEN metric_name = 'source_empty_item_shipment_count' THEN metric_value END) AS source_empty_item_shipment_count
    FROM quality_metrics
)
SELECT
    '${biz_date}' AS affected_dt,
    source_expanded_count,
    target_row_count,
    source_shipment_count,
    target_shipment_count,
    source_distinct_id_count,
    target_distinct_id_count,
    source_empty_item_shipment_count,
    CASE
        WHEN source_expanded_count = target_row_count
         AND source_shipment_count = target_shipment_count
         AND source_distinct_id_count = source_expanded_count
         AND target_distinct_id_count = target_row_count
        THEN 'PASS'
        ELSE 'CHECK'
    END AS count_and_key_check
FROM quality_summary;

-- 3. 主键、货件业务字段及重复检查：各异常计数应为0。
SELECT
    COUNT(*) AS target_row_count,
    SUM(CASE WHEN id IS NULL THEN 1 ELSE 0 END) AS null_id_count,
    SUM(CASE WHEN relate_id IS NULL THEN 1 ELSE 0 END) AS null_relate_id_count,
    SUM(CASE WHEN shipment_id IS NULL OR TRIM(shipment_id) = '' THEN 1 ELSE 0 END) AS empty_shipment_id_count,
    SUM(CASE WHEN sid IS NULL OR TRIM(sid) = '' THEN 1 ELSE 0 END) AS empty_sid_count,
    COUNT(*) - COUNT(DISTINCT id) AS duplicate_id_row_count,
    MIN(gmt_create) AS earliest_gmt_create,
    MAX(gmt_create) AS latest_gmt_create,
    MIN(gmt_modified) AS earliest_gmt_modified,
    MAX(gmt_modified) AS latest_gmt_modified
FROM dwd.lx_fba_shipment
WHERE dt = '${biz_date}';

-- 4. 数量差异公式检查：三项mismatch均应为0。
SELECT
    COUNT(*) AS target_row_count,
    SUM(
        CASE
            WHEN CAST(COALESCE(NULLIF(TRIM(aad_diff), ''), '0') AS BIGINT)
               <> CAST(COALESCE(NULLIF(TRIM(quantity_shipped), ''), '0') AS BIGINT)
                - CAST(COALESCE(NULLIF(TRIM(quantity_shipped_local), ''), '0') AS BIGINT)
            THEN 1 ELSE 0
        END
    ) AS aad_diff_mismatch_count,
    SUM(
        CASE
            WHEN CAST(COALESCE(NULLIF(TRIM(rad_diff), ''), '0') AS BIGINT)
               <> CAST(COALESCE(NULLIF(TRIM(quantity_received), ''), '0') AS BIGINT)
                - CAST(COALESCE(NULLIF(TRIM(quantity_shipped_local), ''), '0') AS BIGINT)
            THEN 1 ELSE 0
        END
    ) AS rad_diff_mismatch_count,
    SUM(
        CASE
            WHEN CAST(COALESCE(NULLIF(TRIM(aar_diff), ''), '0') AS BIGINT)
               <> CAST(COALESCE(NULLIF(TRIM(quantity_shipped), ''), '0') AS BIGINT)
                - CAST(COALESCE(NULLIF(TRIM(quantity_received), ''), '0') AS BIGINT)
            THEN 1 ELSE 0
        END
    ) AS aar_diff_mismatch_count
FROM dwd.lx_fba_shipment
WHERE dt = '${biz_date}';

-- 5. Listing补充字段覆盖情况。空值允许存在，但应记录数量和比例并与历史批次比较。
SELECT
    COUNT(*) AS target_row_count,
    SUM(CASE WHEN country IS NULL OR TRIM(country) = '' THEN 1 ELSE 0 END) AS empty_country_count,
    SUM(CASE WHEN asin IS NULL OR TRIM(asin) = '' THEN 1 ELSE 0 END) AS empty_asin_count,
    SUM(CASE WHEN parent_asin IS NULL OR TRIM(parent_asin) = '' THEN 1 ELSE 0 END) AS empty_parent_asin_count,
    SUM(CASE WHEN local_name IS NULL OR TRIM(local_name) = '' THEN 1 ELSE 0 END) AS empty_local_name_count,
    ROUND(
        100.0 * SUM(CASE WHEN country IS NULL OR TRIM(country) = '' THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0),
        4
    ) AS empty_country_rate_pct
FROM dwd.lx_fba_shipment
WHERE dt = '${biz_date}';

-- 6. 状态和运输方式分布，用于发现枚举映射或数据量突变。
SELECT
    shipment_status,
    shipping_mode,
    is_closed,
    COUNT(*) AS row_count,
    COUNT(DISTINCT relate_id) AS shipment_count
FROM dwd.lx_fba_shipment
WHERE dt = '${biz_date}'
GROUP BY shipment_status, shipping_mode, is_closed
ORDER BY shipment_count DESC, row_count DESC;

-- 7. 最近7个已落地分区的趋势；当天行数突然偏离历史时再检查上游接口窗口和Listing覆盖率。
SELECT
    dt,
    COUNT(*) AS row_count,
    COUNT(DISTINCT relate_id) AS shipment_count,
    COUNT(DISTINCT id) AS distinct_id_count,
    SUM(CASE WHEN country IS NULL OR TRIM(country) = '' THEN 1 ELSE 0 END) AS empty_country_count,
    MIN(gmt_create) AS earliest_gmt_create,
    MAX(gmt_create) AS latest_gmt_create
FROM dwd.lx_fba_shipment
WHERE dt IN
(
    SELECT dt
    FROM
    (
        SELECT DISTINCT dt
        FROM dwd.lx_fba_shipment
        WHERE dt <= '${biz_date}'
        ORDER BY dt DESC
        LIMIT 7
    ) recent_partitions
)
GROUP BY dt
ORDER BY dt DESC;
