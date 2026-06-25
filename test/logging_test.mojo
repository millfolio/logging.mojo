"""Smoke + format tests for logging.mojo."""

from logging import timestamp, log, _pad2, _pad3


def _expect(cond: Bool, msg: String) raises:
    if not cond:
        raise Error("FAIL: " + msg)
    print("ok:", msg)


def main() raises:
    _expect(_pad2(0) == "00", "_pad2(0)")
    _expect(_pad2(9) == "09", "_pad2(9)")
    _expect(_pad2(10) == "10", "_pad2(10)")
    _expect(_pad2(59) == "59", "_pad2(59)")
    _expect(_pad3(0) == "000", "_pad3(0)")
    _expect(_pad3(7) == "007", "_pad3(7)")
    _expect(_pad3(42) == "042", "_pad3(42)")
    _expect(_pad3(999) == "999", "_pad3(999)")

    # `HH:MM:SS.mmm`: 12 bytes, "HH:MM:SS" splits on ':' into 3, ".mmm" tail.
    var ts = timestamp()
    _expect(ts.byte_length() == 12, "timestamp length is 12 (got '" + ts + "')")
    var colon_parts = ts.split(":")
    _expect(len(colon_parts) == 3, "two colons in timestamp")
    var dot_parts = ts.split(".")
    _expect(len(dot_parts) == 2, "one dot in timestamp")
    _expect(String(dot_parts[1]).byte_length() == 3, "millis are 3 digits")

    # log() should emit a prefixed line (visual confirmation).
    log("logging.mojo self-test line")
    print("all logging tests passed")
