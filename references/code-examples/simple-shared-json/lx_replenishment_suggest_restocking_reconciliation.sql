-- 领星补货建议数据验收
-- 执行参数：biz_date与本次DWD实例保持一致，例如2026-09-03。
-- 验收目标：核对OSS信封、EXT父子节点、数组展开结果、DWD写入量和核心字段质量。

SET odps.namespace.schema = true;
SET odps.sql.type.system.odps2 = true;
SET odps.sql.hive.compatible = true;

WITH envelope AS
(
    SELECT
        COUNT(*) AS envelope_count,
        COALESCE(SUM(record_count), 0) AS declared_parent_count,
        COALESCE(SUM(SIZE(data)), 0) AS actual_parent_count
    FROM ext.lx_replenishment_suggest_restocking_raw
    WHERE dt = '${biz_date}'
      AND source = 'lingxing'
      AND dataset = 'lx_replenishment_suggest_restocking'
      AND biz_date = '${biz_date}'
),
parent_source AS
(
    SELECT
        parent_pos,
        parent
    FROM ext.lx_replenishment_suggest_restocking_raw raw
    LATERAL VIEW POSEXPLODE(raw.data) parent_view AS parent_pos, parent
    WHERE raw.dt = '${biz_date}'
      AND raw.source = 'lingxing'
      AND raw.dataset = 'lx_replenishment_suggest_restocking'
      AND raw.biz_date = '${biz_date}'
),
restocking_nodes AS
(
    SELECT
        parent_pos,
        CAST(NULL AS BIGINT) AS child_pos,
        CAST(1 AS BIGINT) AS is_parent,
        parent.basic_info AS basic_info,
        parent.suggest_info AS suggest_info
    FROM parent_source

    UNION ALL

    SELECT
        src.parent_pos,
        CAST(child_pos AS BIGINT) AS child_pos,
        CAST(0 AS BIGINT) AS is_parent,
        child.basic_info AS basic_info,
        child.suggest_info AS suggest_info
    FROM parent_source src
    LATERAL VIEW POSEXPLODE(src.parent.item_list) child_view AS child_pos, child
),
node_skus AS
(
    SELECT
        node.*,
        sku_pos,
        sku_pair,
        node.basic_info.listing_opentime_list[sku_pos] AS listing_create_time
    FROM restocking_nodes node
    LATERAL VIEW OUTER POSEXPLODE(node.basic_info.msku_fnsku_list) sku_view AS sku_pos, sku_pair
),
source_expanded AS
(
    SELECT
        node.is_parent,
        NULLIF(TRIM(node.basic_info.hash_id), '') AS hash_id,
        CAST(node.basic_info.sid AS BIGINT) AS sid,
        NULLIF(TRIM(node.sku_pair.msku), '') AS msku,
        NULLIF(TRIM(node.sku_pair.fnsku), '') AS fnsku,
        NULLIF(TRIM(node.listing_create_time), '') AS listing_create_time,
        CASE
            WHEN sm.sm_id IS NOT NULL
             AND TRIM(sm.sm_id) RLIKE '^[0-9]+$'
            THEN CAST(sm.sm_id AS BIGINT)
        END AS sm_id
    FROM node_skus node
    LATERAL VIEW OUTER POSEXPLODE(node.suggest_info.suggest_sm_list) sm_view AS sm_pos, sm
),
source_node_quality AS
(
    SELECT
        COUNT(*) AS source_node_count,
        COUNT(DISTINCT basic_info.hash_id) AS source_distinct_hash_id_count,
        SUM(
            CASE
                WHEN basic_info.hash_id IS NULL OR TRIM(basic_info.hash_id) = '' THEN 1
                ELSE 0
            END
        ) AS source_empty_hash_id_count,
        SUM(CASE WHEN is_parent = 1 THEN 1 ELSE 0 END) AS source_parent_node_count,
        SUM(CASE WHEN is_parent = 0 THEN 1 ELSE 0 END) AS source_child_node_count
    FROM restocking_nodes
),
source_expanded_quality AS
(
    SELECT
        COUNT(*) AS source_expanded_row_count,
        SUM(CASE WHEN is_parent = 1 THEN 1 ELSE 0 END) AS source_expanded_parent_row_count,
        SUM(CASE WHEN is_parent = 0 THEN 1 ELSE 0 END) AS source_expanded_child_row_count
    FROM source_expanded
),
target_source AS
(
    SELECT *
    FROM dwd.lx_replenishment_suggest_restocking
    WHERE dt = '${biz_date}'
),
target_quality AS
(
    SELECT
        COUNT(*) AS target_row_count,
        COUNT(DISTINCT hash_id) AS target_distinct_hash_id_count,
        SUM(CASE WHEN hash_id IS NULL OR TRIM(hash_id) = '' THEN 1 ELSE 0 END) AS target_empty_hash_id_count,
        SUM(CASE WHEN sid IS NULL THEN 1 ELSE 0 END) AS target_null_sid_count,
        SUM(CASE WHEN parent_id = 0 THEN 1 ELSE 0 END) AS target_parent_row_count,
        SUM(CASE WHEN parent_id <> 0 THEN 1 ELSE 0 END) AS target_child_row_count,
        SUM(CASE WHEN name_y IS NULL OR TRIM(name_y) = '' THEN 1 ELSE 0 END) AS unmatched_seller_count,
        SUM(CASE WHEN node_type NOT IN ('1', '2', '3', '4') OR node_type IS NULL THEN 1 ELSE 0 END)
            AS invalid_node_type_count,
        SUM(
            CASE
                WHEN available_sale_days_fba <> fba_available_sale_days
                  OR (available_sale_days_fba IS NULL AND fba_available_sale_days IS NOT NULL)
                  OR (available_sale_days_fba IS NOT NULL AND fba_available_sale_days IS NULL)
                THEN 1
                ELSE 0
            END
        ) AS inconsistent_fba_sale_days_count,
        MIN(sync_time) AS earliest_sync_time,
        MAX(sync_time) AS latest_sync_time
    FROM target_source
),
target_grain_duplicates AS
(
    SELECT
        COUNT(*) AS duplicate_group_count,
        COALESCE(SUM(group_count - 1), 0) AS duplicate_excess_row_count
    FROM
    (
        SELECT
            hash_id,
            COALESCE(msku, '') AS msku,
            COALESCE(fnsku, '') AS fnsku,
            COALESCE(listing_create_time, '') AS listing_create_time,
            COALESCE(sm_id, -1) AS sm_id,
            COUNT(*) AS group_count
        FROM target_source
        GROUP BY
            hash_id,
            COALESCE(msku, ''),
            COALESCE(fnsku, ''),
            COALESCE(listing_create_time, ''),
            COALESCE(sm_id, -1)
        HAVING COUNT(*) > 1
    ) duplicated
),
metrics AS
(
    SELECT '01_envelope_count' AS metric_name, CAST(envelope_count AS STRING) AS metric_value FROM envelope
    UNION ALL
    SELECT '02_declared_parent_count', CAST(declared_parent_count AS STRING) FROM envelope
    UNION ALL
    SELECT '03_actual_parent_count', CAST(actual_parent_count AS STRING) FROM envelope
    UNION ALL
    SELECT '04_source_node_count', CAST(source_node_count AS STRING) FROM source_node_quality
    UNION ALL
    SELECT '05_source_distinct_hash_id_count', CAST(source_distinct_hash_id_count AS STRING) FROM source_node_quality
    UNION ALL
    SELECT '06_source_empty_hash_id_count', CAST(source_empty_hash_id_count AS STRING) FROM source_node_quality
    UNION ALL
    SELECT '07_source_parent_node_count', CAST(source_parent_node_count AS STRING) FROM source_node_quality
    UNION ALL
    SELECT '08_source_child_node_count', CAST(source_child_node_count AS STRING) FROM source_node_quality
    UNION ALL
    SELECT '09_source_expanded_row_count', CAST(source_expanded_row_count AS STRING) FROM source_expanded_quality
    UNION ALL
    SELECT '10_source_expanded_parent_row_count', CAST(source_expanded_parent_row_count AS STRING) FROM source_expanded_quality
    UNION ALL
    SELECT '11_source_expanded_child_row_count', CAST(source_expanded_child_row_count AS STRING) FROM source_expanded_quality
    UNION ALL
    SELECT '12_target_row_count', CAST(target_row_count AS STRING) FROM target_quality
    UNION ALL
    SELECT '13_target_distinct_hash_id_count', CAST(target_distinct_hash_id_count AS STRING) FROM target_quality
    UNION ALL
    SELECT '14_target_empty_hash_id_count', CAST(target_empty_hash_id_count AS STRING) FROM target_quality
    UNION ALL
    SELECT '15_target_null_sid_count', CAST(target_null_sid_count AS STRING) FROM target_quality
    UNION ALL
    SELECT '16_target_parent_row_count', CAST(target_parent_row_count AS STRING) FROM target_quality
    UNION ALL
    SELECT '17_target_child_row_count', CAST(target_child_row_count AS STRING) FROM target_quality
    UNION ALL
    SELECT '18_unmatched_seller_count', CAST(unmatched_seller_count AS STRING) FROM target_quality
    UNION ALL
    SELECT '19_invalid_node_type_count', CAST(invalid_node_type_count AS STRING) FROM target_quality
    UNION ALL
    SELECT '20_inconsistent_fba_sale_days_count', CAST(inconsistent_fba_sale_days_count AS STRING) FROM target_quality
    UNION ALL
    SELECT '21_duplicate_grain_group_count', CAST(duplicate_group_count AS STRING) FROM target_grain_duplicates
    UNION ALL
    SELECT '22_duplicate_grain_excess_row_count', CAST(duplicate_excess_row_count AS STRING) FROM target_grain_duplicates
    UNION ALL
    SELECT '23_earliest_sync_time', CAST(earliest_sync_time AS STRING) FROM target_quality
    UNION ALL
    SELECT '24_latest_sync_time', CAST(latest_sync_time AS STRING) FROM target_quality
)
SELECT
    '${biz_date}' AS affected_dt,
    metric_name,
    metric_value
FROM metrics
ORDER BY metric_name;

-- 判定标准：
-- 1. 01=1，02=03。
-- 2. 04=05，06=0，表示父子节点hash_id完整且节点级唯一。
-- 3. 09=12、10=16、11=17，表示EXT展开后无增减写入DWD。
-- 4. 13=05，14、15、18、19、20均为0。
-- 5. 21、22应为0；非0表示“hash_id+MSKU+FNSKU+Listing时间+运输方式”粒度仍有重复。
