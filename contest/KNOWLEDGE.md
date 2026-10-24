# Local embeddings and the Knowledge API

This optional platform slice uses the AI Hub EAP RAG SDK and local CPU inference,
not a hosted embedding API. The message-triage Agent is unchanged and does not
yet use this corpus. The separate [privacy Agent factory](./AGENT-FACTORY.md)
now uses pinned knowledge retrieval in real synthetic tests.

## Verified scope

- Pinned `Qdrant/all-MiniLM-L6-v2-onnx`, revision
  `d13954661f83248295ba75c1ed411eef3b7b936e`, Apache-2.0 model.
- 384-dimensional vectors; approximately 90 MB of ONNX weights.
- 715 default-scope records, 1,785 vector chunks, approximately 2.52 MB of
  original UTF-8 record text. This is **not all 23 MB** of published text.
- Scopes: 682 normative, 27 technical, five non-authoritative orientation
  briefs and one synthetic organization policy. Historical/unreviewed records
  are excluded.
- Real top-five retrieval includes source URL, source locator and scope.
  The supplied specific Safe Harbor question returns evidence from
  45 CFR 164.514. This smoke test is not a broad retrieval-quality benchmark.

Tested only on authorized ARM64 AI Hub EAP `2026.3.0AI.154.0`. SDK APIs are
experimental. The image requires authorized access and a valid local license;
this repository does not distribute either. MiniLM is principally an English
retriever; do not assume equivalent Chinese-question quality.

## Prepare a verified model cache

From the repository root:

```sh
python3 contest/embedding.py
# Explicit alternate download endpoint when the official host is inaccessible:
python3 contest/embedding.py --endpoint https://hf-mirror.com
```

Only public model artifacts are downloaded. The endpoint is never used for
inference or sent project/patient data. File sizes, the ONNX SHA-256 and pinned
repository blob hashes are verified; a failed check is fatal, not a remote
inference fallback. Existing cache files are verified too.

For the contest container's durable cache:

```sh
docker exec iris-triage-real-iris-1 mkdir -p /dur/models/fastembed
docker cp contest/data/models/fastembed/. iris-triage-real-iris-1:/dur/models/fastembed/
```

New containers receive `FASTEMBED_CACHE_DIR=/dur/models/fastembed` from the
contest Compose file. For an already-running container without that environment
variable, the verified local development instance uses a `.fastembed_cache`
symlink in its TRIAGE working directory pointing to that durable cache. Do not
restart a business Production just to change an embedding environment setting.
Adapt container names explicitly for your own deployment.

The weights are downloaded once. Verify genuinely offline operation using a
**fresh disposable IRIS container with `--network none`**, not merely a cached
HTTP request:

```sh
python3 contest/offline_embedding.py --license /absolute/path/to/iris.key
```

The helper validates the published corpus/cache, creates its own isolated
TRIAGE namespace, imports all 715 default records and runs the framework
embedding/store tests. It requires eight passing test methods across two suites
(including no-op Production control methods), with no failures. A proof is
saved under ignored `contest/data/embedding-offline-proof.json`; the helper
container is removed afterward. No business Production or provider key is used.

## Enable the local Knowledge API

First run the contest's normal setup so that its dedicated TRIAGE namespace,
database resource and AI Hub SDK are available. Then:

```sh
python3 contest/platform_prepare.py --container iris-triage-real-iris-1
```

This verifies the release corpus, prepares a fixed 715-record export, compiles
the four Knowledge classes and provisions the REST application and two local
accounts. It does not stop, start or reconfigure a Production. Passwords are
generated only when absent, and existing account passwords are not reset.

The updated Gateway configuration must be loaded. When upgrading the already
running local demo, restart **only its Gateway**, not IRIS or other projects:

```sh
docker restart iris-triage-real-gateway-1
```

Start the [frontend](../web/README.md) and open
<http://127.0.0.1:5173/knowledge>. The Vite development proxy targets
`http://host.docker.internal:52779`; for host Node, set
`PLATFORM_API_TARGET=http://127.0.0.1:52779`. No server credentials are embedded
in that proxy.

| Account | Capability | Local password file |
|---|---|---|
| `ContestViewer` | Status, job status and retrieval | `contest/data/platform/ContestViewer.password` |
| `ContestKnowledgeAdmin` | Reader capabilities plus fixed-corpus shadow rebuild | `contest/data/platform/ContestKnowledgeAdmin.password` |

Open the appropriate ignored local password file and paste into the sign-in
form. Credentials stay in React memory, not local/session storage or URLs.
Signing out, refreshing or leaving the Knowledge page clears them. An empty
deployment shows **not ready** until a builder's first verified build completes;
the existing local baseline is recognized when available.

### Security boundary

This is a **localhost-only demo**, not a production identity architecture.
Native IRIS password authentication is required on every request; cookies and
CORS are disabled. POSTs require JSON and an explicit application header, and
the server enforces reader/builder capabilities and input limits.
Use TLS, an appropriate identity provider/session lifecycle, request limiting
and a dedicated platform database before any shared/network deployment.

The dedicated roles have TRIAGE database read/write access for audit and
platform state, IRIS library reads, and no `%All`, development, terminal or
general-purpose SQL API role. The builder additionally has SQL `%CREATE_TABLE`
within this isolated namespace. This is application/API capability separation,
**not per-table or multi-tenant database isolation**; never reuse these roles
for a real business namespace. The developer MCP account was not expanded.

## API contract and index lifecycle

All paths are beneath `/api/monitor/v1`:

| Method | Path | Purpose |
|---|---|---|
| GET | `/knowledge` | Real readiness, counts, active version and caller capabilities |
| POST | `/knowledge/search` | `{"query":"..."}` only; maximum 1,000 characters |
| POST | `/knowledge/builds` | Empty JSON object; builder only; returns `202` and persistent job ID |
| GET | `/knowledge/builds/:id` | Durable stage, record progress, completion or explicit failure |

POST headers include `Content-Type: application/json` and
`X-Requested-With: IRIS-Workflows`. Maximum request body is 4,096 bytes. Malformed
inputs are rejected; there is no fixture fallback. Searches return evidence,
not generated legal answers. Do not enter patient information in the query box.

Each asynchronous build:

1. Verifies the prepared export's SHA-256 against local provisioned state.
2. Creates a fresh, allowlisted `Contest.HIPAAIndex<number>` table.
3. Preserves source metadata while pre-segmenting long paragraphs into windows
   of at most 2,000 characters with 200-character overlap before SDK chunking.
4. Verifies 715 records, 1,785 chunks and a nonempty real retrieval.
5. Grants reader SELECT and switches the active pointer/job state in one
   transaction. Existing requests may finish against the previous version.

The old index remains searchable throughout; failed builds do not switch it.
The scheduler rejects concurrent active builds, and a worker lock prevents
overlapping writers. Jobs without a heartbeat for five minutes are reported as
`interrupted`; they are not silently marked successful or automatically replayed.
This lightweight JOB implementation is not a general distributed job runner.
Old/failed version tables are retained for diagnosis; retention/garbage collection
is not yet implemented. Reserve disk space before repeated builds.

Persistent state uses `^ContestPlatform`, `^ContestKnowledgeJobs` and
`^ContestPlatformAudit`. Audit entries identify the actor, action, version and
failure details; query text is deliberately omitted. Internal error details are
not exposed to browser callers. Inspect them with an authorized local IRIS
administrator, not an endpoint that allows arbitrary global access.

The earlier `Contest.LocalKnowledge.ImportFile` is a destructive single-table
prototype used by isolated tests. The UI does **not** call it. The read-only
store adapter validates existing table configuration instead of invoking the
SDK's DDL path, so retrieval does not need `%CREATE_TABLE`.

## Verification

```sh
# Read-only HTTP checks through the actual UI proxy:
python3 contest/platform_test.py
# Explicitly build and activate a new local version:
python3 contest/platform_test.py --build
# Explicit failure isolation check: temporarily changes ONLY the prepared
# public export and restores it in finally; do not run with other builders.
python3 contest/platform_test.py --failure
python3 -m unittest discover -s contest -p 'test_*.py'
```

HTTP checks cover authentication, reader/build separation, strict inputs,
provenance, specific statute retrieval, concurrent-build rejection and old-index
retrieval during rebuilding. Failure injection proves an invalid source leaves
the active version searchable. Browser checks additionally cover sign-in,
wrong-password errors, five real citations, reader restrictions, sign-out and
mobile overflow. Builder browser acceptance additionally verifies the explicit
confirmation checkbox, running progress, completed job, automatic active-version
refresh, real retrieval after activation, and sign-out. Temporary browser
verification accounts are removed afterward. Framework tests are in [KnowledgeTests.cls](./dev/KnowledgeTests.cls),
[EmbeddingTests.cls](./dev/EmbeddingTests.cls) and
[EmbeddingStoreTests.cls](./dev/EmbeddingStoreTests.cls).

Still not implemented: general uploads/import agents, arbitrary model choice,
automatic Agent review of observations, live events and dynamic Production rule
activation. Instance discovery and synthetic observation transport are now
available in the separate [P2 Connector slice](./MONITORING.md).
