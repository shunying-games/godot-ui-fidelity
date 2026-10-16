import copy
import json
import subprocess
import sys
import unittest
from pathlib import Path

from check_hit_regions import SchemaError, check_hit_regions


def fixture():
    return {"viewport": [844, 390], "targets": [
        {"id": "toggle", "rect": [100, 100, 80, 44], "min_size": [44, 44]},
        {"id": "slider", "rect": [100, 160, 150, 44], "min_size": [44, 44]},
    ], "allowed_overlaps": []}


class GeometryTests(unittest.TestCase):
    def test_normal(self):
        result = check_hit_regions(fixture())
        self.assertEqual(result["status"], "pass")
        self.assertEqual(result["checked_targets"], 2)

    def test_3_65_pixel_overlap(self):
        data = fixture()
        data["targets"][1]["rect"][1] = 140.35
        result = check_hit_regions(data)
        self.assertEqual(result["status"], "fail")
        self.assertEqual(result["violations"][0]["kind"], "overlap")
        self.assertAlmostEqual(result["violations"][0]["intersection_rect"][3], 3.65)

    def test_shared_boundary_and_epsilon(self):
        for offset in (0, -0.0001, -0.00005, 0.00005):
            with self.subTest(offset=offset):
                data = fixture()
                data["targets"][1]["rect"][1] = 144 + offset
                self.assertEqual(check_hit_regions(data)["status"], "pass")
        data["targets"][1]["rect"][1] = 143.9998
        self.assertEqual(check_hit_regions(data)["status"], "fail")

    def test_viewport_boundary_and_outside(self):
        data = fixture()
        data["targets"] = [{"id": "edge", "rect": [800, 346, 44, 44]}]
        self.assertEqual(check_hit_regions(data)["status"], "pass")
        data["targets"][0]["rect"][0] += 0.00005
        self.assertEqual(check_hit_regions(data)["status"], "pass")
        data["targets"][0]["rect"][0] += 0.1
        self.assertEqual(check_hit_regions(data)["violations"][0]["kind"], "outside_viewport")
        data["targets"][0]["rect"] = [-1, 0, 44, 44]
        self.assertEqual(check_hit_regions(data)["status"], "fail")

    def test_min_size_optional_and_tolerance(self):
        data = fixture()
        del data["targets"][0]["min_size"]
        data["targets"][0]["rect"][2] = 1
        self.assertEqual(check_hit_regions(data)["status"], "pass")
        data["targets"][0]["min_size"] = [44, 44]
        self.assertEqual(check_hit_regions(data)["violations"][0]["kind"], "below_min_size")
        data["targets"][0]["rect"][2] = 43.99995
        self.assertEqual(check_hit_regions(data)["status"], "pass")

    def test_nan_inf_and_invalid_dimensions(self):
        for value in (float("nan"), float("inf"), -float("inf"), 0, -1, True, "44"):
            for field in ("viewport", "rect", "min_size"):
                with self.subTest(value=value, field=field):
                    data = fixture()
                    if field == "viewport":
                        data[field][0] = value
                    else:
                        data["targets"][0][field][2 if field == "rect" else 0] = value
                    with self.assertRaises(SchemaError):
                        check_hit_regions(data)
        data = fixture()
        data["targets"][0]["rect"] = [1e308, 0, 1e308, 44]
        with self.assertRaises(SchemaError):
            check_hit_regions(data)

    def test_duplicate_and_empty_id(self):
        for target_id in ("toggle", "", " "):
            data = fixture()
            data["targets"][1]["id"] = target_id
            with self.assertRaises(SchemaError):
                check_hit_regions(data)

    def test_exemption_reported_used_and_unused(self):
        data = fixture()
        data["allowed_overlaps"] = [{"ids": ["slider", "toggle"], "reason": "Reviewed shared gesture zone"}]
        result = check_hit_regions(data)
        self.assertEqual(len(result["overlap_exemptions"]["unused"]), 1)
        data["targets"][1]["rect"][1] = 140.35
        result = check_hit_regions(data)
        self.assertEqual(result["status"], "pass")
        self.assertEqual(result["overlap_exemptions"]["used"][0]["reason"], "Reviewed shared gesture zone")
        self.assertEqual(result["overlap_exemptions"]["unused"], [])
        data["targets"][0]["rect"][0] = -10
        self.assertEqual(check_hit_regions(data)["status"], "fail")

    def test_invalid_exemptions(self):
        examples = [
            {"ids": ["toggle", "missing"], "reason": "x"},
            {"ids": ["toggle", "toggle"], "reason": "x"},
            {"ids": ["toggle"], "reason": "x"},
            {"ids": ["toggle", "slider"], "reason": " "},
            {"ids": ["toggle", "slider"], "reason": None},
        ]
        for exemption in examples:
            data = fixture()
            data["allowed_overlaps"] = [exemption]
            with self.subTest(exemption=exemption), self.assertRaises(SchemaError):
                check_hit_regions(data)
        data = fixture()
        data["allowed_overlaps"] = [
            {"ids": ["toggle", "slider"], "reason": "x"},
            {"ids": ["slider", "toggle"], "reason": "y"},
        ]
        with self.assertRaises(SchemaError):
            check_hit_regions(data)

    def test_empty_targets_rejected(self):
        with self.assertRaisesRegex(SchemaError, "no testable active targets"):
            check_hit_regions({"viewport": [100, 100], "targets": []})

    def test_cli_exit_codes_and_json_output(self):
        base = fixture()
        overlap = copy.deepcopy(base)
        overlap["targets"][1]["rect"][1] = 140.35
        for text, code, status in ((json.dumps(base), 0, "pass"),
                                   (json.dumps(overlap), 1, "fail"),
                                   ('{"viewport": [NaN, 390], "targets": []}', 2, "schema_error"),
                                   ('{"viewport": [100, 100], "targets": []}', 2, "schema_error"),
                                   ('{broken', 2, "schema_error")):
            result = subprocess.run([sys.executable, str(Path(__file__).with_name("check_hit_regions.py")), "-"],
                                    input=text, text=True, capture_output=True, check=False)
            self.assertEqual(result.returncode, code, result.stderr)
            self.assertEqual(json.loads(result.stdout)["status"], status)
        help_result = subprocess.run([sys.executable, str(Path(__file__).with_name("check_hit_regions.py")), "--help"],
                                     text=True, capture_output=True, check=False)
        self.assertEqual(help_result.returncode, 0)
        for schema_key in ('"viewport"', '"targets"', '"rect"', '"min_size"', '"allowed_overlaps"'):
            self.assertIn(schema_key, help_result.stdout)


if __name__ == "__main__":
    unittest.main()
