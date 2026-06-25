"""logging — timestamped log lines for Mojo, stamped at the moment of the call.

Every line is prefixed with the local wall-clock time `[HH:MM:SS.mmm]` computed
WHEN `log()` runs — so the log FILE itself carries the timestamps. No `tail | ts`
filter at view time, and the order/timing is exactly when each line was produced
(a downstream filter only ever sees when the bytes were *read*).

    from logging import log
    log("server up on :10010")        # → [06:11:04.187] server up on :10010

Single-String, drop-in for `print`. Uses gettimeofday(2) + localtime_r(3) via
FFI; allocates nothing beyond the formatted line. Extracted so every millfolio
Mojo binary (server, privacy_box, …) timestamps identically.
"""

from std.ffi import external_call, c_int
from std.memory import UnsafePointer, stack_allocation


def _pad2(n: Int) -> String:
    return (String("0") + String(n)) if n < 10 else String(n)


def _pad3(n: Int) -> String:
    if n < 10:
        return String("00") + String(n)
    if n < 100:
        return String("0") + String(n)
    return String(n)


def timestamp() -> String:
    """`HH:MM:SS.mmm` in local time, to the millisecond, for RIGHT NOW."""
    # struct timeval { time_t tv_sec (8B @0); suseconds_t tv_usec (4B @8) }.
    # Read as two 8-byte words: word 0 = tv_sec, low 32 bits of word 1 = tv_usec.
    var tv = stack_allocation[2, Int64]()
    tv[0] = 0
    tv[1] = 0
    var null = UnsafePointer[NoneType, MutUntrackedOrigin](unsafe_from_address=Int(0))
    _ = external_call["gettimeofday", c_int](tv.bitcast[NoneType](), null)
    var usec = Int(tv[1]) & 0xFFFFFFFF

    # localtime_r(const time_t *clock, struct tm *result). struct tm begins with
    # int tm_sec, tm_min, tm_hour — the first three 32-bit fields are all we need.
    var t = stack_allocation[1, Int64]()
    t[0] = tv[0]
    var tm = stack_allocation[16, Int32]()  # 64B — struct tm is ~56B on macOS
    for i in range(16):
        tm[i] = 0
    _ = external_call["localtime_r", UnsafePointer[NoneType, MutUntrackedOrigin]](
        t.bitcast[NoneType](), tm.bitcast[NoneType]()
    )
    var sec = Int(tm[0])
    var minute = Int(tm[1])
    var hour = Int(tm[2])
    return (
        _pad2(hour) + ":" + _pad2(minute) + ":" + _pad2(sec) + "." + _pad3(usec // 1000)
    )


def log(msg: String):
    """Print `msg` to stdout, prefixed with `[HH:MM:SS.mmm] ` stamped now."""
    print("[" + timestamp() + "] " + msg)
