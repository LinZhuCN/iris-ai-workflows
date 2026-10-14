# -*- coding: utf-8 -*-
"""单元验证：C2 运行期修复的范围、尝试上限和重新验证闭环。"""

import os
import ast
import inspect
import json
import sys
import types
import unittest
from unittest.mock import Mock, patch

# These tests exercise the pure C2 repair loop, not its external clients.
for module_name, attributes in (
    ("dotenv", {"load_dotenv": lambda *args, **kwargs: None}),
    ("iris", {}),
    ("openai", {"OpenAI": type("OpenAI", (), {}),
                "Timeout": type("Timeout", (), {})}),
):
    try:
        __import__(module_name)
    except ImportError:
        stub = types.ModuleType(module_name)
        for name, value in attributes.items():
            setattr(stub, name, value)
        sys.modules[module_name] = stub

from backend.services import pipeline_validator, validate_agent


def runtime_validation():
    return {
        "ok": True,
        "results": {"runtime": {"ok": False, "issues": [
            {"severity": "warning", "message": "[other] transient runtime error"}
        ]}},
        "issues": [],
    }


class C2RuntimeRepairTests(unittest.TestCase):
    def test_incremental_state_consistency_is_per_instance_not_category(self):
        from backend.services import pipeline_generate as gen
        tree = ast.parse(inspect.getsource(gen.generate_multi_pipelines))
        loop = next(node for node in ast.walk(tree) if isinstance(node, ast.For)
                    and isinstance(node.target, ast.Name) and node.target.id == "_rec_state")
        code = compile(ast.fix_missing_locations(ast.Module(body=[loop], type_ignores=[])),
                       "<actual-instance-consistency>", "exec")
        namespace = {"_unchanged_recs": [
            {"id": "USER_DB", "component_names": ["USER_BS", "USER_BP"]},
            {"id": "CLINIC_DB", "component_names": ["CLINIC_BS", "CLINIC_BP"]}],
            "_prod_now": {name: {"enabled": enabled, "category": "sql2db"}
                          for name, enabled in (
                              ("USER_BS", 0), ("USER_BP", 0),
                              ("CLINIC_BS", 1), ("CLINIC_BP", 1))},
            "_inconsistent": []}
        exec(code, namespace)
        self.assertEqual(namespace["_inconsistent"], [])
        namespace["_prod_now"]["CLINIC_BP"]["enabled"] = 0
        exec(code, namespace)
        self.assertEqual(namespace["_inconsistent"], ["CLINIC_DB"])

    def test_incremental_skip_precedes_any_unconditional_production_stop(self):
        from backend.services import pipeline_generate as gen
        source = inspect.getsource(gen.generate_multi_pipelines)
        tree = ast.parse(source).body[0]
        skip = source.index('"render_skipped": True')
        self.assertGreater(source.index("_stop_for_regeneration()\n        topology"), skip)
        unconditional_stops = [
            node for node in tree.body if isinstance(node, ast.Expr)
            and isinstance(node.value, ast.Call)
            and isinstance(node.value.func, ast.Name)
            and node.value.func.id == "reset_ens_messages_for_generate"]
        self.assertEqual(unconditional_stops, [])

    def test_topology_persistence_closes_actual_connection_on_success_and_failure(self):
        from backend.services import pipeline_generate as gen
        for fails in (False, True):
            connection, native = Mock(), Mock()
            if fails:
                native.set.side_effect = RuntimeError("write failed")
            with self.subTest(fails=fails), \
                 patch.object(gen.iris_connector, "get_connection", return_value=connection), \
                 patch("iris.createIRIS", return_value=native, create=True):
                if fails:
                    with self.assertRaisesRegex(RuntimeError, "write failed"):
                        gen.save_pipeline_topology({"components": []})
                else:
                    gen.save_pipeline_topology({"components": []})
                connection.close.assert_called_once()
                native.set.assert_called_once()

    def test_smoke_checks_only_messages_after_checkpoint_without_deleting_history(self):
        messages = [{"id": 10, "status": "Error"}, {"id": 11, "status": "Completed"}]
        with patch.object(pipeline_validator.iris_connector, "class_method_value",
                          return_value=json.dumps(messages)):
            self.assertFalse(pipeline_validator.check_smoke()["ok"])
            self.assertTrue(pipeline_validator.check_smoke(after_id=10)["ok"])

    def test_c1_pipeline_tool_receives_mapping_and_constraint_evidence(self):
        from backend.services import transformation_validator as c1
        maps = [{"id": "M", "source": "Patient", "target_table": "T",
                 "field_mappings": [{"source": "Missing", "target": "ID"}]}]
        with patch.object(pipeline_validator, "run_transformation_validation",
                          return_value={"ok": True, "issues": []}), \
             patch.object(c1, "validate_mapping_against_constraints", return_value={
                 "issues": [{"check": "db_key_value", "severity": "error"}]}), \
             patch.object(c1, "judge_transformation", return_value={
                 "fix": {"action": "none"}}) as judge:
            result = c1.repair_from_pipeline_feedback(
                maps, evidence={}, assets=[], target_models=[])
        self.assertFalse(result["ok"])
        self.assertEqual(judge.call_args.args[1]["mappings"], maps)
        self.assertFalse(judge.call_args.args[0]["ok"])
        self.assertEqual(judge.call_args.args[0]["issues"][0]["check"], "db_key_value")

    def test_method_tool_catalog_excludes_engine_and_generic_bp(self):
        topology = {"components": [{"name": "BP", "type": "PatientTxProcess"}]}
        group = {"component_names": ["BP"], "bp_mode": "engine"}
        evidence = validate_agent._c2_evidence(
            topology, {"issues": []}, "OK", [group], tools_available=True)
        self.assertNotIn("repair_bp", evidence["available_actions"])
        group["bp_mode"] = "full"
        evidence = validate_agent._c2_evidence(
            topology, {"issues": []}, "OK", [group], tools_available=True)
        self.assertIn("repair_bp", evidence["available_actions"])

    def test_single_round_tools_share_budget_and_pass_feedback(self):
        actions = ["repair_mapping", "repair_topology", "repair_bp"]
        seen = []
        def judge(_report, context, _past):
            seen.append(json.loads(json.dumps(context)))
            return {"fix": {"action": actions[len(seen) - 1],
                            "source_id": "S", "target_id": "T"}}
        def tool(action, _fix, topology, _evidence):
            return {"ok": action == "repair_bp", "topology": topology,
                    "audit": {"ok": action == "repair_bp", "message": action}}
        with patch.object(validate_agent, "judge_issues", side_effect=judge):
            calls = []
            result = validate_agent.repair_pipeline_errors(
                {"components": []}, runtime_validation(), {},
                lambda topology: (calls.append(topology) or "OK", {"ok": True}),
                max_attempts=3, execute_repair_tool=tool)
        self.assertEqual(result["status"], "ok")
        self.assertEqual([a["action"] for a in result["attempts"]], actions)
        self.assertEqual(len(calls), 1)
        self.assertEqual(seen[1]["tool_feedback"]["message"], "repair_mapping")
        self.assertEqual(len(seen[1]["previous_attempts"]), 1)
        self.assertNotIn("repair_bp", seen[0]["evidence"]["available_actions"])

    def test_tool_exception_and_terminal_restore_failure_are_explicit(self):
        with patch.object(validate_agent, "judge_issues", return_value={
                "fix": {"action": "repair_bp"}}), \
             patch.object(validate_agent.logger, "exception") as log:
            report = validate_agent.repair_pipeline_errors(
                {}, runtime_validation(), {}, lambda _: self.fail("must not regenerate"),
                max_attempts=1,
                execute_repair_tool=lambda *args: (_ for _ in ()).throw(
                    RuntimeError("private business value")))
        self.assertEqual(report["status"], "failed")
        self.assertNotIn("private business value", str(report["attempts"]))
        log.assert_called_once()
        with patch.object(validate_agent, "judge_issues", return_value={
                "fix": {"action": "repair_bp"}}):
            report = validate_agent.repair_pipeline_errors(
                {}, runtime_validation(), {}, lambda _: self.fail("must not regenerate"),
                execute_repair_tool=lambda *args: {
                    "ok": False, "audit": {"ok": False, "terminal": True,
                                          "message": "restore failed"}})
        self.assertEqual(len(report["attempts"]), 1)
        self.assertEqual(report["message"], "restore failed")

    def test_c1_single_patch_preserves_other_fields_and_identity(self):
        from backend.services import transformation_validator as c1
        maps = [{"id": "M", "source": "Patient", "target_table": "Patient",
                 "target_type": "FHIR", "field_mappings": [
                     {"source": "ID", "target": "PatientNo"},
                     {"source": "Name", "target": "FamilyName", "transform": "identity"}]}]
        decision = {"fix": {"action": "update_mapping", "fix": {"updates": [
            {"id": "M", "field_mappings": [{"source": "Family", "target": "FamilyName"}]}
        ]}}}
        with patch.object(c1, "judge_transformation", return_value=decision) as judge, \
             patch.object(pipeline_validator, "run_transformation_validation",
                          return_value={"ok": True, "issues": []}), \
             patch.object(c1, "validate_mapping_against_constraints",
                          return_value={"ok": True, "issues": []}):
            result = c1.repair_from_pipeline_feedback(
                maps, evidence={"error_codes": ["MissingRequiredProperty"]},
                assets=[], target_models=[])
        self.assertTrue(result["ok"])
        judge.assert_called_once()
        fields = result["mappings"][0]["field_mappings"]
        self.assertEqual(fields[0], maps[0]["field_mappings"][0])
        self.assertEqual(fields[1]["transform"], "identity")
        self.assertEqual(maps[0]["field_mappings"][1]["source"], "Name")
        self.assertEqual(result["mappings"][0]["target_table"], "Patient")

    def test_c1_rejects_identity_change_invalid_constraints_and_unknown_ids(self):
        from backend.services import transformation_validator as c1
        mapping = {"id": "M", "source": "Patient", "target_table": "Patient",
                   "target_type": "FHIR", "field_mappings": [{"target": "ID", "source": "ID"}]}
        for update in (
                {"id": "UNKNOWN", "field_mappings": [{"target": "ID", "source": "No"}]},
                {"id": "M", "source": "Other", "field_mappings": [{"target": "ID", "source": "No"}]},
                {"id": "M", "field_mappings": [{"target": "ID", "source": "No"}]}):
            with self.subTest(update=update), \
                 patch.object(c1, "judge_transformation", return_value={"fix": {
                     "action": "update_mapping", "fix": {"updates": [update]}}}), \
                 patch.object(pipeline_validator, "run_transformation_validation",
                              return_value={"ok": True, "issues": []}), \
                 patch.object(c1, "validate_mapping_against_constraints", return_value={
                     "ok": False, "issues": [{"severity": "error", "check": "required"}]}):
                result = c1.repair_from_pipeline_feedback(
                    [mapping], evidence={}, assets=[], target_models=[])
            self.assertFalse(result["ok"])
            self.assertEqual(mapping["field_mappings"][0]["source"], "ID")

    @staticmethod
    def group_fixture():
        topology = {"components": [
            {"name": "BS", "type": "SQLService", "className": "Bad.Source", "settings": [
                {"target": "Host", "name": "TargetConfigNames", "value": "Missing"},
                {"target": "Adapter", "name": "Query", "value": "SELECT private"}]},
            {"name": "BP", "type": "TransformProcess", "className": "demo.TransformProcess"},
            {"name": "BO", "type": "SQLOperation",
             "className": "EnsLib.SQL.Operation.GenericOperation"},
            {"name": "OTHER", "type": "TransformProcess", "className": "demo.TransformProcess"}]}
        group = {"source_id": "S", "target_id": "T", "source_type": "SQL",
                 "target_type": "DB", "_own_names": ["BS", "BP", "BO"],
                 "mappings": [], "_rt_src": {"connection": {"dsn": "USER"}}}
        return topology, group

    def test_agent_b_corrects_class_and_dispatch_without_changing_other_groups(self):
        from backend.services import pipeline_generate as gen
        topology, group = self.group_fixture()
        proposal = {"pipeline": {"components": [
            {"name": "BS", "type": "SQLService",
             "className": "EnsLib.SQL.Service.GenericService", "settings": [
                 {"target": "Host", "name": "TargetConfigNames", "value": "BP"},
                 {"target": "Adapter", "name": "Query", "value": "[HIDDEN]"}]},
            {"name": "BP"}, {"name": "BO"}]}}
        with patch.object(gen.llm_client, "recommend_pipeline", return_value=proposal) as llm, \
             patch.object(gen, "c1_assets", return_value=[]), \
             patch.object(gen, "c1_target_models", return_value=[]):
            result = gen.execute_c2_group_repair(
                "repair_topology", {"source_id": "S", "target_id": "T"}, topology, {}, [group])
        self.assertTrue(result["ok"])
        llm.assert_called_once()
        self.assertNotIn("SELECT private", str(llm.call_args))
        candidate = result["topology"]["components"]
        self.assertEqual(candidate[0]["className"], "EnsLib.SQL.Service.GenericService")
        self.assertEqual(candidate[0]["settings"][1]["value"], "SELECT private")
        self.assertEqual(candidate[-1], topology["components"][-1])
        self.assertEqual(topology["components"][0]["className"], "Bad.Source")

    def test_agent_b_rejects_cross_group_dispatch_query_changes_and_component_removal(self):
        from backend.services import pipeline_generate as gen
        for setting in (
                {"target": "Host", "name": "TargetConfigNames", "value": "OTHER"},
                {"target": "Host", "name": "TargetConfigNames", "value": "BO"},
                {"target": "Adapter", "name": "Query", "value": "SELECT different"},
                None):
            topology, group = self.group_fixture()
            proposed = [{"name": "BS", "settings": [setting]}] if setting else []
            if setting:
                proposed += [{"name": "BP"}, {"name": "BO"}]
            with self.subTest(setting=setting), \
                 patch.object(gen.llm_client, "recommend_pipeline",
                              return_value={"pipeline": {"components": proposed}}), \
                 patch.object(gen, "c1_assets", return_value=[]), \
                 patch.object(gen, "c1_target_models", return_value=[]):
                result = gen.execute_c2_group_repair(
                    "repair_topology", {"source_id": "S", "target_id": "T"}, topology, {}, [group])
            self.assertFalse(result["ok"])

    def test_tools_reject_missing_identity_and_suspended_groups(self):
        from backend.services import pipeline_generate as gen
        topology, group = self.group_fixture()
        with patch.object(gen.llm_client, "recommend_pipeline") as llm:
            result = gen.execute_c2_group_repair("repair_topology", {}, topology, {}, [group])
            self.assertFalse(result["ok"])
            topology["components"][0]["enabled"] = False
            result = gen.execute_c2_group_repair(
                "repair_topology", {"source_id": "S", "target_id": "T"}, topology, {}, [group])
            self.assertFalse(result["ok"])
        llm.assert_not_called()

    def test_generated_method_repair_rejects_engine_and_inherited_fault_locations(self):
        from backend.services import generated_bp as bp
        source = ("Class demo.SqlFhirPatientTxProcess Extends demo.TransformProcess\n{\n"
                  "Method OnRequest() As %Status\n{\n Quit 1\n}\n}")
        for mode, location in (("engine", "OnRequest+1^demo.SqlFhirPatientTxProcess.1"),
                               ("plan", "ProcessChildLevel+1^demo.TransformProcess.1"),
                               ("full", "NoMethod+1^demo.SqlFhirPatientTxProcess.1")):
            with self.subTest(mode=mode), \
                 patch.object(bp, "get_generated_source", return_value=source), \
                 patch.object(bp.llm_client, "recommend_pipeline") as llm:
                result = bp.repair_generated_methods_once(
                    class_name=bp.BP_CLASS_NAME, bp_mode=mode,
                    evidence={"code_locations": [location]}, mappings=[], components=[],
                    layout={}, component_name="BP")
            self.assertFalse(result["ok"])
            llm.assert_not_called()

    def test_group_tool_refuses_mutating_a_generated_class_shared_by_other_pipeline(self):
        from backend.services import generated_bp as bp, pipeline_generate as gen
        topology, group = self.group_fixture()
        topology["components"][1].update(type="PatientTxProcess", className=bp.BP_CLASS_NAME)
        topology["components"][-1]["className"] = bp.BP_CLASS_NAME
        group["_bp_meta"] = {"bp_mode": "plan"}
        with patch.object(bp, "repair_generated_methods_once") as method_tool:
            result = gen.execute_c2_group_repair(
                "repair_bp", {"source_id": "S", "target_id": "T"}, topology, {}, [group])
        self.assertFalse(result["ok"])
        self.assertIn("多管道共用", result["audit"]["message"])
        method_tool.assert_not_called()

    def test_failed_method_rollback_terminates_and_does_not_restart_broken_host(self):
        from backend.services import generated_bp as bp
        source = ("Class demo.SqlFhirPatientTxProcess Extends demo.TransformProcess\n{\n"
                  "Method OnRequest() As %Status\n{\n Quit 0\n}\n}")
        with patch.object(bp, "get_generated_source", return_value=source), \
             patch.object(bp.llm_client, "recommend_pipeline", return_value={
                 "pipeline": {}, "generated_bp": {"class_name": bp.BP_CLASS_NAME,
                 "method_updates": [{"name": "OnRequest",
                                     "source": "Method OnRequest() As %Status\n{\n Quit 1\n}"}]}}), \
             patch.object(bp, "_write_and_compile", side_effect=[
                 {"ok": False, "message": "ERROR #5373 private Jane"}, {"ok": False}]), \
             patch.object(pipeline_validator, "set_items_enabled",
                          return_value={"ok": True}) as toggle:
            result = bp.repair_generated_methods_once(
                class_name=bp.BP_CLASS_NAME, bp_mode="full",
                evidence={"code_locations": ["OnRequest+1^" + bp.BP_CLASS_NAME + ".1"]},
                mappings=[], components=[], layout={}, component_name="BP")
        self.assertFalse(result["ok"])
        self.assertTrue(result["terminal"])
        self.assertFalse(result["restored"])
        toggle.assert_called_once_with(["BP"], False)
        self.assertEqual(result["compile_evidence"]["error_codes"], ["ERROR #5373"])
        self.assertNotIn("Jane", str(result))

    def test_method_repair_single_llm_static_admission_compile_and_rollback(self):
        from backend.services import generated_bp as bp
        source = ("Class demo.SqlFhirPatientTxProcess Extends demo.TransformProcess\n{\n"
                  "Method OnRequest() As %Status\n{\n Quit 0\n}\n}")
        body = "Method OnRequest() As %Status\n{\n Quit 1\n}"
        for success in (True, False):
            with self.subTest(success=success), \
                 patch.object(bp, "get_generated_source", return_value=source), \
                 patch.object(bp.llm_client, "recommend_pipeline", return_value={
                     "pipeline": {}, "generated_bp": {"class_name": bp.BP_CLASS_NAME,
                     "method_updates": [{"name": "OnRequest", "source": body}]}}) as llm, \
                 patch.object(bp, "_write_and_compile", side_effect=(
                     [{"ok": True}] if success else [{"ok": False}, {"ok": True}])) as compile_bp, \
                 patch.object(pipeline_validator, "set_items_enabled", return_value={"ok": True}) as toggle:
                result = bp.repair_generated_methods_once(
                    class_name=bp.BP_CLASS_NAME, bp_mode="plan",
                    evidence={"code_locations": ["OnRequest+1^" + bp.BP_CLASS_NAME + ".1"]},
                    mappings=[], components=[], layout={}, component_name="BP")
            self.assertEqual(result["ok"], success)
            llm.assert_called_once()
            self.assertEqual(compile_bp.call_count, 1 if success else 2)
            self.assertEqual(toggle.call_args_list[0].args, (["BP"], False))
            self.assertEqual(toggle.call_args_list[-1].args, (["BP"], True))
            if not success:
                self.assertEqual(compile_bp.call_args.args[1], source)
                self.assertTrue(result["restored"])

    def test_method_patch_cannot_inject_extra_methods_or_change_signature(self):
        from backend.services import generated_bp as bp
        source = ("Class demo.SqlFhirPatientTxProcess Extends demo.TransformProcess\n{\n"
                  "Method OnRequest() As %Status\n{\n Quit 0\n}\n}")
        for body in ("Method OnRequest() As %String\n{\n Quit 1\n}",
                     "Method OnRequest() As %Status\n{\n Quit 1\n}\nMethod Other()\n{\n Quit\n}",
                     "Method OnRequest() As %Status\n{\n xecute \"bad\"\n}"):
            with self.subTest(body=body), \
                 patch.object(bp, "get_generated_source", return_value=source), \
                 patch.object(bp.llm_client, "recommend_pipeline", return_value={
                     "pipeline": {}, "generated_bp": {"class_name": bp.BP_CLASS_NAME,
                     "method_updates": [{"name": "OnRequest", "source": body}]}}), \
                 patch.object(bp, "_write_and_compile") as compile_bp:
                result = bp.repair_generated_methods_once(
                    class_name=bp.BP_CLASS_NAME, bp_mode="full",
                    evidence={"code_locations": ["OnRequest+1^" + bp.BP_CLASS_NAME + ".1"]},
                    mappings=[], components=[], layout={}, component_name="BP")
            self.assertFalse(result["ok"])
            compile_bp.assert_not_called()

    def test_effect_requires_new_completed_paths_not_old_success_or_other_group(self):
        for rows, expected in (([], False), ([("OTHER", "OTHERBO", 9)], False),
                               ([("BS", "BP", 9)], False),
                               ([("BS", "OTHER", 9), ("BP", "BO", 9)], False),
                               ([("BS", "BP", 9), ("BP", "BO", 9)], True),
                               ([("BS", "BP", 9), ("BP", "BO", 9), ("BP", "BO", 8)], False)):
            with self.subTest(rows=rows), patch.object(
                    pipeline_validator.iris_connector, "query", return_value=rows) as query:
                report = pipeline_validator.check_repair_effect(["BS", "BP", "BO"], 100)
            self.assertEqual(report["ok"], expected)
            self.assertEqual(query.call_args.args[1], [100])

    def test_actual_generation_tool_refreshes_mappings_and_requires_new_path(self):
        from backend.services import pipeline_generate as gen, transformation_validator as c1
        tree = ast.parse(inspect.getsource(gen.generate_multi_pipelines))
        entry = next(n for n in ast.walk(tree) if isinstance(n, ast.FunctionDef)
                     and n.name == "_repair_with_c2")
        wrapper = ast.parse(
            "def run(result, validation, topology, groups, callback):\n"
            "    c2_report = {}\n"
            "    _src_types = ['SQL']\n"
            "    _tgt_types = ['DB']\n"
            "    _gen_and_validate = callback\n"
            "    mappings_json = '[]'\n"
            "    all_mappings = []\n").body[0]
        wrapper.body.append(entry)
        wrapper.body.extend(ast.parse(
            "_repair_with_c2()\nreturn c2_report, mappings_json\n").body)
        namespace = dict(vars(gen))
        exec(compile(ast.fix_missing_locations(ast.Module(
            body=[wrapper], type_ignores=[])), "<actual-c2-tool-entry>", "exec"), namespace)
        for has_path in (False, True):
            topology, group = self.group_fixture()
            group["mappings"] = [{"id": "M", "source": "Patient", "target_table": "Patient",
                                  "target_type": "DB", "field_mappings": [
                                      {"source": "Bad", "target": "PatientNo"}]}]
            corrected = json.loads(json.dumps(group["mappings"]))
            corrected[0]["field_mappings"][0]["source"] = "ID"
            with self.subTest(has_path=has_path), \
                 patch.object(validate_agent, "judge_issues", return_value={"fix": {
                     "action": "repair_mapping", "source_id": "S", "target_id": "T"}}), \
                 patch.object(c1, "repair_from_pipeline_feedback",
                              return_value={"ok": True, "mappings": corrected}) as tool, \
                 patch.object(gen, "c1_assets", return_value=[]), \
                 patch.object(gen, "c1_target_models", return_value=[]), \
                 patch.object(gen, "write_mapping_patch") as write, \
                 patch.object(gen, "save_fhir_runtime_config"), \
                 patch.object(pipeline_validator, "latest_message_id", return_value=100), \
                 patch.object(pipeline_validator, "check_repair_effect", return_value={
                     "ok": has_path, "issues": [] if has_path else [{
                         "severity": "error", "item": "repair_effect", "message": "no new path"}]}) as effect:
                report, payload = namespace["run"](
                    "OK", runtime_validation(), topology, [group],
                    lambda _: ("OK", {"ok": True, "results": {}, "issues": []}))
            self.assertEqual(report["status"], "ok" if has_path else "failed")
            self.assertEqual(json.loads(payload), corrected)
            self.assertEqual(group["mappings"], corrected)
            self.assertEqual(write.call_args.args[0], corrected[0])
            self.assertEqual(effect.call_args.args, (["BS", "BP", "BO"], 100))
            self.assertEqual(tool.call_count, 1 if has_path else 3)
            self.assertFalse(group["_unchanged"])

    def test_http_failure_preserves_c2_evidence_and_budget_audit(self):
        from flask import Flask
        from backend.routes import pipelines
        app = Flask(__name__)
        app.register_blueprint(pipelines.pipelines_bp)
        report = {
            "status": "failed", "attempt_limit": 3,
            "attempts": [{"attempt": 1, "action": "none", "applied": False}],
            "message": "compile failure outside current repair scope",
            "evidence": {"failed_checks": ["compile"], "error_codes": ["ERROR #5373"]},
        }
        with patch.object(pipelines, "_generate_multi_pipelines", return_value={
                "result": "ERROR", "validation": {"ok": False}, "c2": report}):
            response = app.test_client().post(
                "/api/pipelines/generate", json={"pipelines": [{"source_id": "TEST"}]})
        self.assertEqual(response.status_code, 500)
        body = response.get_json()
        self.assertEqual(body["code"], 1)
        self.assertEqual(body["data"]["c2"], report)
        self.assertFalse(body["data"]["validation"]["ok"])

    def test_generation_and_validation_exceptions_become_explicit_blocking_reports(self):
        from backend.services import pipeline_generate
        tree = ast.parse(inspect.getsource(pipeline_generate.generate_multi_pipelines))
        entry = next(node for node in ast.walk(tree)
                     if isinstance(node, ast.FunctionDef) and node.name == "_gen_and_validate")
        wrapper = ast.parse(
            "def run():\n"
            "    topology = {'components': []}\n"
            "    mappings_json = '[]'\n"
            "    config_json = '{}'\n"
            "    _src_types = ['SQL']\n"
            "    _tgt_types = ['FHIR']\n"
            "    _expect_targets = {}\n"
            "    _active_tgt_types = ['FHIR']\n"
        ).body[0]
        wrapper.body.append(entry)
        wrapper.body.extend(ast.parse("return _gen_and_validate()\n").body)
        namespace = {
            "logger": pipeline_generate.logger, "pipeline_validator": pipeline_validator,
            "iris_connector": pipeline_generate.iris_connector,
        }
        exec(compile(ast.fix_missing_locations(ast.Module(
            body=[wrapper], type_ignores=[])), "<actual-generation-check>", "exec"), namespace)
        for stage in ("generation", "validation"):
            with self.subTest(stage=stage), \
                 patch.object(pipeline_validator, "latest_runtime_error_id", return_value=0), \
                 patch.object(pipeline_validator, "latest_message_id", return_value=0), \
                 patch.object(pipeline_generate.iris_connector, "class_method_value",
                              side_effect=RuntimeError("compile failed")
                              if stage == "generation" else None, return_value="OK"), \
                 patch.object(pipeline_validator, "run_pipeline_validation",
                              side_effect=RuntimeError("probe unavailable")), \
                 patch.object(pipeline_generate.logger, "exception") as log:
                result, validation = namespace["run"]()
            self.assertEqual(result, "ERROR")
            self.assertFalse(validation["ok"])
            self.assertEqual(validation["issues"][0]["check"], stage)
            self.assertTrue(validate_agent.has_blocking_failure(validation, result))
            log.assert_called_once()

    def test_actual_generation_entry_routes_all_failures_through_same_budget(self):
        from backend.services import pipeline_generate
        source = inspect.getsource(pipeline_generate.generate_multi_pipelines)
        tree = ast.parse(source)
        entry = next(node for node in ast.walk(tree)
                     if isinstance(node, ast.FunctionDef) and node.name == "_repair_with_c2")
        wrapper = ast.parse(
            "def run(result, validation, topology, groups, callback):\n"
            "    c2_report = {}\n"
            "    _src_types = ['SQL']\n"
            "    _tgt_types = ['FHIR']\n"
            "    _gen_and_validate = callback\n"
            "    mappings_json = '[]'\n"
            "    all_mappings = []\n"
        ).body[0]
        wrapper.body.append(entry)
        wrapper.body.extend(ast.parse(
            "_repair_with_c2()\nreturn result, validation, c2_report\n").body)
        namespace = {"logger": pipeline_generate.logger}
        exec(compile(ast.fix_missing_locations(ast.Module(
            body=[wrapper], type_ignores=[])), "<actual-generation-entry>", "exec"), namespace)
        for check in ("pipeline", "compile", "start", "smoke", "target_effect"):
            validation = {"ok": False, "results": {check: {"ok": False}}, "issues": []}
            with self.subTest(check=check), \
                 patch.object(validate_agent, "judge_issues", return_value={
                     "fix": {"action": "rebuild"}
                 }) as judge:
                callbacks = []
                def revalidate(_topology):
                    callbacks.append(1)
                    return "OK", validation
                result, final, report = namespace["run"](
                    "ERROR" if check == "compile" else "OK", validation,
                    {"components": []}, [], revalidate)
            self.assertEqual(judge.call_count, 3)
            self.assertEqual(len(callbacks), 1)
            self.assertEqual(result, "OK")
            self.assertEqual(report["status"], "failed")
            self.assertFalse(final["ok"])
            self.assertEqual(final["c2"]["attempt_limit"], 3)
            self.assertIn(check, final["c2"]["evidence"]["failed_checks"])
        self.assertNotIn("_repair_runtime_with_c2", source)
        self.assertNotIn("自动重建一次", source)

    def test_only_updates_existing_enabled_component_settings(self):
        topology = {"components": [{
            "name": "SQLService", "type": "SQLService",
            "className": "EnsLib.SQL.Service.GenericService",
            "category": "sql2db", "settings": [
                {"target": "Adapter", "name": "CallInterval", "value": 5},
                {"target": "Adapter", "name": "Query", "value": "SELECT 1"},
            ],
        }]}
        updated, error = validate_agent._apply_runtime_setting_updates(
            topology, [{"component_name": "SQLService", "target": "Adapter",
                        "name": "CallInterval", "value": 10}])
        self.assertFalse(error)
        self.assertEqual(updated["components"][0]["settings"][0]["value"], 10)
        self.assertEqual(topology["components"][0]["settings"][0]["value"], 5)

        _, error = validate_agent._apply_runtime_setting_updates(
            topology, [{"component_name": "SQLService", "target": "Adapter",
                        "name": "UnknownSetting", "value": 10}])
        self.assertIn("未知设置", error)

        _, error = validate_agent._apply_runtime_setting_updates(
            topology, [{"component_name": "OtherService", "target": "Adapter",
                        "name": "CallInterval", "value": 10}])
        self.assertIn("不存在的组件", error)
        _, error = validate_agent._apply_runtime_setting_updates(
            {"components": [{"name": "SOAPOperation", "settings": [
                {"target": "Adapter", "name": "Password", "value": "private"}
            ]}]},
            [{"component_name": "SOAPOperation", "target": "Adapter",
              "name": "Password", "value": "attacker-controlled"}])
        self.assertIn("凭据设置", error)
        _, error = validate_agent._apply_runtime_setting_updates(
            topology, [{"component_name": "SQLService", "target": "Adapter",
                        "name": "Query", "value": "SELECT 1"}])
        self.assertIn("非运行参数设置", error)

    def test_llm_context_redacts_credentials_and_raw_runtime_text(self):
        topology = {"components": [{
            "name": "SOAPOperation", "settings": [
                {"target": "Adapter", "name": "Password", "value": "private"},
                {"target": "Adapter", "name": "WebServiceURL",
                 "value": "https://user:pass@service/path?token=secret"},
            ],
        }]}
        safe_topology = validate_agent._redact_c2_topology(topology)
        self.assertEqual(
            safe_topology["components"][0]["settings"][0]["value"], "[REDACTED]")
        self.assertEqual(
            safe_topology["components"][0]["settings"][1]["value"],
            "[REDACTED]")
        safe_report = validate_agent._c2_validation_for_llm({
            "results": {"runtime": {"kinds": ["other"], "issues": [{
                "item": "SOAPOperation",
                "message": "[other] Patient Jane Doe failed | 建议: 检查配置",
            }]}},
        })
        self.assertNotIn("Jane Doe", str(safe_report))
        self.assertIn("检查配置", str(safe_report))
        _, error = validate_agent._apply_runtime_setting_updates(
            topology, [{"component_name": "SOAPOperation", "target": "Adapter",
                        "name": "WebServiceURL", "value": "https://service/path"}])
        self.assertIn("凭据设置", error)

    def test_attempt_limit_configuration(self):
        with patch.dict(os.environ, {"C2_MAX_ATTEMPTS": "4"}):
            self.assertEqual(validate_agent.runtime_repair_attempt_limit(), 4)
        with patch.dict(os.environ, {"C2_MAX_ATTEMPTS": "11"}):
            with self.assertRaises(ValueError):
                validate_agent.runtime_repair_attempt_limit()

    def test_unresolved_runtime_error_fails_after_configured_attempts(self):
        with patch.object(pipeline_validator, "load_validation_issues", return_value=[]), \
             patch.object(validate_agent, "judge_issues", return_value={
                 "fix": {"action": "none", "message": "no safe setting change"}
             }) as judge:
            report = validate_agent.repair_runtime_errors(
                {"components": []}, runtime_validation(), {},
                regenerate_and_validate=lambda _topology: self.fail(
                    "none must not regenerate"),
                max_attempts=3)
        self.assertEqual(report["status"], "failed")
        self.assertEqual(report["attempt_limit"], 3)
        self.assertEqual(len(report["attempts"]), 3)
        self.assertEqual(judge.call_count, 3)

    def test_missing_new_logs_does_not_hide_generation_or_validation_failure(self):
        decision = {"fix": {"action": "rebuild"}}
        for generation_result, validation_ok in (("ERROR", True), ("OK", False)):
            with self.subTest(result=generation_result, ok=validation_ok), \
                 patch.object(validate_agent, "judge_issues", return_value=decision), \
                 patch.object(pipeline_validator, "save_validation_issue") as save:
                report = validate_agent.repair_runtime_errors(
                    {"components": []}, runtime_validation(), {},
                    regenerate_and_validate=lambda _topology: (
                        generation_result, {
                            "ok": validation_ok,
                            "results": {"runtime": {"ok": True, "issues": []}},
                        }),
                    max_attempts=3)
            self.assertEqual(report["status"], "failed")
            self.assertEqual(len(report["attempts"]), 3)
            save.assert_not_called()

    def test_all_blocking_checks_enter_c2_without_runtime_logs(self):
        for check in ("pipeline", "compile", "start", "smoke", "target_effect"):
            validation = {
                "ok": False, "error_count": 1,
                "results": {check: {"ok": False}},
                "issues": [{"check": check, "severity": "error", "item": "TestBP"}],
            }
            with self.subTest(check=check), \
                 patch.object(validate_agent, "judge_issues", return_value={
                     "fix": {"action": "none", "terminal": True, "message": "tool unavailable"}
                 }) as judge:
                report = validate_agent.repair_runtime_errors(
                    {"components": []}, validation, {},
                    lambda _: self.fail("must not rebuild"), max_attempts=3)
            self.assertEqual(report["status"], "failed")
            self.assertEqual(judge.call_count, 1)
            self.assertIn(check, report["evidence"]["failed_checks"])
            self.assertIn(check, judge.call_args.args[0]["results"])

    def test_generation_failure_enters_c2_even_when_validation_passes(self):
        with patch.object(validate_agent, "judge_issues", return_value={
            "fix": {"action": "none"}
        }) as judge:
            report = validate_agent.repair_runtime_errors(
                {"components": []}, {"ok": True, "results": {}, "issues": []}, {},
                lambda _: self.fail("must not rebuild"),
                max_attempts=3, generation_result="ERROR secret business value")
        self.assertEqual(judge.call_count, 3)
        self.assertEqual(report["status"], "failed")
        self.assertFalse(report["evidence"]["generation_ok"])
        self.assertNotIn("secret business value", str(judge.call_args))

    def test_warning_only_does_not_call_c2(self):
        with patch.object(validate_agent, "judge_issues") as judge:
            report = validate_agent.repair_runtime_errors(
                {"components": []}, {"ok": True, "results": {
                    "settle": {"ok": False, "level": "warning"}}, "issues": [
                        {"check": "settle", "severity": "warning"}]}, {},
                lambda _: self.fail("must not rebuild"))
        judge.assert_not_called()
        self.assertEqual(report["status"], "ok")

    def test_next_decision_receives_updated_evidence_and_history(self):
        calls = []
        def judge(report, context, _past):
            calls.append(context)
            return {"fix": {"action": "rebuild"}}
        validation = {"ok": False, "results": {"compile": {"ok": False}}, "issues": []}
        with patch.object(validate_agent, "judge_issues", side_effect=judge):
            report = validate_agent.repair_runtime_errors(
                {"components": []}, validation, {},
                lambda _: ("OK", {"ok": False, "results": {"start": {"ok": False}},
                                  "issues": []}), max_attempts=3)
        self.assertEqual(len(report["attempts"]), 3)
        self.assertIn("compile", calls[0]["evidence"]["failed_checks"])
        self.assertIn("start", calls[1]["evidence"]["failed_checks"])
        self.assertEqual(len(calls[1]["previous_attempts"]), 1)
        self.assertEqual(sum(a.get("applied", False) for a in report["attempts"]), 1)

    def test_evidence_never_sends_original_logs_queries_or_business_values(self):
        validation = {"ok": False, "results": {"compile": {
            "ok": False, "message": "ERROR #5373 Patient Jane private secret",
        }, "runtime": {"ok": False, "issues": [{
            "message": "[bp_code] <UNDEFINED> Jane | 建议: private secret",
        }]}}, "issues": []}
        evidence = validate_agent._c2_evidence(
            {"components": []}, validation, "private secret", [])
        self.assertEqual(evidence["error_codes"], ["<UNDEFINED>", "ERROR #5373"])
        self.assertNotIn("Jane", str(evidence))
        self.assertNotIn("private secret", str(evidence))
        topology = validate_agent._redact_c2_topology({"components": [{
            "name": "Test", "comment": "Jane", "settings": [
                {"name": "Query", "value": "SELECT 'Jane'"},
                {"name": "Password", "value": "private secret"},
            ]}]})
        self.assertNotIn("Jane", str(topology))
        self.assertNotIn("private secret", str(topology))

    def test_only_records_verified_successful_experience(self):
        decision = {"fix": {"action": "rebuild"},
                    "experience": {"pattern": "transient", "resolution": "rebuild"}}
        for resolved in (False, True):
            with self.subTest(resolved=resolved), \
                 patch.object(validate_agent, "judge_issues", return_value=decision), \
                 patch.object(pipeline_validator, "save_validation_issue") as save:
                report = validate_agent.repair_runtime_errors(
                    {"components": []}, runtime_validation(), {},
                    regenerate_and_validate=lambda _topology: (
                        "OK", {"ok": True, "results": {
                            "runtime": {"ok": resolved, "issues": []}
                            if resolved else runtime_validation()["results"]["runtime"]}}),
                    max_attempts=1)
            self.assertEqual(report["status"], "ok" if resolved else "failed")
            self.assertEqual(save.call_count, int(resolved))

    def test_revalidates_after_setting_update_and_stops_when_resolved(self):
        topology = {"components": [{
            "name": "SQLService", "type": "SQLService",
            "className": "EnsLib.SQL.Service.GenericService",
            "category": "sql2db", "settings": [
                {"target": "Adapter", "name": "CallInterval", "value": 5}
            ],
        }]}
        decision = {"fix": {
            "action": "update_settings",
            "fix": {"updates": [{
                "component_name": "SQLService", "target": "Adapter",
                "name": "CallInterval", "value": 10,
            }]},
        }}
        resolved = {"ok": True, "results": {"runtime": {"ok": True, "issues": []}}}
        with patch.object(pipeline_validator, "load_validation_issues", return_value=[]), \
             patch.object(validate_agent, "judge_issues", return_value=decision), \
             patch.object(pipeline_validator, "save_validation_issue"):
            report = validate_agent.repair_runtime_errors(
                topology, runtime_validation(), {},
                regenerate_and_validate=lambda candidate: ("OK", resolved),
                max_attempts=3)
        self.assertEqual(report["status"], "ok")
        self.assertEqual(len(report["attempts"]), 1)
        self.assertEqual(
            report["topology"]["components"][0]["settings"][0]["value"], 10)

    def test_retries_generation_until_limit_then_returns_failure_audit(self):
        topology = {"components": [{
            "name": "SQLService", "type": "SQLService",
            "className": "EnsLib.SQL.Service.GenericService",
            "category": "sql2db", "settings": [
                {"target": "Adapter", "name": "CallInterval", "value": 5}
            ],
        }]}

        def decision(report, _context, _past_issues):
            current = report["c2_feedback"] if "c2_feedback" in report else ""
            value = 10 if not current else int(current.rsplit("=", 1)[-1]) + 1
            return {"fix": {
                "action": "update_settings",
                "fix": {"updates": [{
                    "component_name": "SQLService", "target": "Adapter",
                    "name": "CallInterval", "value": value,
                }]},
            }}

        calls = []

        def regenerate(candidate):
            calls.append(candidate["components"][0]["settings"][0]["value"])
            unresolved = runtime_validation()
            unresolved["c2_feedback"] = (
                f"上次设置仍失败，CallInterval={candidate['components'][0]['settings'][0]['value']}")
            return "OK", unresolved

        with patch.object(pipeline_validator, "load_validation_issues", return_value=[]), \
             patch.object(validate_agent, "judge_issues", side_effect=decision):
            report = validate_agent.repair_runtime_errors(
                topology, runtime_validation(), {},
                regenerate_and_validate=regenerate, max_attempts=3)
        self.assertEqual(report["status"], "failed")
        self.assertEqual(report["attempt_limit"], 3)
        self.assertEqual(len(report["attempts"]), 3)
        self.assertEqual(calls, [10, 11, 12])
        self.assertIn("尝试上限（3 次）", report["message"])


if __name__ == "__main__":
    unittest.main()
