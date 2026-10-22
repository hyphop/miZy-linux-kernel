# XR819 saturation and TLS investigation (2026-10-21)

The 2026-10-22 hardware follow-up, failure-status diagnosis, and retry-ceiling
experiment are in [XR819-RETRY.md](XR819-RETRY.md). The operator confirmed that
the access loss described below was an intentional power-off.

## What was isolated

The board retained Linux 6.12.113, firmware .52.58, HT RX correction #34 and
strict IRQ diagnostics. No flash writes were made in this investigation.

Each phase offered 45 seconds of load, three simultaneous 220-packet pings at
0.2 second intervals, CPU samples and 15 HTTPS requests on each of three paths:

- Workstation through a separate, LAN-restricted tinyproxy test listener to a
  workstation TLS server: no WAN or reverse SSH dependency.
- Workstation directly to the public HTTPS origin: WAN control.
- VPS through the production reverse SSH/tinyproxy path to the public origin.

Network load was one continuous 1 MiB download loop and one 1 MiB upload loop
between the board and workstation over plain HTTP. Both were Wi-Fi clients of
the same AP. SPI load repeatedly read mtd4 to /dev/null; it did not write flash
or transfer a backup over Wi-Fi. Tests were sequential in uncontrolled RF
conditions, not randomized comparisons. Curl used a 5 second connect/CONNECT/TLS
deadline and 15 second total deadline. Requests were scheduled every two seconds
within each sequential route; slow requests could push later requests beyond the
45 second load. Counts therefore include some recovery requests after load ends.

## Results

| Phase | Local proxy HTTPS | Direct public HTTPS | Reverse relay HTTPS | Workstation → board ping | Board → gateway ping | No-IRQ recoveries |
|---|---:|---:|---:|---:|---:|---:|
| Idle | 15/15 | 15/15 | 15/15 | 213/220 | 213/220 | 1 |
| Network only | 15/15 | 15/15 | 11/15 | 204/220 | 202/220 | 0 |
| SPI reads only | 15/15 | 15/15 | 15/15 | 210/220 | 215/220 | 2 |
| Network + SPI reads | 15/15 | 15/15 | 11/15 | 204/220 | 207/220 | 0 |
| Network, TCP output limit 16 KiB | 15/15 | 15/15 | 13/15 | 200/220 | 200/220 | 0 |
| Network, SDIO 25 MHz | 15/15 | 15/15 | 10/15 | 196/220 | 209/220 | 0 |

Workstation → gateway was 220/220 in all phases except SPI-only (219/220).
The network-only phase had 25,726 TX retries and 1,172 TX failures reported by
mac80211 for 14,736 TX packets; board TCP retransmissions increased by 252.
The local proxy's maximum TLS completion time increased from 0.226 s idle to
3.675 s under network load. Reverse-path failures included both TLS handshake
timeouts after CONNECT 200 and one timeout waiting for CONNECT. CPU0 averaged
32.6% busy in network-only, with a busiest sampled second of 56.8%; other CPUs
averaged 16.7–18.3%. Network+SPI averaged 39.3% on CPU0. No softnet backlog drops
were observed in these completed phases.

These observations implicate the board's Wi-Fi link/retransmission and queueing
path under saturation, with additional delay on the reverse SSH path. They do
not identify one faulty driver instruction, prove RF conditions alone are to
blame, or establish SSH head-of-line blocking as the sole cause. In particular,
the reproduced timeout phase had zero watchdog recoveries: missed-interrupt
warnings are not a sufficient explanation. SPI/CPU saturation was not supported
by these samples. Tinyproxy forwards TLS bytes; the board's old curl TLS library
is not used to terminate clients' TLS sessions. Raising a client timeout would
change the acceptance criterion rather than demonstrate a stability fix.

One sunxi-mmc `data error, sending stop command` appeared during the original
50 MHz network test. The SDIO clock was temporarily reduced to 25 MHz to test
that hypothesis; timeouts persisted, with worse ping delivery in this sample.
This does not rule out intermittent SDIO errors. The clock was restored to
50 MHz. The TCP limit was also restored to its original 1,048,576 bytes after
its trial, which did not demonstrate a reliable improvement.

## Incomplete rate-cap trial and device access

A final runtime-only trial limited legacy TX rates to 6/12/24 Mbps and HT MCS to
0–3, preserving HT. All three HTTPS routes completed 15/15 requests, and inbound
ping was 212/220. However, before the final device snapshot, SSH became
unreachable and the workstation's USB UART device disappeared. The reverse
forward was also absent afterward. The missing UART cannot be explained by a
Wi-Fi rate mask alone; the physical/power/access state needs confirmation.
Do not treat this incomplete trial as a successful fix or assume its disconnect
cause. The rate mask was not persisted; if the same boot is recovered, clear it
with `iw dev wlan0 set bitrates`. A reboot clears all these runtime experiments.

## Opt-in driver diagnostics prepared, not deployed

`XRADIO_LOAD_DIAGNOSTICS=1` adds read-only module parameters, reset at module
reload, without changing queue limits, scheduling, retry policy or frame format:

| Parameter | Observation |
|---|---|
| diag_host_queue_max_ms | Maximum enqueue-to-dequeue age in the host queue, including any requeues |
| diag_host_queue_over_100ms | Number of dequeue observations aged at least 100 ms; not unique packet count |
| diag_host_queue_expired | Number of host queue entries expired by TTL garbage collection |
| diag_fw_queue_max_us | Maximum firmware-reported pre-transmission queue delay |
| diag_fw_media_max_us | Maximum firmware-reported time until transmission completion |
| diag_tx_confirm_count | TX confirmations observed, including requeues |
| diag_tx_confirm_failed | Nonzero confirmation status excluding WSM_REQUEUE |

Maxima are clamped to INT_MAX, counters are atomic, and no per-frame log messages
are added. Firmware timing fields are observations reported by firmware, not an
independent wall-clock validation. The patch defaults off independently of IRQ
diagnostics. It cross-compiled successfully with the existing ARM toolchain;
reverse/apply round-trip restored the pinned upstream queue.c/tx.c exactly and
then reproduced the modified source hashes. It has **not** been loaded on the
board because device access disappeared before deployment. The previously
verified flashed module remains unchanged.

Next: recover access, clear the rate mask, load this diagnostic module in RAM
with a rollback plan, then measure host queue delay versus firmware delay under
the same load. Repeat any promising rate/queue experiment in alternating order
before persisting it. The current kernel has CONFIG_NET_SCHED unset and wlan0
uses noqueue; fq_codel/tc shaping cannot be enabled by a sysctl alone. XR819 also
maintains its own legacy TX queues, so a future qdisc would not replace those.

Private raw records and the compiled candidate are in ignored
build/artifacts/xradio-load/. No credentials, firmware images or provisioned
flash dumps are included in this report.
