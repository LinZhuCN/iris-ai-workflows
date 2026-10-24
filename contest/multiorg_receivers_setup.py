#!/usr/bin/env python3
"""Explicit, idempotent provisioning for the three owned M2 recipients."""
import argparse
import subprocess

CONTAINER = "iris-triage-real-iris-1"


def session(code, namespace="%SYS"):
    result = subprocess.run(
        ["docker", "exec", "-i", CONTAINER, "iris", "session", "IRIS", "-U", namespace],
        input=code + "\nhalt\n", text=True, capture_output=True, timeout=120)
    if result.returncode or "ERROR #" in result.stdout or "RECEIVER-FAIL" in result.stdout:
        raise RuntimeError(result.stdout + result.stderr)
    return result.stdout


def apply():
    # Generate in the ignored, persistent container volume. Never transmit secrets
    # through shell arguments, environment variables or development tool output.
    script = """
import json, os, pathlib, secrets
root = pathlib.Path('/dur/multiorg-receiver')
if root.is_symlink():
    raise RuntimeError('receiver directory ownership conflict')
root.mkdir(mode=0o700, parents=True, exist_ok=True)
os.chmod(root, 0o700)
path = root / 'credentials.json'
if path.is_symlink():
    raise RuntimeError('receiver credential ownership conflict')
if path.exists():
    value = json.loads(path.read_text())
    if value.get('owner') != 'multi-organization-receivers-v1':
        raise RuntimeError('receiver credential ownership conflict')
else:
    value = dict(owner='multi-organization-receivers-v1',
                 quality_user='MultiOrgQuality', quality_password=secrets.token_urlsafe(36),
                 research_user='MultiOrgResearch', research_password=secrets.token_urlsafe(36))
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, 'w') as out:
        json.dump(value, out)
if 'clinic_user' not in value:
    value['clinic_user'] = 'MultiOrgClinic'
    value['clinic_password'] = secrets.token_urlsafe(36)
    with path.open('w') as out:
        json.dump(value, out)
os.chmod(path, 0o600)
properties = root / 'quality.properties'
if properties.is_symlink():
    raise RuntimeError('receiver JDBC credential ownership conflict')
for branch, username in (('quality', 'MultiOrgQuality'), ('research', 'MultiOrgResearch'), ('clinic', 'MultiOrgClinic')):
    if value.get(branch + '_user') != username or not isinstance(value.get(branch + '_password'), str) or len(value[branch + '_password']) < 32:
        raise RuntimeError('receiver credential shape conflict')
fd = os.open(properties, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
with os.fdopen(fd, 'w') as out:
    out.write('user=' + value['quality_user'] + '\\npassword=' + value['quality_password'] + '\\n')
os.chmod(properties, 0o600)
"""
    subprocess.run(["docker", "exec", "-i", CONTAINER, "python3", "-"],
                   input=script, text=True, check=True, timeout=20)
    print(session(
        'set sc=$system.OBJ.Load("/contest/multiorg/receiver/Provision.cls","ck")\n'
        'if $system.Status.IsError(sc) { write "RECEIVER-FAIL ",$system.Status.GetErrorText(sc),! } '
        'else { set sc=##class(MultiOrg.Receiver.Provision).Apply() '
        'if $system.Status.IsError(sc) { write "RECEIVER-FAIL ",$system.Status.GetErrorText(sc),! } '
        'else { write "RECEIVER-PROVISIONED",! } }'))
    # A live owned listener is detected before starting a replacement job.
    print(session(
        'try { do ##class(MultiOrg.Receiver.API).StartIfNeeded() } '
        'catch ex { write "RECEIVER-FAIL ",ex.DisplayString(),! }',
        "DEMOCLINIC"))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true", help="create/update explicitly owned local resources")
    parser.add_argument("--verify", action="store_true", help="perform real protocol acceptance checks")
    args = parser.parse_args()
    if not args.apply and not args.verify:
        parser.error("choose --apply and/or --verify; no implicit provisioning")
    if args.apply:
        apply()
    if args.verify:
        print(session(
            'set sc=$system.OBJ.Load("/contest/multiorg/receiver/Acceptance.cls","ck")\n'
            'if $system.Status.IsError(sc) { write "RECEIVER-FAIL ",$system.Status.GetErrorText(sc),! } '
            'else { try { do ##class(MultiOrg.Receiver.Acceptance).Run() } '
            'catch ex { write "RECEIVER-FAIL ",ex.DisplayString(),! } }',
            "DEMOCLINIC"))


if __name__ == "__main__":
    main()
