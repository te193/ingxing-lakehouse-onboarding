-- 领星调价队列 OSS JSON 信封外部表
-- 数据来源：guqiao_ods/lx_sale_adjust_price_queue/dt=YYYY-MM-DD/data.json
-- 执行方式：仅在首次创建或Schema变化时手工执行，不配置每日调度。

SET odps.namespace.schema = true;
SET odps.sql.type.system.odps2 = true;
SET odps.sql.hive.compatible = true;

CREATE EXTERNAL TABLE IF NOT EXISTS ext.lx_sale_adjust_price_queue_raw
(
    source       STRING COMMENT '数据来源',
    dataset      STRING COMMENT '数据集名称',
    biz_date     STRING COMMENT '业务日期',
    record_count BIGINT COMMENT '记录数',
    sync_time    STRING COMMENT '同步时间',
    data         ARRAY<STRUCT<
                     msku:STRING,
                     fnsku:STRING,
                     asin:STRING,
                     sid:BIGINT,
                     processing_status:BIGINT,
                     failure_reason:STRING,
                     finish_time:STRING,
                     create_time:STRING,
                     adjust_type:BIGINT,
                     profit_estimate:STRUCT<
                         standard_price_profit:STRING,
                         standard_price_profit_rate:STRING,
                         sale_price_profit:STRING,
                         sale_price_profit_rate:STRING,
                         currency_icon:STRING
                     >,
                     store_name:STRING,
                     marketplace:STRING,
                     create_user:STRING,
                     processing_status_text:STRING,
                     adjust_before_obj:STRUCT<
                         standard_price:STRING,
                         sale_price:STRING,
                         sale_time_range:STRING,
                         icon:STRING
                     >,
                     adjust_after_obj:STRUCT<
                         standard_price:STRING,
                         sale_price:STRING,
                         sale_time_range:STRING,
                         icon:STRING
                     >,
                     adjust_range:STRUCT<
                         standard_price:STRING,
                         sale_price:STRING
                     >,
                     asin_url:STRING,
                     business_id:STRING,
                     can_audit:BIGINT,
                     small_image_url:STRING,
                     local_sku:STRING,
                     local_name:STRING,
                     adjust_before:ARRAY<STRING>,
                     adjust_after:ARRAY<STRING>,
                     audit_info:ARRAY<MAP<STRING,STRING>>
                 >> COMMENT '调价队列记录数组'
)
PARTITIONED BY
(
    dt STRING COMMENT '业务日期，格式YYYY-MM-DD'
)
ROW FORMAT SERDE 'org.apache.hive.hcatalog.data.JsonSerDe'
STORED AS TEXTFILE
LOCATION 'oss://oss-cn-shenzhen-internal.aliyuncs.com/gq-lakehouse/guqiao_ods/lx_sale_adjust_price_queue/'
TBLPROPERTIES
(
    'odps.external.data.enable.extension' = 'true',
    'odps.external.data.file.whitelist.regex' = '.*\\.json'
);
