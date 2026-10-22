# XR819 TX retry-ceiling experiment (2026-10-22)

The operator reconnected and powered on the board. Linux 6.12.113, firmware
.52.58, Wi-Fi, and the production reverse HTTPS proxy returned normally after
that power cycle. The preceding day's missing UART/SSH was confirmed to be an
intentional unplug/power-off, not evidence of a driver crash.

## Diagnosis

The load timing module was loaded in RAM with a known baseline module and UART
available for rollback. It was extended to count firmware confirmation statuses:
retry exhaustion, TX lifetime expiry, link loss, other failures, and requeues.
All 1,250 failed confirmations in the first status-instrumented baseline phase
were WSM_STATUS_RETRY_EXCEEDED; lifetime expiry, link loss, other failures and
requeues were zero. Maximum host queue age was 390 ms and firmware-reported
pre-transmission queue delay was 436,178 us. No host TTL expirations occurred.
These observations identify the reported failure mechanism, not the underlying
RF cause or an electrical proof of hardware health.

Restricting TX to legacy 6/12/24 Mbps plus HT MCS 0–3 did not reproduce the
previous day's apparent benefit: local HTTPS was 11/15, relay HTTPS 9/15, and
board-to-gateway ping 165/220. It was cleared. RTS threshold 500 also failed to
establish a benefit (relay 10/15) and was disabled. The SDIO clock remained
50 MHz and tcp_limit_output_bytes remained 1,048,576 throughout today's trials.

## Change under test

The original TX policy upload sets both shortRetryCount and longRetryCount to
hw_priv->short_frame_max_tx_count - 1, which is 6 with this device's default
7-attempt setting. The experimental patch sets both fields to 14, allowing a
15-attempt ceiling. The existing rate table, mac80211 rate selection, and
policyFlags BIT(2)|BIT(3) are unchanged. A shorter rate policy can still terminate
earlier; this does not force every frame to be transmitted 15 times.

A plausible mechanism is that the original global ceiling can end a packet
before its full fallback-rate policy is used. The status counters alone do not
prove that mechanism. More attempts can consume additional airtime and increase
latency, so TLS timing and throughput must be checked alongside failed TX counts.

Build selection is independent and defaults off:

```sh
XRADIO_FIXES=0 XRADIO_HT_RX_FIX=1 XRADIO_IRQ_DIAGNOSTICS=1 \
XRADIO_IRQ_EXPERIMENT=0 XRADIO_LOAD_DIAGNOSTICS=1 \
XRADIO_RETRY_EXPERIMENT=1 bash /workspace/kernel/mainline/build.sh
```

## Alternating RAM tests

Each row follows a module reload and Wi-Fi reconnect, then the same 45-second
bidirectional HTTP load, three 220-packet pings, and 15 requests per HTTPS route
used in XR819-LOAD.md. The order below is the actual A/B/A/B order. The second
baseline and both candidates used the same instrumentation. One extra relay
probe ran during the first baseline. RF conditions were uncontrolled; samples
were sequential, and signal varied by several dB. Firmware confirmation counts
include all confirmed TX traffic, not only a selected application flow.

| Retry ceiling | Failed TX / confirmations | Local HTTPS | Relay HTTPS | Workstation → board ping | Board → gateway ping | Ending signal average |
|---|---:|---:|---:|---:|---:|---:|
| 7, A1 | 1,250 / 10,709 (11.67%) | 12/15 | 14/15 | 188/220 | 196/220 | -64 dBm |
| 15, B1 | 55 / 12,711 (0.43%) | 15/15 | 15/15 | 216/220 | 218/220 | -61 dBm |
| 7, A2 | 380 / 15,823 (2.40%) | 15/15 | 15/15 | 217/220 | 214/220 | -60 dBm |
| 15, B2 | 40 / 15,752 (0.25%) | 15/15 | 14/15 | 219/220 | 220/220 | -62 dBm |

Direct public HTTPS controls completed 15/15 in every row. Lower failed-TX
fractions were reproduced with the higher ceiling, but a relay TLS timeout
remained in B2. The baseline also completed 15/15 relay requests in A2. Do not
claim that the experiment guarantees HTTPS deadlines or long-term stability.

Request loops are sequential per route and may extend past the offered load.
Of relay requests starting within the first 45 seconds, success counts were
7/8, 7/7, 9/9, and 9/10 respectively. The full 15-request totals must not be
presented as 15 requests wholly inside the saturation window.

## Build and recovery

Both diagnostic and retry modules cross-compiled with the existing GCC 13.3 ARM
toolchain. All four diagnostic/retry patch combinations were applied and reversed
in scratch trees, restoring pinned upstream tx.c/queue.c byte-for-byte. Shell
syntax checks passed. Raw records and private images remain under ignored
build/artifacts/xradio-load/.

## Longer mixed-load sample

With the 15-attempt ceiling, 200 seconds of bidirectional HTTP plus repeated SPI
reads completed with local HTTPS 40/40, direct public controls 40/40, and reverse
HTTPS 37/40. Two relay failures were TLS handshake deadlines and one was a
CONNECT deadline, all using the same 5-second deadline as before. All 40 requests
on each route started within the first 200 seconds (the last relay start was
199.41 s), although later requests could finish after load ended.

Workstation-to-board ping received 988/995 (0.70% loss), board-to-gateway received
993/995 (0.20% loss), and workstation-to-gateway received 995/995. Firmware TX
confirmations failed 187/60,507 times (0.31%), all due to retry exhaustion. Host
TTL expiry, firmware lifetime expiry, and link-loss counts remained zero. The
watchdog observed one IRQ racing its probe and no recovery without an observed
IRQ; no polling read errors occurred. Host queue maximum age was 400 ms and the
firmware pre-transmission maximum was 458,891 us.

This is evidence of a useful packet-delivery improvement in these samples, not
a cure for reverse-path TLS deadlines. It is a roughly three-minute load sample,
not a long-duration soak qualification. HTTP bulk loops used a 10-second request
deadline and some uploads timed out, so do not claim every bulk request finished
or that this experiment establishes maximum throughput.

## Persistence and recovery

A new full 16 MiB SPI backup was fetched and verified against all six partition
SHA-256 values before writing. Backup SHA-256:
`aa4d82d50ce0b27ff219e6cc7a4afaf865a5926c02698a080249d66cd48fd5cd`.

The selected module includes .52.58-compatible HT RX correction, strict IRQ
diagnostics, load/status diagnostics, and the 15-attempt experiment. Native SDIO
IRQ, HT-disable, and ARP correction remain off. Firmware is still .52.58 and the
kernel is still 6.12.113; neither was upgraded again in this experiment.

The rebuilt legacy rootfs image remained exactly 7,352,384 bytes, so boot-script
read lengths did not need changing. Only the initrd/rootfs partition was written.
`mtd verify` passed and all five other partition hashes matched the backup.
The prior known-good full SPI backup and rootfs image are retained locally.

- Selected module SHA-256: `4cdcbbfea92a05c5bc13e78bffc43133bc42e7f7b4a0d6c81c6a1aa00305feb9`.
- Selected uInitrd SHA-256: `aa75f84757f010c1206ad0babe98ac6ea609450c0fbb8dc49ba9547cba056387`.

Unattended software reboot loaded the selected module and .52.58 firmware with
matching hashes, reconnected Wi-Fi, and restored the reverse SSH proxy. A
post-reboot HTTPS series completed 20/20 CONNECT 200 / HTTPS 200. A simultaneous
1 MiB random payload round trip matched its upload/download SHA-256 and byte
length. This post-deployment test is separate from the saturated 37/40 result;
it does not cancel those observed deadline failures. No physical cold-power-cycle
test of the newly flashed retry variant has been performed yet.

The installed board uses the opt-in retry experiment to reduce failed delivery;
default source builds remain unchanged. Genuine missed-interrupt warnings still
occur outside the quoted load windows, and two sunxi-mmc data errors were logged
earlier in the session. Neither is claimed solved. Further work should isolate
reverse SSH/CONNECT latency and repeat longer tests under controlled RF/load
conditions before describing this as a general XR819 fix.

## Ten-minute follow-up on the installed variant

A subsequent test used the same installed module, with no configuration changes,
flashing, driver reload, or reboot. It offered 600 seconds of simultaneous
bidirectional HTTP and repeated read-only SPI access, with 2,995 pings per path
and 80 HTTPS requests per route. HTTPS requests were scheduled six seconds apart;
all started during load, with the last start at about 474 s. The final roughly
two minutes therefore continued bulk load and pings without new HTTPS requests.
The local test endpoint used a self-signed certificate with verification disabled
only for that endpoint; public HTTPS certificate verification remained enabled.
Periodic diagnostic SSH probes also contributed a small amount of traffic.

| Measurement | Result |
|---|---:|
| Workstation → board ping | 2,894/2,995; 3.37% loss |
| Board → gateway ping | 2,897/2,995; 3.27% loss |
| Workstation → gateway control | 2,995/2,995 |
| Local proxy HTTPS | 80/80 |
| Reverse proxy HTTPS | 68/80; 10 TLS deadlines, 2 CONNECT deadlines |
| Direct public HTTPS control | 79/80; one connection reset by peer |
| Failed firmware TX confirmations | 1,074/150,701; 0.71%, all retry exhaustion |
| Host TTL / firmware lifetime / link-loss confirmations | 0 / 0 / 0 |
| Maximum host queue age | 850 ms |
| Maximum firmware pre-transmission / completion delay | 841,314 / 861,740 us |
| Maximum observed temperature | 50.004 C |

Successful reverse HTTPS requests had a median TLS completion time of 3.052 s;
failed requests are excluded from that median. Local HTTPS had a median TLS time
of 1.277 s. CPU averages ranged from 17.5% to 28.6% busy, with the busiest sampled
core interval at 56.3%. No sampled CPU saturation was observed, which does not
exclude shorter scheduling delays.

The observation window contained one sunxi-mmc `data error, sending stop command`
and one watchdog recovery without an observed IRQ. Poll-read-error counters were
zero, with no observed firmware exception or reassociation/reboot. Bulk HTTP
requests also encountered their separate 10-second deadline. Firmware TX failure
fraction and end-to-end ping loss are different measurements and must not be
substituted for each other.

After load stopped, a 1 MiB random payload round trip matched byte count and
SHA-256, followed by 20/20 CONNECT 200 / HTTPS 200 requests without bulk load.
The temporary LAN test proxy and workstation endpoint were stopped. The installed
module hash remained unchanged, and the production proxy stayed running.

This longer sample was worse than the preceding 200-second sample. It confirms
that the current variant is still unsuitable for a claim of stable, deadline-safe
operation under saturation. The lower retry-exhaustion fractions observed in the
alternating tests remain recorded, but do not establish a general stability fix.
The 79/80 direct control also shows that not every observed HTTPS error is unique
to the board path. No new changes were deployed as a result of this test.
