#!/usr/bin/env python3
"""Provision only the owned synthetic distribution Production; no sends/models."""
import argparse
from utilization_test import execute, MARKER


def phase(namespace, action):
    return execute(namespace, (
        'Set sc=$SYSTEM.OBJ.Load("/contest/dev/MultiProvision.cls","ck") '
        'If $SYSTEM.Status.IsError(sc) { Throw ##class(%Exception.StatusException).CreateFromStatus(sc) } '
        + action + f' Write "{MARKER}",{{"ok":true}}.%ToJSON(),!'))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    if not args.apply:
        print("No changes; --apply provisions DEMODISTRIBUTION only.")
        return
    phase("%SYS", "Do ##class(Contest.MultiProvision).Foundation()")
    phase("DEMODISTRIBUTION", "Do ##class(Contest.MultiProvision).Install()")
    print("Owned distribution Production installed; no data sent or model called.")


if __name__ == "__main__":
    main()
