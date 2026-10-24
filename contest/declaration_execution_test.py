#!/usr/bin/env python3
"""D4 explicit installation, local host reload and read-only execution verification; never infers or sends."""
import argparse
import json

from business_privacy import require
from declaration_review_test import BASE
from platform_test import request
from route_ui_test import admin_request, local_base
from utilization_test import MARKER, execute


def install():
    paths = ["/contest/src/" + name + ".cls" for name in
             ("DeclarationCatalog", "DeclarationService", "DeclarationExecution", "KnowledgeAPI")]
    paths += ["/contest/dev/DeclarationTests.cls", "/contest/dev/DeclarationExecutionTests.cls"]
    for namespace, files in (
        ("TRIAGE", paths),
        ("UTILIZATION", ["/contest/utilization/" + name + ".cls" for name in
                         ("DeclarationBridge", "Runtime", "Process", "Receiver")]),
    ):
        code = "For path=" + ",".join(json.dumps(path) for path in files) + (
            ' { Set sc=$SYSTEM.OBJ.Load(path,"ck") '
            'If $SYSTEM.Status.IsError(sc) { Throw ##class(%Exception.StatusException).CreateFromStatus(sc) } } ')
        execute(namespace, code + f'Write "{MARKER}",{{"compiled":true}}.%ToJSON(),!')
    print("Compiled D4. No host restart, Production restart, delivery, credential change or model call.")


def reload_hosts():
    code = (
        'Set sc=##class(Ens.Director).GetProductionStatus(.name,.state) '
        'If $SYSTEM.Status.IsError(sc) { Throw ##class(%Exception.StatusException).CreateFromStatus(sc) } '
        'If (name\'="Contest.Utilization.Production")||(state\'=1) { Do ##class(Demo.Protocol).Fail("Expected running utilization Production") } '
        'If ##class(Ens.Director).ProductionNeedsUpdate(.reason) { Do ##class(Demo.Protocol).Fail("Unrelated pending Production update: "_reason) } '
        'Set changed=[] '
        'Try { '
        'For item="UtilizationProcess","AnalysisReceiver" { '
        'Set sc=##class(Ens.Director).TempStopConfigItem("Contest.Utilization.Production||"_item,1,0) '
        'If $SYSTEM.Status.IsError(sc) { Throw ##class(%Exception.StatusException).CreateFromStatus(sc) } '
        'Do changed.%Push(item) } '
        'Set sc=##class(Ens.Director).UpdateProduction(30,0) '
        'If $SYSTEM.Status.IsError(sc) { Throw ##class(%Exception.StatusException).CreateFromStatus(sc) } '
        '} Catch ex { '
        'For i=0:1:changed.%Size()-1 { '
        'Set resume=##class(Ens.Director).TempStopConfigItem("Contest.Utilization.Production||"_changed.%Get(i),0,0) '
        'If $SYSTEM.Status.IsError(resume) { Write $SYSTEM.Status.GetErrorText(resume),! } } '
        'Set resume=##class(Ens.Director).UpdateProduction(30,0) '
        'If $SYSTEM.Status.IsError(resume) { Write $SYSTEM.Status.GetErrorText(resume),! } '
        'Throw ex } '
        'For item="AnalysisReceiver","UtilizationProcess" { '
        'Set sc=##class(Ens.Director).TempStopConfigItem("Contest.Utilization.Production||"_item,0,0) '
        'If $SYSTEM.Status.IsError(sc) { Throw ##class(%Exception.StatusException).CreateFromStatus(sc) } } '
        'Set sc=##class(Ens.Director).UpdateProduction(30,0) '
        'If $SYSTEM.Status.IsError(sc) { Throw ##class(%Exception.StatusException).CreateFromStatus(sc) } '
    )
    execute("UTILIZATION", code + f'Write "{MARKER}",{{"reloaded_hosts":2,"production_restart":false}}.%ToJSON(),!')
    print("Locally reloaded only UtilizationProcess and AnalysisReceiver. No batch replay or delivery.")


def check(base, record_id):
    require(request(base, "/declarations/execute", body={})[0] == 403, "Readers cannot execute")
    require(request(base, f"/declarations/{record_id}/execution-plan?batch_id=boundary-only")[0] == 403,
            "Readers cannot prepare execution grants")
    status, record = admin_request(base, "/declarations/" + record_id)
    require(status == 200, "Exact declaration required")
    status, history = admin_request(base, "/declarations/" + record_id + "/executions")
    require(status == 200 and history["record_id"] == record_id and history["model_calls"] == 0,
            "Real read-only execution history required")
    require(not history["next_cursor"], "Acceptance must account for complete bounded history")
    output = []
    for run in history["items"]:
        status, current = admin_request(base, "/declarations/executions/" + run["id"])
        require(status == 200 and current == run, "Detail and history must agree")
        require(run["grant"]["record"]["id"] == record_id and run["grant"]["record"]["digest"] == record["digest"],
                "Exact immutable declaration grant required")
        require(run["model_calls"] == 0 and run["monitoring_state"] == "automatic_observer", "No invented inference")
        receipt = run["receipt"]
        if run["state"] == "delivered":
            require(receipt and receipt["receiver_readback_match"] is True, "Verified SQL receiver readback required")
            require(receipt["declaration_binding"]["decision_hash"] == record["decision"]["record_hash"] and
                    receipt["declaration_binding"]["task_hash"] == record["review"]["task"]["record_hash"],
                    "Exact review and human approval binding required")
            require(receipt["inspection"]["resource_counts"] == {"Patient": 2, "Encounter": 2, "Condition": 0, "MedicationRequest": 0}
                    and set(receipt["inspection"]["field_paths"]) == set(record["proposal"]["data"]["fields"]),
                    "Actual four-resource/seven-field output required")
        else:
            require(receipt is None, "Unconfirmed execution is not a delivered batch")
        output.append({"id": run["id"], "batch": run["grant"]["batch_id"], "state": run["state"],
                       "session": receipt["session_id"] if receipt else None})
    print(json.dumps({"record_id": record_id, "executions": output, "model_calls": 0}, indent=2))
    require(any(run["state"] == "delivered" for run in history["items"]), "No real approved-declaration delivery yet")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--install", action="store_true")
    group.add_argument("--reload-hosts", action="store_true", help="Requires explicit operator approval to briefly pause/resume two utilization hosts")
    group.add_argument("--check", action="store_true")
    parser.add_argument("--record-id")
    parser.add_argument("--base", default=BASE)
    args = parser.parse_args(argv)
    local_base(args.base)
    if args.check and not args.record_id:
        parser.error("--check requires --record-id")
    if args.install:
        install()
    elif args.reload_hosts:
        reload_hosts()
    elif args.check:
        check(args.base, args.record_id)
    else:
        print("Inactive. Compilation, explicit host reload and read-only checks are separate; no delivery or inference.")


if __name__ == "__main__":
    main()
