# Lingxing Lakehouse Onboarding

用于把领星 OpenAPI 接口按固定流程接入：

```text
领星 OpenAPI
→ DataWorks PyODPS 3
→ OSS
→ MaxCompute EXT
→ MaxCompute DWD
```

这个 Skill 适合团队批量迁移领星接口。使用者只提供接口名称或 API Path，Codex 会先核对接口契约和历史表结构，再按步骤生成 Python、EXT DDL、DWD DDL、DWD ETL、DataWorks 配置与对账 SQL。

## Codex 如何识别这个 Skill

Skill 名称：

```text
lingxing-lakehouse-onboarding
```

以下两种方式都可以触发。

### 显式调用（推荐）

```text
使用 $lingxing-lakehouse-onboarding，对接“查询货件列表”接口，按照步骤一次生成一个文件。
```

### 自动识别

安装后，当请求中同时出现以下语义时，Codex 可以根据 `SKILL.md` 的 description 自动选择该 Skill：

- 领星 OpenAPI 接口接入、迁移或复核；
- DataWorks、PyODPS 3；
- OSS 原始数据；
- MaxCompute EXT 或 DWD；
- 只给接口名称，希望生成 Python/SQL 接入文件。

如果自动识别没有触发，直接使用 `$lingxing-lakehouse-onboarding` 显式调用。

## 安装

### Windows（Codex）

```powershell
git clone https://github.com/te193/ingxing-lakehouse-onboarding.git "$env:USERPROFILE\.codex\skills\lingxing-lakehouse-onboarding"
```

### macOS / Linux（Codex）

```bash
git clone https://github.com/te193/ingxing-lakehouse-onboarding.git ~/.codex/skills/lingxing-lakehouse-onboarding
```

需要跨多个 Agent 运行时使用，也可以安装到：

```text
~/.agents/skills/lingxing-lakehouse-onboarding
```

安装后重新打开 Codex 任务。如果 Skill 没有出现在可用 Skill 列表中，检查最终路径是否直接包含 `SKILL.md`，不要多嵌套一层同名目录。

## 更新

进入安装目录后执行：

```bash
git pull origin main
```

更新后新建一个 Codex 任务，避免旧任务仍使用更新前已加载的说明。

## 项目标准文档

仓库内置了三份基线文档：

```text
references/project-standards/
├─ 阿里云湖仓一体规范文档.md
├─ 领星接口ODS_DWD迁移台账.md
└─ MySQL到OSS到MaxCompute_DataWorks配置操作手册.md
```

使用优先级：

1. 当前工作区中的同名最新版文档；
2. Skill 自带的 `references/project-standards/` 基线文档；
3. 两处都没有时停止生成受影响的生产代码，并报告缺失内容。

如果团队规范有更新，应先更新业务项目中的文档，再同步更新本仓库中的基线副本。

## 使用前配置

### 1. 工作区

打开实际的数据迁移项目目录作为 Codex 工作区。Skill 不依赖作者电脑的用户名、盘符或绝对路径。

每个接口默认建立独立目录：

```text
{workspace}/{dataset}/
├─ {dataset}.py
├─ ext_{dataset}_ddl.sql
├─ dwd_{dataset}_ddl.sql
├─ dwd_{dataset}_etl.sql
└─ 该接口专用的配置或对账文件
```

### 2. 项目参数

检查 `references/project-rules.md` 中的项目参数是否适用于使用者环境，尤其是：

- MaxCompute Project 和 Schema；
- OSS Bucket、Region、Endpoint 和根目录；
- DataWorks 节点命名；
- `biz_date` 调度参数；
- JSON 或 Parquet 存储规则。

如果使用者不是当前项目成员，必须先改成自己的项目配置，不能直接把示例项目名当成生产配置。

### 3. DataWorks 在线公共资源

生成的 PyODPS 节点默认在线引用：

```python
##@resource_reference{"project_config.py"}
##@resource_reference{"lx_sync_engine.py"}
```

这两个文件属于 DataWorks 在线公共资源，不包含在本仓库中。使用者需要在自己的 DataWorks 工作空间维护等价资源：

- `project_config.py`：从受控环境读取领星、OSS 等凭据；
- `lx_sync_engine.py`：Token、签名、HTTP、重试、分页和 OSS 公共能力。

不要把真实 APP Secret、AccessKey、Token 或数据库密码写进生成代码或提交到 GitHub。

## OSS MCP：连接 OSS 做只读审查

可选安装阿里云官方 [alibabacloud-oss-mcp-server](https://github.com/aliyun/alibabacloud-oss-mcp-server)，用于让 Codex 检查 OSS Bucket 元数据和当前版本支持的对象能力。

官方版本要求 Node.js `>= 18.20.5`，可在独立目录安装：

```bash
npm install alibabacloud-oss-mcp-server@alpha
```

stdio 模式的 MCP 配置示意：

```toml
[mcp_servers.aliyun-oss]
command = "node"
args = ["<绝对路径>/node_modules/alibabacloud-oss-mcp-server/dist/index.js"]
```

Codex 的 MCP 配置通常放在使用者自己的 `~/.codex/config.toml`；Windows 对应
`C:\Users\<用户名>\.codex\config.toml`。环境变量应配置在使用者本机、凭据管理器或
企业密钥服务中，不要把真实值直接写进这个公开仓库。修改配置后重新启动 Codex，再让
Codex 先列出 OSS MCP 当前公开的工具，确认连接和权限范围。

每位使用者必须配置自己的阿里云身份，不要复制他人的密钥：

| 环境变量 | 用途 |
|---|---|
| `OSS_ACCESS_KEY_ID` | 使用者自己的 AccessKey ID |
| `OSS_ACCESS_KEY_SECRET` | 使用者自己的 AccessKey Secret |
| `OSS_SECURITY_TOKEN` | 使用临时 STS 身份时填写 |
| `OSS_REGION` | 例如 `oss-cn-shenzhen` |
| `OSS_ENDPOINT` | 可选的 OSS 访问域名 |

安全要求：

- 优先使用 RAM 子账号或 STS 临时凭据；
- 只授予目标 Bucket 所需的只读权限；
- 不要使用主账号 AccessKey；
- 不要把凭据写进仓库、README、SQL、Python或聊天内容；
- 本地电脑通常不能访问 OSS 内网 Endpoint，应使用可达的外网 Endpoint；只有运行环境位于对应阿里云 VPC 时才使用内网地址；
- MCP 能审查到的范围取决于安装版本公开的工具。先列出工具能力，再决定能否读取对象正文，不能把“能查看 Bucket 信息”当成“已经核对文件内容”。

## MaxCompute MCP：检查表结构和只读数据

如果需要让 Codex 直接核对 MaxCompute 表结构、分区、SQL 或只读数据，应配置团队使用的 `maxcompute-mcp`。

每位使用者使用自己的阿里云身份，并确保至少具备目标 Project/Schema 的元数据和只读权限。不要复制 Skill 作者的 MCP Token、Cookie 或账号配置。

安装和鉴权参数以团队当前采用的 MaxCompute MCP 版本为准。配置完成后，可以先要求 Codex 执行：

```text
使用 MaxCompute MCP 只读检查当前身份、目标项目和 dwd 表结构，不执行写入。
```

## MySQL：历史 ODS/DWD 只读核对

历史字段、枚举映射和数据量需要数据库证据时，可安装配套的 `opt-lyt-db` Skill，并在使用者自己的本地环境配置：

| 环境变量 | 用途 |
|---|---|
| `OPT_LYT_DB_HOST` | MySQL 地址 |
| `OPT_LYT_DB_PORT` | MySQL 端口 |
| `OPT_LYT_DB_USER` | 使用者自己的只读账号 |
| `OPT_LYT_DB_PASSWORD` | 使用者自己的密码 |

数据库账号必须限制为只读，至少禁止 `INSERT`、`UPDATE`、`DELETE`、`ALTER`、`DROP` 和存储过程调用。不要在 README、Skill、脚本或 Git 仓库中保存连接值。

如果没有数据库权限，Skill 仍可使用官方接口文档和已有成功代码，但会把无法验证的历史字段标记为缺失或推断，不会假装已确认。

## 领星接口和凭据

接口路径、请求方式、参数位置、分页和返回结构优先参考领星官方接口文档。真实领星 APP ID、APP Secret、Token 等应由使用者自己的 DataWorks 受控资源提供。

该 Skill 默认不会因为生成代码而自动调用真实业务接口。真实 API 测试、OSS/MaxCompute/MySQL 写入、DataWorks 发布和生产调度修改都需要单独明确授权。

## 标准使用流程

### 第 0 步：接口确认

```text
使用 $lingxing-lakehouse-onboarding。
接口名称：查询货件列表。
先完成第0步确认，不生成代码。
```

Codex 会确认 dataset、API Path、GET/POST、请求参数、分页、时间窗口、存储格式、业务主键、DWD 粒度和覆盖策略。

### 第 1 步：接口到 OSS

```text
确认单没问题，生成第1步PyODPS代码。
```

输出：

```text
{dataset}/{dataset}.py
```

### 第 2 步：EXT 外部表

```text
开始第2步，生成EXT外部表DDL。
```

输出：

```text
{dataset}/ext_{dataset}_ddl.sql
```

### 第 3 步：DWD 建表

```text
开始第3步，生成DWD建表语句。
```

输出：

```text
{dataset}/dwd_{dataset}_ddl.sql
```

### 第 4 步：DWD 清洗同步

```text
开始第4步，生成DWD ETL。
```

输出：

```text
{dataset}/dwd_{dataset}_etl.sql
```

ETL 会包含空源保护、信封数量核对、键值/时间校验、数组展开、显式字段清洗、去重、分区覆盖和质量结果。MaxCompute 质量查询不会生成无提示的笛卡尔积；确需 `CROSS JOIN` 时必须对确定的小表使用 `MAPJOIN`。

### 第 5 步：DataWorks 配置与对账

```text
代码运行成功，开始第5步配置和数据对账。
```

输出包括调度参数、节点依赖、发布顺序和只读对账 SQL。

## 一次性生成全部文件

默认一次只生成一个步骤。如果确实要一次完成，可以明确说：

```text
使用 $lingxing-lakehouse-onboarding，一次完成全部步骤。接口是“查询货件列表”。仍然要先核对阻断项，不能猜字段。
```

## 证据优先级

不同问题使用不同证据：

- 项目规范：工作区最新规范文档优先；
- API 契约：领星官方接口文档优先；
- 历史 DWD 字段：现有 MySQL DWD 表结构和注释优先；
- 工程写法：已经运行成功的同类节点优先；
- 记忆和未经验证的旧代码不能标记为已确认。

结论会标注为：

- `已确认`；
- `有证据的推断`；
- `缺失`。

## 常见问题

### 只给接口名称可以吗？

可以。Skill 会先从迁移台账定位接口，再通过官方文档、历史表和成功代码补齐证据。存在同名接口或关键字段缺失时会先询问，不会直接猜测。

### 为什么不能直接生成所有代码？

请求参数位置、分页方式、数组结构、业务主键和覆盖策略猜错会造成漏数、重复或覆盖有效分区，因此默认逐步确认。

### 为什么找不到 `project_config.py`？

它和 `lx_sync_engine.py` 是 DataWorks 在线资源，本地 Skill 不需要包含这两个文件。使用者需要在自己的 DataWorks 工作空间提供它们。

### 普通运行为什么没有读到 `biz_date`？

普通编辑器运行和调度实例的参数注入机制不同。生产调度和补数据应配置：

```text
biz_date=$[yyyy-mm-dd-1]
```

并通过新建测试/补数据实例检查参数预览。

### 能否直接使用作者的阿里云或数据库账号？

不能。Skill 不提供共享凭据。每位使用者必须使用自己的授权身份，并遵守最小权限原则。

## 安全边界

允许默认执行：

- 读取项目文档和本地代码；
- 查询官方接口文档；
- 使用已配置的只读数据库、OSS 或 MaxCompute 能力收集证据；
- 在本地生成 Python 和 SQL 文件。

需要额外明确授权：

- 调用真实领星业务接口；
- 写入、删除或覆盖 OSS 对象；
- 执行 MaxCompute DDL/DML；
- 修改 MySQL 数据；
- 发布 DataWorks 节点或修改生产调度。

## 仓库说明

GitHub 仓库当前名称为 `ingxing-lakehouse-onboarding`，Skill 的正式名称为 `lingxing-lakehouse-onboarding`。仓库名少了首字母 `l` 不影响 Skill 识别，但建议后续在 GitHub 设置中统一名称。
