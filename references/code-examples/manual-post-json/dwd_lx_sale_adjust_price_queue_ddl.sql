-- 领星调价队列 DWD 明细表
-- 数据粒度：每条调价记录一行。
-- 业务唯一键：business_id。
-- 技术ID：接口不提供MySQL ODS自增ID，MC中id、relate_id由business_id稳定转换得到。
-- 分区口径：dt取queue_create_time的日期，用于回刷最近15天并保留更早历史。

SET odps.namespace.schema = true;
SET odps.sql.type.system.odps2 = true;

CREATE TABLE IF NOT EXISTS dwd.lx_sale_adjust_price_queue
(
    id                                         BIGINT   COMMENT '主键ID，取接口business_id',
    relate_id                                  BIGINT   COMMENT '关联ID，取接口business_id',
    delete_flag                                BIGINT   COMMENT '删除标志，默认0',
    msku                                       STRING   COMMENT '亚马逊卖家SKU',
    local_sku                                  STRING   COMMENT '本地产品SKU',
    fnsku                                      STRING   COMMENT 'FNSKU',
    asin                                       STRING   COMMENT 'ASIN',
    local_name                                 STRING   COMMENT '品名',
    store_name                                 STRING   COMMENT '店铺名称',
    marketplace                                STRING   COMMENT '国家',
    processing_status_text                     STRING   COMMENT '调价状态文字说明',
    adjust_type                                BIGINT   COMMENT '调价类型',
    queue_create_time                          STRING   COMMENT '调价创建时间',
    finish_time                                STRING   COMMENT '调价完成时间',
    sid                                        BIGINT   COMMENT '店铺ID',
    processing_status                          BIGINT   COMMENT '调价状态',
    create_user                                STRING   COMMENT '创建人',
    asin_url                                   STRING   COMMENT 'ASIN跳转亚马逊前台链接',
    business_id                                STRING   COMMENT '调价记录ID',
    can_audit                                  BIGINT   COMMENT '是否可以审批：1是，0不是',
    small_image_url                            STRING   COMMENT '商品缩略图地址',
    failure_reason                             STRING   COMMENT '调价失败原因',
    currency_icon                              STRING   COMMENT '币种符号',
    profit_estimate_standard_price_profit      STRING   COMMENT '价格毛利润',
    profit_estimate_standard_price_profit_rate STRING   COMMENT '价格毛利率',
    profit_estimate_sale_price_profit          STRING   COMMENT '优惠价毛利润',
    profit_estimate_sale_price_profit_rate     STRING   COMMENT '优惠价毛利率',
    adjust_before_obj_standard_price           STRING   COMMENT '调价前价格',
    adjust_before_obj_sale_price               STRING   COMMENT '调价前优惠价',
    adjust_before_obj_sale_time_range          STRING   COMMENT '调价前优惠价生效期',
    adjust_before_obj_icon                     STRING   COMMENT '调价前币种符号',
    adjust_after_obj_standard_price            STRING   COMMENT '调价后价格',
    adjust_after_obj_sale_price                STRING   COMMENT '调价后优惠价',
    adjust_after_obj_sale_time_range           STRING   COMMENT '调价后优惠价生效期',
    adjust_after_obj_icon                      STRING   COMMENT '调价后币种符号',
    adjust_range_standard_price                STRING   COMMENT '价格幅度',
    adjust_range_sale_price                    STRING   COMMENT '优惠价幅度',
    adjust_before                              STRING   COMMENT '调整前JSON数组',
    adjust_after                               STRING   COMMENT '调整后JSON数组',
    audit_info                                 STRING   COMMENT '审批信息JSON数组',
    backup_time                                DATETIME COMMENT '备份时间，取本批次接口同步时间',
    ods_update_time                            DATETIME COMMENT '源数据更新时间，取本批次接口同步时间',
    create_time                                DATETIME COMMENT '数据创建时间，取本批次接口同步时间',
    update_time                                DATETIME COMMENT '数据最近更新时间，取本批次接口同步时间'
)
COMMENT '领星亚马逊Listing调价队列明细'
PARTITIONED BY
(
    dt STRING COMMENT '调价创建日期，格式YYYY-MM-DD'
);
