# RAFTER Passport Prototype V0.1

**Status:** DEFINED — implementation not started
**Date:** 2026-09-06
**World:** RAFTER
**Scope:** two bench-capable physical terminals, one Passport, one Mystery consequence
**Depends on:** `docs/product/OUTLAND_PASSPORT_PLATFORM_CONCEPT_V1.md`

> Build the smallest real loop that proves one secure Passport can control temporary access, advance one Mystery and preserve one consequence.

## 1. Recommendation

Build a two-terminal bench prototype before installing anything on RAFTER:

1. **Terminal 1 — Entrance:** authenticate a DESFire EV3 Passport, evaluate a locally cached time-bounded access grant and pulse a test lock.
2. **Terminal 2 — Mystery:** authenticate the same Passport, reject an invalid sequence, accept a valid step, play one audio message, change one light and release a test drawer/cabinet latch.

Use OUTLAND OS as the source of truth, but require both terminals to complete the active stay during a controlled internet outage.

Do not yet build a complete PASSPORT portal, BOOKING product, generalized game engine, generalized IoT fleet platform or final production lock installation.

## 2. Why now

RAFTER provides the first concrete workflow that simultaneously needs:

- persistent guest identity;
- temporary accommodation access;
- physical Mystery interaction;
- offline operation;
- one cross-session consequence.

The prototype exists to discover the minimum real requirements for PASSPORT, SENSE and Universe Engine. It is not a miniature version of the complete future platform.

## 3. Observable outcome

At the end of V0.1, one tester must be able to:

1. receive and activate one OUTLAND Passport;
2. open the entrance test latch during an active RAFTER stay;
3. repeat the entrance action while the internet is disconnected;
4. receive a clear denial before the required Mystery condition is met;
5. complete the required condition;
6. activate light, audio and the Mystery latch;
7. retain `RIVER_KEEPER` after accommodation access expires;
8. replace the card without losing that achievement.

## 4. Scope boundaries

| Capability | V0.1 responsibility | Explicitly excluded |
|---|---|---|
| PASSPORT | Person, Passport, credential status, replacement, one persistent achievement | membership, loyalty, full profile portal |
| BOOKING boundary | One manually created RAFTER stay window used to issue access | availability, pricing, payment, OTA sync |
| Universe Engine boundary | One session, one prerequisite and one completion transition | content editor, generic rules engine, multiple Mysteries |
| SENSE | Two terminals, local decisions, event queue and physical actions | fleet management, telemetry platform, remote automation |

For V0.1, the temporary stay record may be created by an operator fixture or minimal admin action. It does not justify building BOOKING.

## 5. Prototype topology

### Shared server-side role

OUTLAND OS provides:

- Passport activation and credential status;
- manually entered RAFTER stay window;
- terminal-specific access material;
- Mystery session state;
- persistent `RIVER_KEEPER` achievement;
- receipt of idempotent terminal events.

### Terminal 1 — Entrance

Inputs:

- DESFire card presentation;
- local trusted time;
- cached grant and credential verification material;
- optional operator override input.

Outputs:

- green/amber/red feedback;
- short confirmation/denial tone;
- dry-contact relay pulse to a 12 V test latch;
- append-only local event.

### Terminal 2 — Mystery

Inputs:

- DESFire card presentation;
- cached or synchronized Mystery session state;
- one explicit prerequisite flag.

Outputs:

- status light;
- one locally stored audio message;
- relay pulse to a test drawer/cabinet latch;
- append-only local event;
- server-side persistence of `RIVER_KEEPER` after synchronization.

## 6. Hardware decision

### Controller

Use **ESP32-S3-DevKitC-1** or an equivalent ESP32-S3 development board for each credential terminal.

Reasons:

- Wi-Fi is integrated;
- sufficient SPI/I²C/GPIO for NFC, relay, RTC, light and audio;
- ESP-IDF supports Secure Boot V2, flash encryption, encrypted NVS and signed OTA;
- the controller is inexpensive and replaceable.

The existing **ESP32-2432S028** may be used as a display/UI or actuator bench aid. It is not the locked credential-controller choice for V0.1 because its exact module revision and secure provisioning path must first be verified.

### NFC reader

Use an **NXP PN7160 evaluation/development board** connected over SPI for the first secure integration spike.

Reasons:

- ISO/IEC 14443 and ISO-DEP support required by DESFire;
- NCI 2.0 host interface;
- official NXP development path;
- avoids designing an RF antenna in V0.1.

The spike must prove genuine DESFire EV3 AES mutual authentication; merely reading a UID is an automatic FAIL.

Do not use RC522, NTAG213 or UID-only authorization.

### Passport cards

Use 10 original **NXP MIFARE DESFire EV3 4K** blank/test cards from a traceable supplier.

Ten cards are enough for:

- active card;
- expired card;
- revoked card;
- replacement card;
- wrong-key card;
- corrupted/unprovisioned card;
- repeatability and spare samples.

Do not order the first branded batch of 100 cards until AES authentication, personalization and replacement are proven.

### Time

Each terminal requires a battery-backed RTC such as **DS3231**.

Offline authorization must not depend only on time retained by the ESP32 after a power loss. The terminal must reject access if trusted time is unavailable or implausibly rolled back.

### Entrance actuator

For the bench prototype use:

- opto-isolated relay or MOSFET driver;
- fused 12 V DC supply;
- test electric strike or cabinet latch;
- mechanical/manual release independent of firmware.

The bench test does not approve a specific real RAFTER door lock.

### Mystery outputs

Use:

- one addressable or switched 12 V light;
- MAX98357A-class I²S amplifier and small speaker, or equivalent;
- one 12 V cabinet/drawer latch;
- local audio file storage;
- separate fused actuator power.

### Enclosure and power

Use an indoor bench enclosure first. The RAFTER installation will later require a marine-appropriate enclosure, glands, corrosion-resistant connectors and final electrical review.

V0.1 power design:

- isolated AC/DC supply or certified external adapters;
- 5 V rail for controller/reader/audio;
- 12 V rail for latches/light;
- fuse per actuator branch;
- flyback protection for inductive loads;
- physical disconnect;
- no mains voltage exposed inside the user-facing terminal.

## 7. Credential model

### Card identity

- Printed Passport number: human-facing `OP-000001` format.
- Internal credential reference: random 128-bit value.
- Chip UID: diagnostic input only; never the authorization identity.
- Card data: credential reference and minimal version metadata only.
- Profile, access history, Mystery progress and achievements remain in OUTLAND OS.

### DESFire application

V0.1 uses one OUTLAND test application on the DESFire card with:

- a dedicated application identifier;
- AES keys changed from transport defaults during provisioning;
- authenticated access to the credential-reference file;
- no personal data;
- no reservation or Mystery progress stored as primary truth.

Key numbers, file layout and diversification inputs must be recorded in a private provisioning runbook, not in this public repository.

### Key handling

V0.1 must use per-card diversified AES keys.

- The diversification master is used only by the controlled provisioning process.
- A terminal receives only the active card-specific verification material it needs for its current grants.
- No master key is committed to Git, embedded in source code, printed in logs or stored in Supabase client-visible configuration.
- ESP32 Secure Boot, flash encryption and encrypted NVS are enabled before treating the terminal as security-relevant.

A secure element/SAM is a production-hardening candidate, not a V0.1 dependency. The prototype must document the residual risk of terminal extraction before any real guest deployment.

## 8. Provisioning workflow

1. Create a Passport profile with a public Passport number.
2. Generate a random internal credential reference.
3. Generate/diversify card-specific AES keys inside the provisioning process.
4. Create the OUTLAND DESFire application.
5. Replace all relevant default keys.
6. Write the credential reference to an authenticated file.
7. Verify readback through AES mutual authentication.
8. Mark the credential ACTIVE and associate it with the Passport.
9. Produce a signed provisioning result containing no secret keys.
10. Test the card on both terminals.

Any card that still accepts a transport/default key after provisioning fails personalization.

## 9. Access-grant model

For V0.1, an operator manually creates one RAFTER stay:

- `starts_at`;
- `ends_at`;
- Passport/credential;
- RAFTER scope;
- allowed entrance terminal;
- grant revision.

The server derives and sends a terminal-specific cached grant. The card does not carry the stay as booking truth.

Default timing rules:

- grant activates at check-in time;
- grant expires at check-out time plus a configurable 30-minute operational grace period;
- terminal caches only current and next relevant grants;
- cached grant is never valid beyond its explicit `ends_at`;
- revoked credential is rejected after the terminal receives the new revocation revision;
- while offline, revocation latency can last until the cached grant expires.

The operator UI must state that offline revocation is bounded, not instantaneous.

## 10. Offline behavior

### Terminal local state

Each terminal stores:

- terminal identity and configuration version;
- trusted current/next grants for that terminal;
- card-specific verification material for those grants;
- credential revocation revision;
- minimum Mystery session state needed for the active crew;
- append-only unsynchronized event queue;
- last successful synchronization time;
- RTC health state.

### Offline authorization

Entrance access is allowed offline only when:

1. DESFire AES authentication succeeds;
2. credential is locally ACTIVE;
3. trusted RTC time is within the cached grant window;
4. grant scope includes this terminal;
5. local configuration is valid;
6. no local lockout or safety condition is active.

If trusted time is unavailable, the terminal must fail closed for electronic entry while preserving mechanical/operator access and unrestricted safe exit.

### Event queue

Each event uses an idempotency key formed from:

- terminal ID;
- boot/session ID;
- monotonic local sequence number.

The terminal stores at least 1,000 compact events. On reconnection it uploads oldest-first, accepts per-event acknowledgment and deletes only acknowledged local events.

Duplicate delivery must not duplicate Mystery progress or achievements.

## 11. Mystery state machine

V0.1 implements only these states:

- `NOT_STARTED`;
- `READY`;
- `COMPLETED`.

Transitions:

| Current state | Input | Result |
|---|---|---|
| NOT_STARTED | Passport at Mystery terminal | deny; no latch; neutral/amber feedback |
| NOT_STARTED | operator/test prerequisite completed | READY |
| READY | wrong/revoked Passport | deny; state unchanged |
| READY | valid active Passport | play audio, change light, pulse latch, record completion |
| COMPLETED | same Passport again | acknowledgement only; no duplicate achievement |

The prerequisite is intentionally simple in V0.1. It may be set by a test action representing the earlier RAFTER chapter. No generalized rule engine is built.

## 12. Terminal event contract

Minimum event fields:

- `event_id` / idempotency key;
- `terminal_id`;
- `world_code = RAFTER`;
- `location_code`;
- terminal-local timestamp and time-trust status;
- pseudonymous credential reference;
- authentication result;
- decision: ALLOW or DENY;
- reason code;
- Mystery session reference when applicable;
- requested physical action;
- confirmed physical action result;
- firmware/configuration version;
- online/offline mode;
- synchronization status.

No AES key, raw personal data or reusable authentication secret may appear in an event.

## 13. Minimum persistence — candidate model

The prototype may begin with the following minimum logical records:

| Record | Owner | Purpose |
|---|---|---|
| Passport | PASSPORT | persistent person journey identifier |
| Credential | PASSPORT | card status and replacement chain |
| Manual stay | BOOKING boundary | temporary RAFTER time window |
| Access grant | access boundary, still provisional | terminal-scoped derived permission |
| Terminal | SENSE | device identity and configuration |
| Terminal event | SENSE | authentication, decision, action and sync evidence |
| Mystery session | Universe Engine | one crew/session state |
| Achievement | PASSPORT | persistent `RIVER_KEEPER` consequence |

This table is not approval to create eight database tables. During implementation, records may be represented by fixtures or fewer explicit tables if that proves the loop safely. Any structural database change requires a separate reviewed migration.

## 14. Minimal operator workflow

V0.1 needs only four operator actions:

1. activate/provision Passport;
2. create or expire one manual RAFTER stay;
3. revoke and replace a credential;
4. reset the test Mystery session.

These actions may initially be scripts or a restricted internal test screen. A complete guest/admin application is out of scope.

## 15. Failure and safety behavior

| Failure | Required behavior |
|---|---|
| internet unavailable | cached valid entrance grant still works; events queue locally |
| server unavailable | no loss of local events; Mystery uses bounded local state |
| NFC authentication fails | deny; no actuator pulse |
| RTC invalid or rolled back | deny electronic entry; mechanical/operator route remains |
| relay/actuator feedback fails | record physical-action failure; do not claim success |
| audio fails | Mystery latch may remain available only if the game design explicitly allows graceful completion |
| Mystery service/state invalid | normal accommodation remains unaffected |
| power loss | safe exit remains possible; mechanical/operator access remains |
| card lost | revoke; issue replacement; achievement stays on Passport profile |

No terminal may control an exit path that could trap a guest.

## 16. PASS/FAIL test protocol

### P01 — Valid online entrance

Given an ACTIVE card and active stay, presentation at Terminal 1 authenticates with AES, pulses the latch once and records ALLOW.

**PASS:** latch pulse and synchronized event both occur.
**FAIL:** UID-only decision, repeated pulse, missing event or incorrect time window.

### P02 — Controlled offline entrance

Synchronize the active grant, disconnect the network and power-cycle the terminal.

**PASS:** trusted RTC survives, AES authentication succeeds, latch pulses and event remains queued.
**FAIL:** network is required, time resets, or event is lost.

### P03 — Expired and future grant

Present the card before `starts_at` and after `ends_at + grace`.

**PASS:** both attempts are denied with distinct reason codes.
**FAIL:** either attempt opens the latch.

### P04 — Revocation and replacement

Revoke the active card while terminals are online, issue a replacement card and repeat at both terminals.

**PASS:** old card is denied; new card works; Passport and existing achievement identity remain unchanged.
**FAIL:** old card remains valid after revocation sync or achievement is lost.

### P05 — Mystery ordering

Present the valid card in `NOT_STARTED`, then set the prerequisite and present it again.

**PASS:** first attempt denies without outputs; second attempt transitions READY → COMPLETED.
**FAIL:** the first attempt completes the Mystery or the second fails without a defined reason.

### P06 — Physical Mystery reaction

Complete the valid Mystery step.

**PASS:** light, audio and latch execute once; action result is recorded.
**FAIL:** partial action is reported as full success or repeated card taps duplicate completion.

### P07 — Offline event synchronization

Generate entrance and Mystery events offline, reconnect and retry the upload.

**PASS:** all events arrive once logically despite retransmission; order and action results are preserved.
**FAIL:** missing events, duplicate progress or duplicate achievement.

### P08 — Safe degradation

Independently disconnect server, network, NFC reader, RTC, audio and actuator feedback.

**PASS:** no guest can be trapped; normal accommodation remains possible through the defined fallback; failures are visible to the operator.
**FAIL:** unsafe lock state, silent false success or Mystery failure blocking essential accommodation.

V0.1 is complete only when all eight tests pass in one recorded run.

## 17. Evidence package

The final prototype run must retain:

- terminal firmware/configuration versions;
- card personalization test result without secrets;
- exact test timestamps;
- P01–P08 result table;
- exported terminal events;
- offline duration;
- photos or short video of both terminal reactions;
- known limitations;
- go/no-go decision for real RAFTER installation.

## 18. Prototype BOM

Working estimate for two terminals:

| Item | Qty | Working unit estimate | Working total |
|---|---:|---:|---:|
| ESP32-S3 development board | 2 + 1 spare | €15–30 | €45–90 |
| NXP PN7160 evaluation/development board | 2 + 1 optional spare | €45–90 | €90–270 |
| Original DESFire EV3 4K test cards | 10 | €5–10 | €50–100 |
| DS3231 RTC module and battery | 3 | €5–12 | €15–36 |
| Isolated relay/MOSFET drivers | 4 | €8–20 | €32–80 |
| 12 V test latch/strike | 2 | €25–60 | €50–120 |
| 5 V/12 V certified power, fuses and protection | set | €80–160 | €80–160 |
| Light, I²S amplifier and speaker | set | €35–80 | €35–80 |
| Bench enclosures, connectors, wiring and spares | set | €120–250 | €120–250 |
| **Hardware subtotal** |  |  | **€517–1,186** |

These are planning ranges, not supplier quotations.

External or fully costed engineering, provisioning, firmware, backend integration, test fixtures and documentation can reasonably keep the earlier total prototype envelope at approximately **€3,000–5,000**. Internal development changes the cash cost but not the engineering effort.

Do not buy 100 branded cards or marine-installation hardware in V0.1.

## 19. Implementation sequence

### Gate A — NFC security spike

- one ESP32-S3;
- one PN7160 development board;
- two DESFire EV3 cards;
- AES mutual authentication;
- diversified keys;
- authenticated credential-reference read;
- UID-only access demonstrably impossible.

Stop if Gate A fails. Do not build relays or backend tables around an unproven NFC stack.

### Gate B — Entrance bench loop

- trusted RTC;
- one manually issued grant;
- online and offline decision;
- relay/test latch;
- durable event queue.

### Gate C — Mystery bench loop

- one prerequisite;
- three-state session;
- light, audio and latch;
- idempotent completion;
- persistent `RIVER_KEEPER`.

### Gate D — Replacement and failure tests

- revocation;
- replacement;
- P01–P08;
- evidence package;
- real-installation decision.

## 20. Deliberately not building

- full BOOKING;
- full PASSPORT web/mobile experience;
- loyalty or membership;
- more than one Mystery session model;
- generic rules/workflow engine;
- event bus;
- microservices;
- multi-World synchronization;
- production fleet management;
- remote safety-critical unlocking;
- final marine enclosure or door hardware;
- branded card batch.

## 21. Expansion triggers

Proceed from V0.1 to a real RAFTER pilot only if:

1. P01–P08 all pass;
2. secure NFC integration is maintainable;
3. offline behavior is predictable;
4. residual key-extraction risk has an accepted mitigation plan;
5. real lock and egress design is approved by a qualified installer;
6. hardware quotations keep the pilot within the agreed envelope;
7. RAFTER has a legal, supervised operating location.

Only the operating evidence may justify additional terminals, schemas, UI or cross-World behavior.

## 22. Open decisions before Gate A

These are procurement/implementation decisions, not architecture redesign:

- exact PN7160 evaluation board SKU and supplier;
- exact ESP32-S3 module/board revision;
- card supplier and proof of genuine NXP silicon;
- AES diversification scheme and private provisioning environment;
- firmware language/library choice within ESP-IDF;
- whether a secure element/SAM is required already for the real RAFTER pilot;
- who performs final lock and low-voltage installation.

## 23. Authoritative technical references

- NXP, **MIFARE DESFire EV3** product documentation: <https://www.nxp.com/products/rfid-nfc/mifare-hf/mifare-desfire/mifare-desfire-ev3-high-security-ic-for-contactless-smart-city-services:MF3DHX3>
- NXP, **PN7160** NFC controller documentation: <https://www.nxp.com/products/rfid-nfc/nfc-hf/nfc-readers/plug-and-play-nfc-controller-with-integrated-firmware-and-nci-interface:PN7160>
- Espressif, **ESP32-S3 datasheet and ESP-IDF documentation**: <https://docs.espressif.com/projects/esp-idf/en/stable/esp32s3/>
- Espressif, **ESP32-S3 flash encryption**: <https://docs.espressif.com/projects/esp-idf/en/stable/esp32s3/security/flash-encryption.html>
- Espressif, **ESP32-S3 Secure Boot V2**: <https://docs.espressif.com/projects/esp-idf/en/stable/esp32s3/security/secure-boot-v2.html>
- Espressif, **NVS encryption**: <https://docs.espressif.com/projects/esp-idf/en/stable/esp32s3/api-reference/storage/nvs_encryption.html>

## 24. Decision

**RAFTER Passport Prototype V0.1 is sufficiently defined to begin Gate A — the NFC security spike.**

No database migration, application module or hardware purchase is authorized by this document alone.
