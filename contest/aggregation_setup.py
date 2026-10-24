#!/usr/bin/env python3
"""Explicitly provision only this demo's isolated synthetic aggregation environment."""
import argparse
import subprocess

import aggregation_prepare
from business_privacy import require

MARKER = "@@AGGREGATION-SETUP@@"


def phase(namespace, action):
    code = (
        'Try { Set sc=$SYSTEM.OBJ.Load("/contest/dev/AggregationProvision.cls","ck") '
        'If $SYSTEM.Status.IsError(sc) { Throw ##class(%Exception.StatusException).CreateFromStatus(sc) } '
        + action + f' Write "{MARKER}OK",! '
        + f'}} Catch ex {{ Write "{MARKER}FAILED: ",ex.DisplayString(),! }}\nHalt\n')
    result = subprocess.run(
        ["docker", "exec", "-i", "iris-triage-real-iris-1", "iris", "session", "IRIS", "-U", namespace],
        input=code, text=True, capture_output=True, check=True, timeout=300)
    statuses = [line.split(MARKER, 1)[1] for line in result.stdout.splitlines() if MARKER in line]
    require(statuses == ["OK"], "Setup phase failed: " + repr(statuses))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true",
                        help="Create isolated namespaces/repo/client and start only aggregation Production")
    args = parser.parse_args(argv)
    if not args.apply:
        print("No changes. --apply provisions PIPELINE/FHIRDEMO and a dedicated authenticated local FHIR client.")
        return
    aggregation_prepare.main()
    phase("%SYS", "Do ##class(User.ContestAggregationProvision).Foundation()")
    phase("FHIRDEMO", "Do ##class(User.ContestAggregationProvision).Repository()")
    phase("%SYS", "Do ##class(User.ContestAggregationProvision).Access()")
    subprocess.run(
        ["docker", "exec", "iris-triage-real-gateway-1", "sh", "-c",
         "cp /config/CSP.conf /etc/apache2/conf-enabled/CSP.conf && apache2ctl configtest && apache2ctl graceful"],
        check=True, timeout=30)
    phase("PIPELINE", "Do ##class(User.ContestAggregationProvision).Pipeline() "
          "Set ref=##class(User.ContestAggregationProvision).PresetApproval()")
    print("Aggregation installed; preset synthetic approval pinned. No batch sent or model called.")


if __name__ == "__main__":
    main()
