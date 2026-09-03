from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SKILL = (ROOT / "SKILL.md").read_text(encoding="utf-8")
README = (ROOT / "README.md").read_text(encoding="utf-8")
INSTALL_CHECK = ROOT / "references" / "installation-check.md"
EXAMPLES = ROOT / "references" / "code-examples"
RECONCILIATION_REPORT = ROOT / "references" / "reconciliation-report.md"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


require(INSTALL_CHECK.exists(), "missing one-time installation check reference")
install_text = INSTALL_CHECK.read_text(encoding="utf-8")

for name in ("maxcompute-mcp", "opt-lyt-db"):
    require(name in SKILL, f"SKILL.md does not route installation checks to {name}")
    require(name in install_text, f"installation check does not probe {name}")

require("Normal interface onboarding must not repeat" in install_text, "normal runs are not exempted")
require("user's own least-privilege, read-only account or key" in install_text, "own read-only credentials are not required")

require(EXAMPLES.joinpath("README.md").exists(), "missing bundled code-example index")
require("references/code-examples/README.md" in SKILL, "SKILL.md does not route bundled examples")
require("内置参考代码" in README, "README does not explain bundled examples")

for scenario in ("simple-shared-json", "manual-post-json", "sid-batch-parent-child"):
    folder = EXAMPLES / scenario
    require(folder.is_dir(), f"missing example scenario: {scenario}")
    names = [path.name for path in folder.iterdir() if path.is_file()]
    require(any(name.endswith(".py") for name in names), f"{scenario} has no PyODPS example")
    require(any(name.startswith("ext_") and name.endswith("_ddl.sql") for name in names), f"{scenario} has no EXT DDL")
    require(any(name.startswith("dwd_") and name.endswith("_ddl.sql") for name in names), f"{scenario} has no DWD DDL")
    require(any(name.startswith("dwd_") and name.endswith("_etl.sql") for name in names), f"{scenario} has no DWD ETL")

require(RECONCILIATION_REPORT.exists(), "missing compact reconciliation report template")
require("references/reconciliation-report.md" in SKILL, "SKILL.md does not route the reconciliation template")
report_text = RECONCILIATION_REPORT.read_text(encoding="utf-8")
for status in ("通过", "条件通过", "不通过", "未完成"):
    require(status in report_text, f"reconciliation status missing: {status}")
require("异常时" in report_text, "template does not expand only on anomalies")
require("不生成文件" in report_text, "template does not default to chat-only output")

print("package behavior checks passed")
