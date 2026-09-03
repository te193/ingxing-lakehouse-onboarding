-- 领星FBA货件 OSS JSON信封外部表
-- 数据来源：guqiao_ods/lx_fba_shipment/dt=YYYY-MM-DD/data.json
-- 结构证据：领星“查询货件列表”接口文档及现有MySQL ODS嵌套字段样本
-- 执行方式：仅在首次创建或Schema变化时手工执行，不配置每日调度。

SET odps.namespace.schema = true;
SET odps.sql.type.system.odps2 = true;
SET odps.sql.hive.compatible = true;

CREATE EXTERNAL TABLE IF NOT EXISTS ext.lx_fba_shipment_raw
(
    source       STRING COMMENT '数据来源',
    dataset      STRING COMMENT '数据集名称',
    biz_date     STRING COMMENT '业务日期',
    record_count BIGINT COMMENT '货件记录数',
    sync_time    STRING COMMENT '本批次同步时间',
    data         ARRAY<STRUCT<
                     id:BIGINT,
                     sid:BIGINT,
                     seller:STRING,
                     uid:BIGINT,
                     username:STRING,
                     shipment_id:STRING,
                     shipment_name:STRING,
                     sta_shipment_id:STRING,
                     sta_inbound_plan_id:STRING,
                     sta_plan_name:STRING,
                     is_closed:BIGINT,
                     shipment_status:STRING,
                     gmt_modified:STRING,
                     gmt_create:STRING,
                     sync_time:STRING,
                     destination_fulfillment_center_id:STRING,
                     is_synchronous:BIGINT,
                     is_uploaded_box:BIGINT,
                     is_sta:BIGINT,
                     shipping_mode:STRING,
                     shipping_solution:STRING,
                     alpha_code:STRING,
                     alpha_name:STRING,
                     sta_shipment_date:STRING,
                     sta_delivery_start_date:STRING,
                     sta_delivery_end_date:STRING,
                     tracking_number_list:ARRAY<STRUCT<
                         box_id:STRING,
                         tracking_number:STRING
                     >>,
                     bill_of_lading_number:STRING,
                     freight_bill_number:STRING,
                     item_list:ARRAY<STRUCT<
                         id:BIGINT,
                         zid:BIGINT,
                         msku:STRING,
                         fnsku:STRING,
                         asin:STRING,
                         sku:STRING,
                         quantity_shipped:BIGINT,
                         init_quantity_shipped:BIGINT,
                         quantity_received:BIGINT,
                         quantity_shipped_local:BIGINT,
                         quantity_in_case:BIGINT,
                         prep_details:STRING,
                         prep_instruction:STRING,
                         prep_owner:STRING,
                         prep_labelowner:STRING,
                         expiration:STRING,
                         release_date:STRING,
                         ware_house_storage_id:BIGINT,
                         shipment_plan_list:ARRAY<STRUCT<
                             shipment_plan_sn:STRING
                         >>
                     >>,
                     working_time:STRING,
                     shipped_time:STRING,
                     receiving_time:STRING,
                     closed_time:STRING,
                     reference_id:STRING,
                     ship_from_address:STRUCT<
                         name:STRING,
                         country_code:STRING,
                         state_or_province_code:STRING,
                         city:STRING,
                         region:STRING,
                         address_line1:STRING,
                         address_line2:STRING,
                         postal_code:STRING,
                         phone:STRING
                     >,
                     ship_to_address:STRUCT<
                         name:STRING,
                         country_code:STRING,
                         state_or_province_code:STRING,
                         city:STRING,
                         region:STRING,
                         address_line1:STRING,
                         address_line2:STRING,
                         postal_code:STRING,
                         doorplate:STRING
                     >
                 >> COMMENT '领星FBA货件记录数组'
)
PARTITIONED BY
(
    dt STRING COMMENT '业务日期，格式YYYY-MM-DD'
)
ROW FORMAT SERDE 'org.apache.hive.hcatalog.data.JsonSerDe'
STORED AS TEXTFILE
LOCATION 'oss://oss-cn-shenzhen-internal.aliyuncs.com/gq-lakehouse/guqiao_ods/lx_fba_shipment/'
TBLPROPERTIES
(
    'odps.external.data.enable.extension' = 'true',
    'odps.external.data.file.whitelist.regex' = '.*\\.json'
);
