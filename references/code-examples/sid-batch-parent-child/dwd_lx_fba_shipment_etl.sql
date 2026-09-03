-- 节点名称：dwd_lx_fba_shipment
-- 上游依赖：lx_fba_shipment、dwd_lx_sales_mws_listing
-- 调度参数：biz_date=$[yyyy-mm-dd-1]
-- 处理策略：读取biz_date对应的近90个自然日货件快照，展开item_list后覆盖同一biz_date分区。
-- 明细粒度：每个货件商品一行；item_list为空的货件保留一行。
-- 补充字段：country、asin、parent_asin、local_name从最新Listing表补充，未匹配时保留货件明细。

SET odps.namespace.schema = true;
SET odps.sql.type.system.odps2 = true;
SET odps.sql.hive.compatible = true;

-- 注册本批次OSS目录。重复执行不会重复创建分区。
ALTER TABLE ext.lx_fba_shipment_raw
ADD IF NOT EXISTS PARTITION (dt = '${biz_date}')
LOCATION 'oss://oss-cn-shenzhen-internal.aliyuncs.com/gq-lakehouse/guqiao_ods/lx_fba_shipment/dt=${biz_date}/';

-- 校验单文件JSON信封、数据集、业务日期及record_count。
-- 异常时故意转换非法BIGINT，使节点在覆盖DWD前失败。
SELECT
    CASE
        WHEN COUNT(*) = 0
        THEN CAST('EMPTY_OSS_SOURCE' AS BIGINT)
        WHEN COUNT(*) <> 1
        THEN CAST('UNEXPECTED_ENVELOPE_COUNT' AS BIGINT)
        WHEN SUM(
                 CASE
                     WHEN COALESCE(source, '') <> 'lingxing'
                       OR COALESCE(dataset, '') <> 'lx_fba_shipment'
                       OR COALESCE(biz_date, '') <> '${biz_date}'
                     THEN 1
                     ELSE 0
                 END
             ) > 0
        THEN CAST('INVALID_ENVELOPE_METADATA' AS BIGINT)
        WHEN COALESCE(SUM(record_count), 0) = 0
          OR COALESCE(SUM(SIZE(data)), 0) = 0
        THEN CAST('EMPTY_SHIPMENT_DATA' AS BIGINT)
        WHEN COALESCE(SUM(record_count), 0) <> COALESCE(SUM(SIZE(data)), 0)
        THEN CAST('RECORD_COUNT_MISMATCH' AS BIGINT)
        ELSE COALESCE(SUM(SIZE(data)), 0)
    END AS checked_shipment_count
FROM ext.lx_fba_shipment_raw
WHERE dt = '${biz_date}';

-- 校验货件主键、业务单号、店铺、必要时间和货件记录重复。
SELECT
    CASE
        WHEN SUM(
                 CASE
                     WHEN shipment.id IS NULL
                       OR shipment.shipment_id IS NULL
                       OR TRIM(shipment.shipment_id) = ''
                       OR shipment.sid IS NULL
                       OR shipment.gmt_create IS NULL
                       OR NOT (shipment.gmt_create RLIKE '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}(:[0-9]{2})?$')
                       OR shipment.gmt_modified IS NULL
                       OR NOT (shipment.gmt_modified RLIKE '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}(:[0-9]{2})?$')
                     THEN 1
                     ELSE 0
                 END
             ) > 0
        THEN CAST('INVALID_SHIPMENT_KEY_OR_TIME' AS BIGINT)
        WHEN COUNT(*) <> COUNT(DISTINCT shipment.id)
        THEN CAST('DUPLICATE_SHIPMENT_RECORD_ID' AS BIGINT)
        ELSE COUNT(*)
    END AS checked_shipment_count
FROM ext.lx_fba_shipment_raw raw
LATERAL VIEW EXPLODE(raw.data) exploded AS shipment
WHERE raw.dt = '${biz_date}'
  AND raw.source = 'lingxing'
  AND raw.dataset = 'lx_fba_shipment'
  AND raw.biz_date = '${biz_date}';

-- 校验商品子记录：非空item_list必须有商品id，展开后的技术id必须全局唯一。
WITH expanded_items AS
(
    SELECT
        shipment.id AS shipment_record_id,
        item_pos,
        item,
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
)
SELECT
    CASE
        WHEN SUM(
                 CASE
                     WHEN shipment_record_id IS NULL
                       OR (item_pos IS NOT NULL AND item.id IS NULL)
                     THEN 1
                     ELSE 0
                 END
             ) > 0
        THEN CAST('INVALID_PARENT_OR_ITEM_ID' AS BIGINT)
        WHEN COUNT(*) <> COUNT(DISTINCT technical_id)
        THEN CAST('DUPLICATE_TECHNICAL_ID' AS BIGINT)
        ELSE COUNT(*)
    END AS checked_expanded_count
FROM expanded_items;

WITH shipment_source AS
(
    SELECT
        raw.sync_time AS batch_sync_time,
        shipment_pos,
        shipment
    FROM ext.lx_fba_shipment_raw raw
    LATERAL VIEW POSEXPLODE(raw.data) shipment_view AS shipment_pos, shipment
    WHERE raw.dt = '${biz_date}'
      AND raw.source = 'lingxing'
      AND raw.dataset = 'lx_fba_shipment'
      AND raw.biz_date = '${biz_date}'
),
shipment_items AS
(
    SELECT
        batch_sync_time,
        shipment_pos,
        shipment,
        item_pos,
        item
    FROM shipment_source
    LATERAL VIEW OUTER POSEXPLODE(shipment.item_list) item_view AS item_pos, item
),
listing_ranked AS
(
    SELECT
        sid,
        NULLIF(TRIM(seller_sku), '') AS seller_sku,
        NULLIF(TRIM(fnsku), '') AS fnsku,
        NULLIF(TRIM(asin), '') AS asin,
        NULLIF(TRIM(parent_asin), '') AS parent_asin,
        NULLIF(TRIM(local_name), '') AS local_name,
        NULLIF(TRIM(marketplace), '') AS marketplace,
        ROW_NUMBER() OVER
        (
            PARTITION BY sid, NULLIF(TRIM(seller_sku), ''), NULLIF(TRIM(fnsku), '')
            ORDER BY create_time DESC, id DESC
        ) AS row_num
    FROM dwd.lx_sales_mws_listing
),
shipment_clean AS
(
    SELECT
        CASE
            WHEN src.item_pos IS NULL THEN 0 - src.shipment.id
            ELSE src.item.id
        END AS id,
        src.shipment.id AS relate_id,
        NULLIF(TRIM(src.batch_sync_time), '') AS create_time,
        NULLIF(TRIM(src.shipment.shipment_id), '') AS shipment_id,
        CAST(src.shipment.sid AS STRING) AS sid,
        NULLIF(TRIM(src.shipment.seller), '') AS seller,
        listing.marketplace AS country,
        NULLIF(TRIM(src.shipment.shipment_name), '') AS shipment_name,
        CASE NULLIF(TRIM(src.shipment.shipping_mode), '')
            WHEN 'GROUND_SMALL_PARCEL' THEN '小包裹快递（SPD）'
            WHEN 'FREIGHT_LTL' THEN '汽运零担（LTL）'
            ELSE NULLIF(TRIM(src.shipment.shipping_mode), '')
        END AS shipping_mode,
        NULLIF(TRIM(src.shipment.alpha_name), '') AS alpha_name,
        NULLIF(TRIM(src.shipment.shipment_status), '') AS shipment_status,
        NULLIF(TRIM(src.shipment.working_time), '') AS working_time,
        NULLIF(TRIM(src.shipment.shipped_time), '') AS shipped_time,
        NULLIF(TRIM(src.shipment.receiving_time), '') AS receiving_time,
        NULLIF(TRIM(src.shipment.closed_time), '') AS closed_time,
        CASE src.shipment.is_closed
            WHEN 0 THEN '进行中'
            WHEN 1 THEN '已完成'
            ELSE CAST(src.shipment.is_closed AS STRING)
        END AS is_closed,
        NULLIF(TRIM(src.shipment.reference_id), '') AS reference_id,
        NULLIF(TRIM(src.shipment.username), '') AS username,
        NULLIF(TRIM(src.shipment.gmt_create), '') AS gmt_create,
        NULLIF(TRIM(src.shipment.gmt_modified), '') AS gmt_modified,
        NULLIF(TRIM(src.item.msku), '') AS msku,
        NULLIF(TRIM(src.item.fnsku), '') AS fnsku,
        COALESCE(listing.asin, NULLIF(TRIM(src.item.asin), '')) AS asin,
        listing.parent_asin AS parent_asin,
        listing.local_name AS local_name,
        NULLIF(TRIM(src.item.sku), '') AS sku,
        CAST(src.item.quantity_shipped AS STRING) AS quantity_shipped,
        CAST(src.item.quantity_shipped_local AS STRING) AS quantity_shipped_local,
        CAST(src.item.quantity_received AS STRING) AS quantity_received,
        NULLIF(TRIM(src.item.prep_labelowner), '') AS prep_labelowner,
        CAST(
            COALESCE(src.item.quantity_shipped, 0)
            - COALESCE(src.item.quantity_shipped_local, 0)
            AS STRING
        ) AS aad_diff,
        CAST(
            COALESCE(src.item.quantity_received, 0)
            - COALESCE(src.item.quantity_shipped_local, 0)
            AS STRING
        ) AS rad_diff,
        CAST(
            COALESCE(src.item.quantity_shipped, 0)
            - COALESCE(src.item.quantity_received, 0)
            AS STRING
        ) AS aar_diff,
        NULLIF(TRIM(src.shipment.ship_from_address.name), '') AS ship_from_name,
        NULLIF(TRIM(src.shipment.ship_from_address.phone), '') AS ship_from_phone,
        NULLIF(TRIM(src.shipment.ship_from_address.postal_code), '') AS ship_from_postal_code,
        NULLIF(TRIM(src.shipment.ship_from_address.country_code), '') AS ship_from_country_code,
        NULLIF(TRIM(src.shipment.ship_from_address.state_or_province_code), '') AS ship_from_state_or_province_code,
        NULLIF(TRIM(src.shipment.ship_from_address.city), '') AS ship_from_city,
        NULLIF(TRIM(src.shipment.ship_from_address.address_line1), '') AS ship_from_address_line1,
        NULLIF(TRIM(src.shipment.ship_to_address.name), '') AS ship_to_name,
        NULLIF(TRIM(src.shipment.ship_to_address.postal_code), '') AS ship_to_postal_code,
        NULLIF(TRIM(src.shipment.ship_to_address.country_code), '') AS ship_to_country_code,
        NULLIF(TRIM(src.shipment.ship_to_address.state_or_province_code), '') AS ship_to_state_or_province_code,
        NULLIF(TRIM(src.shipment.ship_to_address.city), '') AS ship_to_city,
        NULLIF(TRIM(src.shipment.ship_to_address.address_line1), '') AS ship_to_address_line1,
        NULLIF(TRIM(src.shipment.ship_to_address.doorplate), '') AS ship_to_doorplate,
        ROW_NUMBER() OVER
        (
            PARTITION BY
                CASE
                    WHEN src.item_pos IS NULL THEN 0 - src.shipment.id
                    ELSE src.item.id
                END
            ORDER BY
                src.shipment.gmt_modified DESC,
                src.batch_sync_time DESC,
                src.shipment_pos DESC,
                src.item_pos DESC
        ) AS row_num
    FROM shipment_items src
    LEFT JOIN listing_ranked listing
      ON listing.row_num = 1
     AND listing.sid = src.shipment.sid
     AND listing.seller_sku = NULLIF(TRIM(src.item.msku), '')
     AND listing.fnsku = NULLIF(TRIM(src.item.fnsku), '')
)
INSERT OVERWRITE TABLE dwd.lx_fba_shipment PARTITION (dt = '${biz_date}')
SELECT
    id,
    relate_id,
    create_time,
    shipment_id,
    sid,
    seller,
    country,
    shipment_name,
    shipping_mode,
    alpha_name,
    shipment_status,
    working_time,
    shipped_time,
    receiving_time,
    closed_time,
    is_closed,
    reference_id,
    username,
    gmt_create,
    gmt_modified,
    msku,
    fnsku,
    asin,
    parent_asin,
    local_name,
    sku,
    quantity_shipped,
    quantity_shipped_local,
    quantity_received,
    prep_labelowner,
    aad_diff,
    rad_diff,
    aar_diff,
    ship_from_name,
    ship_from_phone,
    ship_from_postal_code,
    ship_from_country_code,
    ship_from_state_or_province_code,
    ship_from_city,
    ship_from_address_line1,
    ship_to_name,
    ship_to_postal_code,
    ship_to_country_code,
    ship_to_state_or_province_code,
    ship_to_city,
    ship_to_address_line1,
    ship_to_doorplate
FROM shipment_clean
WHERE row_num = 1;

-- 返回本次分区质量结果。未匹配Listing不会丢行，在补充字段空值数中体现。
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
source_quality AS
(
    SELECT
        COUNT(*) AS source_expanded_count,
        COUNT(DISTINCT shipment_record_id) AS source_shipment_count,
        SUM(CASE WHEN item_pos IS NULL THEN 1 ELSE 0 END) AS source_empty_item_shipment_count,
        COUNT(DISTINCT technical_id) AS source_distinct_id_count
    FROM source_expanded
),
target_quality AS
(
    SELECT
        COUNT(*) AS target_row_count,
        COUNT(DISTINCT relate_id) AS target_shipment_count,
        COUNT(DISTINCT id) AS target_distinct_id_count,
        SUM(CASE WHEN id IS NULL THEN 1 ELSE 0 END) AS target_null_id_count,
        SUM(CASE WHEN shipment_id IS NULL OR TRIM(shipment_id) = '' THEN 1 ELSE 0 END) AS empty_shipment_id_count,
        SUM(CASE WHEN country IS NULL OR TRIM(country) = '' THEN 1 ELSE 0 END) AS listing_country_unmatched_count,
        SUM(CASE WHEN parent_asin IS NULL OR TRIM(parent_asin) = '' THEN 1 ELSE 0 END) AS empty_parent_asin_count,
        SUM(CASE WHEN local_name IS NULL OR TRIM(local_name) = '' THEN 1 ELSE 0 END) AS empty_local_name_count,
        MIN(gmt_create) AS earliest_gmt_create,
        MAX(gmt_create) AS latest_gmt_create,
        MIN(gmt_modified) AS earliest_gmt_modified,
        MAX(gmt_modified) AS latest_gmt_modified
    FROM dwd.lx_fba_shipment
    WHERE dt = '${biz_date}'
)
SELECT /*+ MAPJOIN(target_quality) */
    '${biz_date}' AS affected_dt,
    source_quality.source_expanded_count,
    target_quality.target_row_count,
    source_quality.source_shipment_count,
    target_quality.target_shipment_count,
    source_quality.source_empty_item_shipment_count,
    source_quality.source_distinct_id_count,
    target_quality.target_distinct_id_count,
    target_quality.target_null_id_count,
    target_quality.empty_shipment_id_count,
    target_quality.listing_country_unmatched_count,
    target_quality.empty_parent_asin_count,
    target_quality.empty_local_name_count,
    target_quality.earliest_gmt_create,
    target_quality.latest_gmt_create,
    target_quality.earliest_gmt_modified,
    target_quality.latest_gmt_modified
FROM source_quality
CROSS JOIN target_quality;
