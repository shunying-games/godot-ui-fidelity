#!/usr/bin/env python3
"""Check explicitly supplied active UI hit rectangles; not rendering/input routing.

Supply actual runtime global rectangles and viewport in the same coordinate space.
Import check_hit_regions(data), or pass a JSON path (- or no path means stdin).

Minimal input (runtime global rect and viewport must share coordinates):
  {"viewport":[390,844],"targets":[{"id":"close","rect":[320,20,44,44],
   "min_size":[44,44]}],"allowed_overlaps":[]}

min_size and allowed_overlaps are optional. Nonempty targets are required.
Overlap exemptions use {"ids":["first","second"],"reason":"intentional overlap"}.
"""
import argparse
import json
import math
import sys
from pathlib import Path

EPSILON = 1e-4


class SchemaError(ValueError):
    """Input cannot safely be interpreted as geometry evidence."""


def _object(value, path, required, optional=()):
    if not isinstance(value, dict):
        raise SchemaError(f"{path} must be an object")
    missing = set(required) - value.keys()
    unknown = value.keys() - set(required) - set(optional)
    if missing or unknown:
        raise SchemaError(f"{path}: missing keys {sorted(missing)}; unknown keys {sorted(unknown)}")


def _numbers(value, length, path, positive_from=0):
    if not isinstance(value, list) or len(value) != length:
        raise SchemaError(f"{path} must be an array of {length} numbers")
    result = []
    for index, number in enumerate(value):
        try:
            if isinstance(number, bool) or not isinstance(number, (int, float)):
                raise ValueError()
            number = float(number)
            if not math.isfinite(number) or (index >= positive_from and number <= 0):
                raise ValueError()
        except (ValueError, OverflowError):
            raise SchemaError(f"{path}[{index}] must be finite" +
                              (" and positive" if index >= positive_from else "")) from None
        result.append(number)
    return result


def check_hit_regions(data):
    """Return a JSON-compatible pass/fail report; raise SchemaError for invalid data.

    EPSILON is a coordinate tolerance on each axis. Intersections whose width or
    height is <= EPSILON count as boundary contact, not positive-area overlap.
    """
    _object(data, "input", ("viewport", "targets"), ("allowed_overlaps",))
    viewport = _numbers(data["viewport"], 2, "viewport")
    if not isinstance(data["targets"], list) or not data["targets"]:
        raise SchemaError("targets must be a nonempty array; no testable active targets were supplied")
    targets = {}
    for index, target in enumerate(data["targets"]):
        path = f"targets[{index}]"
        _object(target, path, ("id", "rect"), ("min_size",))
        target_id = target["id"]
        if not isinstance(target_id, str) or not target_id.strip():
            raise SchemaError(f"{path}.id must be a nonempty string")
        if target_id in targets:
            raise SchemaError(f"duplicate target id: {target_id}")
        rect = _numbers(target["rect"], 4, f"{path}.rect", positive_from=2)
        if not all(math.isfinite(edge) for edge in (rect[0] + rect[2], rect[1] + rect[3])):
            raise SchemaError(f"{path}.rect computed right/bottom edges must remain finite")
        minimum = _numbers(target["min_size"], 2, f"{path}.min_size") if "min_size" in target else None
        targets[target_id] = {"rect": rect, "min_size": minimum}
    exemptions = {}
    allowed = data.get("allowed_overlaps", [])
    if not isinstance(allowed, list):
        raise SchemaError("allowed_overlaps must be an array")
    for index, exemption in enumerate(allowed):
        path = f"allowed_overlaps[{index}]"
        _object(exemption, path, ("ids", "reason"))
        ids = exemption["ids"]
        if (not isinstance(ids, list) or len(ids) != 2 or
                any(not isinstance(value, str) or value not in targets for value in ids)):
            raise SchemaError(f"{path}.ids must contain two known target ids")
        if ids[0] == ids[1]:
            raise SchemaError(f"{path}.ids must identify different targets")
        pair = tuple(sorted(ids))
        if pair in exemptions:
            raise SchemaError(f"duplicate overlap exemption for {list(pair)}")
        reason = exemption["reason"]
        if not isinstance(reason, str) or not reason.strip():
            raise SchemaError(f"{path}.reason must be a nonempty string")
        exemptions[pair] = reason.strip()
    violations = []
    for target_id, target in targets.items():
        x, y, width, height = target["rect"]
        if (x < -EPSILON or y < -EPSILON or
                x + width > viewport[0] + EPSILON or y + height > viewport[1] + EPSILON):
            violations.append({"kind": "outside_viewport", "id": target_id, "rect": target["rect"]})
        minimum = target["min_size"]
        if minimum and (width + EPSILON < minimum[0] or height + EPSILON < minimum[1]):
            violations.append({"kind": "below_min_size", "id": target_id,
                               "actual_size": [width, height], "min_size": minimum})
    used, used_pairs = [], set()
    target_items = list(targets.items())
    for index, (first_id, first) in enumerate(target_items):
        ax, ay, aw, ah = first["rect"]
        for second_id, second in target_items[index + 1:]:
            bx, by, bw, bh = second["rect"]
            left, top = max(ax, bx), max(ay, by)
            width = min(ax + aw, bx + bw) - left
            height = min(ay + ah, by + bh) - top
            # Compare edges before subtraction to keep an exact epsilon-sized
            # intersection from failing due to cancellation rounding.
            if (min(ax + aw, bx + bw) <= left + EPSILON or
                    min(ay + ah, by + bh) <= top + EPSILON):
                continue
            pair = tuple(sorted((first_id, second_id)))
            overlap = {"ids": list(pair), "intersection_rect": [left, top, width, height]}
            if pair in exemptions:
                used.append({**overlap, "reason": exemptions[pair]})
                used_pairs.add(pair)
            else:
                violations.append({"kind": "overlap", **overlap})
    return {
        "status": "fail" if violations else "pass",
        "evidence_scope": "geometry_only; does not establish visual quality or actual input routing",
        "epsilon": EPSILON, "viewport": viewport, "checked_targets": len(targets),
        "violations": violations,
        "overlap_exemptions": {
            "used": used,
            "unused": [{"ids": list(pair), "reason": reason}
                       for pair, reason in exemptions.items() if pair not in used_pairs],
        },
    }


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("input", nargs="?", default="-", help="JSON path, or - for stdin")
    args = parser.parse_args(argv)
    try:
        source = sys.stdin.read() if args.input == "-" else Path(args.input).read_text(encoding="utf-8")
        report = check_hit_regions(json.loads(source))
        exit_code = 0 if report["status"] == "pass" else 1
    except (OSError, UnicodeError, json.JSONDecodeError, SchemaError) as error:
        report = {"status": "schema_error", "errors": [str(error)],
                  "evidence_scope": "no valid geometry result"}
        exit_code = 2
    print(json.dumps(report, ensure_ascii=False, indent=2, allow_nan=False))
    return exit_code


if __name__ == "__main__":
    sys.exit(main())
