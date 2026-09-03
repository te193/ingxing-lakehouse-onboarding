-- 领星FBA货件 DWD 明细表
-- 数据来源：ext.lx_fba_shipment_raw。
-- 结构基准：MySQL dwd_datasync.lx_fba_shipment，共47个业务字段。
-- 数据粒度：每个货件商品一行；item_list为空的货件仍保留一行。
-- 业务唯一键：领星货件记录id + 货件商品记录id；无商品时以货件记录id作为稳定标识。
-- 技术ID：relate_id对应领星货件记录id，id对应货件商品记录id或无商品货件的稳定技术ID。
-- 同步策略：每天重拉包含biz_date当天在内的最近90个自然日。
-- 分区口径：dt取本次同步biz_date，同一biz_date重跑覆盖同一快照分区。

SET odps.namespace.schema = true;
SET odps.sql.type.system.odps2 = true;

CREATE TABLE IF NOT EXISTS dwd.lx_fba_shipment
(
    id                                      BIGINT COMMENT '主键',
    relate_id                               BIGINT COMMENT '关联ID',
    create_time                             STRING COMMENT '同步时间',
    shipment_id                             STRING COMMENT '货件单号',
    sid                                     STRING COMMENT '店铺id',
    seller                                  STRING COMMENT '店铺',
    country                                 STRING COMMENT '国家',
    shipment_name                           STRING COMMENT '货件名称',
    shipping_mode                           STRING COMMENT '货件类型',
    alpha_name                              STRING COMMENT '承运人',
    shipment_status                         STRING COMMENT '货件状态',
    working_time                            STRING COMMENT 'WORKING状态变更时间',
    shipped_time                            STRING COMMENT 'SHIPPED状态变更时间',
    receiving_time                          STRING COMMENT 'RECEIVING状态变更时间',
    closed_time                             STRING COMMENT 'CLOSED状态变更时间',
    is_closed                               STRING COMMENT '货件实际状态',
    reference_id                            STRING COMMENT 'Reference_ID',
    username                                STRING COMMENT '创建人',
    gmt_create                              STRING COMMENT '创建时间',
    gmt_modified                            STRING COMMENT '更新时间',
    msku                                    STRING COMMENT 'MSKU',
    fnsku                                   STRING COMMENT 'FNSKU',
    asin                                    STRING COMMENT 'ASIN',
    parent_asin                             STRING COMMENT '父ASIN',
    local_name                              STRING COMMENT '品名',
    sku                                     STRING COMMENT 'SKU',
    quantity_shipped                        STRING COMMENT '申报量',
    quantity_shipped_local                  STRING COMMENT '已发货',
    quantity_received                       STRING COMMENT '签收量',
    prep_labelowner                         STRING COMMENT '标签类型',
    aad_diff                                STRING COMMENT '申发差异',
    rad_diff                                STRING COMMENT '收发差异',
    aar_diff                                STRING COMMENT '申收差异',
    ship_from_name                          STRING COMMENT '寄件人',
    ship_from_phone                         STRING COMMENT '寄件电话',
    ship_from_postal_code                   STRING COMMENT '寄件邮编',
    ship_from_country_code                  STRING COMMENT '寄件国家',
    ship_from_state_or_province_code        STRING COMMENT '寄件州/省',
    ship_from_city                          STRING COMMENT '寄件城市',
    ship_from_address_line1                 STRING COMMENT '寄件街道地址',
    ship_to_name                            STRING COMMENT '收件人',
    ship_to_postal_code                     STRING COMMENT '收件邮编',
    ship_to_country_code                    STRING COMMENT '收件国家',
    ship_to_state_or_province_code          STRING COMMENT '收件州/省',
    ship_to_city                            STRING COMMENT '收件城市',
    ship_to_address_line1                   STRING COMMENT '收件街道地址',
    ship_to_doorplate                       STRING COMMENT '收件门牌号'
)
COMMENT '领星FBA货件商品明细，按业务日期保存最近90个自然日快照'
PARTITIONED BY
(
    dt STRING COMMENT '同步业务日期，格式YYYY-MM-DD'
)
STORED AS ALIORC;
