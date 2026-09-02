from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SKILL = (ROOT / "SKILL.md").read_text(encoding="utf-8")
INSTALL_CHECK = ROOT / "references" / "installation-check.md"


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

print("package behavior checks passed")
