# 领星 → OSS → MaxCompute：DataWorks 配置操作手册

> 更新时间：2026-09-01  
> 用途：新人培训，快速完成一条领星 OpenAPI 数据进入 MaxCompute 的离线链路。  
> 链路：`领星 OpenAPI → DataWorks PyODPS 3 → OSS JSON → MaxCompute EXT → MaxCompute DWD`
>
> **重要提示：数据拉取完成后必须进行数据核验，确保领星接口返回记录数、OSS信封记录数、EXT展开行数和DWD有效记录数符合既定清洗口径。**

---

## 1. 开始前确认

开发前先确认以下内容，不允许自行推测：

- 领星接口名称、接口路径和请求方式；
- 接口请求参数、分页方式及店铺等上游参数来源；
- 同步方式：全量或增量；
- 接口业务日期字段和请求时间范围；
- OSS数据集名称及文件格式；
- DWD是否保留每日历史；
- 调度时间和上游依赖。

> OSS数据源、MaxCompute Schema和OSS基础目录均已完成初始化，新任务直接复用现有配置。领星接口凭据和OSS访问凭据必须按项目凭据规范管理，禁止写入节点代码、普通调度参数、Git或文档。

---

## 2. 第一步：创建“领星到OSS”PyODPS节点

进入：

```text
数据开发 → 新建节点 → MaxCompute → PyODPS 3
```

### 2.1 准备运行环境和公共资源

1. 节点使用Python 3.11自定义镜像，推荐基础镜像`dataworks_pyodps_py311_task_pod`；
2. 镜像按脚本实际需要安装`requests`、`oss2`和`pycryptodome`等依赖；写Parquet时再安装`pyarrow`；
3. 将`project_config.py`和`lx_sync_engine.py`上传为DataWorks Python资源；
4. 在接口节点顶部声明资源：

```python
##@resource_reference{"project_config.py"}
##@resource_reference{"lx_sync_engine.py"}
```

5. 每个接口建立与dataset同名的独立文件夹，例如`lx_basic_seller/`；接口节点文件命名为`lx_basic_seller/lx_basic_seller.py`，不要额外添加`sync`、`df`或`di`；该接口的EXT和DWD SQL也统一放在此文件夹。

### 2.2 配置领星接口任务

接口节点需要明确配置：

- `name`：数据集名称；
- `api_path`：领星接口路径；
- `method`：`GET`或`POST`；
- `oss_prefix`：`guqiao_ods/{dataset}`；
- `pagination`：接口是否支持分页；
- `req_params_tpl`和请求体模板：按接口文档及实际验证结果配置。

示例：

```python
task = {
    "name": "{dataset}",
    "api_path": "/已确认的领星接口路径",
    "method": "GET",
    "oss_prefix": "guqiao_ods/{dataset}",
    "pagination": False,
    "req_params_tpl": {},
}
```

> 注意：不同领星接口的分页、日期参数和同步策略可能不同，必须逐接口确认。GET分页接口的`offset`和`length`按已验证的签名规则同时放入query string与body；不支持分页的接口不得强行循环分页，并需保留重复数据检测以避免无限循环。

### 2.3 `biz_date`参数及作用

在领星到OSS节点的调度参数中新增：

```text
参数名：biz_date
参数值：$[yyyy-mm-dd-1]
预览格式：YYYY-MM-DD
```

`biz_date`表示**DataWorks实例定时时间对应的前一天业务日期**。当前任务在次日凌晨处理前一天的数据，因此使用`$[yyyy-mm-dd-1]`，并通过该参数统一整条链路的数据归属日：

```text
PyODPS args['biz_date']
= OSS目录 dt
= JSON信封中的 biz_date
= EXT分区 dt
= DWD SQL中的 ${biz_date}
```

例如实例在`2026-09-01`执行时：

```text
biz_date = 2026-08-31
OSS目录 = guqiao_ods/{dataset}/dt=2026-08-31/
```

接口节点优先从DataWorks全局`args`读取参数，并兼容调度环境变量：

```python
import os
from datetime import datetime

node_args = globals().get("args") or {}
biz_date = str(
    node_args.get("biz_date")
    or node_args.get("bizdate")
    or os.getenv("SKYNET_BIZDATE")
    or ""
).strip()
if not biz_date:
    biz_date = datetime.now().strftime("%Y-%m-%d")
    print(f"未收到biz_date，普通运行自动使用当天日期: {biz_date}")
```

要求：

- 正式参数名统一使用`biz_date`；
- 参数值统一使用`$[yyyy-mm-dd-1]`；
- `bizdate`只作为存量代码兼容名，`SKYNET_BIZDATE`作为调度环境兜底；不得使用`SKYNET_GMTDATE`替代补数据业务日期；
- 普通开发台直接运行可能不注入调度参数，此时才使用当天日期；正式调度、补数据和冒烟测试必须确认业务日期替换结果；
- `biz_date`是前一天的业务日期，也是OSS目录和MaxCompute分区的日期，不是节点实际运行日期；
- Python代码不得再对`biz_date`执行加一天或减一天；
- 上下游节点必须预览确认参数值为相同的`YYYY-MM-DD`。

### 2.4 写入OSS

只有已确认属于少量数据的领星接口使用紧凑的单行JSON信封，写入：

```text
guqiao_ods/{dataset}/dt=${biz_date}/data.json
```

JSON信封通常包含：

```text
source、dataset、biz_date、record_count、sync_time、data
```

其中`data`保存接口记录数组。JSON必须使用UTF-8紧凑格式，不设置`indent`，确保MaxCompute JSON外部表可以读取。

除已确认少量数据外，其他接口统一使用Parquet+Snappy列式存储，并按明确的PyArrow Schema写入。数据量未确认时不得擅自选择JSON；NDJSON仅在另行设计并确认后使用，不作为默认方案。

同一`biz_date`重跑时，应先清理该日期目录下的旧对象，再写入新文件，保证结果幂等。

### 2.5 试运行并检查OSS

运行节点后确认：

- 领星接口调用成功且返回码正常；
- 对应`biz_date`的`dt=YYYY-MM-DD`目录已生成；
- 已确认少量数据的方案存在`data.json`，且文件为有效单行JSON；其他方案存在符合Schema的Parquet分片；
- 信封中的`dataset`和`biz_date`与节点配置一致；
- `record_count`与`data`数组长度一致；
- 文件大小和记录数合理；
- 同一`biz_date`重跑不会产生重复或残留旧文件。

---

## 3. 第二步：创建MaxCompute EXT外部表

EXT外部表只保存表结构和OSS路径映射，不复制OSS数据。

在DataWorks中新建一次性`ODPS SQL`节点，执行EXT DDL：

```sql
SET odps.namespace.schema = true;
SET odps.sql.type.system.odps2 = true;

CREATE EXTERNAL TABLE IF NOT EXISTS ext.{dataset}_raw
(
    source       STRING COMMENT '数据来源',
    dataset      STRING COMMENT '数据集名称',
    biz_date     STRING COMMENT '采集日期',
    record_count BIGINT COMMENT '记录数',
    sync_time    STRING COMMENT '同步时间',
    data         ARRAY<STRUCT<
                     id:BIGINT,
                     field_name:STRING
                 >> COMMENT '领星接口记录数组'
)
PARTITIONED BY
(
    dt STRING COMMENT '采集日期，格式YYYY-MM-DD'
)
ROW FORMAT SERDE 'org.apache.hive.hcatalog.data.JsonSerDe'
STORED AS TEXTFILE
LOCATION 'oss://oss-cn-shenzhen-internal.aliyuncs.com/gq-lakehouse/guqiao_ods/{dataset}/'
TBLPROPERTIES
(
    'odps.external.data.enable.extension' = 'true'
);
```

要求：

- EXT信封字段及`data`内层结构必须与OSS `data.json`一致；
- `data`内层字段应按领星接口实际返回结构完整定义，示例字段不可直接用于生产；
- 单行JSON信封统一使用`JsonSerDe + TEXTFILE`；
- 若某接口已单独确认采用Parquet或NDJSON，EXT存储格式必须同步按该接口方案调整；
- 本地文件命名为`{dataset}/ext_{dataset}_ddl.sql`；
- MaxCompute表命名为`ext.{dataset}_raw`；
- EXT DDL仅在首次创建或结构变化时手工执行，不配置每日调度。

---

## 4. 第三步：创建MaxCompute DWD表

新建一次性`ODPS SQL`节点，执行DWD DDL。

表结构要求：

- 若数据库DWD已有同名业务表，MC DWD必须以该同名表作为唯一结构基准；
- 字段名称、顺序、中文注释和可等价类型保持一致；
- 按领星接口用途确认保存最新全量还是每日历史，不能因为每天运行就默认按`dt`分区；
- 最新全量表使用非分区表，历史快照表才按已确认方案设置`dt`分区；
- 本地文件命名为`{dataset}/dwd_{dataset}_ddl.sql`；
- MaxCompute表命名为`dwd.{dataset}`。

---

## 5. 第四步：创建“OSS到MC”清洗节点

新建`ODPS SQL`节点，节点名使用；本地清洗SQL保存为`{dataset}/dwd_{dataset}_etl.sql`：

```text
dwd_{dataset}
```

核心处理：

```sql
SET odps.namespace.schema = true;
SET odps.sql.type.system.odps2 = true;

-- 注册biz_date对应的OSS目录。
ALTER TABLE ext.{dataset}_raw
ADD IF NOT EXISTS PARTITION (dt = '${biz_date}')
LOCATION 'oss://oss-cn-shenzhen-internal.aliyuncs.com/gq-lakehouse/guqiao_ods/{dataset}/dt=${biz_date}/';

-- 先检查领星JSON信封和数据数组是否有效，再写入DWD。
SELECT
    CASE
        WHEN COUNT(*) = 0 OR COALESCE(SUM(SIZE(data)), 0) = 0
        THEN CAST('EMPTY_OSS_SOURCE' AS BIGINT)
        ELSE SUM(SIZE(data))
    END AS source_count
FROM ext.{dataset}_raw
WHERE dt = '${biz_date}'
  AND dataset = '{dataset}'
  AND biz_date = '${biz_date}';

WITH source_data AS
(
    SELECT
        raw.sync_time,
        pos,
        item
    FROM ext.{dataset}_raw raw
    LATERAL VIEW POSEXPLODE(raw.data) exploded AS pos, item
    WHERE raw.dt = '${biz_date}'
      AND raw.dataset = '{dataset}'
      AND raw.biz_date = '${biz_date}'
)
INSERT OVERWRITE TABLE dwd.{dataset} PARTITION (dt = '${biz_date}')
SELECT
    -- 按DWD字段顺序从item中逐字段填写，禁止直接使用SELECT *。
    item.id,
    item.field_name
FROM source_data;
```

要求：

- 节点参数同样配置`biz_date=$[yyyy-mm-dd-1]`；
- Python读取值、OSS目录`dt`、JSON信封`biz_date`、EXT分区`dt`和SQL中的`${biz_date}`必须一致；
- 使用`POSEXPLODE(data)`展开领星JSON信封中的记录数组；
- 正式覆盖前增加空源保护，防止0条接口记录覆盖DWD；
- 使用明确字段白名单，避免领星接口新增字段造成结构错位；
- 示例为历史分区表写法；如果业务确认只保留最新全量，应改为非分区表`INSERT OVERWRITE TABLE dwd.{dataset}`；
- DWD只做类型转换、空值处理和基础清洗，不写报表指标逻辑。

---

## 6. 发布与验收

推荐顺序：

```text
1. 执行EXT DDL
2. 执行DWD DDL
3. 发布领星到OSS的PyODPS节点
4. 发布OSS到DWD的ODPS SQL节点
5. 创建新测试实例
6. 核对领星接口、OSS、EXT和DWD数据
```

验收清单：

```text
□ 领星接口调用成功，接口返回记录数合理
□ OSS中biz_date对应的dt目录和data.json存在
□ data.json为有效的UTF-8单行JSON
□ JSON信封dataset和biz_date正确
□ JSON信封record_count与data数组长度一致
□ EXT可以读取当天分区并展开data数组
□ EXT展开行数与领星有效接口记录数一致
□ DWD行数与EXT清洗后有效行数一致
□ 关键字段无异常空值
□ 主键或业务唯一键无异常重复
□ 字段类型、顺序和中文注释正确
□ 同一biz_date重跑结果幂等
□ PyODPS与DWD节点使用相同的biz_date
□ 正式代码和文档中没有账号密码或AK/SK
```

---

## 7. 常见问题

| 问题 | 优先检查 |
|---|---|
| 领星鉴权或签名失败 | 接口凭据读取、系统时间、请求参数、签名参数及GET分页参数位置 |
| 接口拉取不完整 | 接口是否支持分页、分页终止条件、店铺批次、重复数据检测 |
| OSS没有文件 | PyODPS节点日志、写入目录、`biz_date`预览、OSS权限、接口是否返回数据 |
| JSON文件无法读取 | 文件是否为UTF-8紧凑单行JSON、是否设置了`indent`、JSON结构是否合法 |
| EXT查不到数据 | `LOCATION`、分区是否注册、Endpoint、OSS读取权限、JsonSerDe结构 |
| EXT展开数量异常 | 信封`record_count`、`SIZE(data)`、`POSEXPLODE(data)`及接口过滤逻辑 |
| DWD数据为空 | `biz_date`对应的OSS文件、信封`biz_date`、EXT分区和`${biz_date}`是否一致 |
| 数据重复 | 同日期重跑是否清理旧对象、接口分页是否重复、业务唯一键是否正确 |
| 修改EXT结构未生效 | `CREATE IF NOT EXISTS`不会更新旧结构，需要按变更方案重建外表元数据 |
| 发布后仍使用旧配置 | 创建新测试实例验证，不要只重跑旧实例 |

---

## 8. 新人必须记住的五条规则

1. `biz_date`统一使用`$[yyyy-mm-dd-1]`，表示实例运行日前一天的业务日期，链路日期格式统一为`YYYY-MM-DD`。
2. 只有已确认少量数据的领星接口使用UTF-8紧凑单行JSON信封；其他接口使用Parquet+Snappy，数据量不明时不得擅自选择JSON。
3. EXT只映射OSS；正式数据加工后写入DWD内部表。
4. 接口分页、业务日期窗口、调度时间和历史保留方式必须逐接口确认。
5. 先核对接口记录数与JSON信封，再核对EXT/DWD行数、重复、空值和字段类型，最后发布生产调度。
