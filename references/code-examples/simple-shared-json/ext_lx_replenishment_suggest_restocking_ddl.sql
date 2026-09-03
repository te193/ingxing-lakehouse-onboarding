-- 领星补货列表 OSS JSON信封外部表
-- 数据来源：guqiao_ods/lx_replenishment_suggest_restocking/dt=YYYY-MM-DD/data.json
-- 结构证据：领星官方“查询补货列表”文档及现有MySQL ODS父子嵌套样本。
-- item_list按业务父子两层建模；子项自身的空item_list不递归映射。
-- 执行方式：仅在首次创建或Schema变化时手工执行，不配置每日调度。

SET odps.namespace.schema = true;
SET odps.sql.type.system.odps2 = true;
SET odps.sql.hive.compatible = true;

CREATE EXTERNAL TABLE IF NOT EXISTS ext.lx_replenishment_suggest_restocking_raw
(
    source       STRING COMMENT '数据来源',
    dataset      STRING COMMENT '数据集名称',
    biz_date     STRING COMMENT '业务日期',
    record_count BIGINT COMMENT '补货父记录数',
    sync_time    STRING COMMENT '本批次同步时间',
    data         ARRAY<STRUCT<
                     basic_info:STRUCT<
                         data_type:BIGINT,
                         node_type:BIGINT,
                         sid:STRING,
                         asin:STRING,
                         msku_fnsku_list:ARRAY<STRUCT<
                             msku:STRING,
                             fnsku:STRING
                         >>,
                         listing_opentime_list:ARRAY<STRING>,
                         sync_time:STRING,
                         hash_id:STRING
                     >,
                     amazon_quantity_info:STRUCT<
                         amazon_quantity_valid:BIGINT,
                         amazon_quantity_shipping:BIGINT,
                         afn_reserved_quantity:BIGINT,
                         amazon_quantity_shipping_plan:BIGINT,
                         afn_fulfillable_quantity:BIGINT,
                         reserved_fc_transfers:BIGINT,
                         reserved_fc_processing:BIGINT,
                         afn_inbound_receiving_quantity:BIGINT
                     >,
                     scm_quantity_info:STRUCT<
                         sc_quantity_local_valid:BIGINT,
                         sc_quantity_oversea_valid:BIGINT,
                         sc_quantity_oversea_shipping:BIGINT,
                         sc_quantity_local_qc:BIGINT,
                         sc_quantity_purchase_plan:BIGINT,
                         sc_quantity_purchase_shipping:BIGINT,
                         sc_quantity_local_shipping:BIGINT
                     >,
                     sales_info:STRUCT<
                         sales_avg_3:DOUBLE,
                         sales_avg_7:DOUBLE,
                         sales_avg_14:DOUBLE,
                         sales_avg_30:DOUBLE,
                         sales_avg_60:DOUBLE,
                         sales_avg_90:DOUBLE,
                         sales_total_3:BIGINT,
                         sales_total_7:BIGINT,
                         sales_total_14:BIGINT,
                         sales_total_30:BIGINT,
                         sales_total_60:BIGINT,
                         sales_total_90:BIGINT
                     >,
                     suggest_info:STRUCT<
                         out_stock_flag:BIGINT,
                         out_stock_date:STRING,
                         estimated_sale_quantity:BIGINT,
                         estimated_sale_avg_quantity:DOUBLE,
                         available_sale_days:DOUBLE,
                         fba_available_sale_days:DOUBLE,
                         quantity_sug_purchase:BIGINT,
                         quantity_sug_local_to_oversea:BIGINT,
                         quantity_sug_local_to_fba:BIGINT,
                         quantity_sug_oversea_to_fba:BIGINT,
                         out_stock_date_purchase:STRING,
                         out_stock_date_local:STRING,
                         out_stock_date_oversea:STRING,
                         sug_date_purchase:STRING,
                         sug_date_send_local:STRING,
                         sug_date_send_oversea:STRING,
                         suggest_sm_list:ARRAY<STRUCT<
                             sm_id:STRING,
                             name:STRING,
                             quantity_sug_purchase:BIGINT,
                             quantity_sug_local_to_fba:BIGINT,
                             quantity_sug_local_to_oversea:BIGINT
                         >>
                     >,
                     ext_info:STRUCT<
                         restock_status:BIGINT,
                         remark:STRING,
                         star:BIGINT,
                         need_flag:ARRAY<BIGINT>
                     >,
                     item_list:ARRAY<STRUCT<
                         basic_info:STRUCT<
                             data_type:BIGINT,
                             node_type:BIGINT,
                             sid:STRING,
                             asin:STRING,
                             msku_fnsku_list:ARRAY<STRUCT<
                                 msku:STRING,
                                 fnsku:STRING
                             >>,
                             listing_opentime_list:ARRAY<STRING>,
                             sync_time:STRING,
                             hash_id:STRING
                         >,
                         amazon_quantity_info:STRUCT<
                             amazon_quantity_valid:BIGINT,
                             amazon_quantity_shipping:BIGINT,
                             afn_reserved_quantity:BIGINT,
                             amazon_quantity_shipping_plan:BIGINT,
                             afn_fulfillable_quantity:BIGINT,
                             reserved_fc_transfers:BIGINT,
                             reserved_fc_processing:BIGINT,
                             afn_inbound_receiving_quantity:BIGINT
                         >,
                         scm_quantity_info:STRUCT<
                             sc_quantity_local_valid:BIGINT,
                             sc_quantity_oversea_valid:BIGINT,
                             sc_quantity_oversea_shipping:BIGINT,
                             sc_quantity_local_qc:BIGINT,
                             sc_quantity_purchase_plan:BIGINT,
                             sc_quantity_purchase_shipping:BIGINT,
                             sc_quantity_local_shipping:BIGINT
                         >,
                         sales_info:STRUCT<
                             sales_avg_3:DOUBLE,
                             sales_avg_7:DOUBLE,
                             sales_avg_14:DOUBLE,
                             sales_avg_30:DOUBLE,
                             sales_avg_60:DOUBLE,
                             sales_avg_90:DOUBLE,
                             sales_total_3:BIGINT,
                             sales_total_7:BIGINT,
                             sales_total_14:BIGINT,
                             sales_total_30:BIGINT,
                             sales_total_60:BIGINT,
                             sales_total_90:BIGINT
                         >,
                         suggest_info:STRUCT<
                             out_stock_flag:BIGINT,
                             out_stock_date:STRING,
                             estimated_sale_quantity:BIGINT,
                             estimated_sale_avg_quantity:DOUBLE,
                             available_sale_days:DOUBLE,
                             fba_available_sale_days:DOUBLE,
                             quantity_sug_purchase:BIGINT,
                             quantity_sug_local_to_oversea:BIGINT,
                             quantity_sug_local_to_fba:BIGINT,
                             quantity_sug_oversea_to_fba:BIGINT,
                             out_stock_date_purchase:STRING,
                             out_stock_date_local:STRING,
                             out_stock_date_oversea:STRING,
                             sug_date_purchase:STRING,
                             sug_date_send_local:STRING,
                             sug_date_send_oversea:STRING,
                             suggest_sm_list:ARRAY<STRUCT<
                                 sm_id:STRING,
                                 name:STRING,
                                 quantity_sug_purchase:BIGINT,
                                 quantity_sug_local_to_fba:BIGINT,
                                 quantity_sug_local_to_oversea:BIGINT
                             >>
                         >,
                         ext_info:STRUCT<
                             restock_status:BIGINT,
                             remark:STRING,
                             star:BIGINT,
                             need_flag:ARRAY<BIGINT>
                         >
                     >>
                 >> COMMENT '补货父记录及其子项数组'
)
PARTITIONED BY
(
    dt STRING COMMENT '业务日期，格式YYYY-MM-DD'
)
ROW FORMAT SERDE 'org.apache.hive.hcatalog.data.JsonSerDe'
STORED AS TEXTFILE
LOCATION 'oss://oss-cn-shenzhen-internal.aliyuncs.com/gq-lakehouse/guqiao_ods/lx_replenishment_suggest_restocking/'
TBLPROPERTIES
(
    'odps.external.data.enable.extension' = 'true',
    'odps.external.data.file.whitelist.regex' = '.*\\.json'
);
