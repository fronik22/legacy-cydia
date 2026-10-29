# RAM attribution — iPad mini 2 / iOS 7.1.2

2026-10-29. Read-only investigation for the user's ~500–600MiB versus ~150MiB iOS6 comparison. Only the exact attached iPad4,5/7.1.2 was sampled. No iPad2/iOS6 command, UI change, application kill, restart, profile/account change, cache purge or package installation.

## What the HUD number contains

Three native arm64 samples, one second apart, obtained HOST_VM_INFO64 rev1 successfully (returned38 words, matching the SDK layout). Task page size16384 and kernel accounting page size4096 remain different; all counts below use4096. The already-fixed 4x bug was not reapplied.

The final sample at2026-10-29 09:01:28UTC gives:

| System allocation class | MiB |
| --- | ---: |
| Pageable anonymous |177.56 |
| Occupied file-backed |256.35 |
| Wired/nonpageable |114.50 |
| **HUD used: sum above** |**548.41** |
| Free, including speculative |427.12 |
| Physical total reported |975.96 |

The small0.44MiB difference between total and used+free is not assigned to any process. Global snapshots are not atomic across every counter; no fabricated residual allocation is added.

All three samples satisfy the exact page identity:

```
file_backed + anonymous == active + inactive + speculative
used = active + inactive + wired
     = anonymous + (file_backed - speculative) + wired
```

Speculative148.82MiB is already included in free. Total file-backed405.17MiB includes it; subtract it once to obtain occupied file-backed256.35MiB. Purgeable3.30MiB overlaps existing queues and is not a fourth additive bucket. Compressor and compressed-page counts were0. Pageouts stayed0; the cumulative purge counter stayed3078 across these samples (delta0, not “no purge has ever occurred”).

File-backed pages include mapped executable/framework data and filesystem-backed cache; they are not all private app allocations, and not every file-backed page is guaranteed immediately discardable. Anonymous memory also includes system processes and purgeable allocations. Thus “548MiB used” does not mean “548MiB owned exclusively by applications” or “548MiB cannot be reclaimed.”

These counter meanings and the free/speculative identity are checked against Apple's matching XNU2422 source: [vm_statistics.h](https://github.com/apple-oss-distributions/xnu/blob/xnu-2422.1.72/osfmk/mach/vm_statistics.h), [host_statistics64 implementation](https://github.com/apple-oss-distributions/xnu/blob/xnu-2422.1.72/osfmk/kern/host.c). The device arithmetic is independently verified, not inferred merely from field names.

## Which processes are large

Native proc_pidinfo supplied79 process records. Largest RSS values in the same sample:

| Process | RSS MiB |
| --- | ---: |
| SpringBoard |80.13 |
| kernel_task |79.73 |
| Preferences |17.57 |
| CommCenter |15.41 |
| backboardd |15.24 |
| MobileMail |13.34 |
| mediaserverd |13.07 |
| locationd |11.18 |
| deleted |10.54 |
| mobileassetd |9.86 |
| sharingd |9.80 |
| itunesstored |9.05 |
| dataaccessd |8.66 |

Owned products/background services:

| Process | RSS MiB |
| --- | ---: |
| Amnezia6 app |7.81 |
| legacypowerd |1.61 |
| amnezia6d |0.31 |
| Temporary read-only RAM probe |1.97 |

PerfOverlay is injected inside SpringBoard, so it has no independent process RSS and cannot be isolated from SpringBoard by this list. Native kernel_task RSS is also not a second bucket to add on top of wired memory.

All79 RSS values sum to523.20MiB, but that sum is deliberately **not** used to reconcile548.41MiB: RSS can count shared mappings in multiple processes and excludes some unmapped cache/kernel accounting. The near numerical values do not establish equivalent accounting. No500MiB process appears among the successfully read records.

Attempted TASK_VM_INFO counters via task_for_pid succeeded only for the Amnezia6 app; system tasks returnedKERN_FAILURE(5). The application returned rev0/36words, so no unsupported physical-footprint field was read. Its resident7.81MiB splits internal3.73MiB/external4.09MiB. Accurate private-footprint attribution for all system processes remains unavailable; no entitlement escalation, injection or process-memory reading was attempted.

## What differs from the saved iOS6 sample

Reused the existing read-only cached results from2026-10-28; did not access or alter the iOS6 device. That iPad2,2 has~502.98MiB visible physical RAM versus mini2~975.96MiB. It is a different model, OS, runtime architecture, screen resolution, uptime and application set.

The cached iOS6 native HUD uses the same active+inactive+wired definition and recorded173.71MiB (75.56active+26.05inactive+72.11wired). This supports the user's approximate150MiB scale; it is not a fresh simultaneous150-versus548 controlled experiment.

Cached/native process RSS illustrates concrete system differences:

| Process | Cached iOS6 RSS MiB | Current iOS7 RSS MiB |
| --- | ---: | ---: |
| SpringBoard |21.38 |80.13 |
| kernel_task |51.83 |79.73 |
| Preferences |8.97 |17.57 |
| backboardd |8.62 |15.24 |
| MobileMail |6.58 |13.34 |
| mediaserverd |5.99 |13.07 |
| locationd |4.63 |11.18 |

The cached sample contains60 process records and Troubadour68.34MiB; current sample79 records and no Troubadour. This is evidence of genuinely larger measured system processes plus considerable file-backed occupancy, not proof that changing only the OS causes a specific byte delta. iOS6 file-backed/anonymous counters were not retained, so a precise category-by-category OS-only delta cannot be reconstructed. Retina surfaces, dual32/64bit shared libraries, individual injected tweaks and particular caches were not separately measured; none is presented as the proven sole explanation.

## Actions, evidence and cleanup

Inspected existing HUD/native counters and matching Apple kernel field semantics. Wrote a bounded Foundation read-only probe using the already verified96-byte PROC_PIDTASKINFO ABI, counter-count checks and per-task return/count guards. Compiled/signed arm64/iOS7, uploaded through strict localhost22772 (existing exact-device iproxy), took3samples and asserted all three queue identities. No compile/upload/runtime errors occurred. System task-port denials are retained as a measurement limit, not hidden.

Original source/build logs/raw JSONL/sanitized arithmetic summary reside only in private/ram-20261029. The observer's own~1.97MiB and SSH overhead were present; this is an as-found sample, not an unobserved idle minimum. Removed only /var/tmp/codex-ram-probe and verified absence. Parent received the completed as-found window before its exclusive HUD/GPU tests.

Remaining limits: short sampling cannot exclude a long-term leak; no memory-pressure allocation/purge test was run; complete private per-process footprint and a controlled same-hardware iOS6/iOS7 comparison are not established. No service-removal recommendation follows from RSS alone.
