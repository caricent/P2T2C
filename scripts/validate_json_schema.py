#!/usr/bin/env python3
"""Small dependency-free validator for the JSON-Schema subset used by P2T2C fixtures."""
import json
import re
import sys


class ValidationError(Exception):
    pass


def resolve_ref(root, ref):
    if not ref.startswith("#/"):
        raise ValidationError(f"unsupported $ref: {ref}")
    value = root
    for part in ref[2:].split("/"):
        value = value[part.replace("~1", "/").replace("~0", "~")]
    return value


def is_type(value, expected):
    return {
        "object": isinstance(value, dict),
        "array": isinstance(value, list),
        "string": isinstance(value, str),
        "integer": isinstance(value, int) and not isinstance(value, bool),
        "boolean": isinstance(value, bool),
        "null": value is None,
    }.get(expected, True)


def matches(value, schema, root, path):
    try:
        check(value, schema, root, path, False)
        return True
    except ValidationError:
        return False


def check(value, schema, root, path="$", probe=False):
    try:
        if "$ref" in schema:
            return check(value, resolve_ref(root, schema["$ref"]), root, path, probe)
        if "const" in schema and value != schema["const"]:
            raise ValidationError(f"{path}: expected const {schema['const']!r}")
        if "enum" in schema and value not in schema["enum"]:
            raise ValidationError(f"{path}: value is outside enum")
        if "type" in schema:
            expected = schema["type"]
            valid = any(is_type(value, item) for item in expected) if isinstance(expected, list) else is_type(value, expected)
            if not valid:
                raise ValidationError(f"{path}: wrong type")
        if "oneOf" in schema:
            match_count = sum(1 for branch in schema["oneOf"] if matches(value, branch, root, path))
            if match_count != 1:
                raise ValidationError(f"{path}: oneOf matched {match_count} branches")
        for branch in schema.get("allOf", []):
            check(value, branch, root, path, probe)
        if "if" in schema and matches(value, schema["if"], root, path):
            check(value, schema.get("then", {}), root, path, probe)
        elif "else" in schema:
            check(value, schema["else"], root, path, probe)
        if isinstance(value, dict):
            for key in schema.get("required", []):
                if key not in value:
                    raise ValidationError(f"{path}: missing {key}")
            properties = schema.get("properties", {})
            for key, item in value.items():
                if key in properties:
                    check(item, properties[key], root, f"{path}.{key}", probe)
                elif schema.get("additionalProperties") is False:
                    raise ValidationError(f"{path}: unsupported property {key}")
        if isinstance(value, list):
            if len(value) < schema.get("minItems", 0) or len(value) > schema.get("maxItems", len(value)):
                raise ValidationError(f"{path}: invalid item count")
            if schema.get("uniqueItems"):
                encoded = [json.dumps(item, sort_keys=True, separators=(",", ":")) for item in value]
                if len(encoded) != len(set(encoded)):
                    raise ValidationError(f"{path}: duplicate items")
            if "items" in schema:
                for index, item in enumerate(value):
                    check(item, schema["items"], root, f"{path}[{index}]", probe)
        if isinstance(value, str):
            if len(value) < schema.get("minLength", 0) or len(value) > schema.get("maxLength", len(value)):
                raise ValidationError(f"{path}: invalid string length")
            if "pattern" in schema and re.search(schema["pattern"], value) is None:
                raise ValidationError(f"{path}: pattern mismatch")
        if isinstance(value, int) and not isinstance(value, bool):
            if value < schema.get("minimum", value) or value > schema.get("maximum", value):
                raise ValidationError(f"{path}: numeric bound mismatch")
        return True
    except ValidationError:
        if probe:
            return False
        raise


def main():
    if len(sys.argv) not in (2, 3):
        raise SystemExit("usage: validate_json_schema.py SCHEMA [--jsonl]")
    with open(sys.argv[1], encoding="utf-8") as handle:
        schema = json.load(handle)
    raw = sys.stdin.read()
    values = [json.loads(line) for line in raw.splitlines() if line] if len(sys.argv) == 3 and sys.argv[2] == "--jsonl" else [json.loads(raw)]
    for value in values:
        check(value, schema, schema)


if __name__ == "__main__":
    try:
        main()
    except (ValidationError, ValueError, KeyError) as error:
        print(f"schema validation failed: {error}", file=sys.stderr)
        raise SystemExit(1)
