# M2 local recipients

[English](./README.md) | [简体中文](./README.zh-CN.md)

These are three logically isolated synthetic recipients, not independent
organizations or a compliance decision engine. No provider/model is called.

## Deployment

```sh
python3 -m unittest contest/test_multiorg_receivers.py -q
python3 contest/multiorg_receivers_setup.py --apply
python3 contest/multiorg_receivers_setup.py --verify
```

`--apply` creates only owned databases/namespaces, dedicated users/roles, a REST
application and a loopback MLLP listener. It refuses conflicting database paths,
namespace mappings, ownership markers, credentials, web applications and ports.
It never resets an existing namespace. Reapplying preserves receipts.
The default container is `iris-triage-real-iris-1`; sources are mounted at
`/contest/multiorg/receiver`.

Protected generated credentials live only in the ignored persistent volume:
`/dur/multiorg-receiver/credentials.json` and `quality.properties`, mode `0600`;
their directory is `0700`. SQL credentials have a dedicated role, database access,
SQL service access and only `SELECT, INSERT` on the receipt table. REST credentials
have only their receiver database, web application resource, embedded Python
service use and receipt `SELECT, INSERT`. No `%All` role is
assigned. Administrative setup runs through the explicitly authorized local
container console; it is not an API.
The clinic worker drops the setup identity by logging in as the dedicated
`MultiOrgClinic` account before entering its receive loop. Its role has only
its own database, embedded Python service use, and receipt `SELECT, INSERT`.

| Recipient | Endpoint | Actual storage |
| --- | --- | --- |
| `DEMOQUALITY` | JDBC TCP `127.0.0.1:1972/DEMOQUALITY` | `MultiOrg_Receiver.Receipt` with `patient_id`, `birthYear`, `status`, `RawPayload`, `PayloadHash`, delivery primary key |
| `DEMORESEARCH` | authenticated `http://gateway:80/csp/multiresearch/receipts` | namespace-local receipt table |
| `DEMOCLINIC` | UTF-8 HL7 v2 MLLP `127.0.0.1:25751` | namespace-local receipt table, then correlated `MSA|AA` or rejected `MSA|AE` |

Database directories are `/dur/multiorg-receiver/<NAMESPACE>/`. Recipient data
globals are not mapped between namespaces. The marker in each is
`^MultiOrgReceiverInstall("owner")="multi-organization-receivers-v1"`.

Gateway requirements: route `/csp/multiresearch` and `/csp/multiresearch/` to
the IRIS instance, including extensionless REST paths. The fixed `gateway:80`
host is used because this instance has no private HTTP listener on port 52773.
This package does not change compose or gateway configuration.

The clinic uses a small embedded-Python MLLP listener rather than a native HL7
Production so that the receipt digest binds the exact received UTF-8 wire payload,
including CR segment terminators. It stores durably before returning an ACK.
Only one bounded message is accepted per TCP connection; missing/invalid framing
and negative or uncorrelated ACKs never become positive delivery evidence.
An ACK confirms local receipt, not clinical use.

After container restart, an explicitly owned startup hook must switch to
`DEMOCLINIC`, verify the marker, then call
`##class(MultiOrg.Receiver.API).StartIfNeeded()`.
That method also verifies ownership and probes listener identity before starting
an IRIS background job. There is no receiver Production to start.

## Client contract

From embedded Python, including `DEMODISTRIBUTION`:

```python
import sys
sys.path.insert(0, "/contest/multiorg/receiver")
import transport
receipt = transport.send("sql", delivery_id, payload)
stored = transport.read("sql", delivery_id)
health = transport.readiness()
```

Public `send`/`read` accept both institution IDs `quality`, `research`, `clinic`
and protocol IDs `sql`, `rest`, `hl7`, respectively. `readiness()` retains
protocol IDs in its `name` field. Delivery IDs are exactly 1–64 ASCII
alphanumeric/hyphen characters. Payloads are bounded to 16,000 UTF-8 bytes.
Receipts include `delivery_id`, `payload_hash` (SHA-256 exact UTF-8),
`payload`/`stored_payload`, `readback_match`, `namespace`, and `protocol`.
SQL sends use a real bundled JDBC connection with prepared insert and select.
REST sends use actual authenticated HTTP POST and independent GET readback.
Clinic sends use actual MLLP with ACK correlation and read-only administrative
readback, restoring the caller namespace even on error.
Administrative readback callers need permission to read the clinic database/table.
IRIS `Process.NameSpace()` is a getter (its argument is a process ID);
the client uses `Process.SetNamespace()` in a `try/finally` instead.

SQL JSON must contain exactly `patient_id` (string ≤64), `birthYear` (integer
1800–2100), and `status` (string ≤64). REST POST envelopes contain
`{"delivery_id":"...","payload":"<exact raw JSON object text>"}`.
GET uses `/receipts/<delivery_id>`. HL7 requires `MSH|^~\&`, matching MSH-10,
a single PID with MRN, name and YYYYMMDD DOB, and final CR.

SQL receipt `columns` contains the independently read actual persisted SQL
columns `patient_id`, `birthYear`, `status`; `column_inventory` lists those exact
SQL identifiers in `MultiOrg_Receiver.Receipt`. Additional persisted columns are
`DeliveryId` (primary key), `RawPayload`, `PayloadHash`. `PatientId` is only the
ObjectScript property name: its SQL field name is `patient_id`.

Same ID/same body returns the existing receipt. Different body is rejected,
never overwritten. Clients do not automatically retry sends. A lost ACK or
HTTP/JDBC response is uncertain; reconcile by ID before an explicit retry.
Raw synthetic data stays local; do not pass these raw receipts to a model.

`--verify` appends one synthetic receipt per branch, checks independent
readback, duplicate counts, changed-body rejection and namespace preservation.
It does not delete existing data. Framework contract tests are
`Contest.MultiReceiverTests`, loaded from `ReceiverTests.cls` into `TRIAGE`;
their `TestControl` never restarts the existing Production.

## Class/source loading

`--apply` loads `Provision.cls` as `MultiOrg.Receiver.Provision` into `%SYS`
and calls `Apply()`. It loads `Receipt.cls` and `API.cls` into each recipient;
`REST.cls` is loaded only into `DEMORESEARCH`. `--verify` loads
`Acceptance.cls` into `DEMOCLINIC`. These files all define
`MultiOrg.Receiver.<FileName>` classes except `ReceiverTests.cls`, which defines
`Contest.MultiReceiverTests` in `TRIAGE`.

The framework suite can be compiled with pinned `iris_compile` and run through
`iris_test(pattern="Contest.MultiReceiverTests", namespace="TRIAGE",
test_type="testproduction")`. That execution identity must have
`%Service_EmbeddedPython:U`. If the development MCP identity lacks it, do not
broaden that existing account: run the same compiled tests via the authorized
local IRIS console instead:

```objectscript
set manager=##class(%UnitTest.Manager).%New()
do manager.RunTest(":Contest.MultiReceiverTests","/nodelete/noload")
```

The protocol acceptance also tests UTF-8 non-ASCII JSON, SQL UPDATE/DELETE
denial, anonymous REST denial and a malformed on-wire HL7 message receiving
no positive ACK and no durable row.
