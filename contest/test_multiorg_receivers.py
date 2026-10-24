"""Offline contract tests; --integration executes real receiver round trips in IRIS."""
import importlib.util
import pathlib
import unittest
from unittest import mock
from types import SimpleNamespace

ROOT = pathlib.Path(__file__).parent


def transport():
    spec = importlib.util.spec_from_file_location(
        "receiver_transport", ROOT / "multiorg/receiver/transport.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class ReceiverContract(unittest.TestCase):
    def test_recipient_aliases_send_and_read(self):
        mod = transport()
        payloads = {
            "quality": '{"patient_id":"SYN001","birthYear":1980,"status":"ok"}',
            "research": '{"name":"Synthetic"}',
            "clinic": ("MSH|^~\\&|S|S|C|C|20261024||ADT^A04|abc|P|2.5\r"
                       "PID|1||SYN001||Synthetic^Alex||19800412\r"),
        }
        for alias, canonical in (("quality", "sql"), ("research", "rest"), ("clinic", "hl7")):
            payload = payloads[alias]
            receipt = mod._receipt(canonical, "abc", payload)
            with (mock.patch.object(mod, "_sql", return_value=dict(receipt)) as sql,
                  mock.patch.object(mod, "_http", return_value=dict(receipt)) as http,
                  mock.patch.object(mod, "_mllp", return_value=dict(receipt)) as mllp):
                self.assertTrue(mod.send(alias, "abc", payload)["readback_match"])
                {"sql": sql, "rest": http, "hl7": mllp}[canonical].assert_called()
            with mock.patch.object(mod, "_sql", return_value=dict(receipt)), \
                    mock.patch.object(mod, "_http", return_value=dict(receipt)):
                if canonical != "hl7":
                    self.assertEqual(mod.read(alias, "abc")["payload_hash"], mod.digest(payload))
                else:
                    api = mock.Mock()
                    api.Read.return_value = __import__("json").dumps(receipt)
                    fake_iris = SimpleNamespace(system=SimpleNamespace(
                        Process=SimpleNamespace(NameSpace=lambda: "DEMODISTRIBUTION",
                                                SetNamespace=lambda ns: None)),
                        cls=lambda name: api)
                    with mock.patch.dict("sys.modules", {"iris": fake_iris}):
                        self.assertEqual(mod.read(alias, "abc")["payload_hash"], mod.digest(payload))

    def test_delivery_id_bound(self):
        mod = transport()
        for value in ("", "../x", "x" * 65, "é", "a_b"):
            with self.assertRaises(ValueError):
                mod.validate_id(value)
        self.assertEqual(mod.validate_id("A-123"), "A-123")

    def test_hash_is_exact_utf8(self):
        mod = transport()
        import hashlib
        self.assertEqual(mod.digest('{"name":"é"}'),
                         hashlib.sha256('{"name":"é"}'.encode()).hexdigest())

    def test_ack_requires_matching_control_id(self):
        mod = transport()
        self.assertEqual(mod.check_ack("MSH|^~\\&|C||||||ACK|ack|P|2.5\rMSA|AA|abc\r", "abc"), "AA")
        for ack in ("MSA|AA|other\r", "MSA|AE|abc\r", "PID|abc\r"):
            with self.assertRaises(ValueError):
                mod.check_ack(ack, "abc")

    def test_sql_shape_and_hl7_control_validation(self):
        mod = transport()
        with self.assertRaises(ValueError):
            mod.validate_payload("sql", "abc", '{"patient_id":"x","birthYear":true,"status":"ok"}')
        with self.assertRaises(ValueError):
            mod.validate_payload("hl7", "abc", "MSH|^~\\&|S||||||ADT^A01|other|P|2.5\rPID|1||SYN001\r")

    def test_read_restores_namespace_after_storage_exception(self):
        mod = transport()
        namespace = ["DEMODISTRIBUTION"]

        def switch(value=None):
            if value is not None:
                namespace[0] = value
            return namespace[0]

        api = mock.Mock()
        api.Read.side_effect = RuntimeError("storage unavailable")
        fake_iris = SimpleNamespace(system=SimpleNamespace(
            Process=SimpleNamespace(NameSpace=lambda: namespace[0],
                                    SetNamespace=switch)), cls=lambda name: api)
        with mock.patch.dict("sys.modules", {"iris": fake_iris}):
            with self.assertRaises(RuntimeError):
                mod.read("hl7", "abc")
        self.assertEqual(namespace[0], "DEMODISTRIBUTION")

    def test_send_rejects_unknown_branch_before_any_network(self):
        mod = transport()
        with mock.patch.object(mod.socket, "create_connection") as connection:
            with self.assertRaises(ValueError):
                mod.send("remote", "abc", "{}")
            connection.assert_not_called()


if __name__ == "__main__":
    unittest.main()
