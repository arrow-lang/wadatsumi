from os import path, makedirs
from sys import argv
from subprocess import check_call
from tempfile import NamedTemporaryFile

def run(bin_path, test_filename, expected_filename):
    with NamedTemporaryFile(suffix=".bmp", delete=False) as test_out:
        check_call([
            bin_path,
            "--test",
            "--test-output", test_out.name,
            test_filename,
        ])

        try:
            makedirs(path.dirname(expected_filename))

        except:
            # Ignore error (dirs already there)
            pass

        check_call([
            "convert",
            test_out.name,
            expected_filename
        ])

def main():
    base_dir = path.dirname(__file__)
    bin_path = path.join(base_dir, "../bin/wadatsumi")

    for test in argv[1:]:
        expected_filename = test.replace("test/suite", "test/expected").replace(
            ".gb", ".png")

        run(bin_path, test, expected_filename)

if __name__ == "__main__":
    main()
