-- 领星补货建议明细 DWD 表
-- 来源表：ext.lx_replenishment_suggest_restocking_raw
-- 字段合同：沿用现有 MySQL dwd_datasync.lx_replenishment_suggest_restocking
-- 数据粒度：每个补货父/子节点、MSKU/FNSKU及运输方式组合一行
-- 业务标识：接口字段hash_id；数组展开后结合MSKU、FNSKU和sm_id识别明细行
-- 装载策略：按业务日期 dt 覆盖当天快照

SET odps.namespace.schema = true;
SET odps.sql.type.system.odps2 = true;

CREATE TABLE IF NOT EXISTS dwd.lx_replenishment_suggest_restocking (
    parent_id                         BIGINT          COMMENT '父ID',
    create_time                       DATETIME        COMMENT '创建时间',
    node_type                         STRING          COMMENT '节点类型',
    data_type                         STRING          COMMENT '数据类型',
    asin                              STRING          COMMENT 'ASIN',
    sync_time                         DATETIME        COMMENT '数据更新时间',
    hash_id                           STRING          COMMENT '唯一标识',
    sid                               BIGINT          COMMENT '店铺ID',
    listing_create_time               STRING          COMMENT 'Listing创建时间',
    msku                              STRING          COMMENT 'MSKU',
    fnsku                             STRING          COMMENT 'FNSKU',
    afn_fulfillable_quantity          BIGINT          COMMENT 'FBA可售_可售',
    afn_reserved_quantity             BIGINT          COMMENT 'FBA预留数量',
    amazon_quantity_shipping          BIGINT          COMMENT 'FBA在途',
    reserved_fc_transfers             BIGINT          COMMENT 'FBA可售_待调仓',
    amazon_quantity_valid             BIGINT          COMMENT 'FBA可售',
    afn_inbound_receiving_quantity    BIGINT          COMMENT '亚马逊入库正在接收数量',
    reserved_fc_processing            BIGINT          COMMENT 'FBA可售_调仓中',
    amazon_quantity_shipping_plan     BIGINT          COMMENT '预计发货量',
    sc_quantity_purchase_shipping     BIGINT          COMMENT 'SCM_待交付',
    sc_quantity_purchase_plan         BIGINT          COMMENT 'SCM_采购计划',
    sc_quantity_local_valid           BIGINT          COMMENT 'SCM_本地仓可用',
    sc_quantity_local_qc              BIGINT          COMMENT 'SCM_待检待上架量',
    sc_quantity_oversea_valid         BIGINT          COMMENT 'SCM_海外仓可用',
    sc_quantity_local_shipping        BIGINT          COMMENT 'SCM_本地仓在途',
    sc_quantity_oversea_shipping      BIGINT          COMMENT 'SCM_海外仓在途',
    sales_avg_30                      DECIMAL(12, 2)  COMMENT '日均销量_30天',
    sales_total_7                     BIGINT          COMMENT '总销量_7天',
    sales_total_60                    BIGINT          COMMENT '总销量_60天',
    sales_avg_60                      DECIMAL(12, 2)  COMMENT '日均销量_60天',
    sales_total_30                    BIGINT          COMMENT '总销量_30天',
    sales_total_90                    BIGINT          COMMENT '总销量_90天',
    sales_avg_7                       DECIMAL(12, 2)  COMMENT '日均销量_7天',
    sales_avg_90                      DECIMAL(12, 2)  COMMENT '日均销量_90天',
    sales_total_14                    BIGINT          COMMENT '总销量_14天',
    sales_total_3                     BIGINT          COMMENT '总销量_3天',
    sales_avg_3                       DECIMAL(12, 2)  COMMENT '日均销量_3天',
    sales_avg_14                      DECIMAL(12, 2)  COMMENT '日均销量_14天',
    out_stock_date_purchase           STRING          COMMENT '采购上架断货时间',
    sug_date_send_oversea             STRING          COMMENT '建议海外仓发货日',
    fba_available_sale_days           DECIMAL(12, 2)  COMMENT '预计可售天数（只考虑FBA库存和FBA在途）',
    out_stock_date_local              STRING          COMMENT '本地仓发货断货时间',
    sug_date_purchase                 STRING          COMMENT '建议采购日',
    out_stock_flag                    STRING          COMMENT '断货标记',
    available_sale_days_fba           DECIMAL(12, 2)  COMMENT 'FBA可售天数',
    estimated_sale_avg_quantity       DECIMAL(12, 2)  COMMENT '预计日均销量',
    sug_date_send_local               STRING          COMMENT '建议本地仓发货日',
    available_sale_days               DECIMAL(12, 2)  COMMENT '预计可售天数',
    out_stock_date_oversea            STRING          COMMENT '海外仓发货断货时间',
    out_stock_date                    STRING          COMMENT '预计断货日期',
    estimated_sale_quantity           BIGINT          COMMENT '预计销量',
    quantity_sug_oversea_to_fba       BIGINT          COMMENT '建议海外仓发FBA量',
    quantity_sug_local_to_oversea     BIGINT          COMMENT '建议本地发海外仓量',
    sm_id                             BIGINT          COMMENT '运输方式ID',
    name_x                            STRING          COMMENT '运输方式',
    quantity_sug_purchase             BIGINT          COMMENT '建议采购量',
    quantity_sug_local_to_fba         BIGINT          COMMENT '建议本地发FBA量',
    restock_status                    STRING          COMMENT '无需补货标识',
    star                              STRING          COMMENT '是否关注',
    remark                            STRING          COMMENT '备注',
    name_y                            STRING          COMMENT '店铺名',
    country                           STRING          COMMENT '商城所在国家地区'
)
COMMENT '领星补货建议父子明细，按业务日期保存当日快照'
PARTITIONED BY (
    dt STRING COMMENT '业务日期，格式yyyy-MM-dd'
)
STORED AS ALIORC;
