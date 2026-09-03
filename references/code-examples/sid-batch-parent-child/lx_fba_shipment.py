##@resource_reference{"project_config.py"}
##@resource_reference{"lx_sync_engine.py"}
"""领星FBA货件近90个自然日同步节点（DataWorks PyODPS 3）。"""

import os
import sys
import time
from datetime import datetime, timedelta

sys.path.append(os.path.dirname(os.path.abspath("lx_sync_engine.py")))

from lx_sync_engine import create_clients


DATASET = "lx_fba_shipment"
API_PATH = "/erp/sc/data/fba_report/shipmentList"
OSS_PREFIX = f"guqiao_ods/{DATASET}"
SID_SOURCE_PREFIX = "guqiao_ods/lx_basic_seller"
PAGE_SIZE = 1000


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


def build_request_params(sid, biz_date):
    """生成包含biz_date当天在内的最近90个自然日查询窗口。"""
    start_date = biz_date - timedelta(days=89)
    end_date = biz_date + timedelta(days=1)
    return {
        "sid": str(sid),
        "start_date": start_date.strftime("%Y-%m-%d"),
        "end_date": end_date.strftime("%Y-%m-%d"),
    }


def load_sids(oss_client, biz_date_text):
    """从同一业务日期的店铺OSS文件读取有效SID。"""
    object_key = f"{SID_SOURCE_PREFIX}/dt={biz_date_text}/data.json"
    print(f"读取店铺SID: oss://{oss_client.bucket_name}/{object_key}")
    package = oss_client.download_json(object_key)
    if not isinstance(package, dict):
        raise ValueError("店铺OSS文件顶层必须是JSON对象")

    records = package.get("data")
    if not isinstance(records, list):
        raise ValueError("店铺OSS文件的data字段必须是数组")

    declared_count = package.get("record_count")
    if declared_count is not None:
        try:
            declared_count = int(declared_count)
        except (TypeError, ValueError) as exc:
            raise ValueError(
                f"店铺OSS文件record_count不是有效整数: {declared_count}"
            ) from exc
        if declared_count != len(records):
            raise ValueError(
                f"店铺OSS文件记录数不一致: record_count={declared_count}, "
                f"data实际={len(records)}"
            )

    sids = []
    invalid_count = 0
    for record in records:
        if not isinstance(record, dict):
            invalid_count += 1
            continue
        sid = record.get("sid")
        if sid is None or str(sid).strip() == "":
            invalid_count += 1
            continue
        try:
            sids.append(int(sid))
        except (TypeError, ValueError):
            invalid_count += 1

    sids = sorted(set(sids))
    if not sids:
        raise ValueError("店铺OSS文件未读取到有效SID，终止同步")

    print(
        f"店铺文件记录={len(records)}条, 有效SID={len(sids)}个, "
        f"无效SID记录={invalid_count}条"
    )
    return sids


def fetch_all_shipments(lx_client, sids, biz_date):
    """逐店铺拉取FBA货件；全部店铺成功后才允许上传。"""
    all_shipments = []
    seen_record_ids = set()

    for index, sid in enumerate(sids, start=1):
        request_params = build_request_params(sid, biz_date)
        print(
            f"开始处理店铺 {index}/{len(sids)}: sid={sid}, "
            f"窗口=[{request_params['start_date']}, {request_params['end_date']})"
        )
        shipments = lx_client.fetch_all(
            API_PATH,
            "POST",
            req_body=request_params,
            page_size=PAGE_SIZE,
            pagination=True,
            require_total_match=True,
        )

        for shipment in shipments:
            if not isinstance(shipment, dict):
                raise ValueError(f"sid={sid}返回了非JSON对象记录")
            record_id = shipment.get("id")
            if record_id is None or str(record_id).strip() == "":
                raise ValueError(f"sid={sid}返回货件缺少必填id")
            record_key = str(record_id)
            if record_key in seen_record_ids:
                raise ValueError(f"检测到重复货件id={record_id}，终止上传")
            seen_record_ids.add(record_key)

        all_shipments.extend(shipments)
        print(
            f"店铺sid={sid}完成: 本店={len(shipments)}条, "
            f"累计={len(all_shipments)}条"
        )

    if not all_shipments:
        raise ValueError("全部有效SID在最近90个自然日均返回0条货件，终止上传")
    return all_shipments


def main():
    biz_date = get_biz_date()
    biz_date_text = biz_date.strftime("%Y-%m-%d")
    window = build_request_params("示例SID", biz_date)
    print("=" * 60)
    print(f"开始同步: {DATASET}")
    print(f" API: {API_PATH}")
    print(f" 业务日期: {biz_date_text}")
    print(f" 查询窗口: [{window['start_date']}, {window['end_date']})")
    print("=" * 60)

    lx_client, oss_client = create_clients()
    sids = load_sids(oss_client, biz_date_text)
    data_list = fetch_all_shipments(lx_client, sids, biz_date)

    package = {
        "source": "lingxing",
        "dataset": DATASET,
        "biz_date": biz_date_text,
        "record_count": len(data_list),
        "sync_time": time.strftime("%Y-%m-%d %H:%M:%S"),
        "data": data_list,
    }
    object_key = f"{OSS_PREFIX}/dt={biz_date_text}/data.json"
    oss_path = oss_client.upload_json(object_key, package)
    print(
        f"节点执行完成: {oss_path}, 货件={len(data_list)}条, "
        f"店铺={len(sids)}个"
    )


if __name__ == "__main__":
    main()
