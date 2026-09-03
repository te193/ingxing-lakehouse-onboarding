##@resource_reference{"project_config.py"}
##@resource_reference{"lx_sync_engine.py"}

import os
import sys
import time
from datetime import datetime, timedelta

sys.path.append(os.path.dirname(os.path.abspath("lx_sync_engine.py")))

from lx_sync_engine import create_clients


DATASET = "lx_sale_adjust_price_queue"
API_PATH = "/basicOpen/module/adjustPrice/AdjustPriceManual"


def get_biz_date():
    """调度运行使用biz_date；普通运行时自动使用当天日期。"""
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
        return datetime.strptime(value, "%Y-%m-%d")
    except ValueError as exc:
        raise ValueError(f"biz_date格式错误或日期非法: {value}") from exc


def build_request_params(biz_date):
    """生成截至biz_date、共15个自然日的查询窗口。"""
    start_date = biz_date - timedelta(days=14)
    return {
        "time_type": 1,
        "start_time": start_date.strftime("%Y-%m-%d 00:00:00"),
        "end_time": biz_date.strftime("%Y-%m-%d 23:59:59"),
    }


biz_date = get_biz_date()
lx_client, oss_client = create_clients()
data_list = lx_client.fetch_all(
    API_PATH,
    "POST",
    req_body=build_request_params(biz_date),
    page_size=500,
    pagination=True,
    require_total_match=True,
)

biz_date_text = biz_date.strftime("%Y-%m-%d")
package = {
    "source": "lingxing",
    "dataset": DATASET,
    "biz_date": biz_date_text,
    "record_count": len(data_list),
    "sync_time": time.strftime("%Y-%m-%d %H:%M:%S"),
    "data": data_list,
}

object_key = f"guqiao_ods/{DATASET}/dt={biz_date_text}/data.json"
oss_path = oss_client.upload_json(object_key, package)
print(f"节点执行完成: {oss_path}, 共{len(data_list)}条")
