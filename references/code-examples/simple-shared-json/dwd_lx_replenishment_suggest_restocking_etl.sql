-- 节点名称：dwd_lx_replenishment_suggest_restocking
-- 上游依赖：lx_replenishment_suggest_restocking、dwd_lx_basic_seller
-- 调度参数：biz_date=$[yyyy-mm-dd-1]
-- 处理策略：读取biz_date批次OSS信封，展开父项、子项、MSKU/FNSKU和运输方式后，覆盖同一biz_date分区。
-- 父子关系：父项parent_id=0；子项parent_id使用“业务日期+父项位置”生成的批次内稳定父ID。
-- 字段补充：name_y、country从最新店铺表按sid补充；未匹配时保留补货明细。

SET odps.namespace.schema = true;
SET odps.sql.type.system.odps2 = true;
SET odps.sql.hive.compatible = true;

-- 注册本批次OSS目录。重复执行不会重复创建分区。
ALTER TABLE ext.lx_replenishment_suggest_restocking_raw
ADD IF NOT EXISTS PARTITION (dt = '${biz_date}')
LOCATION 'oss://oss-cn-shenzhen-internal.aliyuncs.com/gq-lakehouse/guqiao_ods/lx_replenishment_suggest_restocking/dt=${biz_date}/';

-- 覆盖DWD前执行必要的空源和单信封保护。
SELECT
    CASE
        WHEN COUNT(*) = 0
        THEN CAST('EMPTY_OSS_SOURCE' AS BIGINT)
        WHEN COUNT(*) <> 1
        THEN CAST('UNEXPECTED_ENVELOPE_COUNT' AS BIGINT)
        WHEN COALESCE(SUM(record_count), 0) = 0
          OR COALESCE(SUM(SIZE(data)), 0) = 0
        THEN CAST('EMPTY_RESTOCKING_DATA' AS BIGINT)
        WHEN COALESCE(SUM(record_count), 0) <> COALESCE(SUM(SIZE(data)), 0)
        THEN CAST('RECORD_COUNT_MISMATCH' AS BIGINT)
        ELSE COALESCE(SUM(SIZE(data)), 0)
    END AS checked_parent_count
FROM ext.lx_replenishment_suggest_restocking_raw
WHERE dt = '${biz_date}'
  AND source = 'lingxing'
  AND dataset = 'lx_replenishment_suggest_restocking'
  AND biz_date = '${biz_date}';

WITH parent_source AS
(
    SELECT
        raw.sync_time AS batch_sync_time,
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
        batch_sync_time,
        parent_pos,
        CAST(NULL AS BIGINT) AS child_pos,
        CAST(1 AS BIGINT) AS is_parent,
        parent.basic_info AS basic_info,
        parent.amazon_quantity_info AS amazon_quantity_info,
        parent.scm_quantity_info AS scm_quantity_info,
        parent.sales_info AS sales_info,
        parent.suggest_info AS suggest_info,
        parent.ext_info AS ext_info
    FROM parent_source

    UNION ALL

    SELECT
        src.batch_sync_time,
        src.parent_pos,
        CAST(child_pos AS BIGINT) AS child_pos,
        CAST(0 AS BIGINT) AS is_parent,
        child.basic_info AS basic_info,
        child.amazon_quantity_info AS amazon_quantity_info,
        child.scm_quantity_info AS scm_quantity_info,
        child.sales_info AS sales_info,
        child.suggest_info AS suggest_info,
        child.ext_info AS ext_info
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
node_transport_modes AS
(
    SELECT
        node.*,
        sm_pos,
        sm
    FROM node_skus node
    LATERAL VIEW OUTER POSEXPLODE(node.suggest_info.suggest_sm_list) sm_view AS sm_pos, sm
),
seller_ranked AS
(
    SELECT
        sid,
        NULLIF(TRIM(name), '') AS seller_name,
        NULLIF(TRIM(country), '') AS country,
        ROW_NUMBER() OVER
        (
            PARTITION BY sid
            ORDER BY create_time DESC, id DESC
        ) AS row_num
    FROM dwd.lx_basic_seller
),
restocking_clean AS
(
    SELECT
        CASE
            WHEN node.is_parent = 1 THEN CAST(0 AS BIGINT)
            ELSE CAST(
                     CONCAT(
                         REPLACE('${biz_date}', '-', ''),
                         LPAD(CAST(node.parent_pos + 1 AS STRING), 7, '0')
                     ) AS BIGINT
                 )
        END AS parent_id,
        CAST(node.batch_sync_time AS DATETIME) AS create_time,
        CAST(node.basic_info.node_type AS STRING) AS node_type,
        CAST(node.basic_info.data_type AS STRING) AS data_type,
        NULLIF(TRIM(node.basic_info.asin), '') AS asin,
        CAST(node.basic_info.sync_time AS DATETIME) AS sync_time,
        NULLIF(TRIM(node.basic_info.hash_id), '') AS hash_id,
        CAST(node.basic_info.sid AS BIGINT) AS sid,
        NULLIF(TRIM(node.listing_create_time), '') AS listing_create_time,
        NULLIF(TRIM(node.sku_pair.msku), '') AS msku,
        NULLIF(TRIM(node.sku_pair.fnsku), '') AS fnsku,
        node.amazon_quantity_info.afn_fulfillable_quantity AS afn_fulfillable_quantity,
        node.amazon_quantity_info.afn_reserved_quantity AS afn_reserved_quantity,
        node.amazon_quantity_info.amazon_quantity_shipping AS amazon_quantity_shipping,
        node.amazon_quantity_info.reserved_fc_transfers AS reserved_fc_transfers,
        node.amazon_quantity_info.amazon_quantity_valid AS amazon_quantity_valid,
        node.amazon_quantity_info.afn_inbound_receiving_quantity AS afn_inbound_receiving_quantity,
        node.amazon_quantity_info.reserved_fc_processing AS reserved_fc_processing,
        node.amazon_quantity_info.amazon_quantity_shipping_plan AS amazon_quantity_shipping_plan,
        node.scm_quantity_info.sc_quantity_purchase_shipping AS sc_quantity_purchase_shipping,
        node.scm_quantity_info.sc_quantity_purchase_plan AS sc_quantity_purchase_plan,
        node.scm_quantity_info.sc_quantity_local_valid AS sc_quantity_local_valid,
        node.scm_quantity_info.sc_quantity_local_qc AS sc_quantity_local_qc,
        node.scm_quantity_info.sc_quantity_oversea_valid AS sc_quantity_oversea_valid,
        node.scm_quantity_info.sc_quantity_local_shipping AS sc_quantity_local_shipping,
        node.scm_quantity_info.sc_quantity_oversea_shipping AS sc_quantity_oversea_shipping,
        CAST(node.sales_info.sales_avg_30 AS DECIMAL(12, 2)) AS sales_avg_30,
        node.sales_info.sales_total_7 AS sales_total_7,
        node.sales_info.sales_total_60 AS sales_total_60,
        CAST(node.sales_info.sales_avg_60 AS DECIMAL(12, 2)) AS sales_avg_60,
        node.sales_info.sales_total_30 AS sales_total_30,
        node.sales_info.sales_total_90 AS sales_total_90,
        CAST(node.sales_info.sales_avg_7 AS DECIMAL(12, 2)) AS sales_avg_7,
        CAST(node.sales_info.sales_avg_90 AS DECIMAL(12, 2)) AS sales_avg_90,
        node.sales_info.sales_total_14 AS sales_total_14,
        node.sales_info.sales_total_3 AS sales_total_3,
        CAST(node.sales_info.sales_avg_3 AS DECIMAL(12, 2)) AS sales_avg_3,
        CAST(node.sales_info.sales_avg_14 AS DECIMAL(12, 2)) AS sales_avg_14,
        NULLIF(TRIM(node.suggest_info.out_stock_date_purchase), '') AS out_stock_date_purchase,
        NULLIF(TRIM(node.suggest_info.sug_date_send_oversea), '') AS sug_date_send_oversea,
        CAST(node.suggest_info.fba_available_sale_days AS DECIMAL(12, 2)) AS fba_available_sale_days,
        NULLIF(TRIM(node.suggest_info.out_stock_date_local), '') AS out_stock_date_local,
        NULLIF(TRIM(node.suggest_info.sug_date_purchase), '') AS sug_date_purchase,
        CAST(node.suggest_info.out_stock_flag AS STRING) AS out_stock_flag,
        CAST(node.suggest_info.fba_available_sale_days AS DECIMAL(12, 2)) AS available_sale_days_fba,
        CAST(node.suggest_info.estimated_sale_avg_quantity AS DECIMAL(12, 2)) AS estimated_sale_avg_quantity,
        NULLIF(TRIM(node.suggest_info.sug_date_send_local), '') AS sug_date_send_local,
        CAST(node.suggest_info.available_sale_days AS DECIMAL(12, 2)) AS available_sale_days,
        NULLIF(TRIM(node.suggest_info.out_stock_date_oversea), '') AS out_stock_date_oversea,
        NULLIF(TRIM(node.suggest_info.out_stock_date), '') AS out_stock_date,
        node.suggest_info.estimated_sale_quantity AS estimated_sale_quantity,
        node.suggest_info.quantity_sug_oversea_to_fba AS quantity_sug_oversea_to_fba,
        COALESCE(node.sm.quantity_sug_local_to_oversea, node.suggest_info.quantity_sug_local_to_oversea)
            AS quantity_sug_local_to_oversea,
        CASE
            WHEN node.sm.sm_id IS NOT NULL
             AND TRIM(node.sm.sm_id) RLIKE '^[0-9]+$'
            THEN CAST(node.sm.sm_id AS BIGINT)
        END AS sm_id,
        NULLIF(TRIM(node.sm.name), '') AS name_x,
        COALESCE(node.sm.quantity_sug_purchase, node.suggest_info.quantity_sug_purchase)
            AS quantity_sug_purchase,
        COALESCE(node.sm.quantity_sug_local_to_fba, node.suggest_info.quantity_sug_local_to_fba)
            AS quantity_sug_local_to_fba,
        CAST(node.ext_info.restock_status AS STRING) AS restock_status,
        CAST(node.ext_info.star AS STRING) AS star,
        NULLIF(TRIM(node.ext_info.remark), '') AS remark,
        seller.seller_name AS name_y,
        seller.country AS country
    FROM node_transport_modes node
    LEFT JOIN seller_ranked seller
      ON seller.row_num = 1
     AND seller.sid = CAST(node.basic_info.sid AS BIGINT)
)
INSERT OVERWRITE TABLE dwd.lx_replenishment_suggest_restocking PARTITION (dt = '${biz_date}')
SELECT
    parent_id,
    create_time,
    node_type,
    data_type,
    asin,
    sync_time,
    hash_id,
    sid,
    listing_create_time,
    msku,
    fnsku,
    afn_fulfillable_quantity,
    afn_reserved_quantity,
    amazon_quantity_shipping,
    reserved_fc_transfers,
    amazon_quantity_valid,
    afn_inbound_receiving_quantity,
    reserved_fc_processing,
    amazon_quantity_shipping_plan,
    sc_quantity_purchase_shipping,
    sc_quantity_purchase_plan,
    sc_quantity_local_valid,
    sc_quantity_local_qc,
    sc_quantity_oversea_valid,
    sc_quantity_local_shipping,
    sc_quantity_oversea_shipping,
    sales_avg_30,
    sales_total_7,
    sales_total_60,
    sales_avg_60,
    sales_total_30,
    sales_total_90,
    sales_avg_7,
    sales_avg_90,
    sales_total_14,
    sales_total_3,
    sales_avg_3,
    sales_avg_14,
    out_stock_date_purchase,
    sug_date_send_oversea,
    fba_available_sale_days,
    out_stock_date_local,
    sug_date_purchase,
    out_stock_flag,
    available_sale_days_fba,
    estimated_sale_avg_quantity,
    sug_date_send_local,
    available_sale_days,
    out_stock_date_oversea,
    out_stock_date,
    estimated_sale_quantity,
    quantity_sug_oversea_to_fba,
    quantity_sug_local_to_oversea,
    sm_id,
    name_x,
    quantity_sug_purchase,
    quantity_sug_local_to_fba,
    restock_status,
    star,
    remark,
    name_y,
    country
FROM restocking_clean;

-- 返回本次分区的基础结果，供节点日志快速核对。
SELECT
    '${biz_date}' AS affected_dt,
    COUNT(*) AS row_count,
    COUNT(DISTINCT hash_id) AS distinct_hash_id_count,
    SUM(CASE WHEN hash_id IS NULL OR TRIM(hash_id) = '' THEN 1 ELSE 0 END) AS empty_hash_id_count,
    SUM(CASE WHEN parent_id = 0 THEN 1 ELSE 0 END) AS parent_row_count,
    SUM(CASE WHEN parent_id <> 0 THEN 1 ELSE 0 END) AS child_row_count,
    SUM(CASE WHEN name_y IS NULL OR TRIM(name_y) = '' THEN 1 ELSE 0 END) AS unmatched_seller_count
FROM dwd.lx_replenishment_suggest_restocking
WHERE dt = '${biz_date}';
