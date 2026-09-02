# 领星接口 ODS / DWD 与 DataWorks 迁移台账

## 1. 盘点范围与结论

- Java项目：`E:\DATASYNC\datasync-lingxing`
- 旧ODS→DWD Python目录：`E:\work\数据中台项目\ETL调度脚本\db_etl`
- DataWorks本地项目目录：`E:\work\阿里云项目目录`
- Java调度任务：55个
- 可定位的旧Python脚本：52个
- Java已引用但旧目录缺失的Python脚本：3个
- 当前已在DataWorks目录落地的55项内接口：3个（店铺列表、Listing、FBA库存明细）
- 当前另有`lx_basic_account_list.py`，但它不在本次55个Java ODS任务中，单列为新增链路，不计入完成率。

> 本台账中的ODS、DWD关系以实际Java和Python代码为准；本地血缘知识库仅供参考。

## 2. 目标链路

```text
DataWorks PyODPS 3接口节点
  → 领星OpenAPI
  → OSS原始区 guqiao_ods/<dataset>/dt=${biz_date}/
  → MaxCompute EXT外部表 ext.<table>_raw
  → MaxCompute DWD清洗节点
  → MaxCompute DWD表 dwd.<table>
  → 按需同步到MySQL应用层
```

迁移后不再保留以下耦合：

```text
XXL-JOB → Java任务 → MySQL ODS → Java AOP启动本机Python → MySQL DWD
```

## 3. 迁移状态定义

| 状态 | 含义 |
|---|---|
| 已落地 | DataWorks接口节点、EXT、DWD代码已存在 |
| 部分落地 | 只完成接口节点或只完成EXT/DWD的一部分 |
| 待迁移 | Java和旧Python均存在，尚未转成DataWorks链路 |
| 旧脚本缺失 | Java引用Python文件，但旧目录找不到，需依据表结构和业务逻辑重建 |
| 待核验 | 存在表名、字段或策略疑点，迁移前必须确认 |

## 4. 全部领星任务 ODS / DWD 映射

### 4.1 基础、商品、采购与补货

| 序号 | 任务/接口 | API（HTTP） | ODS表 | Java采集策略 | 旧Python → DWD表 | DWD策略 | DW状态 |
|---:|---|---|---|---|---|---|---|
| 1 | `lx_basic_seller` 店铺列表 | `erp/sc/data/seller/lists`（GET） | `ods_datasync.lx_basic_seller` | 不分页；按SID新增、更新、删除失效店铺 | `lx_basic_seller.py` → `dwd_datasync.lx_basic_seller` | 最新全量 | 已落地 |
| 2 | `lx_basic_concept_seller` 概念店铺 | `erp/sc/data/seller/conceptLists`（GET） | `ods_datasync.lx_basic_concept_seller` | 按conceptSid同步 | `lx_basic_concept_seller.py` → `dwd_datasync.lx_basic_concept_seller` | 最新全量 | 待迁移 |
| 3 | `lx_purchase_supplier` 供应商 | `erp/sc/data/local_inventory/supplier`（POST） | `ods_datasync.lx_purchase_supplier` | 供应商列表同步 | `lx_purchase_supplier.py` → `dwd_datasync.lx_purchase_supplier` | 全量覆盖 | 待迁移 |
| 4 | `lx_sales_mws_listing` Listing | `erp/sc/data/mws/listing`（POST） | `ods_datasync.lx_sales_mws_listing` | SID每200个一批，全量重采 | `lx_sales_mws_listing.py` → `dwd_datasync.lx_sales_mws_listing` | 最新全量 | 已落地 |
| 5 | `lx_statistics_product_performance` 产品表现 | `bd/productPerformance/openApi/asinList`（POST） | `ods_datasync.lx_statistics_product_performance` | 近15天逐日、SID分批重采 | `lx_statistics_product_performance.py` → `dwd_datasync.lx_statistics_product_performance` | 日期窗口覆盖 | 待迁移 |
| 6 | `lx_finance_profit_report_msku` 利润报表-MSKU | `bd/profit/report/open/report/msku/list`（POST） | `ods_datasync.lx_finance_profit_report_msku` | 近2月重采 | `lx_finance_profit_report_msku.py` → `dwd_datasync.lx_finance_profit_report_msku` | 近2月覆盖 | 待迁移 |
| 7 | `lx_product_local_product_info` 本地产品详情 | `erp/sc/routing/data/local_inventory/batchGetProductInfo`（POST） | `ods_datasync.lx_product_local_product_info` | 全量重采 | `lx_product_local_product_info.py` → 主表、`_TouChengQingGuan`、`_GongYingShangBaoJia`、`_DanPinXinXi` | 1张ODS拆4张DWD | 待迁移 |
| 8 | `lx_fba_shipment` FBA货件 | `erp/sc/data/fba_report/shipmentList`（POST） | `ods_datasync.lx_fba_shipment` | 近90天覆盖 | `lx_fba_shipment.py` → `dwd_datasync.lx_fba_shipment` | 近90天覆盖 | 待迁移 |
| 9 | `lx_inbound_shipment_detail` FBA发货单详情 | `erp/sc/routing/storage/shipment/getInboundShipmentListMwsDetailList`（POST） | `ods_datasync.lx_inbound_shipment_detail` | 近90天批量查询详情 | `lx_inbound_shipment_detail.py` → 主表及商品、物流、辅料、权限人、新版物流、箱规6张子表 | 1张ODS拆7张DWD | 待迁移 |
| 10 | `lx_purchase_purchase_order` 采购单 | `erp/sc/routing/data/local_inventory/purchaseOrderList`（POST） | `ods_datasync.lx_purchase_purchase_order` | 近30天覆盖 | `lx_purchase_purchase_order.py` → `dwd_datasync.lx_purchase_purchase_order` | 创建时间窗口覆盖 | 待迁移 |
| 11 | `lx_statistics_profit_statistics_msku` 利润统计-MSKU | `bd/profit/statistics/open/msku/list`（POST） | `ods_datasync.lx_statistics_profit_statistics_msku` | 近60天逐日重采 | `lx_statistics_profit_statistics_msku.py` → 同名DWD | 数据日期窗口覆盖 | 待迁移 |
| 12 | `lx_statistics_profit_statistics_asin` 利润统计-ASIN | `bd/profit/statistics/open/asin/list`（POST） | `ods_datasync.lx_statistics_profit_statistics_asin` | 近60天逐日重采 | `lx_statistics_profit_statistics_asin.py` → 同名DWD | 数据日期窗口覆盖 | 待迁移 |
| 13 | `lx_replenishment_suggest_restocking` 补货列表 | `erp/sc/routing/restocking/analysis/getSummaryList`（POST） | `ods_datasync.lx_replenishment_suggest_restocking` | 拉取父子嵌套数据 | `lx_replenishment_suggest_restocking.py` → 同名DWD | 当日覆盖并展开父子项 | 待迁移 |
| 15 | `lx_basic_currency` 汇率 | `erp/sc/routing/finance/currency/currencyMonth`（POST） | `ods_datasync.lx_basic_currency` | 近2月逐月重采 | `lx_basic_currency.py` → `dwd_datasync.lx_basic_currency` | 近2月覆盖 | 待迁移 |
| 17 | `lx_storage_warehouse` 仓库列表 | `erp/sc/data/local_inventory/warehouse`（POST） | `ods_datasync.lx_storage_warehouse` | 分类拉取后全量覆盖 | `lx_storage_warehouse.py` → `dwd_datasync.lx_storage_warehouse` | 最新全量 | 待迁移 |
| 30 | `lx_fba_shipment_plan` FBA发货计划 | `erp/sc/data/fba_report/shipmentPlanLists`（POST） | `ods_datasync.lx_fba_shipment_plan` | 近60天覆盖 | `lx_fba_shipment_plan.py` → 主表、`lx_fba_shipment_plan_mws_relate` | 主表及关联明细覆盖 | 待迁移 |
| 36 | `lx_sales_listing_relation_tag` Listing标签 | `basicOpen/listingManage/queryListingRelationTagList`（POST） | `ods_datasync.lx_sales_listing_relation_tag` | 全量重采 | `lx_sales_listing_relation_tag.py` → 同名DWD | 最新全量并展开标签 | 待迁移 |
| 40 | `lx_purchase_purchase_plan` 采购计划 | `erp/sc/routing/data/local_inventory/getPurchasePlans`（POST） | `ods_datasync.lx_purchase_purchase_plan` | 近30天覆盖 | `lx_purchase_purchase_plan.py` → 同名DWD | 近30天覆盖 | 待迁移 |
| 55 | `lx_replenishment_restriction` 补货限制 | `basicOpen/openapi/replenishmentRestriction/page/list`（POST） | `ods_datasync.lx_replenishment_restriction` | 当月、店铺、5种仓储类型重采 | `lx_replenishment_restriction.py`（旧目录缺失）→ 知识库存在同名DWD | 需重建数组展开逻辑 | 旧脚本缺失 |

### 4.2 订单、财务与销售统计

| 序号 | 任务/接口 | API（HTTP） | ODS表 | Java采集策略 | 旧Python → DWD表 | DWD策略 | DW状态 |
|---:|---|---|---|---|---|---|---|
| 14 | `lx_finance_profit_report_order` 利润报表-订单 | `basicOpen/finance/profitReport/order/transcation/list`（POST） | `ods_datasync.lx_finance_profit_report_order` | 近45天逐日覆盖 | `lx_finance_profit_report_order.py` → 同名DWD | 日期窗口覆盖 | 待迁移 |
| 18 | `lx_finance_receivable_report` 应收报告 | `bd/sp/api/open/monthly/receivable/report/list`（POST） | `ods_datasync.lx_finance_receivable_report` | 近2月覆盖 | `lx_finance_receivable_report.py` → 同名DWD | 近2月覆盖 | 待迁移 |
| 19 | `lx_finance_fba_cost_stream` FBA成本流水 | `cost/center/api/cost/stream`（POST） | `ods_datasync.lx_finance_fba_cost_stream` | 近2月覆盖 | `lx_finance_fba_cost_stream.py` → 同名DWD | 近2月覆盖 | 待迁移 |
| 21 | `lx_sales_mws_orders` 订单列表 | `erp/sc/data/mws/orders`（POST） | `ods_datasync.lx_sales_mws_orders` | 近90天覆盖 | `lx_sales_mws_orders.py` → 同名DWD | 近90天覆盖 | 待迁移 |
| 22 | `lx_sales_mws_orders_detail` 订单详情 | `erp/sc/data/mws/orderDetail`（POST） | `ods_datasync.lx_sales_mws_orders_detail` | 近15天订单分批重采 | `lx_sales_mws_orders_detail.py` → 同名DWD | 近15天覆盖 | 待迁移 |
| 23 | `lx_sales_mws_orders_detail_polling` 订单详情轮询 | 同订单详情接口（POST） | 与22共用ODS表 | 按轮询日期集合回补 | `lx_sales_mws_orders_detail_polling.py` → 与22共用DWD表 | 历史日期回补 | 待迁移 |
| 24 | `lx_statistics_order_profit_msku` 订单利润-MSKU | `basicOpen/finance/mreport/OrderProfit`（POST） | `ods_datasync.lx_statistics_order_profit_msku` | 近90天逐日覆盖 | `lx_statistics_order_profit_msku.py` → 同名DWD | 近90天覆盖 | 待迁移 |
| 39 | `lx_platform_sales_statistics` 销量统计 | `basicOpen/platformStatisticsV2/saleStat/pageList`（POST） | `ods_datasync.lx_platform_sales_statistics` | 近60天逐日、3类指标重采 | `lx_platform_sales_statistics.py` → 同名DWD | 近60天覆盖 | 待迁移 |
| 53 | `lx_sale_adjust_price_queue` 调价队列 | `basicOpen/module/adjustPrice/AdjustPriceManual`（POST） | `ods_datasync.lx_sale_adjust_price_queue` | 近15天覆盖 | `lx_sale_adjust_price_queue/lx_sale_adjust_price_queue.py` → 同名DWD | 近15天覆盖并展开对象 | 待迁移 |
| 54 | `lx_reports_fulfillment_removal_order` 移除订单 | `erp/sc/routing/data/order/removalOrderListNew`（POST） | `ods_datasync.lx_reports_fulfillment_removal_order` | 近90天按店铺覆盖 | `lx_reports_fulfillment_removal_order.py`（旧目录缺失）→ 知识库存在同名DWD及历史拼写表 | 目标表名及逻辑待确认 | 旧脚本缺失/待核验 |

### 4.3 库存、仓储与FBA

| 序号 | 任务/接口 | API（HTTP） | ODS表 | Java采集策略 | 旧Python → DWD表 | DWD策略 | DW状态 |
|---:|---|---|---|---|---|---|---|
| 16 | `lx_storage_outbound_order` 出库单 | `erp/sc/routing/storage/outbound/getOrders`（POST） | `ods_datasync.lx_storage_outbound_order` | 昨日存在则跳过，否则追加 | `lx_storage_outbound_order.py` → 同名DWD | 业务键增量 | 待迁移 |
| 20 | `lx_storage_inventory_details` 仓库库存明细 | `erp/sc/routing/data/local_inventory/inventoryDetails`（POST） | `ods_datasync.lx_storage_inventory_details` | 已有当期数据则跳过 | `lx_storage_inventory_details.py` → 同名DWD | 业务键增量 | 待迁移 |
| 25 | `lx_statistics_storage_fee_month` 月仓储费 | `erp/sc/data/fba_report/storageFeeMonth`（POST） | `ods_datasync.lx_statistics_storage_fee_month` | 近2月按店铺重采 | `lx_statistics_storage_fee_month.py` → 同名DWD | 月份窗口覆盖 | 待迁移 |
| 26 | `lx_statistics_storage_fee_long_term` 长期仓储费 | `erp/sc/data/fba_report/storageFeeLongTerm`（POST） | `ods_datasync.lx_statistics_storage_fee_long_term` | 近2月按店铺重采 | `lx_statistics_storage_fee_long_term.py` → 同名DWD | 快照日期窗口覆盖 | 待迁移 |
| 27 | `lx_storage_inventory_log` 库存流水 | `erp/sc/routing/inventoryLog/WareHouseInventory/wareHouseCenterStatement`（POST） | `ods_datasync.lx_storage_inventory_log` | 昨日存在则跳过，否则追加 | `lx_storage_inventory_log.py` → 同名DWD | 业务键增量 | 待迁移 |
| 28 | `lx_storage_fba_warehouse_detail` FBA库存明细 | `basicOpen/openapi/storage/fbaWarehouseDetail`（POST） | `ods_datasync.lx_storage_fba_warehouse_detail` | 当期快照采集 | `lx_storage_fba_warehouse_detail.py` → 同名DWD | 每日历史分区 | 已落地 |
| 29 | `lx_storage_inbound_order` 入库单 | `erp/sc/routing/storage/inbound/getOrders`（POST） | `ods_datasync.lx_storage_inbound_order` | 昨日存在则跳过，否则追加 | `lx_storage_inbound_order.py` → 同名DWD | 当日覆盖并展开明细 | 待迁移 |
| 31 | `lx_statistics_fba_new_aggregate` FBA库存汇总 | `cost/center/openApi/fba/gather/query`（POST） | `ods_datasync.lx_statistics_fba_new_aggregate` | 近2月按店铺覆盖 | `lx_statistics_fba_new_aggregate.py` → 同名DWD | 近2月覆盖 | 待迁移 |
| 32 | `lx_statistics_local_new_aggregate` 本地仓汇总 | `inventory/center/openapi/storageReport/local/aggregate/list`（POST） | `ods_datasync.lx_statistics_local_new_aggregate` | 近2月逐月覆盖 | `lx_statistics_local_new_aggregate.py` → 同名DWD | 近2月覆盖 | 待迁移 |
| 33 | `lx_statistics_local_new_detail` 本地仓明细 | `inventory/center/openapi/storageReport/local/detail/page`（POST） | `ods_datasync.lx_statistics_local_new_detail` | 近2月逐月覆盖 | `lx_statistics_local_new_detail.py` → 主表、`_ZiXiang` | 近2月覆盖并拆子项 | 待迁移 |
| 34 | `lx_statistics_fba_new_detail` FBA新版明细 | `cost/center/openApi/fba/detail/query`（POST） | `ods_datasync.lx_statistics_fba_new_detail` | 近2月按店铺覆盖 | `lx_statistics_fba_new_detail.py` → 主表、`_child_data` | 近2月覆盖并拆子项 | 待迁移 |
| 35 | `lx_storage_check_order_detail` 盘点单详情 | `erp/sc/routing/inventoryReceipt/InventoryCheck/getOrderDetail`（POST） | `ods_datasync.lx_storage_check_order_detail` | 近30天覆盖 | `lx_storage_check_order_detail.py` → 同名DWD | 近30天覆盖并展开商品 | 待迁移 |
| 37 | `lx_storage_qc_order` 质检单 | `erp/sc/routing/deliveryReceipt/ReceiptOrderQc/getOrderList`（POST） | `ods_datasync.lx_storage_qc_order` | 近30天覆盖 | `lx_storage_qc_order.py` → 同名DWD | 近30天覆盖 | 待迁移 |
| 38 | `lx_storage_receipt_order` 收货单 | `erp/sc/routing/deliveryReceipt/PurchaseReceiptOrder/getOrderList`（POST） | `ods_datasync.lx_storage_receipt_order` | 近30天覆盖 | `lx_storage_receipt_order.py` → 同名DWD | 近30天覆盖 | 待迁移 |
| 48 | `lx_storage_order_lists` 加工单 | `erp/sc/routing/inventoryReceipt/StorageProcess/getOrderLists`（POST） | `ods_datasync.lx_storage_order_lists` | 全量分类型采集 | `lx_storage_order_lists.py`（旧目录缺失）→ 知识库存在主表及`lx_storage_order_list_items` | 需重建主子表拆分 | 旧脚本缺失 |

### 4.4 广告

| 序号 | 任务/接口 | API（HTTP） | ODS表 | Java采集策略 | 旧Python → DWD表 | DWD策略 | DW状态 |
|---:|---|---|---|---|---|---|---|
| 42 | `lx_advertising_sp_campaign_data` SP广告活动 | `pb/openapi/newad/spCampaigns`、`spCampaignReports`（POST） | `lx_advertising_sp_campaigns`、`lx_advertising_sp_campaign_reports` | 活动全量，报表近15天 | `lx_advertising_sp_campaign_data.py` → `dwd_datasync.lx_advertising_sp_campaign_reports` | 报表近15天覆盖；活动主数据未入DWD | 待迁移/待核验 |
| 43 | `lx_advertising_sp_ad_groups_data` SP广告组 | `spAdGroups`、`spAdGroupReports`（POST） | 广告组、广告组报表两表 | 主数据全量，报表近15天 | `lx_advertising_sp_ad_groups_data.py` → 广告组报表DWD | 报表窗口覆盖；主数据未入DWD | 待迁移/待核验 |
| 44 | `lx_advertising_sp_product_ads_data` SP商品广告 | `spProductAds`、`spProductAdReports`（POST） | 商品广告、商品广告报表两表 | 主数据全量，报表近15天 | `lx_advertising_sp_product_ads_data.py` → 商品广告报表DWD | 报表窗口覆盖；主数据未入DWD | 待迁移/待核验 |
| 45 | `lx_advertising_sp_keywords_data` SP关键词 | `spKeywords`、`spKeywordReports`（POST） | 关键词、关键词报表两表 | 主数据全量，报表近15天 | `lx_advertising_sp_keywords_data.py` → 关键词报表DWD | 报表窗口覆盖；主数据未入DWD | 待迁移/待核验 |
| 46 | `lx_advertising_sp_query_word_reports` 搜索词报表 | `pb/openapi/newad/queryWordReports`（POST） | `ods_datasync.lx_advertising_sp_query_word_reports` | 近15天、店铺、两类型 | 同名Python → 同名DWD | 近15天覆盖 | 待迁移 |
| 47 | `lx_advertising_api_log_standard` 广告操作日志 | `pb/openapi/newad/apiLogStandard`（POST） | `ods_datasync.lx_advertising_api_log_standard` | 近7天、店铺、操作类型 | 同名Python → 同名DWD | 近7天覆盖并展开日志 | 待迁移 |

### 4.5 客服与店铺绩效

| 序号 | 任务/接口 | API（HTTP） | ODS表 | Java采集策略 | 旧Python → DWD表 | DWD策略 | DW状态 |
|---:|---|---|---|---|---|---|---|
| 49 | `lx_service_store_target` 店铺绩效 | `basicOpen/customerService/storeTarget/list`（POST） | `ods_datasync.lx_service_store_target` | 近30天逐日重采 | `lx_service_store_target.py` → 同名DWD | 旧脚本按近60天覆盖 | 待迁移/窗口待统一 |
| 50 | `lx_service_store_target_detail` 店铺绩效详情 | `basicOpen/customerService/storeTarget/detail`（POST） | `ods_datasync.lx_service_store_target_detail` | 按日期和店铺重采 | `lx_service_store_target_detail.py` → 同名DWD | 近60天覆盖并展开详情 | 待迁移 |
| 51 | `lx_service_feedback_list` 1-3星Feedback | `erp/sc/cs/feedback/listMws`（POST） | `ods_datasync.lx_service_feedback_list` | 近60天按店铺覆盖 | `lx_service_feedback_list.py` → 同名DWD | 近60天覆盖并展开商品 | 待迁移 |
| 52 | `lx_service_review_list` Review | `basicOpen/openapi/service/v3/data/mws/reviews`（POST） | `ods_datasync.lx_service_review_list` | 近60天覆盖 | `lx_service_review_list.py` → 同名DWD | 近60天覆盖并展开多值 | 待迁移 |

## 5. Java实际请求参数明细

### 5.1 公共请求规则

- 除店铺列表、概念店铺列表为GET外，本台账其余业务接口均为POST。
- POST业务参数及分页参数在旧Java中同时参与签名Query，并再次作为JSON Body发送。
- 公共Query参数：`timestamp`、`app_key`、`access_token`、`sign`。
- 常规`offset`分页从0开始，按`length`递增，直到响应目标列表为空；个别接口使用`page`或以1开始的页码型`offset`。
- 以下为代码实际发送值；“代码发送”不等于领星官方文档认定必填，正式迁移仍需用真实接口验证。

### 5.2 基础、商品、采购、财务参数

| 任务 | 实际业务参数及来源 | 分页 | 响应列表路径 |
|---|---|---|---|
| `lx_basic_seller` | 无业务参数 | 不分页 | `data` |
| `lx_basic_concept_seller` | 无业务参数 | 不分页 | `data` |
| `lx_purchase_supplier` | 无业务参数 | `offset=0`，`length=10000`，按10000递增 | `data` |
| `lx_sales_mws_listing` | `sid`=店铺SID，每200个一批；`is_delete=0` | `offset=0`，`length=1000` | `data` |
| `lx_statistics_product_performance` | `sort_field=volume`；`sort_type=desc`；`summary_field=asin`；`sid`=店铺SID每200个；`start_date/end_date`=近15天逐日同一天；`currency_code=CNY` | `offset=0`，`length=10000` | `data.list` |
| `lx_finance_profit_report_msku` | `currencyCode=CNY`；`monthlyQuery=true`；`startDate/endDate`=近2月逐月同月`YYYY-MM`；`summaryEnabled=true`；`orderStatus=All` | `offset=0`，`length=1000` | `data.records` |
| `lx_product_local_product_info` | 阶段1产品列表无业务参数；阶段2 `productIds`=阶段1 ID，每100个一批 | 阶段1：`offset=0,length=1000`；阶段2不分页 | 阶段1 `data[].id`；阶段2 `data` |
| `lx_fba_shipment` | `sid`=逐店铺；`start_date`=今日-90天；`end_date`=昨日 | `offset=0`，`length=1000` | `data.list` |
| `lx_inbound_shipment_detail` | 阶段1：`time_type=2`，`start_date`=今日-90天，`end_date`=昨日；阶段2：`shipment_sn_arr`=单号每50个一批 | 阶段1：`offset=0,length=10000`；阶段2不分页 | 阶段1 `data.list[].shipment_sn`；阶段2 `data` |
| `lx_purchase_purchase_order` | `start_date`=今日-30天；`end_date`=昨日 | `offset=0`，`length=500` | `data` |
| `lx_statistics_profit_statistics_msku` | `startDate/endDate`=近60天逐日同一天；`currencyCode=CNY` | `offset=0`，`length=10000` | `data.records` |
| `lx_statistics_profit_statistics_asin` | `startDate/endDate`=近60天逐日同一天；`currencyCode=CNY` | `offset=0`，`length=10000` | `data.records` |
| `lx_replenishment_suggest_restocking` | `data_type=2`（MSKU维度） | `offset=0`，`length=50` | `data` |
| `lx_finance_profit_report_order` | `startDate/endDate`=近45天逐日同一天；`orderStatus=All`；`fulfillment=null`因此不发送 | `offset=0`，`length=1000` | `data.records` |
| `lx_basic_currency` | `date`=近2月逐月`YYYY-MM` | 不分页 | `data` |
| `lx_storage_warehouse` | `type`依次1/3/4/6；`sub_type`：type=3时取1/2，其余取1；`is_delete="0,1"` | `offset=0`，`length=1000` | `data` |
| `lx_finance_receivable_report` | `settleMonth`=近2月逐月`YYYY-MM` | `offset=0`，`length=20` | `data` |
| `lx_finance_fba_cost_stream` | `start_date/end_date`=近2月各月首末日；`query_type=01`；`business_types=[10,11,12,13,14,20,35,25,30,31,200,201,202,205,220,15,215,225,226,227,5,210,400,420]` | `offset=0`，`length=10000` | `data.records` |

### 5.3 订单、仓储、库存参数

| 任务 | 实际业务参数及来源 | 分页 | 响应列表路径 |
|---|---|---|---|
| `lx_storage_outbound_order` | `start_date/end_date`=昨日 | `offset=0`，`length=200` | `data` |
| `lx_storage_inventory_details` | 无业务参数 | `offset=0`，`length=800` | `data` |
| `lx_sales_mws_orders` | `start_date`=今日-90天；`end_date`=今日 | `offset=0`，`length=5000` | `data` |
| `lx_sales_mws_orders_detail` | `order_id`=近15天订单号，每150个用英文逗号拼接 | 不分页 | `data` |
| `lx_sales_mws_orders_detail_polling` | `order_id`=轮询轮次对应日期的订单号，每150个逗号拼接 | 不分页 | `data` |
| `lx_statistics_order_profit_msku` | `startDate/endDate`=近90天逐日同一天；`currencyCode=CNY` | `offset=0`，`length=5000` | `data` |
| `lx_statistics_storage_fee_month` | `sid`=逐店铺；`month`=近2月逐月`YYYY-MM` | `offset=0`，`length=5000` | `data` |
| `lx_statistics_storage_fee_long_term` | `sid`=逐店铺；`start_date/end_date`=近2月各月首末日 | `offset=0`，`length=5000` | `data` |
| `lx_storage_inventory_log` | `start_date/end_date`=昨日 | `offset=0`，`length=10000` | `data` |
| `lx_storage_fba_warehouse_detail` | `query_fba_storage_quantity_list=true`；`fulfillment_channel_type=FBA` | `offset=0`，`length=200` | `data` |
| `lx_storage_inbound_order` | `search_field_time=create_time`；`start_date/end_date`=昨日 | `offset=0`，`length=200` | `data` |
| `lx_fba_shipment_plan` | `search_field_time=gmt_create`；`start_date`=今日-60天；`end_date`=昨日 | `offset=0`，`length=1000` | `data` |
| `lx_statistics_fba_new_aggregate` | `seller_id`=店铺seller_id每100个；`start_date/end_date`=近2月逐月同月`YYYY-MM` | `offset=0`，`length=1000` | `data.row_data` |
| `lx_statistics_local_new_aggregate` | `start_date/end_date`=近2月各月首末日 | 不分页 | `data` |
| `lx_statistics_local_new_detail` | `start_date/end_date`=近2月各月首末日 | `offset=1`，`length=100`，`offset++`（页码型） | `data` |
| `lx_statistics_fba_new_detail` | `seller_id`=店铺seller_id每100个；`start_date/end_date`=近2月逐月同月`YYYY-MM` | `offset=0`，`length=1000` | `data.row_data` |
| `lx_storage_check_order_detail` | 阶段1：`start_date`=今日-30天，`end_date`=昨日；阶段2：`order_sn`=阶段1单号 | 阶段1：`page=1,page_size=100`；阶段2：`page=1,page_size=200` | 阶段1 `data[].order_sn`；阶段2 `data.product_list` |
| `lx_sales_listing_relation_tag` | `bind_detail`=当日Listing的`sid+seller_sku(relation_id)`，每40条一批 | 不分页 | `data` |
| `lx_storage_qc_order` | `date_type=3`；`start_date`=今日-30天；`end_date`=昨日 | `offset=0`，`length=500` | `data.list` |
| `lx_storage_receipt_order` | `date_type=3`；`start_date`=今日-30天；`end_date`=昨日 | `offset=0`，`length=500` | `data.list` |
| `lx_platform_sales_statistics` | `result_type`依次1/2/3；`date_unit=4`；`data_type=1`；`start_date/end_date`=近60天逐日同一天 | `page=1`，`length=1000`，`page++` | `data` |
| `lx_purchase_purchase_plan` | `search_field_time="creator_time "`（源码末尾有空格，迁移时重点核验）；`start_date`=今日-30天；`end_date`=昨日 | `offset=0`，`length=500` | `data` |
| `lx_statistics_product_performance_polling` | 与产品表现相同固定参数；日期来自当前轮询轮次，逐日；SID每200个 | `offset=0`，`length=10000` | `data.list` |
| `lx_storage_order_lists` | `type`依次1/2 | `offset=0`，`length=1000` | `data` |
| `lx_reports_fulfillment_removal_order` | `sid`=逐店铺；`start_date`=今日-90天；`end_date`=昨日；`search_field_time=request_date` | `offset=0`，`length=1000` | `data` |
| `lx_replenishment_restriction` | `storage_type`依次`Standard/Oversize/Apparel/Footwear/ExtraLarge`；`sids`=逐店铺SID转字符串 | `offset=0`，`length=200`；`offset>=data.total`结束 | `data.list` |

### 5.4 广告参数

| 任务 | 实际业务参数及来源 | 分页 | 响应列表路径 |
|---|---|---|---|
| `lx_advertising_sp_campaign_data` | 主数据：`sid`=逐店铺；报表：`show_detail=1`、`sid`=逐店铺、`report_date`=近15天逐日 | 两接口均`offset=0,length=1000` | 均为`data` |
| `lx_advertising_sp_ad_groups_data` | 主数据：`sid`；报表：`show_detail=1`、`sid`、`report_date`=近15天逐日 | 两接口均`offset=0,length=1000` | 均为`data` |
| `lx_advertising_sp_product_ads_data` | 主数据：`sid`；报表：`show_detail=1`、`sid`、`report_date`=近15天逐日 | 两接口均`offset=0,length=1000` | 均为`data` |
| `lx_advertising_sp_keywords_data` | 主数据：`sid`；报表：`show_detail=1`、`sid`、`report_date`=近15天逐日 | 两接口均`offset=0,length=1000` | 均为`data` |
| `lx_advertising_sp_query_word_reports` | `show_detail=1`；`sid`=逐店铺；`report_date`=近15天逐日；`target_type`依次`keyword/target` | `offset=0`，`length=1000` | `data` |
| `lx_advertising_api_log_standard` | `log_source=all`；`sponsored_type=sp`；`operate_type`依次`campaigns/adGroups/productAds/keywords/negativeKeywords/targets/negativeTargets/profiles`；`sid`=逐店铺；`start_date`=今日-7天；`end_date`=昨日 | `offset=0`，`length=1000` | `data` |

### 5.5 客服、绩效与调价参数

| 任务 | 实际业务参数及来源 | 分页 | 响应列表路径 |
|---|---|---|---|
| `lx_service_store_target` | `search_field_time=pull_date`；`search_time`=近30天逐日；`sids/anomaly_indicator=null`因此不发送 | `offset=0`，`length=200` | `data` |
| `lx_service_store_target_detail` | `pullDate`=近30天逐日；`sid`=绩效列表按`pull_date`查得SID | 不分页 | `data` |
| `lx_service_feedback_list` | `sid`=逐店铺；`start_date/end_date`=近60天日期列表首尾 | `offset=0`，`length=200` | `data` |
| `lx_service_review_list` | `start_date/end_date`=近60天日期列表首尾；`date_field=review_time` | `offset=0`，`length=200` | `data` |
| `lx_sale_adjust_price_queue` | `time_type=1`；`start_time`=今日-15天`00:00:00`；`end_time`=昨日`23:59:59` | `offset=0`，`length=500` | `data.list` |

### 5.6 迁移时需要重点复核的参数问题

1. `lx_storage_inventory_log`把`start_date`和`end_date`都设为昨日，但源码注释称结束日期为开区间，存在空区间风险。
2. `lx_statistics_storage_fee_long_term`源码注释称`end_date`为开区间，实际却传当月最后一天。
3. `lx_purchase_purchase_plan.search_field_time`实际字符串为`"creator_time "`，末尾有空格。
4. `lx_statistics_local_new_detail.offset`从1开始并每次加1，实际语义是页码，不是记录偏移量。
5. `lx_sales_mws_orders_detail`注释说接口每批最多200个，代码实际按150个订单号请求。
6. Java公共分页没有最大页数和重复页保护；迁移后的`lx_sync_engine.fetch_all`必须保留重复数据检测。

## 6. 共享目标表的特殊任务

以下任务不能简单建成两个互相覆盖的普通节点：

| 主节点 | 回补节点 | 共用目标 | 迁移要求 |
|---|---|---|---|
| `lx_statistics_product_performance` | `lx_statistics_product_performance_polling` | 同一产品表现ODS、DWD | 日常任务和历史回补任务分开；都按目标日期幂等覆盖，禁止全表覆盖 |
| `lx_sales_mws_orders_detail` | `lx_sales_mws_orders_detail_polling` | 同一订单详情ODS、DWD | 日常近15天与历史轮询分开；用业务日期或订单日期定向覆盖 |

## 6. Java转Python的改造范围

### 6.1 可复用公共引擎

现有公共引擎：

- `阿里云项目目录/领星同步到OSS/01_公共资源/lx_sync_engine.py`
- 已具备Token、签名、HTTP请求、分页、OSS上传等基础能力。

每个Java任务转成Python时，应只保留接口特有配置：

- `API_PATH`
- HTTP方法
- 请求参数
- 日期窗口
- 店铺/SID批次
- 分页开关和页大小
- 响应数据路径
- OSS目录及文件格式
- 空结果保护

### 6.2 必须保持的领星兼容规则

1. GET分页参数`offset/length`同时放入query string和body。
2. 店铺列表等不支持分页的接口必须关闭分页。
3. `fetch_all`保留重复页检测，防止接口忽略分页时死循环。
4. API返回`code`可能是字符串`"200"`，统一转字符串后判断。
5. SID依赖从同一`biz_date`的店铺OSS产物读取，并设置DataWorks上游依赖。
6. 任一分页或SID批次失败，不得上传残缺文件。
7. 全量接口返回0条时主动失败，不能覆盖有效下游数据。

### 6.3 旧Python不能直接搬到DataWorks

旧脚本普遍需要调整：

- 删除MySQL明文连接和SQLAlchemy建表逻辑。
- 禁止`DROP TABLE`后重建目标表。
- ODS原始数据改为OSS，不再先落MySQL ODS。
- DWD转换优先改写成MaxCompute SQL节点。
- MySQL `DELETE + INSERT`改成MaxCompute分区`INSERT OVERWRITE`或整表覆盖。
- pandas展开JSON数组改成MaxCompute `LATERAL VIEW`、`EXPLODE/POSEXPLODE`、`FROM_JSON`。
- Snowflake ID改为稳定、可重跑的MaxCompute表达式或明确的新ID规则。
- 脚本中的“当前时间/当前日期”改用DataWorks参数`${biz_date}`。
- 空字符串统一用`NULLIF(TRIM(...), '')`处理。

## 7. 建议的DataWorks节点结构

每个接口原则上拆成两个生产节点：

```text
lx_<业务接口>                  PyODPS 3：领星API → OSS
  └─ dwd_lx_<业务接口>         ODPS SQL：EXT注册分区 → DWD清洗
```

复杂嵌套接口仍建议保持一个采集节点，但DWD可拆多个SQL节点或在同一SQL节点写多张表：

- 本地产品详情：1个采集节点 → 4张DWD表。
- FBA发货单详情：1个采集节点 → 7张DWD表。
- FBA发货计划：1个采集节点 → 2张DWD表。
- FBA/本地仓新版明细：各1个采集节点 → 主表+子表。
- 加工单：1个采集节点 → 主表+商品明细表。

## 8. 分批迁移建议

### 第一批：基础依赖与已落地链路

1. `lx_basic_seller`（已落地）
2. `lx_sales_mws_listing`（已落地）
3. `lx_storage_fba_warehouse_detail`（已落地）
4. `lx_basic_concept_seller`
5. `lx_storage_warehouse`
6. `lx_purchase_supplier`
7. `lx_basic_currency`

目标：先建立店铺、仓库、供应商、汇率等公共维度。

### 第二批：核心订单、产品、库存

- 本地产品详情
- 产品表现及轮询
- 订单列表、订单详情及轮询
- FBA货件、发货计划、发货单详情
- 仓库库存、本地仓/FBA新版汇总和明细

### 第三批：财务、利润、采购、补货

- 利润报表/利润统计/订单利润
- 应收报告/FBA成本流水
- 采购单/采购计划
- 补货建议/补货限制
- 仓储费

### 第四批：广告、客服及低频仓储单据

- SP广告六类任务
- 店铺绩效、Feedback、Review
- 入库、出库、收货、质检、盘点、加工单
- 调价队列、移除订单
