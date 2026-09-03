-- 节点名称：dwd_lx_sale_adjust_price_queue
-- 上游依赖：lx_sale_adjust_price_queue
-- 调度参数：biz_date=$[yyyy-mm-dd-1]
-- 处理策略：读取biz_date批次OSS信封，按business_id去重，动态覆盖其中包含的调价创建日期分区。

SET odps.namespace.schema = true;
SET odps.sql.type.system.odps2 = true;
SET odps.sql.hive.compatible = true;

-- 注册本批次OSS目录。重复执行不会重复创建分区。
ALTER TABLE ext.lx_sale_adjust_price_queue_raw
ADD IF NOT EXISTS PARTITION (dt = '${biz_date}')
LOCATION 'oss://oss-cn-shenzhen-internal.aliyuncs.com/gq-lakehouse/guqiao_ods/lx_sale_adjust_price_queue/dt=${biz_date}/';

-- 写入前检查信封是否存在、data是否为空、record_count是否与数组长度一致。
-- 异常时故意转换非法BIGINT，使节点失败，避免错误数据覆盖DWD分区。
SELECT
    CASE
        WHEN COUNT(*) = 0
          OR COALESCE(SUM(SIZE(data)), 0) = 0
        THEN CAST('EMPTY_OSS_SOURCE' AS BIGINT)
        WHEN COALESCE(SUM(record_count), 0) <> COALESCE(SUM(SIZE(data)), 0)
        THEN CAST('RECORD_COUNT_MISMATCH' AS BIGINT)
        ELSE COALESCE(SUM(SIZE(data)), 0)
    END AS checked_source_count
FROM ext.lx_sale_adjust_price_queue_raw
WHERE dt = '${biz_date}'
  AND source = 'lingxing'
  AND dataset = 'lx_sale_adjust_price_queue'
  AND biz_date = '${biz_date}';

-- 校验业务唯一键和调价创建时间；异常数据不得在清洗时被静默过滤。
SELECT
    CASE
        WHEN SUM(
                 CASE
                     WHEN item.business_id IS NULL
                       OR TRIM(item.business_id) = ''
                       OR NOT (item.business_id RLIKE '^[0-9]+$')
                       OR item.create_time IS NULL
                       OR NOT (item.create_time RLIKE '^[0-9]{4}-[0-9]{2}-[0-9]{2} ')
                     THEN 1
                     ELSE 0
                 END
             ) > 0
        THEN CAST('INVALID_BUSINESS_KEY_OR_CREATE_TIME' AS BIGINT)
        WHEN COUNT(*) <> COUNT(DISTINCT item.business_id)
        THEN CAST('DUPLICATE_BUSINESS_ID' AS BIGINT)
        ELSE COUNT(*)
    END AS checked_business_key_count
FROM ext.lx_sale_adjust_price_queue_raw raw
LATERAL VIEW EXPLODE(raw.data) exploded AS item
WHERE raw.dt = '${biz_date}'
  AND raw.source = 'lingxing'
  AND raw.dataset = 'lx_sale_adjust_price_queue'
  AND raw.biz_date = '${biz_date}';

WITH queue_source AS
(
    SELECT
        raw.sync_time,
        pos,
        item
    FROM ext.lx_sale_adjust_price_queue_raw raw
    LATERAL VIEW POSEXPLODE(raw.data) exploded AS pos, item
    WHERE raw.dt = '${biz_date}'
      AND raw.source = 'lingxing'
      AND raw.dataset = 'lx_sale_adjust_price_queue'
      AND raw.biz_date = '${biz_date}'
),
queue_clean AS
(
    SELECT
        CAST(item.business_id AS BIGINT) AS id,
        CAST(item.business_id AS BIGINT) AS relate_id,
        CAST(0 AS BIGINT) AS delete_flag,
        NULLIF(TRIM(item.msku), '') AS msku,
        NULLIF(TRIM(item.local_sku), '') AS local_sku,
        NULLIF(TRIM(item.fnsku), '') AS fnsku,
        NULLIF(TRIM(item.asin), '') AS asin,
        NULLIF(TRIM(item.local_name), '') AS local_name,
        NULLIF(TRIM(item.store_name), '') AS store_name,
        NULLIF(TRIM(item.marketplace), '') AS marketplace,
        NULLIF(TRIM(item.processing_status_text), '') AS processing_status_text,
        item.adjust_type AS adjust_type,
        NULLIF(TRIM(item.create_time), '') AS queue_create_time,
        NULLIF(TRIM(item.finish_time), '') AS finish_time,
        item.sid AS sid,
        item.processing_status AS processing_status,
        NULLIF(TRIM(item.create_user), '') AS create_user,
        NULLIF(TRIM(item.asin_url), '') AS asin_url,
        NULLIF(TRIM(item.business_id), '') AS business_id,
        item.can_audit AS can_audit,
        NULLIF(TRIM(item.small_image_url), '') AS small_image_url,
        NULLIF(TRIM(item.failure_reason), '') AS failure_reason,
        NULLIF(TRIM(item.profit_estimate.currency_icon), '') AS currency_icon,
        NULLIF(TRIM(item.profit_estimate.standard_price_profit), '') AS profit_estimate_standard_price_profit,
        NULLIF(TRIM(item.profit_estimate.standard_price_profit_rate), '') AS profit_estimate_standard_price_profit_rate,
        NULLIF(TRIM(item.profit_estimate.sale_price_profit), '') AS profit_estimate_sale_price_profit,
        NULLIF(TRIM(item.profit_estimate.sale_price_profit_rate), '') AS profit_estimate_sale_price_profit_rate,
        NULLIF(TRIM(item.adjust_before_obj.standard_price), '') AS adjust_before_obj_standard_price,
        NULLIF(TRIM(item.adjust_before_obj.sale_price), '') AS adjust_before_obj_sale_price,
        NULLIF(TRIM(item.adjust_before_obj.sale_time_range), '') AS adjust_before_obj_sale_time_range,
        NULLIF(TRIM(item.adjust_before_obj.icon), '') AS adjust_before_obj_icon,
        NULLIF(TRIM(item.adjust_after_obj.standard_price), '') AS adjust_after_obj_standard_price,
        NULLIF(TRIM(item.adjust_after_obj.sale_price), '') AS adjust_after_obj_sale_price,
        NULLIF(TRIM(item.adjust_after_obj.sale_time_range), '') AS adjust_after_obj_sale_time_range,
        NULLIF(TRIM(item.adjust_after_obj.icon), '') AS adjust_after_obj_icon,
        NULLIF(TRIM(item.adjust_range.standard_price), '') AS adjust_range_standard_price,
        NULLIF(TRIM(item.adjust_range.sale_price), '') AS adjust_range_sale_price,
        TO_JSON(item.adjust_before) AS adjust_before,
        TO_JSON(item.adjust_after) AS adjust_after,
        TO_JSON(item.audit_info) AS audit_info,
        CAST(sync_time AS DATETIME) AS backup_time,
        CAST(sync_time AS DATETIME) AS ods_update_time,
        CAST(sync_time AS DATETIME) AS create_time,
        CAST(sync_time AS DATETIME) AS update_time,
        SUBSTR(item.create_time, 1, 10) AS target_dt,
        ROW_NUMBER() OVER
        (
            PARTITION BY item.business_id
            ORDER BY sync_time DESC, pos DESC
        ) AS row_num
    FROM queue_source
    WHERE item.business_id IS NOT NULL
      AND TRIM(item.business_id) <> ''
      AND item.business_id RLIKE '^[0-9]+$'
      AND item.create_time RLIKE '^[0-9]{4}-[0-9]{2}-[0-9]{2} '
)
INSERT OVERWRITE TABLE dwd.lx_sale_adjust_price_queue PARTITION (dt)
SELECT
    id,
    relate_id,
    delete_flag,
    msku,
    local_sku,
    fnsku,
    asin,
    local_name,
    store_name,
    marketplace,
    processing_status_text,
    adjust_type,
    queue_create_time,
    finish_time,
    sid,
    processing_status,
    create_user,
    asin_url,
    business_id,
    can_audit,
    small_image_url,
    failure_reason,
    currency_icon,
    profit_estimate_standard_price_profit,
    profit_estimate_standard_price_profit_rate,
    profit_estimate_sale_price_profit,
    profit_estimate_sale_price_profit_rate,
    adjust_before_obj_standard_price,
    adjust_before_obj_sale_price,
    adjust_before_obj_sale_time_range,
    adjust_before_obj_icon,
    adjust_after_obj_standard_price,
    adjust_after_obj_sale_price,
    adjust_after_obj_sale_time_range,
    adjust_after_obj_icon,
    adjust_range_standard_price,
    adjust_range_sale_price,
    adjust_before,
    adjust_after,
    audit_info,
    backup_time,
    ods_update_time,
    create_time,
    update_time,
    target_dt AS dt
FROM queue_clean
WHERE row_num = 1;

-- 校验本批次涉及分区的行数、业务键、技术ID和同步时间。
WITH touched_partitions AS
(
    SELECT DISTINCT
        SUBSTR(item.create_time, 1, 10) AS dt
    FROM ext.lx_sale_adjust_price_queue_raw raw
    LATERAL VIEW EXPLODE(raw.data) exploded AS item
    WHERE raw.dt = '${biz_date}'
      AND raw.source = 'lingxing'
      AND raw.dataset = 'lx_sale_adjust_price_queue'
      AND raw.biz_date = '${biz_date}'
      AND item.create_time RLIKE '^[0-9]{4}-[0-9]{2}-[0-9]{2} '
)
SELECT
    COUNT(*) AS row_count,
    COUNT(DISTINCT dwd.business_id) AS distinct_business_id_count,
    SUM(CASE WHEN dwd.business_id IS NULL OR TRIM(dwd.business_id) = '' THEN 1 ELSE 0 END) AS empty_business_id_count,
    COUNT(DISTINCT dwd.id) AS distinct_id_count,
    SUM(CASE WHEN dwd.id IS NULL THEN 1 ELSE 0 END) AS null_id_count,
    MIN(dwd.queue_create_time) AS earliest_queue_create_time,
    MAX(dwd.queue_create_time) AS latest_queue_create_time,
    MAX(dwd.update_time) AS latest_update_time
FROM dwd.lx_sale_adjust_price_queue dwd
JOIN touched_partitions touched
  ON dwd.dt = touched.dt;
