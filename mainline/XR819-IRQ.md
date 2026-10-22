# XR819 interrupt and firmware investigation (2026-10-21)

The original warning is emitted after the BH thread's HZ/30 watchdog expires and
a control-register read discovers RX data. It is not proof that the IRQ line is
dead, nor does its count equal packet loss. GPIO IRQs were arriving normally
(about 100,000 observed), with the rising-edge polarity recommended upstream.

Instrumentation snapshots an atomic IRQ count and the pending BH wake flag before
and after the watchdog's SDIO read. It keeps separate counters for recoveries,
IRQs racing the read, recoveries with no observed IRQ, and read errors. The latter
are observations within that window, not logic-analyzer proof of an electrical
failure. The pending BH wake flag also represents TX work and is not sufficient
evidence of an IRQ; the final classifier uses the IRQ counter delta alone. The diagnostic patch no longer calls a recovery a missed interrupt only when
the IRQ counter actually changed during the check; all recoveries remain
counted and the no-IRQ case still produces a warning. Recovery scheduling and
the 33 ms watchdog are unchanged.

## Controlled configuration comparisons

Each row runs simultaneous 300-packet pings at 0.2 second intervals, from the
board to the gateway and from the workstation to the board, followed by a short
idle period. These are sequential samples in an uncontrolled RF environment,
not randomized trials or a long-duration reliability qualification.

| Firmware / configuration | Gateway received | Board received | Recoveries without observed IRQ | Provisional IRQ/wake races |
|---|---:|---:|---:|---:|
| .52.28 / GPIO / HT | 285/300 | 284/300 | 2 | 0 |
| .52.28 / native SDIO / HT | 290/300 | 282/300 | 0 | 0 |
| .52.28 / native SDIO / HT disabled | 280/300 | 278/300 | 2 | 1 |
| .52.58 / GPIO / HT | 293/300 | 295/300 | 0 | 1 |
| .52.58 / native SDIO / HT | 288/300 | 296/300 | 1 | 0 |
| .52.58 / GPIO / HT / upstream RX fix #34 | 296/300 | 298/300 | 1 | 0 |

The table was collected with the initial diagnostic predicate, which classified
either an IRQ delta or a pending wake as a race. The final deployed predicate
requires an actual IRQ counter delta; TX-only wakes are not suppressed. The
.52.58/GPIO race was directly observed as IRQ count 1380 to 1381 during the read.

Switching transport or disabling HT did not eliminate losses. Native SDIO initially
showed no recoveries, but subsequent runs still did, so it is not a cure. No SDIO
read errors or firmware exceptions were observed. Signal was approximately
-60 to -62 dBm with significant TX retries. MFP was not negotiated, so upstream
ARP/PMF fix #31 is not part of the selected configuration.

## Firmware discrepancy

miZy retained firmware XR_C01.08.52.28 (2017-09-04). Armbian's pinned firmware is
XR_C01.08.52.58 (2018-07-19), imported in 2020. It is newer than the device's file,
not a newly released 2026 firmware. Boot and SDD calibration blobs match exactly;
only fw_xr819.bin changes.

- Original SHA-256: `9cab72aa85e8a88ac752422de8e1e78698532da467465eaef7e16be9eff3fb3e`.
- Candidate SHA-256: `fb81436ad7cc0876614a2a9c2a54c5a93a75315aee164e3a3afe3db80842a9e1`.
- Source: https://github.com/armbian/firmware/commit/aff348fa9eef0fcc97d4f2bb7304f0862baffc20
- Vendor-firmware reference: https://github.com/karabek/xradio/pull/1
- IRQ setup and known firmware limits: https://github.com/fifteenhex/xradio

The new firmware plus the one-line HT RX encoding fix was the best of these
short samples. RX bitrate metadata then showed actual HT MCS rates. This does
not prove that firmware caused all observed differences or that losses are fixed.

## Load limits

Follow-up isolated load tests and the opt-in queue/firmware timing instrumentation
are recorded in [XR819-LOAD.md](XR819-LOAD.md). Saturation reproduced TLS timeouts
without any watchdog recovery, so an IRQ-only explanation is insufficient.


A subsequent run added two 4 MiB SSH transfers in each direction (16 MiB total),
HTTPS relay requests and a concurrent 16 MiB SPI backup. All transfer hashes
matched, the driver stayed up, and no firmware exception/read error occurred.
Gateway ping was 578/600; inbound was 571/600. The watchdog counted 1 recovery
without observed IRQ and 2 provisional IRQ/pending-wake race classifications. Fifteen HTTPS requests succeeded, then one
TLS handshake exceeded its 5 second deadline. This additional SPI/SSH load is not
a matched comparison to the quiet rows. After the backup ended, a separate
20-request HTTPS retest completed 20/20 CONNECT 200 / HTTPS 200.

Do not claim that this fixes packet loss, guarantees TLS deadlines under saturation,
or establishes long-term stability. The original pre-experiment image remains
available for recovery. Private raw logs, payloads and backups stay in ignored
build/artifacts/xradio-irq/.

## Reproduction

The default driver remains unchanged upstream code. To build the selected module:

```sh
XRADIO_FIXES=0 XRADIO_HT_RX_FIX=1 XRADIO_IRQ_DIAGNOSTICS=1 \
  XRADIO_IRQ_EXPERIMENT=0 bash /workspace/kernel/mainline/build.sh
```

Download firmware into the ignored build directory from the pinned Armbian commit,
then pass XRADIO_FIRMWARE_FILE to package-rootfs.sh; it rejects any SHA-256 except
the one above. No firmware binary is checked in. A reused build tree can reverse
all source patches by setting the flags to 0. Native SDIO and disable_ht options
are available only with XRADIO_IRQ_EXPERIMENT=1, remain opt-in, and were not
selected for persistence. Diagnostics alone does not add either transport option.

## Persistence and recovery

The selected .52.58 firmware, #34 and diagnostic classification were written to
the rootfs slot and verified with mtd verify. Only initrd changed: kernel, DTB,
boot script, U-Boot and user partitions retained their previous hashes. Unattended
software reboot loaded the new firmware label and matching module hashes and
reconnected Wi-Fi. The kernel remains 6.12.113-mizy-h2plus. No final physical
power-cycle or long-duration soak qualification has been performed.

A full pre-change SPI backup is preserved locally with SHA-256
`757b85384fd6c045a22777d40dd98f601d852b903ed1f205289e8a9929632a6c`.
Source patch toggles were tested to restore all five driver files byte-for-byte
to the pinned upstream version and then back to the selected configuration.
The native SDIO and HT-disable paths are retained strictly as optional diagnostic
experiments, not as the installed fix. The firmware binary is not distributed
in the repository.

Inside the prepared container, the optional firmware can be supplied explicitly:

```sh
curl -fL https://raw.githubusercontent.com/armbian/firmware/aff348fa9eef0fcc97d4f2bb7304f0862baffc20/xr819/fw_xr819.bin \
  -o /workspace/build/downloads/xr819-fw-52.58.bin
XRADIO_FIRMWARE_FILE=/workspace/build/downloads/xr819-fw-52.58.bin \
  bash /workspace/kernel/mainline/package-rootfs.sh
```
