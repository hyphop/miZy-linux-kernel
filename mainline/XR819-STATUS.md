# XR819 stability review — 2026-10-21

Latest follow-up: [XR819-IRQ.md](XR819-IRQ.md) records the IRQ race investigation,
firmware update and separate HT RX fix. The tested device now uses .52.58 firmware,
#34 and IRQ diagnostics; #31, native SDIO and HT-disable are not deployed. The
older A/B results and baseline disposition below are historical.

The pinned driver, `3ce657ae533e2213f6fda2297da1598fa11d7a03`, is the latest
merged commit in fifteenhex/xradio as checked through GitHub API. Armbian's
current drivers_network.sh pins the same commit. Its last merged change adds
management frame protection capability (PR #29, 2026-09-01).

The tested H2+ remains connected after 37 minutes, but its kernel log repeatedly
reports `xradio_wlan ... missed interrupt`. Successful boot and HTTPS requests
are functional smoke tests, not evidence of long-term reliability. A subsequent
20-packet LAN gateway sample had 0% loss, 8.445 ms mean RTT, while the current
kernel log contained 67 missed-interrupt messages. This short sample does not
establish sustained throughput or reliability.

## Unmerged candidates

- [#31](https://github.com/fifteenhex/xradio/pull/31): preserve the data cipher
  when rejecting an unsupported management key. The submitter reports malformed
  ARP replies with WPA2/PMF. The diff moves cipherType assignment after cipher
  validation. Potentially relevant to transient ARP reachability; not diagnosed
  as the cause on this board.
- [#34](https://github.com/fifteenhex/xradio/pull/34): correct HT receive metadata
  written to the wrong field. Its submitter still reports packet loss in 802.11n
  and uses 802.11g. This is a report, not a measured result on this board.
- [#32](https://github.com/fifteenhex/xradio/pull/32): honor lower transmit power
  limits instead of always requesting 20 dBm.
- [#33](https://github.com/fifteenhex/xradio/pull/33): broad bounds, buffer and
  firmware-error handling changes intended to reduce lockups. The author says
  it needs testing; it is not an established stable release.
- [#30](https://github.com/fifteenhex/xradio/pull/30): experimental firmware/driver
  stability changes; its author says the branch was not hardware-tested.

The SPI image still uses the baseline. PR #31 and #34 were subsequently tested
in RAM as described below; #30/#32/#33 were not installed. Keep the
working image and backup as the baseline. A useful next experiment is reviewing
and testing #31 and #34 separately in RAM, measuring packet loss, reconnects,
missed interrupts and sustained HTTPS traffic before considering persistence.
Do not claim that disabling 802.11n or applying these patches fixes this board
without measuring it.

Sources:
- https://github.com/fifteenhex/xradio/commits/master/
- https://github.com/armbian/build/blob/main/lib/functions/compilation/patch/drivers_network.sh

## RAM module A/B experiment (2026-10-21)

Built PR #31 at commit `5c994171ff9a935ea15bbc32d4cf1a8901c18730`
and PR #34 at `0a6c8c3ff71432c3297c2e00ab0371f06eda3b33` against the
running 6.12.113 kernel with its existing configuration and matching vermagic.
The checked-in patches preserve upstream authorship. Built modules were loaded
through UART after stopping Wi-Fi and its DHCP client. No flash writes occurred.

| Driver | Quiet gateway ping | New missed interrupts | HTTPS requests |
|---|---|---|---|
| Baseline | 29/30 received | 1 | 5/5 successful |
| #31 only | 29/30 received | 1 | 5/5 successful |
| #31 + #34 | 30/30 received | 0 | 5/5 successful |

The combined candidate then ran 120 gateway pings while transferring two 4 MiB
payloads in each direction (16 MiB total) and making 20 HTTPS relay requests.
The baseline was subsequently reloaded and given the same workload. Payload
SHA-256 values matched in every transfer; both drivers completed 20/20 HTTPS
requests with CONNECT 200 / HTTPS 200.

| Driver | Loaded gateway ping | Mean RTT | New missed interrupts |
|---|---|---|---|
| #31 + #34 | 113/120 received (7 lost) | 20.818 ms | 1 |
| Baseline | 118/120 received (2 lost) | 19.475 ms | 0 |

Candidate 4 MiB uploads took 9.020/7.073 seconds; downloads 10.443/11.637 seconds.
Baseline uploads took 9.483/8.745 seconds; downloads 9.903/9.099 seconds.
These are end-to-end SSH timings, including encryption/process startup, not raw
Wi-Fi throughput. Sequential samples in an uncontrolled RF environment cannot
establish statistical causality, but they do not demonstrate a stability gain.

**Disposition:** leave the baseline running and keep SPI unchanged. Neither fix
is enabled by default. The opt-in `XRADIO_FIXES=1` build supports further testing;
`XRADIO_FIXES=0` reverses both source patches and is the default. Source toggle,
shell syntax, whitespace checks and both module builds passed. Existing traces
showed no new panic, BUG or firmware error during the candidate test. This does
not address the underlying missed-interrupt issue or prove long-term stability.

Private raw logs and module hashes are under ignored build/artifacts/xradio-tests.
