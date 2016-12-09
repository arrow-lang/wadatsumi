from __future__ import print_function
import sys
from os import path
import os
import re
import subprocess
from subprocess import check_call, check_output
from glob import glob
from tempfile import NamedTemporaryFile

def get_name(filename):
    suite_name = path.dirname(filename).replace("test/suite/", "")
    test_name = path.basename(filename).replace(".gb", "").replace(".cgb", "")

    return (suite_name, test_name)

def cpad(string, width=80, sep="-"):
    l = (78 - len(string))
    pad = l / 2
    lpad = pad
    rpad = pad
    rem = l % 2
    if rem > 0:
        rpad += 1

    return "%s %s %s" % (sep * lpad, string, sep * rpad)

_passed = 0
_failed = 0
_xfailed = 0
_xpassed = 0

def print_result(test_name, result):
    global _passed
    global _xfailed
    global _failed

    prefix = "\x1b[30;1m"

    if result == "PASS":
        prefix = "\x1b[32m"
        _passed += 1

    elif result == "XFAIL":
        _xfailed += 1

    else:
        prefix = "\x1b[31m"
        _failed += 1

    print("{:<72s}{}{:>7s}{}".format(test_name, prefix, result, "\x1b[0m"))

def print_report():
    message = []
    if _passed:
        message.append("{} passed".format(_passed))

    if _failed:
        message.append("{} failed".format(_failed))

    if _xfailed:
        message.append("{} xfailed".format(_xfailed))

    if _xpassed:
        message.append("{} xpassed".format(_xpassed))

    message = ', '.join(message)

    if message:
        print()

        if not _failed:
            print("\x1b[1;32m%s\x1b[0m" % cpad(message, sep="="))

        else:
            print("\x1b[1;31m%s\x1b[0m" % cpad(message, sep="="))

def run(bin_path, test_filename, expected_filename):
    with NamedTemporaryFile(suffix=".bmp", delete=False) as test_out:
        check_call([
            bin_path,
            "--test",
            "--test-output", test_out.name,
            test_filename,
        ])

        try:
            r = check_output([
                "compare", "-metric", "rmse",
                test_out.name,
                expected_filename,
                "null:"
            ], stderr=subprocess.STDOUT)

            is_pass = r == "0 (0)"
            return "PASS" if is_pass else "FAIL"

        except Exception as ex:
            if path.exists(expected_filename):
                return "FAIL"

            # Any error here is a missing expected result
            return "XFAIL"

def find_tests(dirname):
    test_files = []
    for root, dirs, files in os.walk(dirname):
        for filename in files:
            if filename.endswith(".gb"):
                test_files.append(path.join(root, filename))

    return test_files

def main():
    base_dir = path.dirname(__file__)
    bin_path = path.join(base_dir, "../bin/wadatsumi")

    pattern = sys.argv[1] if len(sys.argv) >= 2 else None

    tests = find_tests(path.join(base_dir, "suite/"))
    current_suite = None
    for test in tests:
        if pattern is not None:
            if not re.search(pattern, test, flags=re.I):
                continue

        suite_name, test_name = get_name(test)
        if current_suite != suite_name:
            if current_suite is not None:
                print()

            current_suite = suite_name
            print(cpad("%s" % suite_name))

        expected_filename = test.replace("test/suite", "test/expected").replace(
            ".gb", ".png")

        is_pass = run(bin_path, test, expected_filename)
        print_result(test_name, is_pass)

    print_report()

if __name__ == "__main__":
    main()
