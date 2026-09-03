##@resource_reference{"project_config.py"}
##@resource_reference{"lx_sync_engine.py"}
"""领星补货列表全量同步到OSS JSON节点（DataWorks PyODPS 3）。"""

import os
import sys
from datetime import datetime

sys.path.append(os.path.dirname(os.path.abspath("lx_sync_engine.py")))

from lx_sync_engine import create_clients, sync_task


def get_biz_date():
    """读取并校验DataWorks业务日期参数。"""
    node_args = globals().get("args") or {}
    value = str(
        node_args.get("biz_date")
        or node_args.get("bizdate")
        or os.getenv("SKYNET_BIZDATE")
        or ""
    ).strip()
    if not value:
        value = datetime.now().strftime("%Y-%m-%d")
        print(f"未收到biz_date，普通运行自动使用当天日期: {value}")

    if len(value) == 8 and value.isdigit():
        value = f"{value[:4]}-{value[4:6]}-{value[6:]}"

    try:
        return datetime.strptime(value, "%Y-%m-%d").strftime("%Y-%m-%d")
    except ValueError as exc:
        raise ValueError(f"biz_date格式错误或日期非法: {value}") from exc


def main():
    biz_date = get_biz_date()
    task = {
        "name": "lx_replenishment_suggest_restocking",
        "api_path": "/erp/sc/routing/restocking/analysis/getSummaryList",
        "method": "POST",
        "oss_prefix": "guqiao_ods/lx_replenishment_suggest_restocking",
        "pagination": True,
        "page_size": 50,
        "req_params_tpl": {},
        "req_body_tpl": {"data_type": 2},
    }
    lx_client, oss_client = create_clients()
    result_path = sync_task(
        lx_client,
        oss_client,
        task,
        biz_date,
    )
    print(f"节点执行完成: {result_path}")


if __name__ == "__main__":
    main()
