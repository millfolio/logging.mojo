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
    """`YYYY-MM-DD HH:MM:SS.mmm` in local time, to the millisecond, for RIGHT NOW.
    Full date + time so the log FILE is self-dated — no external timestamping
    wrapper needed."""
    # struct timeval { time_t tv_sec (8B @0); suseconds_t tv_usec (4B @8) }.
    # Read as two 8-byte words: word 0 = tv_sec, low 32 bits of word 1 = tv_usec.
    var tv = stack_allocation[2, Int64]()
    tv[unsafe_offset=0] = 0
    tv[unsafe_offset=1] = 0
    var null = Pointer[NoneType, MutUntrackedOrigin](unsafe_from_address=Int(0))
    _ = external_call["gettimeofday", c_int](
        tv.unsafe_bitcast[NoneType](), null
    )
    var usec = Int(tv[unsafe_offset=1]) & 0xFFFFFFFF

    # localtime_r(const time_t *clock, struct tm *result). struct tm's leading
    # int fields are: tm_sec, tm_min, tm_hour, tm_mday, tm_mon (0-11), tm_year
    # (years since 1900) — indices 0..5 of the Int32 view below.
    var t = stack_allocation[1, Int64]()
    t[unsafe_offset=0] = tv[unsafe_offset=0]
    var tm = stack_allocation[16, Int32]()  # 64B — struct tm is ~56B on macOS
    for i in range(16):
        tm[unsafe_offset=i] = 0
    _ = external_call["localtime_r", Pointer[NoneType, MutUntrackedOrigin]](
        t.unsafe_bitcast[NoneType](), tm.unsafe_bitcast[NoneType]()
    )
    var sec = Int(tm[unsafe_offset=0])
    var minute = Int(tm[unsafe_offset=1])
    var hour = Int(tm[unsafe_offset=2])
    var day = Int(tm[unsafe_offset=3])
    var month = Int(tm[unsafe_offset=4]) + 1  # tm_mon is 0-based
    var year = Int(tm[unsafe_offset=5]) + 1900  # tm_year is years since 1900
    return (
        String(year)
        + "-"
        + _pad2(month)
        + "-"
        + _pad2(day)
        + " "
        + _pad2(hour)
        + ":"
        + _pad2(minute)
        + ":"
        + _pad2(sec)
        + "."
        + _pad3(usec // 1000)
    )


def log(msg: String):
    """Print `msg` to stdout, prefixed with `[YYYY-MM-DD HH:MM:SS.mmm] ` now."""
    print("[" + timestamp() + "] " + msg)
