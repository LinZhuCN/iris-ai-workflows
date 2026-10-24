# Installation and demo entry points

[Project overview](./README.md) · [中文说明](./README.zh-CN.md)

This project monitors inter-organization data exchanges for potential privacy
and compliance risks without changing the observed Production's business flow.
IRIS AI Hub assists post-send review; findings support human investigation,
not automatic legal certification.

There are two setup levels: a small mock triage workflow and the extended
monitoring demonstration. Starting the first does not provision the second.

## Platform prerequisites

- Docker Compose 2.24.4+ and Python 3.
- Authorized AI Hub EAP image and appropriate license, obtained separately.
- Tested on ARM64 IRIS for Health `2026.3.0AI.154.0`; the ordinary Community
  image lacks the required AI Hub runtime.
- Node 22.12+ for host frontend use, or the
  [Docker-based UI setup](./web/README.md#run-without-host-node).

The contest announcement currently specifies AI Hub Community build 154.
This EAP environment is not production-ready. Do not redistribute its image
or license based on this repository's open-source license.

## Mock triage quick start

Put your license at `iris/license/iris.key`, or set `IRIS_LICENSE_PATH` to
its absolute local path. From the repository root:

```sh
python3 contest/prepare.py
docker compose --profile mock up -d --wait
python3 contest/test.py --restart
```

The provider is a local synthetic mock; the AI Hub SDK, fact ToolSet, BP policy
checks, BO and persistent audit are real. The test includes synthetic traffic
and restart checks. Open <http://127.0.0.1:52777/csp/sys/UtilHome.csp>,
sign in with your IRIS administrator identity and select **TRIAGE**.

The [runtime guide](./contest/README.md) explains image configuration, initial
credentials, expected behavior and troubleshooting. No patient data is needed.

## Real-model runtime

Populate an ignored root `.env` using [.env.example](./.env.example).
Configure `LLM_BASE_URL`, `LLM_API_KEY` and `LLM_MODEL` locally:

```sh
python3 contest/prepare.py
docker compose --env-file .env -p iris-triage-real \
  -f contest/compose.yaml -f contest/real.yaml up -d --wait
```

The separate real instance uses
<http://127.0.0.1:52779/csp/sys/UtilHome.csp>. Do not print resolved Compose
configuration containing credentials.

The following is an optional **paid triage test**, not monitoring installation:

```sh
COMPOSE_PROJECT_NAME=iris-triage-real python3 contest/test.py --real --restart
```

It sends synthetic cases through the real provider and may incur charges.
The triage Agent sees restricted case facts, not arbitrary patient records.

## Extended monitoring demonstration

Provision the following before the presentation:

1. [Knowledge API and offline local embeddings](./contest/KNOWLEDGE.md).
2. [Monitoring infrastructure and Production observation](./contest/MONITORING.md).
3. The fixed M5 foundation, published reviewer and source installation described
   in [M5 prerequisites](./contest/M5-ONBOARDING-DEMO.md#before-presenting).
4. [Frontend setup and shared authentication](./web/README.md).

The complete clean-machine M5 deployment still needs a release rehearsal.
Existing local acceptance journals are not distributed bootstrap fixtures.

For host Node, restore and run the UI against the real local runtime:

```sh
cd web
npm ci --legacy-peer-deps
PLATFORM_API_TARGET=http://127.0.0.1:52779 npm run dev -- --host 127.0.0.1
```

Open <http://localhost:5173/demo/m5>. Sign in, enter institution profiles,
enroll `M5OBSERVATION / Contest.M5.Production`, authorize local inspection,
send the synthetic research flow, inspect captured evidence and separately
authorize its bounded audit. Read the result and adjacent **AI log**.

Enrollment does not change the business BP, authorize payload inspection or
purchase inference. The reviewer runs in an independent observation worker.
The [optional three-recipient demo](./contest/MULTI-ORGANIZATION-DEMO.md)
adds actual SQL, REST and HL7 V2 recipients in isolated local namespaces.

Keep the HTTP development deployment on localhost. Credentials remain in
browser memory; a secure public deployment needs additional work.

## Verification and rehearsal

Free corpus checks:

```sh
python3 contest/knowledge.py verify --profile demo
python3 contest/knowledge.py release-check
```

Frontend checks, inside the environment where dependencies were installed:

```sh
cd web
npm test
npm run lint
npm run build
```

For an already completed local M5 acceptance:

```sh
python3 contest/m5_demo.py --check
```

This is read-only and requires its saved journal. It does not create acceptance
evidence on a fresh clone. `--run` sends a new message and funds model requests;
`--reset` archives fixed M5 logical state. Read the
[scope and safeguards](./contest/M5-ONBOARDING-DEMO.md) before either operation.

## More information

- [Project capabilities, measured evidence and limitations](./README.md)
- [Live demo in Chinese](./contest/M5-ONBOARDING-DEMO.zh-CN.md)
- [HIPAA corpus provenance](./hipaa-demo-knowledge/README.md)
- [Historical experiments and retained failures](./contest/MONITORING.md)
- [Contest article](./contest/CONTEST-ARTICLE.md) and
  [release checklist](./contest/CONTEST-SUBMISSION.md)
- [Development MCP and Skills](./contest/dev/README.md), separate from runtime AI

Forked from [DataPipelineDemo](https://github.com/zlnick/DataPipelineDemo);
upstream is unchanged. Project code is [Apache-2.0](./LICENSE), with additional
attributions and material-specific notices in [NOTICE](./NOTICE).
