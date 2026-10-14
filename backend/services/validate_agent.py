"""验证-修复 Agent（C2：数据管道验证-修复）：工具事实检查 + AI 判断 + 分层修复闭环。

职责范围 = 数据管道（组件拓扑/编译/启动/消息流转），与数据转换验证-修复
（Agent C1，transformation_validator.py）分离：
- C2 验证对象 = 管道拓扑 + 生成结果，知识域 = IRIS 互操作性；
- C1 验证对象 = 转换关系（字段映射），知识域 = FHIR 字段语义；
- 事实检查工具共享（pipeline_validator），L1/L2/L3 分层修复框架各自实现。
- C2 隐藏原始运行日志和凭据；专用工具按源/目标身份受控修改生成产物。

验证原则：
- 事实检查（组件枚举/编译/启动/消息状态）由函数工具完成（AI 做不了精确事实检查）；
- 验证策略（错误是否实质、如何修复）由 AI Agent 动态组合；
- 当前生成路由所有生成后阻断故障统一进入 C2，共用 C2_MAX_ATTEMPTS 预算；
  单轮工具调用也计入预算，不允许工具内部另起多轮修复；
- 经验沉淀入 ^demo.ValidationIssue 并在后续 prompt 注入。
"""

import json
import logging
import os
import re

from backend.services import iris_connector, pipeline_validator, type_registry
from backend.services.llm_client import _call_llm

logger = logging.getLogger(__name__)

# ===== Agent C2：管道验证-修复（系统提示词，聚焦 IRIS 管道） =====
SYSTEM_PROMPT_VALIDATE = (
    "你是 IRIS 数据管道验证与修复专家。给定数据管道生成/验证报告（事实检查结果，"
    "覆盖组件拓扑/编译/启动/消息流转）与上下文，判断哪些问题是实质性错误并给出修复动作。"
    "原则：1. 事实检查结果可信（组件类型合法性、className 有效性、编译错误、启动状态、"
    "消息状态），你只负责判断影响与选择修复路径。"
    "2. 运行期修复优先使用 update_settings，只能修改拓扑中已存在、且所属组件已启用的"
    "运行参数：CallInterval、ConnectTimeout、MaxRetries、PollingInterval、ResponseTimeout、"
    "RetryCount、RetryInterval、Timeout。"
    "不得改 DSN、Query、InputParameters、目标/端点、身份凭据或其他设置。"
    "update_settings 不得增删组件，也不得更改组件 name/type/className/category 或设置名。"
    '{"action":"update_settings","fix":{"updates":[{"component_name":"...","target":"Adapter|Host",'
    '"name":"ExistingSetting","value":"..."}]}}。'
    "若现有设置无法修复，可选择已接入的专用工具；所有工具均无法安全修复时选择 none。"
    "当上下文包含 repair_scope 时，只能选择 evidence.available_actions 中的动作。"
    "repair_mapping 调用 C1 单轮修复字段映射；repair_topology 调用 Agent B 单轮修正"
    "既有组件类名或组内派发；repair_bp 调用生成 BP 的单轮方法修复。"
    "这些动作必须指定 source_id 和 target_id，唯一标识待修管道，不能只按 category 猜测。"
    '{"action":"repair_mapping|repair_topology|repair_bp","source_id":"源ID","target_id":"目标ID",'
    '"message":"故障归属与工具选择理由"}。'
    "每轮只能调用一个工具；工具失败应结合下一轮证据调整策略。"
    "engine 模式父类逻辑、平台源码、凭据和外部环境不在自动修改权限内。"
    "不能安全修复时用 none，并设置 terminal=true 说明能力边界；"
    "bp_code 分类并不意味着可修生成源码：通用 TransformProcess 或 engine 父类不可用 repair_bp。"
    "优先查看 pipeline_groups.mapping_checks，源字段/转换约束错误交 repair_mapping；"
    "仅从 evidence.available_actions 选择动作，工具动作必须填写对应组顶层 source_id/target_id。"
    "不能将修改映射、拓扑或源码伪装为 rebuild。"
    "只有瞬态故障才选择原样 rebuild；参考 previous_attempts，避免重复无效操作。"
    "repair_scope 下不得使用 fix_topology、start 或 fallback。"
    "只有未提供 repair_scope 的旧入口兼容以下动作："
    '{"action":"fix_topology","fix":{"components":[...]}} 修正拓扑后重新生成；'
    '{"action":"rebuild","message":"带错误反馈重新生成"}；'
    '{"action":"start","message":"重启 Production"}；'
    '{"action":"fallback","message":"回退默认拓扑"}；'
    '{"action":"none","message":"无需修复"}。'
    "3. 只修实质性错误（编译失败、必选组件缺失、className 无效、启动失败、消息 Error），"
    "warning 类（如尚无消息流转）不视为错误。"
    "4. 若提供 past_issues，参考其中历史解决方案，避免重复错误。"
    "严格输出 JSON（不要输出其他文字），格式："
    '{"assessment":[{"issue":"...","severity":"error|warning","impact":"high|low","reason":"..."}],'
    '"fix":{"action":"...","message":"...","fix":{"..."}},'
    '"experience":{"pattern":"历史问题模式","resolution":"解决方案"}}'
)

# 修复动作白名单（管道域）
VALID_ACTIONS = {"update_settings", "fix_topology", "rebuild", "start", "fallback", "none"}
VALID_ACTIONS.update({"repair_mapping", "repair_topology", "repair_bp"})
_C2_TOOL_ACTIONS = {"repair_mapping", "repair_topology", "repair_bp"}
_C2_SENSITIVE_SETTING_PARTS = (
    "password", "passwd", "token", "secret", "api_key", "apikey",
    "credential", "authorization",
)
_C2_MUTABLE_RUNTIME_SETTING_NAMES = {
    "callinterval", "connecttimeout", "maxretries", "pollinginterval",
    "responsetimeout", "retrycount", "retryinterval", "timeout",
}
_C2_URL_CREDENTIALS = re.compile(r"(?i)(https?://)[^/@\s]+@")
_C2_SECRET_PARAMS = re.compile(
    r"(?i)[?&](?:access_token|api_key|apikey|key|password|secret|token)=")


def _is_sensitive_setting(name: str, value) -> bool:
    lowered = str(name or "").lower()
    if any(part in lowered for part in _C2_SENSITIVE_SETTING_PARTS):
        return True
    return (isinstance(value, str) and
            bool(_C2_URL_CREDENTIALS.search(value) or _C2_SECRET_PARAMS.search(value)))


def judge_issues(report: dict, context: dict, past_issues: list[dict]) -> dict:
    """Agent C：判断问题 + 给出修复动作（LLM 单轮决策）。

    参数:
        report: pipeline_validator.run_validation 输出
        context: {source_type, target_type, production, component_types}
        past_issues: ^demo.ValidationIssue 历史经验
    返回:
        {"assessment": [...], "fix": {"action", "message", "fix"}, "experience": {...}}
    """
    user_content = json.dumps({
        "validation_report": report,
        "context": context,
        "past_issues": past_issues,
    }, ensure_ascii=False, indent=2)
    result = _call_llm(SYSTEM_PROMPT_VALIDATE, user_content, "验证修复Agent")
    fix = result.get("fix") or {}
    if fix.get("action") not in VALID_ACTIONS:
        fix = {"action": "none", "message": "LLM 返回未知动作，拒绝未授权的拓扑回退"}
    return {
        "assessment": result.get("assessment", []),
        "fix": fix,
        "experience": result.get("experience", {}) or {},
    }


def runtime_repair_attempt_limit() -> int:
    """返回 C2 管道修复决策上限；配置无效时显式报错。"""
    raw = os.getenv("C2_MAX_ATTEMPTS", "3")
    try:
        limit = int(raw)
    except (TypeError, ValueError) as exc:
        raise ValueError("C2_MAX_ATTEMPTS 必须是 1 到 10 之间的整数") from exc
    if not 1 <= limit <= 10:
        raise ValueError("C2_MAX_ATTEMPTS 必须是 1 到 10 之间的整数")
    return limit


def _apply_runtime_setting_updates(topology: dict, updates: list[dict]) -> tuple[dict, str]:
    """只应用针对现有、已启用组件设置值的 C2 补丁，保留所有组件身份与拓扑结构。"""
    if not isinstance(updates, list) or not updates:
        return topology, "C2 未提供设置更新"

    candidate = json.loads(json.dumps(topology))
    components = {
        str(c.get("name")): c for c in (candidate.get("components") or [])
        if isinstance(c, dict) and c.get("name")
    }
    seen: set[tuple[str, str, str]] = set()
    changed = False
    for update in updates:
        if not isinstance(update, dict):
            return topology, "设置更新必须是对象"
        component_name = str(update.get("component_name") or "")
        target = str(update.get("target") or "")
        setting_name = str(update.get("name") or "")
        key = (component_name, target, setting_name)
        if not all(key) or key in seen:
            return topology, "设置更新缺少组件/目标/名称，或包含重复项"
        seen.add(key)
        component = components.get(component_name)
        if not component:
            return topology, f"设置更新引用了不存在的组件: {component_name}"
        if component.get("enabled") in (False, 0, "false", "False"):
            return topology, f"拒绝修改已停用组件: {component_name}"
        value = update.get("value")
        if value is None or value == "" or isinstance(value, (dict, list)):
            return topology, f"设置 {component_name}.{setting_name} 必须是非空标量值"
        setting = next((s for s in component.get("settings") or []
                        if isinstance(s, dict) and
                        str(s.get("target") or "") == target and
                        str(s.get("name") or "") == setting_name), None)
        if setting is None:
            return topology, f"拒绝新增或更改未知设置: {component_name}.{target}.{setting_name}"
        if (_is_sensitive_setting(setting_name, setting.get("value"))
                or _is_sensitive_setting(setting_name, value)):
            return topology, f"拒绝通过 C2 修改凭据设置: {component_name}.{setting_name}"
        if setting_name.replace("_", "").lower() not in _C2_MUTABLE_RUNTIME_SETTING_NAMES:
            return topology, f"拒绝通过 C2 修改非运行参数设置: {component_name}.{setting_name}"
        if setting.get("value") != value:
            setting["value"] = value
            changed = True
    if not changed:
        return topology, "C2 设置更新没有产生变化"

    before = {
        str(c.get("name")): (c.get("type"), c.get("className"), c.get("category"))
        for c in (topology.get("components") or []) if isinstance(c, dict)
    }
    after = {
        str(c.get("name")): (c.get("type"), c.get("className"), c.get("category"))
        for c in (candidate.get("components") or []) if isinstance(c, dict)
    }
    if before != after:
        return topology, "C2 设置补丁改变了组件身份或归属，已拒绝"
    return candidate, ""


def _redact_c2_topology(topology: dict) -> dict:
    """隐藏 C2 无权修改、也不应发送给 LLM 的凭据设置值。"""
    safe = json.loads(json.dumps(topology or {}))
    for component in safe.get("components") or []:
        if not isinstance(component, dict):
            continue
        for setting in (component or {}).get("settings") or []:
            if not isinstance(setting, dict):
                continue
            name = str(setting.get("name") or "")
            if _is_sensitive_setting(name, setting.get("value")):
                setting["value"] = "[REDACTED]"
            elif name.lower() not in _C2_MUTABLE_RUNTIME_SETTING_NAMES and name != "TargetConfigNames":
                setting["value"] = "[HIDDEN]"
        for key in list(component):
            if key not in ("name", "type", "className", "category", "enabled", "settings"):
                del component[key]
    return safe


def _c2_validation_for_llm(validation: dict) -> dict:
    """仅发送检查状态、错误分类和平台建议，隐藏原始日志与业务值。"""
    runtime = (validation.get("results") or {}).get("runtime") or {}
    safe_issues = []
    for issue in runtime.get("issues") or []:
        if not isinstance(issue, dict):
            continue
        message = str(issue.get("message") or "")
        kind = message[1:message.find("]")] if message.startswith("[") and "]" in message \
            else "other"
        if kind not in ("bp_code", "fhir_schema", "other"):
            kind = "other"
        advice = {
            "bp_code": "核对生成方法、聚合布局与继承引擎的故障归属",
            "fhir_schema": "核对字段映射、转换指令与 FHIR 结构约束",
            "other": "结合结构化错误码和组件事实检查配置",
        }[kind]
        safe_issues.append({
            "severity": issue.get("severity", "warning"),
            "item": issue.get("item") or "runtime",
            "kind": kind,
            "advice": advice,
            "message": "运行期日志详情已隐藏，避免发送业务数据。",
        })
    return {
        "ok": validation.get("ok"),
        "error_count": validation.get("error_count", 0),
        "warning_count": validation.get("warning_count", 0),
        "issues": [{"check": issue.get("check"), "severity": issue.get("severity"),
                    "item": issue.get("item")}
                   for issue in validation.get("issues") or []],
        "results": {**{
            key: {
                "ok": value.get("ok"),
                "level": value.get("level"),
                "issues": [{"severity": issue.get("severity"), "item": issue.get("item")}
                           for issue in value.get("issues") or []],
            }
            for key, value in (validation.get("results") or {}).items()
            if key != "runtime" and isinstance(value, dict)
        }, "runtime": {
            "ok": runtime.get("ok"),
            "kinds": runtime.get("kinds") or [],
            "issues": safe_issues,
        }},
        "c2_feedback": validation.get("c2_feedback", ""),
        "c2_tool_feedback": validation.get("c2_tool_feedback", {}),
    }


def has_blocking_failure(validation: dict, generation_result="OK") -> bool:
    """运行日志暂为 warning，但实际运行错误仍必须进入修复闭环。"""
    runtime = (validation.get("results") or {}).get("runtime") or {}
    return (generation_result != "OK" or not validation.get("ok")
            or any(i.get("severity") == "error" for i in validation.get("issues") or [])
            or bool(runtime.get("issues")) or runtime.get("ok") is False)


def _c2_evidence(topology: dict, validation: dict, generation_result,
                 pipeline_groups: list[dict], *, tools_available: bool = False) -> dict:
    safe = _c2_validation_for_llm(validation)
    checks = set((safe.get("results") or {}).keys())
    checks.update(i.get("check") for i in safe["issues"] if i.get("check"))
    tokens = set()
    locations = set()
    for check in (validation.get("results") or {}).values():
        if not isinstance(check, dict):
            continue
        texts = [str(check.get("message") or "")]
        texts.extend(str(i.get("message") or "") for i in check.get("issues") or [])
        for text in texts:
            locations.update(re.findall(
                r"\b[A-Za-z%][A-Za-z0-9%]*\+[0-9]+\^"
                r"[A-Za-z%][A-Za-z0-9_.%]*", text))
            tokens.update(re.findall(
                r"\b(?:Err[A-Za-z0-9_]+|MPP[0-9]+|MissingRequiredProperty|"
                r"MalformedRelativeReference)\b|"
                r"<(?:UNDEFINED|SUBSCRIPT|INVALID OREF|METHOD DOES NOT EXIST|"
                r"CLASS DOES NOT EXIST)>|ERROR #[0-9]+", text))
    return {
        "generation_ok": generation_result == "OK",
        "validation": safe,
        "failed_checks": sorted(
            key for key in checks
            if any(i.get("check") == key and i.get("severity") == "error"
                   for i in safe["issues"])
            or ((safe["results"].get(key) or {}).get("ok") is False
                and (safe["results"].get(key) or {}).get("level") != "warning")),
        "error_codes": sorted(tokens),
        "code_locations": sorted(locations),
        "pipeline_groups": pipeline_groups,
        "components": [{k: c.get(k) for k in
                        ("name", "type", "className", "category", "enabled")}
                       for c in topology.get("components") or []],
        "available_actions": ["update_settings", "rebuild", "none"] + (
            sorted(_C2_TOOL_ACTIONS - (set() if any(
                g.get("bp_mode") in ("plan", "full", "full_fallback")
                and any(c.get("type") == "PatientTxProcess"
                        and c.get("name") in (g.get("component_names") or [])
                        for c in topology.get("components") or [])
                for g in pipeline_groups) else {"repair_bp"})) if tools_available else []),
        "unavailable_tools": [] if tools_available else [
            "C1", "Agent B", "generated BP method repair"],
    }


def repair_pipeline_errors(topology: dict, validation: dict, context: dict,
                           regenerate_and_validate, max_attempts: int | None = None,
                           generation_result="OK", execute_repair_tool=None) -> dict:
    """统一处理生成后阻断故障；每轮最多执行一个单轮修复工具并复验。"""
    limit = runtime_repair_attempt_limit() if max_attempts is None else int(max_attempts)
    if not 1 <= limit <= 10:
        raise ValueError("C2 修复尝试次数必须是 1 到 10 之间的整数")
    current_topology = json.loads(json.dumps(topology or {}))
    current_validation = validation or {}
    attempts: list[dict] = []
    current_result = generation_result
    executed_actions: set[str] = set()
    pipeline_groups = [{key: group.get(key) for key in (
        "source_id", "target_id", "category", "component_names", "bp_mode", "mapping_ids",
        "mapping_checks")}
        for group in context.get("pipeline_groups") or []]
    evidence = _c2_evidence(current_topology, current_validation, current_result, pipeline_groups,
                            tools_available=execute_repair_tool is not None)
    tool_feedback = {}

    for attempt in range(1, limit + 1):
        evidence = _c2_evidence(
            current_topology, current_validation, current_result, pipeline_groups,
            tools_available=execute_repair_tool is not None)
        if not has_blocking_failure(current_validation, current_result):
            return {"status": "ok", "evidence": evidence,
                    "generation_result": current_result,
                    "topology": current_topology,
                    "validation": current_validation, "attempts": attempts,
                    "attempt_limit": limit}

        decision_context = {
            **context,
            "attempt": attempt,
            "max_attempts": limit,
            "current_topology": _redact_c2_topology(current_topology),
            "repair_scope": "single-round tools; no platform source or credentials",
            "evidence": evidence,
            "tool_feedback": tool_feedback,
            "previous_attempts": json.loads(json.dumps(attempts)),
        }
        try:
            decision = judge_issues(
                _c2_validation_for_llm(current_validation),
                decision_context, [])
        except Exception as exc:
            attempts.append({"attempt": attempt, "action": "error",
                             "message": f"C2 Agent 调用失败: {exc}"})
            return {"status": "failed", "evidence": evidence,
                    "generation_result": current_result, "topology": current_topology,
                    "validation": current_validation, "attempts": attempts,
                    "attempt_limit": limit,
                    "message": f"C2 Agent 调用失败: {exc}"}

        fix = decision.get("fix")
        if not isinstance(fix, dict):
            fix = {}
        action = str(fix.get("action") or "none")
        tool_audit = {}
        if action in _C2_TOOL_ACTIONS:
            if execute_repair_tool is None:
                tool_feedback = {"ok": False, "message": "修复工具未接入"}
            else:
                try:
                    outcome = execute_repair_tool(
                        action, fix, current_topology, evidence)
                    tool_feedback = json.loads(json.dumps(outcome.get("audit") or {}))
                    if outcome.get("ok"):
                        current_topology = outcome["topology"]
                        tool_audit = tool_feedback
                    else:
                        tool_feedback = {**tool_feedback, "ok": False}
                except Exception as exc:
                    logger.exception("C2 单轮工具 %s 执行失败", action)
                    tool_feedback = {
                        "ok": False, "message": "单轮工具执行异常，详见服务日志",
                        "exception_type": type(exc).__name__,
                    }
            if not tool_feedback.get("ok"):
                attempts.append({"attempt": attempt, "action": action,
                                 "applied": False, "tool": tool_feedback})
                current_validation = {**current_validation,
                                      "c2_feedback": tool_feedback.get("message", "工具未通过"),
                                      "c2_tool_feedback": tool_feedback}
                if tool_feedback.get("terminal"):
                    return {"status": "failed", "evidence": evidence,
                            "generation_result": current_result, "topology": current_topology,
                            "validation": current_validation, "attempts": attempts,
                            "attempt_limit": limit, "message": tool_feedback["message"]}
                continue
        elif action == "update_settings":
            fix_payload = fix.get("fix")
            candidate, rejection = _apply_runtime_setting_updates(
                current_topology,
                (fix_payload.get("updates") or [])
                if isinstance(fix_payload, dict) else [])
            if rejection:
                attempts.append({"attempt": attempt, "action": action,
                                 "message": rejection, "applied": False})
                current_validation = {
                    **current_validation,
                    "c2_feedback": rejection,
                }
                continue
            current_topology = candidate
        elif action == "rebuild":
            pass
        else:
            message = str(fix.get("message") or
                          f"C2 未提出可执行的管道修复（action={action}）")
            attempts.append({"attempt": attempt, "action": action,
                             "message": message, "applied": False})
            current_validation = {
                **current_validation,
                "c2_feedback": (message + "；请基于证据选择已接入的受控工具，若不可修则明确说明。"),
            }
            if fix.get("terminal") is True:
                return {"status": "failed", "topology": current_topology,
                        "validation": current_validation, "attempts": attempts,
                        "attempt_limit": limit, "evidence": evidence,
                        "generation_result": current_result,
                        "message": f"C2 无法在当前修复范围内解决故障: {message}"}
            continue

        fingerprint = json.dumps({"action": action, "topology": current_topology,
                                  "tool": tool_audit},
                                 sort_keys=True, ensure_ascii=False)
        if fingerprint in executed_actions:
            rejection = "相同动作及产物已执行且未解决故障，拒绝重复无效操作"
            attempts.append({"attempt": attempt, "action": action,
                             "message": rejection, "applied": False})
            current_validation = {**current_validation, "c2_feedback": rejection}
            continue
        executed_actions.add(fingerprint)
        try:
            result, current_validation = regenerate_and_validate(current_topology)
            current_result = result
            evidence = _c2_evidence(
                current_topology, current_validation, current_result, pipeline_groups,
                tools_available=execute_repair_tool is not None)
        except Exception as exc:
            attempts.append({"attempt": attempt, "action": action,
                             "message": f"重新生成或验证失败: {exc}", "applied": True})
            return {"status": "failed", "evidence": evidence,
                    "generation_result": current_result, "topology": current_topology,
                    "validation": current_validation, "attempts": attempts,
                    "attempt_limit": limit,
                    "message": f"重新生成或验证失败: {exc}"}
        attempts.append({"attempt": attempt, "action": action,
                         "message": str(fix.get("message") or ""),
                         "applied": True, "generation_result": str(result),
                         "tool": tool_audit,
                         "failed_checks": evidence["failed_checks"],
                         "runtime_error_count": len(
                             (((current_validation.get("results") or {}).get("runtime") or {})
                              .get("issues") or []))})
        experience = decision.get("experience") or {}
        if not has_blocking_failure(current_validation, current_result):
            if (isinstance(experience, dict) and experience.get("pattern")
                    and experience.get("resolution")):
                try:
                    pipeline_validator.save_validation_issue(
                        experience["pattern"], experience["resolution"],
                        source="validate-agent")
                except Exception as exc:
                    logger.warning("C2 经验沉淀失败（不影响修复循环）: %s", exc)
            return {"status": "ok", "evidence": evidence,
                    "generation_result": current_result,
                    "topology": current_topology,
                    "validation": current_validation, "attempts": attempts,
                    "attempt_limit": limit,
                    "message": ""}

    message = (f"C2 已达到管道修复尝试上限（{limit} 次），"
               "阻断故障仍未解决；请检查返回的验证报告与 C2 尝试记录")
    return {"status": "failed", "evidence": evidence,
            "generation_result": current_result, "topology": current_topology,
            "validation": current_validation, "attempts": attempts,
            "attempt_limit": limit, "message": message}


# 兼容既有调用者；生成编排使用统一管道故障入口。
repair_runtime_errors = repair_pipeline_errors


def _l1_rule_fix(topology: dict | None, source_type: str,
                 target_type: str) -> tuple[dict, bool]:
    """L1 规则修复：只做机械补全（补 className、补必选件），**不删除 AI/Agent 决策组件**。

    红线：规则不得改写 AI 决策的组件构成。未注册类型的组件若已有 className
    （如 Agent 生成的 BP、设计 Skill 的查询 BO），一律保留（是否精简由 LLM 决策
    fix_topology 负责）；仅当既未注册、又没有 className（无法参数化）时才剔除。

    返回: (修正后的拓扑, 是否有改动)
    """
    components = (topology or {}).get("components", [])
    templates: dict[str, dict] = {}
    for c in type_registry.get_source_components(source_type):
        templates[c["type"]] = c
    for c in type_registry.get_target_components(target_type):
        templates[c["type"]] = c
    for c in type_registry.get_common_components():
        templates[c["type"]] = c
    # 设计 Skill 专属组件（sql2fhir 患者聚合 BP 等，类源码由 Agent 生成——平台不预置）
    for c in type_registry.get_pipeline_asset_components():
        templates[c["type"]] = c
    # SQL 源的查询 BO = 现成 EnsLib.SQL.Operation.GenericOperation（读语义），与目标类型无关
    if source_type == "SQL" or "SQL" in (source_type or []):
        templates.setdefault("SQLOperation", {
            "type": "SQLOperation", "className": "EnsLib.SQL.Operation.GenericOperation",
            "comment": "SQL 查询 BO（读语义，回喂聚合 BP）"})

    changed = False
    fixed: list[dict] = []
    for c in components:
        ctype = c.get("type", "")
        tpl = templates.get(ctype)
        if not c.get("className"):
            if tpl and tpl.get("className"):
                # 已注册类型缺 className → 机械补全
                c = {**c, "className": tpl["className"],
                     "comment": c.get("comment") or tpl.get("comment", "")}
                changed = True
            else:
                changed = True  # 既未注册又无 className，无法参数化 → 剔除
                continue
        fixed.append(c)

    seen = {c.get("type") for c in fixed}
    # 必选件补齐：处理组件（TransformProcess 或 Skill 聚合 BP）+ JavaGateway
    process_seen = any(t in seen for t in ("TransformProcess", "PatientTxProcess"))
    required = ([("TransformProcess", "TransformProcess")] if not process_seen else []) \
        + [("JavaGateway", "JavaGateway")]
    for key, req in required:
        if req in seen or req not in templates:
            continue
        tpl = templates[req]
        fixed.append({
            "type": req, "name": tpl.get("className", req),
            "className": tpl["className"],
            "comment": tpl.get("comment", ""),
            "settings": [{"target": "Host", "name": k, "value": v}
                         for k, v in (tpl.get("settings") or {}).items()],
        })
        seen.add(req)
        changed = True
        logger.info("管道 L1 机械补齐必选组件 %s（校验性补齐，不改 AI 决策构成）", key)

    new_topo = {
        "production": (topology or {}).get("production")
        or pipeline_validator.PRODUCTION_NAME,
        "components": fixed,
    }
    return new_topo, changed


def _default_topology(mappings: list[dict], source_type: str,
                      target_type: str, base_topology: dict | None = None) -> dict:
    """L3 回退：**保守重建**——保留 AI/Agent 决策组件，只做机械补全。

    红线：规则兜底不得丢弃 Agent 生成组件（如 sql2fhir 的聚合 BP / 查询 BO），
    因此不再用通用 build_pipeline_topology 整体替换拓扑，而是在现有拓扑基础上
    补齐 className 与必选件（JavaGateway / 处理组件）后返回。
    """
    base = {"production": (base_topology or {}).get("production")
            or pipeline_validator.PRODUCTION_NAME,
            "components": list((base_topology or {}).get("components", []))}
    topo, _ = _l1_rule_fix(base, source_type, target_type)
    return topo


def validate_and_fix_pipeline(mappings: list[dict], topology: dict | None,
                              generate_fn, source_type: str = "FHIR",
                              target_type: str = "DB",
                              production: str = pipeline_validator.PRODUCTION_NAME,
                              max_rounds: int = 2) -> dict:
    """验证-修复闭环（≤2 轮）：工具检查 → L1 规则修复 → L2 LLM 决策 → L3 回退。

    参数:
        mappings: 转换关系列表
        topology: 完整拓扑（build_pipeline_topology 输出）
        generate_fn: 重新生成的可调用对象 generate_fn(topology, mappings) -> str
    返回:
        {"status": "ok"|"failed", "rounds": [...], "topology", "mappings",
         "report", "message"}
    """
    context = {
        "source_type": source_type,
        "target_type": target_type,
        "production": production,
        "component_types": [c.get("type") for c in (topology or {}).get("components", [])],
    }
    past_issues = pipeline_validator.load_validation_issues()
    current_topology = topology or {}
    rounds_log: list[dict] = []
    report: dict = {}
    # AI 驱动红线审计：规则/默认拓扑是否在修复中改写了 AI 决策的构成（必须向用户显式标注）
    rule_applied = False

    for round_i in range(max_rounds + 1):
        report = pipeline_validator.run_pipeline_validation(
            current_topology, source_type, target_type, production)
        errors = [i for i in report["issues"] if i.get("severity") == "error"]
        err_summary = "；".join(f"[{i.get('check')}] {i.get('message')}" for i in errors)
        rounds_log.append({"round": round_i, "error_count": len(errors),
                           "summary": err_summary or "无错误"})
        if not errors:
            return {"status": "ok", "rounds": rounds_log,
                    "topology": current_topology, "mappings": list(mappings or []),
                    "report": report, "message": "验证通过",
                    "rule_applied": rule_applied}

        # L1 规则修复（管道域机械规则：剔未知组件/补 className/补必选）
        new_topo, topo_fixed = _l1_rule_fix(current_topology, source_type, target_type)
        if topo_fixed:
            current_topology = new_topo
            # 红线审计：L1 改变了 AI 决策的组件构成（剔除未知/补必选）→ 显式标记
            rule_applied = True
            logger.info("管道 L1 规则修复生效（规则介入改写 AI 拓扑，已审计标记）: 拓扑改动=True")
            # L1 修复后立即重新生成，下一轮验证修复效果
            try:
                gen_result = generate_fn(current_topology, mappings)
                logger.info("管道 L1 修复后重新生成: %s", gen_result)
            except Exception as exc:  # noqa: BLE001 - 修复循环需记录并继续
                logger.error("管道 L1 修复后重新生成失败: %s", exc)
            continue

        # L2：LLM 决策修复
        decision = judge_issues(report, context, past_issues)
        fix = decision.get("fix", {})
        action = fix.get("action", "fallback")
        logger.info("管道验证 Agent 决策: action=%s message=%s",
                    action, fix.get("message", ""))
        if action == "fix_topology":
            comps = fix.get("fix", {}).get("components")
            if isinstance(comps, list) and comps:
                current_topology = {"production": production, "components": comps}
        elif action == "start":
            # 启动 Production（Ens 恢复场景：验证通过但 Production 未运行）
            try:
                start_result = iris_connector.class_method_value(
                    "demo.PipelineQuery", "StartProduction", production)
                logger.info("启动 Production: %s", start_result)
            except Exception as exc:  # noqa: BLE001
                logger.error("启动 Production 失败: %s", exc)
        elif action == "fallback":
            # L3 回退默认：规则重建整拓扑（红线审计：AI 决策被规则默认替换，必须显式标注）
            rule_applied = True
            current_topology = _default_topology(
                list(mappings or []), source_type, target_type,
                base_topology=current_topology)

        # 重新生成（L2/L3；none/start 不触发重新生成，start 已单独执行启动）
        if action not in ("none", "start"):
            try:
                gen_result = generate_fn(current_topology, mappings)
                logger.info("第 %d 轮重新生成: %s", round_i + 1, gen_result)
            except Exception as exc:  # noqa: BLE001 - 修复循环需记录并继续
                logger.error("第 %d 轮重新生成失败: %s", round_i + 1, exc)

        # 经验沉淀
        exp = decision.get("experience") or {}
        if exp.get("pattern") and exp.get("resolution"):
            saved = pipeline_validator.save_validation_issue(
                exp["pattern"], exp["resolution"], source="validate-agent")
            logger.info("管道验证经验已沉淀: %s", saved.get("ok"))

    return {"status": "failed", "rounds": rounds_log,
            "topology": current_topology, "mappings": list(mappings or []),
            "report": report, "message": "超过最大修复轮数仍存在问题",
            "rule_applied": rule_applied}
