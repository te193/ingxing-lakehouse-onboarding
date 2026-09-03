# 内置参考代码索引

这些文件是项目中已有接口的代码快照，用于当前工作区没有合适本地样例时提供工程结构参考。它们不是新的公共引擎，也不能替代当前项目规范、领星官方接口文档或相同接口的最新成功代码。

## 场景选择

| 场景目录 | 原始接口案例 | 适用结构 | 重点参考 |
|---|---|---|---|
| `simple-shared-json/` | 补货列表 `lx_replenishment_suggest_restocking` | 公共 `sync_task`、POST body、原始 JSON | 最简接口节点、task 配置、EXT/DWD 基本链路 |
| `manual-post-json/` | 调价队列 `lx_sale_adjust_price_queue` | 手动 `fetch_all`、日期窗口、POST `req_body` | 参数位置、时间窗口、JSON 信封与调价明细清洗 |
| `sid-batch-parent-child/` | FBA 货件 `lx_fba_shipment` | 从 OSS 读取 SID、逐店铺采集、父子数组展开 | 上游依赖、批次完整性、父子表 DDL/ETL 和对账 |

每个目录至少包含 PyODPS 采集代码、EXT DDL、DWD DDL 和 DWD ETL；项目中已有的对账 SQL 也一并保留。

## 使用顺序

1. 优先使用当前工作区中相同接口的最新成功代码。
2. 没有相同接口代码时，先确认当前接口契约和响应结构，再从本索引选择一个结构最接近的目录。
3. 只复用公共工程骨架，例如资源引用、`biz_date`、调用方式、表骨架、SerDe、分区、质量检查和发布顺序。
4. API Path、请求字段、分页规则、返回字段、业务键、表粒度和覆盖策略必须来自当前接口证据，不能从示例照搬。
5. 当前工作区规范与内置案例不一致时，以当前规范和已确认的在线公共引擎契约为准。

## 公共资源边界

示例只调用 DataWorks 在线维护的 `project_config.py` 和 `lx_sync_engine.py`，仓库不包含这两个公共资源。不要因为示例是快照就在接口目录重新实现 Token、签名、HTTP、PyArrow、OSS 客户端、暂存或发布逻辑。

## 维护

仅在案例完成实际运行验证并且不含凭据后更新快照。更新时同时检查 Python、EXT、DWD DDL、DWD ETL 和对账 SQL 是否仍属于同一版接口实现。
