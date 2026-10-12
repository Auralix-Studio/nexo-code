#!/usr/bin/env python3
"""Convierte la salida `flutter test --machine` en anotaciones de GitHub.

Así los tests que fallan aparecen con nombre, archivo y error en la pestaña
del PR, sin abrir el log completo. Sale con 1 si hubo fallos.

Uso: flutter test --machine > test-results.jsonl; python3 scripts/test_report.py test-results.jsonl
"""
import json
import sys


def esc(s: str) -> str:
    return s.replace("%", "%25").replace("\r", "").replace("\n", "%0A")


def main(path: str) -> int:
    tests, suites, errors = {}, {}, {}
    passed = failed = 0
    load_error = None
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            line = line.strip()
            if not line.startswith("{"):
                continue
            try:
                e = json.loads(line)
            except ValueError:
                continue
            t = e.get("type")
            if t == "suite":
                suites[e["suite"]["id"]] = e["suite"].get("path") or ""
            elif t == "testStart":
                tests[e["test"]["id"]] = e["test"]
            elif t == "error":
                errors.setdefault(e["testID"], []).append(e.get("error", ""))
            elif t == "print":
                # flutter_test imprime aquí el detalle de los fallos de widgets.
                errors.setdefault(e["testID"], []).append(e.get("message", ""))
            elif t == "testDone":
                if e.get("hidden"):
                    continue
                if e.get("result") == "success" and not e.get("skipped"):
                    passed += 1
                elif e.get("result") in ("failure", "error"):
                    failed += 1
                    test = tests.get(e["testID"], {})
                    name = test.get("name", "?")
                    file = suites.get(test.get("suiteID"), "")
                    if file.startswith("/"):
                        file = file.split("/test/", 1)[-1]
                        file = "test/" + file
                    line_no = test.get("root_line") or test.get("line") or 1
                    msg = "\n".join(errors.get(e["testID"], []))
                    msg = "\n".join(l for l in msg.splitlines() if l.strip() and not set(l) <= set("═╡╞ ═"))[:3000]
                    if not name.startswith("loading "):
                        print(f"::error file={file},line={line_no},title={esc(name)}::{esc(msg)}")
                    else:
                        load_error = msg
                        print(f"::error file={file},title=No compila::{esc(msg)}")
    print(f"{passed} tests OK, {failed} con fallos")
    return 1 if failed or load_error else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
