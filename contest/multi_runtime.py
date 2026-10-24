"""Fixed synthetic FHIR projections and minimized actual-wire inspection."""
import base64
import datetime
import hashlib
import json
import re
import urllib.error
import urllib.request
from pathlib import Path

FHIR_ROOT = "http://gateway:80/csp/healthshare/fhirdemo/fhir/r4"
PATIENT = {
    "resourceType": "Patient", "id": "agg-multi-p1",
    "meta": {"tag": [{"system": "urn:iris-ai-workflows:demo", "code": "synthetic"}]},
    "identifier": [{"system": "urn:synthetic:mrn", "value": "SYNTHETIC-MRN-001"}],
    "name": [{"family": "Synthetic", "given": ["Alex"]}],
    "birthDate": "1980-04-12",
}


def digest(text):
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def fhir(method="GET", resource=None):
    password = Path("/contest/data/platform/AggregationFHIR.password").read_text().strip()
    auth = base64.b64encode(("ContestAggregationFHIR:" + password).encode()).decode()
    data = json.dumps(resource).encode() if resource is not None else None
    request = urllib.request.Request(
        FHIR_ROOT + "/Patient/" + PATIENT["id"], data=data, method=method,
        headers={"Authorization": "Basic " + auth, "Accept": "application/fhir+json",
                 "Content-Type": "application/fhir+json"})
    with urllib.request.urlopen(request, timeout=15) as response:
        if method == "PUT":
            response.read()
            return fhir()
        value = json.load(response)
    if value.get("resourceType") != "Patient" or value.get("id") != PATIENT["id"]:
        raise ValueError("FHIR response identity mismatch")
    if not value.get("meta", {}).get("versionId"):
        raise ValueError("Versioned FHIR source required")
    return value


def seed():
    try:
        existing = fhir()
    except urllib.error.HTTPError as error:
        if error.code != 404:
            raise
    else:
        comparable = {key: value for key, value in existing.items() if key != "meta"}
        expected = {key: value for key, value in PATIENT.items() if key != "meta"}
        if comparable != expected:
            raise ValueError("Synthetic FHIR identity already has different data; no overwrite")
        return {"resources": ["Patient/" + PATIENT["id"]], "version": existing["meta"]["versionId"]}
    saved = fhir("PUT", PATIENT)
    return {"resources": ["Patient/" + PATIENT["id"]], "version": saved["meta"]["versionId"]}


def source_readiness():
    try:
        patient = fhir()
        return {"name": "FHIR source", "ready": True,
                "detail": "FHIRDEMO synthetic Patient version " + patient["meta"]["versionId"]}
    except urllib.error.HTTPError as error:
        if error.code != 404:
            raise
        outcome = json.load(error)
        if outcome.get("resourceType") != "OperationOutcome":
            raise ValueError("FHIR source did not return a FHIR error response") from error
        return {"name": "FHIR source", "ready": True,
                "detail": "Authenticated FHIR endpoint reachable; load the synthetic cohort before dispatch"}


def transform(branch, delivery_id, patient, variant):
    if not re.fullmatch(r"[A-Za-z0-9-]{1,64}", delivery_id):
        raise ValueError("Bounded delivery ID required")
    if variant not in ("identifier-leak", "corrected"):
        raise ValueError("Unknown synthetic variant")
    dob = patient["birthDate"]
    if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", dob):
        raise ValueError("Fixed full-date synthetic source required")
    datetime.date.fromisoformat(dob)
    mrn = patient["identifier"][0]["value"]
    family = patient["name"][0]["family"]
    given = patient["name"][0]["given"][0]
    for value in (mrn, family, given):
        if not re.fullmatch(r"[A-Za-z0-9 -]{1,80}", value):
            raise ValueError("Unexpected HL7 delimiters or non-demo source values")
    if branch == "quality":
        payload = {"patient_id": "LOCAL-MULTI-001", "birthYear": int(dob[:4]), "status": "referred"}
    elif branch == "research":
        payload = {"export_context": {"synthetic": True, "method": "safe_harbor",
                                     "processing_status": "deidentified", "purpose": "external_statistics"},
                   "status": "referred"}
        if variant == "identifier-leak":
            payload.update(name=given + " " + family, mrn=mrn, birthDate=dob)
        else:
            payload["birthYear"] = dob[:4]
    elif branch == "clinic":
        return (f"MSH|^~\\&|DemoHospital|DemoHospital|DemoClinic|DemoClinic|20261024000000||"
                f"ADT^A04|{delivery_id}|P|2.5\r"
                f"PID|1||{mrn}^^^DemoHospital^MR||{family}^{given}||{dob.replace('-', '')}\r"
                "PV1|1|O\r")
    else:
        raise ValueError("Unknown recipient branch")
    return json.dumps(payload, separators=(",", ":"))


def inspect_payload(branch, wire):
    declaration = None
    if branch == "clinic":
        segments = {row.split("|")[0]: row.split("|") for row in wire.split("\r") if row}
        msh, pid = segments.get("MSH", []), segments.get("PID", [])
        if len(msh) < 12 or len(pid) < 8 or not pid[3] or not pid[5]:
            raise ValueError("Complete MSH and PID required")
        if not re.fullmatch(r"\d{8}", pid[7]):
            raise ValueError("Full HL7 DOB required")
        datetime.datetime.strptime(pid[7], "%Y%m%d")
        fields = ["mrn", "name", "birthDate"]
        full_date = True
        wire_paths = ["PID-3", "PID-5", "PID-7", "PV1-2"]
    else:
        payload = json.loads(wire)
        if branch not in ("quality", "research") or not isinstance(payload, dict):
            raise ValueError("Supported actual-wire JSON object required")
        fields = [field for field in payload if field != "export_context"]
        if any(isinstance(payload[field], (dict, list)) for field in fields):
            raise ValueError("Unsupported nested recipient data is a coverage gap")
        declaration = payload.get("export_context")
        full_date = bool(re.fullmatch(r"\d{4}-\d{2}-\d{2}", str(payload.get("birthDate", ""))))
        if "birthDate" in payload:
            if not full_date:
                raise ValueError("Unsupported birthDate precision or format")
            datetime.date.fromisoformat(payload["birthDate"])
        wire_paths = fields
    return {"fields": fields, "wire_paths": wire_paths, "full_date": full_date,
            "identifier_present": bool({"name", "mrn", "patient_id"} & set(fields)),
            "declaration": declaration, "payload_hash": digest(wire),
            "scope": "Bounded actual outbound fields; not comprehensive de-identification or downstream-use verification"}


def policy_mismatches(facts, policy):
    allowed = set(policy["allowed_fields"])
    prohibited = set(policy["prohibited_fields"])
    return [field for field in facts["fields"] if field not in allowed or field in prohibited]
