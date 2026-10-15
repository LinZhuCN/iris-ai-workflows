#!/bin/bash
set -eu
rm -f /tmp/triage-ready
iris session IRIS -U %SYS < /contest/setup.script
test -f /tmp/triage-ready
