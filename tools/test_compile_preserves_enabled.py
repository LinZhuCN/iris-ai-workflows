# -*- coding: utf-8 -*-
"""Real IRIS regression: compile checks preserve current Production enabled states."""
import json
import sys

sys.path.insert(0, "/app")

import iris
from backend.services import iris_connector, pipeline_validator


def snapshot():
    rows = iris_connector.query(
        "SELECT Name, Enabled FROM Ens_Config.Item ORDER BY Name")
    connection = iris_connector.get_connection()
    try:
        native = iris.createIRIS(connection)
        return {
            str(name): {
                "enabled": bool(enabled),
                "running": bool(native.get("^Ens.Runtime", "ConfigItem", name, "Job")),
            } for name, enabled in rows
        }
    finally:
        connection.close()


before = snapshot()
if not before:
    raise RuntimeError("Requires an existing Production; empty configuration is not a pass")
result = pipeline_validator.check_compile()
after = snapshot()
assert result.get("ok"), result
assert before == after, {"before": before, "after": after}
print(json.dumps({"passed": True, "hosts_checked": len(before),
                  "enabled_states_preserved": True, "runtime_states_preserved": True}))
