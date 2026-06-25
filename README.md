# logging.mojo

Timestamped log lines for Mojo, **stamped at the moment of the call**.

Every line is prefixed with the local wall-clock time `[HH:MM:SS.mmm]` computed
when `log()` runs, so the log *file* carries the timestamps. No `tail | ts`-style
filter at view time — and the time reflects when each line was *produced*, not
when a downstream reader happened to see it.

```mojo
from logging import log

log("server up on :10010")
# → [06:11:04.187] server up on :10010
```

`timestamp()` is also exposed if you want just the `HH:MM:SS.mmm` string.

## How it works

`gettimeofday(2)` for the millisecond, `localtime_r(3)` for the local
hour/minute/second — both via FFI. Pure Mojo otherwise; allocates nothing beyond
the formatted line.

## Use it

Pure Mojo + libc, no extra dependencies. Consumers just add the include path:

```
mojo build your.mojo -I ../logging.mojo/src
```

## Test

```
pixi run test
```

Extracted from the millfolio binaries (server, privacy_box, …) so they all
timestamp identically.
