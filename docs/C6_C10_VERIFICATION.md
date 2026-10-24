# C6–C10 implementation and verification evidence

## Scope and source

Source: the user's approved C6–C10 task list in this session, with the revised
Gateway detail design: preserve Gateway metadata, put Telemetry history first
and the existing Sensor catalog second in two tabs, and select one authorized
Sensor in a dropdown. History rendering is shared with Sensor Twin detail.

No backend edits, new dependencies, release builds, commits, or pushes are
authorized by this task. Commands in the supplied plan were treated as
verification intent; only repository-appropriate local checks are run.

## User journeys and acceptance boundaries

- A signed-in member browses and filters assigned Twins, explicitly loading the
  next page without one detail request per list row.
- A member opens a Twin deep link, reads normalized metadata/relationships and
  lazily loads read-only state when that tab is selected.
- A member chooses one Sensor within Gateway detail, queries bounded raw or
  aggregated history, and switches to the unchanged Sensor catalog.
- An authorized owner/admin edits metadata only, without device commands,
  changing units, or automatically replaying an uncertain mutation.
- Switching identity, filters, resource, or tab does not expose a late response
  from the previous query/session. Read denial purges unauthorized data without
  logging the user out.

## Baseline (before implementation)

- Checkout: `dev`; `git status --short` returned no changes.
- Local SDK: Flutter 3.47.6 / Dart 3.13.5. Existing CI pins Flutter 3.47.1;
  no SDK or dependency upgrade was performed.
- `flutter test --reporter expanded`: **414 passed**, `All tests passed!`.
  Local log: `/tmp/opencode/c6-c10-baseline-tests.log`.
- `flutter analyze`: **PASS**, `No issues found!`.
  Local log: `/tmp/opencode/c6-c10-baseline-analyze.log`.
- Read-only HTTP probes: `http://localhost/healthz` returned **200**;
  `http://localhost/v1/health` returned **502**. This is not backend acceptance.
- Chrome is installed at `/usr/bin/google-chrome`.

## Implementation evidence

Implementation, RED/GREEN results, coverage, and review findings will be recorded
here only after the corresponding checks actually run.

### C6 — membership-scoped simplified Twin list

- Added authenticated `/digital-twins` navigation/list with typed root-array
  summaries, type/member-Gateway filters, explicit load-more, no row detail/state
  requests, and a 20-page/1000-row in-memory bound. Filter/session changes fence
  pending responses; denial purges rows without signing out. Repeated cursors or
  non-advancing pages stop with a visible error, retaining new valid rows.
- Uses the existing repository, `ApiResponse.asList` (the accessor actually
  present in this checkout), shared `ApiClient.buildUri('digital-twins')`, and
  `SafeLinkParser`. Next links resolve against the query-bearing request URI;
  origin/path/query allowlist, filters, simplified format and page size are checked.
  Gateway options use only `GatewayRepository.getGateways`, never admin inventory.
- Tightened URN IDs/reserved Gateway validation and summary parsing. Backend
  `TwinSummaryFlatDTO.Name` is optional (`omitempty`), so absent/null name remains
  supported; identity, type, Gateway and required UTC `modifiedAt` cannot silently
  default. No repository interface/signature or shared Link parser changes.
- Added single-encoding route helpers and links in Gateway catalog/detail and
  Sensor catalog without rearranging existing metadata/Sensors. **At C6 handoff:**
  `/digital-twins/<encoded-URN>` was not registered, so those detail links reached
  the existing not-found page. No fake detail screen was added. This dependency
  is now resolved by the separate C7 implementation recorded below.
- Runtime RED: `flutter test test/c6_foundation_test.dart --reporter expanded`
  executed and failed **3 assertions** (invalid URN accepted, malformed summary
  defaulted, navigation missing). Log: `/tmp/opencode/c6-red.log`.
  Additional runtime regressions for optional backend name and required timestamp
  each failed before their correction: `/tmp/opencode/c6-optional-name-red.log`,
  `/tmp/opencode/c6-required-timestamp-red.log`. A temporary widget-test compile
  error was corrected; it is **not** counted as RED evidence.
- GREEN command:
  `flutter test test/c6_foundation_test.dart test/twin_list_page_test.dart test/twin_list_provider_test.dart test/twin_list_screen_test.dart test/twin_list_http_test.dart test/digital_twin_dto_test.dart test/digital_twin_repository_test.dart --reporter expanded`
  — **40 passed**, `All tests passed!`; `/tmp/opencode/c6-targeted.log`.
  Covers root-array HTTP fixtures/Accept/auth, safe next links, terminal no-Link,
  filters/reset, stale/session responses, anonymous no-fetch, authorized-empty
  admin/no bypass, cursor/no-progress/capacity, denial and no N+1; widget tests
  check 390x844, 1024x768, 1366x768, 1920x1080 without reported layout exceptions,
  plus catalog/detail/Sensor navigation helpers at 390/1366px.
- Final `flutter test --reporter expanded`: **443 passed** (29 added tests),
  `/tmp/opencode/c6-full-tests.log`. `flutter analyze`: **PASS**, `No issues found!`,
  `/tmp/opencode/c6-analyze.log`. Changed Dart files formatted with `dart format`;
  ARBs regenerated with `flutter gen-l10n`; `git diff --check`: **PASS**.
- Runtime wiring uses real Go repositories; tests use explicit fakes/HTTP fixtures.
  Coverage percentages, live browser/backend acceptance and release builds were
  not run or claimed. C7–C10 were not implemented in this call.

### C7 — normalized detail, relationships and lazy read-only state

- Registered `/digital-twins/:entityId`, preserving the single-decoded raw URN
  from the existing `R.twinDetail` helpers. Invalid/unknown-type/reserved URNs
  render a safe localized not-found message without a business request; a valid
  but inaccessible/absent entity returns the same UI on backend 404, retains the
  deep-link URL/session, and offers back-to-list. The existing restoring-session
  barrier is preserved; widget tests simulate restore without a login redirect.
- Added `TwinDetail`, passive typed `TwinProperty<T>`, and `TwinDetailPage` in
  `data/twin_detail.dart`; `DigitalTwinRepository.getTwinDetail` uses the existing
  authenticated `ApiClient.getEnvelope` with `Accept: application/ld+json` and
  retained Link headers. Gateway identity comes from the validated URN, NOT a
  nonexistent root `gateway_id`. Supports omitted optional Properties/empty
  hasSensor, Gateway URI-array relationships and Sensor isHostedBy without
  objectType. Property timestamps are parsed independently of root timestamps.
  Known CEL/C81/P1 units map to °C/rad/%; unknown raw measurementUnit is retained.
  Context is ignored, never fetched/processed; API strings are plain text.
- Extended the existing `SafeLinkParser` with an optional endpoint path
  canonicalizer (not another Link parser). Encoded and colon URN paths compare
  after exactly one decode and strict URN validation; raw dot/slash escapes are
  checked before URI normalization. Origin, endpoint, query allowlist, duplicate
  query checks and immutable page-size enforcement remain in place. Only
  relationship_limit/relationship_after are accepted. The notifier explicitly
  loads more, stops duplicate/non-advancing/repeated-cursor pages and bounds
  accumulation at 20 pages × 20 relationships (400 maximum), without Sensor
  detail fan-out or admin inventory/read bypass.
- The information pane requests normalized detail only. The state pane is
  mounted only on selection and calls `GET ?format=simplified` only then;
  inactive panes/providers dispose. State JSONB uses `formatTwinJson`, which
  writes BigInt numeric tokens intact while retaining ordinary numbers, quoted
  strings, nulls and nested arrays/maps. Versions stay exact strings; nullable
  UTC timestamps show localized no-data. Both panes are read-only.
- Fixed `TwinStateViewNotifier` explicit-null clearing, anonymous fetches,
  identity/epoch/sequence fencing, cross-session in-flight lock ownership,
  denial purge (403/404) versus transient stale retention (503), and same-user
  token-refresh resets. Both detail/state providers are autoDispose. Detail
  first-page retry replaces rather than duplicate-appends its stale snapshot.
- TDD runtime RED evidence (compilation/setup failures are NOT counted):
  - `flutter test test/c7_state_regression_test.dart --reporter expanded`:
    **6 failed assertions, 1 passed** on the original provider; log
    `/tmp/opencode/c7-state-red.log` (denial purge, refresh reset, session lock,
    anonymous fetch, explicit null clear).
  - `flutter test test/c7_detail_screen_test.dart --reporter expanded`:
    **11 failed runtime tests** before route/detail UI implementation; log
    `/tmp/opencode/c7-screen-red.log` (deep link, restore, invalid URL handling,
    lazy reads and responsive detail missing). The HTTP fixture tests were also
    written/run before adding the repository method; their initial runtime
    missing-method results are in `/tmp/opencode/c7-detail-red.log`.
  - Additional correction REDs: first-page retry **1 failed / 14 passed** in
    `/tmp/opencode/c7-retry-red.log`; wrong-state-identity acceptance
    **1 failed / 7 passed** in `/tmp/opencode/c7-state-identity-red.log`.
- GREEN and final verification actually run:
  - `flutter test test/c7_state_regression_test.dart test/c7_detail_http_test.dart test/c7_detail_provider_test.dart test/c7_detail_screen_test.dart --reporter expanded`:
    **55 passed**; `/tmp/opencode/c7-focused.log`.
  - `flutter test --coverage --reporter expanded`: **498 passed** (443 prior +
    55 C7), `All tests passed!`; `/tmp/opencode/c7-full-tests.log`.
  - Coverage from that run (`coverage/lcov.info`): new detail DTO/page **82/82**
    lines, detail notifier **69/69**, JSON display **11/11**, detail screen
    **124/140 (88.6%)**, existing state provider **51/52 (98.1%)**. These are
    line-coverage measurements, not branch/browser acceptance certification.
  - `flutter analyze --fatal-infos`: **PASS**, `No issues found!`;
    `/tmp/opencode/c7-analyze.log`. Changed Dart formatted with `dart format`;
    `flutter gen-l10n` regenerated ARBs; `git diff --check`: **PASS**.
  - Widget tests cover metadata detail at **390×768, 1024×768, 1366×768,
    1920×1080**, Vietnamese/light and English/dark, with no reported layout
    exceptions; lazy state/null/exact-number scenarios at desktop. HTTP fixtures
    cover malformed shapes, Link terminal/encoding/origin/path/query constraints;
    runtime tests cover late success/error, tab/resource/session switching,
    denial/stale distinction, bounded accumulation and request counts/no N+1.
- C8 insertion interface: `TwinDetailScreen.entityId` is the authoritative raw
  Sensor URN. Add a separately mounted history pane at its existing active-pane
  conditional, sharing a history widget outside cross-feature presentation
  internals with Gateway detail. `TwinDetail.entity` provides validated identity
  and `displayUnit`/Properties expose passive metadata; no history query or chart
  is implemented here. Gateway detail metadata and Sensor catalog ordering were
  not edited by C7. C9 may attach an explicitly authorized metadata action in the
  info pane and refresh `twinDetailProvider(rawUrn)` after confirmed success;
  no edit controls/mutations were added in C7.
- Runtime API wiring is real; tests use explicit repository fakes/HTTP fixtures.
  The pre-existing list fake now explicitly implements all repository methods
  (no blanket noSuchMethod). No backend/dependency edits, release build,
  staging/commit/push or C8–C10 implementation occurred. No new live backend or
  browser acceptance is claimed; the baseline localhost API health probe was
  502, and no credentials were requested or extracted. Browser F5 is simulated
  through restoring-session widget tests, not certified against a deployment.

### C8 — temporal observation history charts and shared history component

- Added `packages/kite_ui/lib/src/temporal_chart.dart` exported from `packages/kite_ui/lib/kite_ui.dart`,
  keeping `KiteLineChart` unchanged. Implemented straight segments (`isCurved: false`), gap
  handling for omitted missing buckets (segmented lines without zero-filling or smoothing),
  relative time microsecond arithmetic (`inMicroseconds / 1e6`) against `baseTime` avoiding
  float32 precision loss, responsive tooltips with formatted UTC microsecond timestamp, value
  and unit, spot-specific tooltip mapping showing bucket start and end time, `fitInsideHorizontally`
  and `fitInsideVertically` boundary fitting, series legend, and keyboard-accessible focusable
  button toggle separating `totalCount` from the measurement Y-axis. Removed third-party `fl_chart`
  re-exports from `kite_ui` to preserve encapsulation; no direct `fl_chart` imports exist in app `lib/`.
- Implemented `TemporalHistoryPanel` in `lib/shared/widgets/temporal_history_panel.dart` with extracted
  modular components `TemporalHistoryControls` (`temporal_history_controls.dart`) and
  `TemporalHistoryTable` (`temporal_history_table.dart`). Features:
  - Strict Draft vs Applied query separation: `effectiveUnit` derives exclusively from `appliedQuery?.attrs`
    so modifying draft dropdowns without Apply never mislabels old displayed data. A separate status banner
    displays applied query parameters (time range, mode, attribute, and max points).
  - Refresh button explicitly reruns `appliedQuery`, while Apply applies draft form inputs.
  - Strict calendar date parsing (`parseStrictUtcDate`): rejects invalid dates such as Feb 30 rather than
    Dart normalizing to March 2; validates month/day ranges explicitly.
  - Configurable `max_points` control (500, 1000 default, 2000) and 6 quick presets (10s raw, 15m, 1h, 24h, 7d, 30d).
  - Detailed bounded data inspection table rendering exact sample timestamps (with microseconds when present),
    formatted values, and exact BigInt sample counts without `.0` floating loss.
- Enhanced query guards in `DigitalTwinRepository.getSensorTemporal`: reuses `TemporalQueryParameters.validate()`,
  strictly forbidding `aggrPeriodDuration` and `aggrMethods` in raw mode, enforcing 31-day range cap, canonical
  9 durations, and method allowlist without duplicates. Serializes RFC3339 UTC microsecond timestamps.
- Corrected DTO parsing in `TwinTemporalResponse.fromJson`:
  - Retains `isAggregated == true` on valid empty aggregate responses.
  - Rejects mixed payloads containing both raw `values` and aggregate method keys as malformed with `FormatException`.
  - Rejects string measurements in raw tuples and aggregate triples; enforces strictly finite numeric types.
  - Rejects negative counts or inverted bucket timestamps (`start >= end`).
- Complete bucket-key sets in `TemporalStats`:
  - Matches composite bucket keys (`start_end`) across `avg`, `min`, `max`, and `count`; withholds stats
    (returns `null`) if any method has unmatched bucket boundaries.
  - Calculates exact sum of `totalCount` via `BigInt` addition without floating precision loss, and
    calculates weighted mean `sum(avg * count) / sum(count)` avoiding average-of-averages.
- Localized error guidance & Request ID tracing:
  - `TemporalHistoryState` stores typed `TemporalGuidanceCode` (`rawLimitExceeded`, `rawResolutionRequired`,
    `resolutionTooFine`, `queryRangeExceeded`, `invalidDateFormat`) and `requestId`.
  - Differentiates `raw_limit_exceeded` (capacity/points overflow) from `raw_resolution_required` (range too long).
  - Error notice displays the error message alongside `requestId` prominently above retained/stale data
    rather than hiding failures when a previous response is present.
  - Replaced hardcoded ad-hoc colors with semantic `KiteColors` tokens (`c.primary`, `c.secondary`, `c.destructive`).
- Updated `GatewayDetailScreen` (`lib/features/gateways/presentation/gateway_detail_screen.dart`):
  - Preserved Gateway metadata card and all existing header/admin/provision buttons unchanged in appearance.
  - Two tabs under metadata: Tab 0 Telemetry History (default) with Flutter `DropdownMenu` keyed to the active
    sensor ID to prevent stale selection text on catalog updates; Tab 1 Sensor Catalog.
  - Inactive tab content is not mounted or prefetched.
  - Admin without gateway membership retains exact sensor-read denial (`l.gatewaySensorReadDeniedMessage`)
    with zero temporal calls. Gateway changes reset selected sensor and tab-scoped state.
  - Gateway metadata remains visible on independent history errors.
- Integrated `TemporalHistoryPanel` into `TwinDetailScreen` (`lib/features/digital_twin/presentation/twin_detail_screen.dart`)
  as a lazy 3rd tab (`l.twinHistory`) for Sensor Twins only; Gateway Twins show only 2 tabs (Information, State).
- TDD runtime RED evidence saved:
  - `/tmp/opencode/c8-regression-red.log`: Demonstrates 6 failing runtime assertions across draft vs applied unit isolation,
    refresh rerun behavior, complete bucket-key matching, strict numeric validation, and raw methods rejection.
  - `/tmp/opencode/c8-dto-red.log`: Initial DTO empty aggregate & finite numeric checks.
  - `/tmp/opencode/c8-chart-red.log`: Initial KiteTemporalChart missing widget runtime failures.
  - `/tmp/opencode/c8-provider-red.log`: Initial provider sequence fencing & denial purge failures.
  - `/tmp/opencode/c8-twindetail-red.log`: Initial TwinDetail lazy history tab missing failures.
  - `/tmp/opencode/c8-gatewaytabs-red.log`: Initial GatewayDetail tabs & admin denial failures.
- GREEN verification:
  - Focused C8 test suites: **40 passed** (`/tmp/opencode/c8-focused.log`).
  - Full test suite: **538 passed** (498 baseline + 40 C8), **zero failures** (`/tmp/opencode/c8-full-tests.log`).
  - `flutter analyze --fatal-infos`: **PASS**, `No issues found!`.
  - Dart formatting and `git diff --check`: **PASS**.
- C9 insertion interface: C9 may attach metadata update mutations via `PATCH /v1/digital-twins/{entity_id}/attrs`
  in the Digital Twin info pane and refresh `twinDetailProvider(rawUrn)` after confirmed success; C8 added
  purely read-only temporal telemetry history and charts, without adding downlink control or metadata mutations.

### C9 — authorized metadata PATCH, Twin info integration, and catalog refresh

- **Discrepancy recorded:** In Go backend `../main_src/src/internal/httpserver/patch_entity_request.go:385`,
  the HTTP parser enforces `len(frag.Value) <= 512` for description, whereas domain/architecture
  documentation specifies up to 4096 bytes. The client validation in `PatchTwinAttrsInput` enforces
  a 512-byte limit to prevent 400 Bad Request responses. Backend code was kept strictly unmodified.
- **Normalized Property Fragment DTOs (`digital_twin_dto.dart`):**
  - Updated `PatchTwinAttrsInput`: made `name` optional (`String?`), added strict validation
    (1..256 UTF-8 bytes non-blank for name; <= 512 UTF-8 bytes for description; no NUL bytes;
    at least one field modified; cannot set text description and `clearDescription` simultaneously).
  - Preserved exact user-intended string whitespace without arbitrary `.trim()`.
  - Added support for clearing description via `clearDescription: true` generating the NGSI-LD sentinel
    `{'type': 'Property', 'value': 'urn:ngsi-ld:null'}`. Literal JSON `null` is forbidden.
  - Added canonical flat response DTO `PatchTwinResponseDto.fromJson` parsing `{id, type, gateway_id,
    sensor_id?, name, description?, unit?, updated_at}`.
  - Updated `DigitalTwinRepository.patchTwinAttrs` to return typed `Future<PatchTwinResponseDto>`.
- **Role Authority & Controller (`metadata_edit_provider.dart`):**
  - Authority resolution matrix (`resolveMetadataEditAuthority`):
    - Gateway metadata: Platform Admin ONLY (backend rejects non-admin with 403 Forbidden).
    - Sensor metadata: Platform Admin OR Gateway Owner (operator and viewer denied).
    - Loading or error permission states fail closed (null authority).
  - Controller `MetadataEditNotifier`:
    - Scoped to actor session epoch, resource, and authorization snapshot.
    - Suppresses duplicate submissions while in-flight.
    - Sends only changed fields (does not resend unchanged name when updating description).
    - Session change or epoch mismatch in-flight discards stale responses.
    - Timeout, network failure, or HTTP 503 marks mutation state as `unknownOutcome`, blocking
      blind resubmit.
    - Reconcile via metadata readback: matching fields confirm success (`reconcileStatus.confirmed`,
      `status.success`); mismatch honestly reports divergence (`reconcileStatus.mismatch`);
      subsequent 404 (e.g. admin without gateway membership read access) honestly reports
      `cannotVerify` without misreporting failure or unlocking blind retries.
    - On confirmed success, invalidates only relevant providers (`gatewayDetailProvider`,
      `gatewayListProvider`, `twinDetailProvider`, `twinListProvider`); does not invalidate
      unrelated history, credential, or state view providers.
- **Presentation & Decoupled Architecture (`edit_metadata_dialog.dart`, `metadata_edit_launcher.dart`):**
  - Created `EditMetadataDialog` in `lib/features/digital_twin/presentation/edit_metadata_dialog.dart`.
  - Created shared typed launcher `metadataEditLauncherProvider` in `lib/shared/widgets/metadata_edit_launcher.dart`
    to ensure `features/gateways` never imports `digital_twin` presentation internals.
  - Added header action button in `GatewayDetailScreen` next to existing admin actions for Platform Admins;
    preserved Gateway metadata card appearance and sensor catalog layout intact.
  - Added edit action button in `TwinDetailScreen` info tab when authority resolves for Gateway or Sensor.
  - Form displays explanatory notice that metadata is updated in the database, not hardware execution.
  - Responsive across 390px, 1024px, 1366px, and 1920px. Disables save button when no fields changed.
  - Dismisses fail-closed if permissions are revoked or session switches while dialog is open.
- **TDD & Verification Evidence:**
  - Runtime RED: Initial tests executed and failed with runtime assertions on `PatchTwinAttrsInput`
    whitespace trimming (`Expected: '  Exact Gateway Name  ', Actual: 'Exact Gateway Name'`) and missing
    metadata edit action button in `TwinDetailScreen` before C9 wiring. Saved to `/tmp/opencode/c9-red.log`.
  - GREEN: 16 focused tests in `test/c9_patch_metadata_test.dart` passed (`All tests passed!`).
  - Full test suite: **554 passed** (538 baseline + 16 new C9 tests), 0 failures. Log: `/tmp/opencode/c9-full-tests.log`.
  - `flutter analyze --fatal-infos`: **PASS**, `No issues found!`. Log: `/tmp/opencode/c9-analyze.log`.
  - Dart formatting: formatted only changed Dart files (`digital_twin_dto.dart`, `digital_twin_repository.dart`,
    `twin_detail_screen.dart`, `edit_metadata_dialog.dart`, `metadata_edit_provider.dart`,
    `gateway_detail_screen.dart`, `metadata_edit_launcher.dart`, `digital_twin_repository_test.dart`,
    `c9_patch_metadata_test.dart`). Unrelated files untouched.
  - `git diff --check`: **PASS**, no whitespace or merge artifacts.

## Unverified acceptance

Live multi-role browser/backend acceptance and release builds have not been run.
Automated tests using fake repositories or HTTP fixtures do not establish live
backend, physical-device, or production acceptance. No credentials will be
invented or extracted to bypass this boundary.

## C10 — final integration / regression / security review (2026-10-23)

This section supersedes optimistic C6–C9 implementation claims above. Earlier
passing suites did not exercise all of the behaviors their descriptions claimed.
The review read actual DTOs, repositories, notifiers, route composition and UI,
not only previous worker reports. No other writer, subagent, backend edit,
dependency change, build/release, staging operation, commit or push was used.

### Corrected defects

- Metadata mutation now enforces its provider's canonical URN and current
  authority, rejects anonymous/forged calls, and refreshes real permissions and
  owner membership before dispatch. Gateway and Sensor authority remain separate;
  membership changes do not revoke independent Platform Admin authority.
- Unknown outcomes block direct provider resubmit/reset, including same-user
  token refresh and dialog close/reopen. The uncertainty lock lives in memory,
  not browser storage. Submit/readback have mounted, sequence and session guards;
  authority revocation fences an in-flight mutation without implying failure.
  Malformed or undecodable mutation responses are uncertain, not permission to
  blindly resend. PATCH response identity/type/Sensor ID and UTC timestamps are
  checked against the canonical backend `mutation_dto.go` representation.
- Readback is bound to the original resource and changed fields. Mismatch,
  403/404/503 or unreadable results never unlock mutation replay. Matching readback
  closes the dialog successfully and refreshes authoritative values. A known
  PATCH success is not demoted by a later readback 404. Nullable state fields can
  genuinely clear previous errors/results.
- Confirmed metadata changes explicitly reload manual Gateway/Twin list loaders
  instead of leaving them reset/empty or permanently loading. Gateway metadata,
  Sensor catalog and Twin reads refresh from repositories, not optimistic edits
  to roles. Direct Sensor Twin links load membership authority without requiring
  a previous Gateway-list visit. Dialog opening refreshes authority first.
- The cross-feature metadata launcher is now injected by `KiteApp`, not a shared
  widget that imports a feature's presentation internals.
- Twin list, Gateway catalog/detail and permissions use stable identity scopes,
  not token/session-object identity. Active history/list screens reload when the
  actual identity changes. Permission refresh single-flight ownership is also
  scoped: a pending old user's refresh cannot block the new user's discovery.
- Temporal decoding rejects absent/malformed Properties, incorrect identity,
  type/attribute/mode/method projection, invalid tuple lengths and nonfinite
  measurements. UTC dates reject normalization, offsets and >6 fractional digits.
  Repository/provider binding checks ordering, `[start,end)` raw membership and
  per-series point caps. Duplicate raw timestamps remain distinct; partial edge
  buckets may straddle the query boundary. Empty aggregation retains its mode.
  The existing 10-second raw, 31-day range, 100..2000 point and nine-duration
  query limits remain enforced.
- Statistics require complete matching start/end bucket sets, preserve exact
  BigInt counts, normalize weights before multiplication to avoid unnecessary
  overflow, exclude zero-count buckets from extrema, and withhold nonfinite
  results. Backend `twin_history_dto.go` explicitly permits nonnegative counts
  (zero is not rejected merely because normally missing buckets are omitted).
- Chart tooltips now retain full UTC start/end dates and milliseconds plus
  microseconds, including overnight buckets and exact integer count text.
  Narrow count toggles wrap instead of overflowing. Nonfinite/unplottable ranges
  show a safe error, never a fabricated zero. Package-internal chart assertions
  live under `packages/kite_ui/test/`, not app imports of `fl_chart`.
- Metadata and history errors/guidance are localized and do not expose raw
  exception/server diagnostic text. Request IDs remain visible, including above
  retained stale history. Metadata notices use Kite theme tokens. Changed-field
  validation permits an unchanged legacy oversized description; clearing an
  already-null description no longer hides a separate name change.
- Restored only the three task-owned C8 formatting diffs in
  `placeholder_screen.dart`, `edit_user_dialog.dart`, `user_list_screen.dart`.
  Their diffs are empty again. No whole-repository formatter was run in C10.
  `AGENTS.md` was minimally updated locally, but it is ignored by this checkout;
  it will not appear in the tracked Git diff unless the user chooses otherwise.

### RED evidence and corrections to earlier reports

- `/tmp/opencode/c10-security-red.log`: six executed assertion failures for
  uncertainty replay/reset, forged authority/scope, wrong-resource readback,
  malformed PATCH/temporal DTO acceptance, and token-refresh list clearing.
- Additional runtime assertion REDs: `c10-copywith-red.log`,
  `c10-authority-red.log`, `c10-property-red.log`, `c10-chart-red.log`,
  `c10-nonfinite-red.log`, `c10-stats-red.log`, `c10-property-date-red.log`,
  `c10-permission-lock-red.log` (all under `/tmp/opencode/`). Compilation/setup
  failures encountered while editing are not counted as behavioral REDs.
- C7's initial HTTP `c7-detail-red.log` is a runtime **missing-method** failure,
  not an assertion proving an implemented parser violated its contract. Other
  C7 assertion-based regression logs remain separate evidence.
- The available `c8-chart-red.log` contains missing-widget assertions and
  `StateError: No element` failures, not a compiler-error RED. Any earlier
  unpreserved compilation attempt is NOT valid TDD evidence. Current chart
  tests differ from that historical suite; do not derive current coverage from
  its old test count.
- C9's original "blocking blind resubmit" test only inspected `unknownOutcome`;
  it did not actually attempt another submit. Its original reconcile test also
  allowed an already-confirmed success to be downgraded. C10 explicitly tests
  direct resubmit/reset/token refresh/reopen and keeps confirmed success final.
- Integration runs caught a real narrow chart overflow; no RenderFlex exception
  was swallowed. Later validation-test failures were missing widget-frame pumps,
  corrected in the test rather than bypassing form validation or skipping it.

### Contract / acceptance limitations

- Local SDK remains Flutter **3.47.6 / Dart 3.13.5**; existing CI pins **3.47.1**.
  No SDK/dependency upgrade was performed.
- Verified source discrepancy: `patch_entity_request.go` description parsing
  checks both domain 4096-byte metadata validation and `len(frag.Value) > 512`.
  PATCH forms intentionally enforce the actual **512 UTF-8 byte HTTP limit**;
  this does not silently redefine the documented domain/provisioning limit.
- A fresh read-only probe `curl ... http://localhost/v1/health` returned **200**
  during C10. This corrects the earlier baseline 502, but proves neither login
  nor multi-role API acceptance.
- **NOT RUN:** live owner/operator/viewer/admin/dual-role browser acceptance,
  real login/F5/revocation/transfer flows: no designated test credentials were
  supplied. No user-session tokens/passwords or server secrets were extracted;
  no JWTs were minted or live accounts mutated. Chrome fixture tests are not
  live backend acceptance.
- **NOT RUN:** release/web build, staging deployment, production acceptance,
  board/device tests or load certification: explicitly outside C10 scope.
  All production repositories remain real Go API integrations; mocks/fakes
  exist only in automated test fixtures. Controls, realtime, media and summary
  APIs remain unavailable and were not added.

### Final checks actually run

- `flutter gen-l10n`: PASS. `dart format` was run on the explicit changed/new
  Dart paths only, excluding the three restored unrelated files.
- `flutter analyze --fatal-infos`: PASS, **No issues found**;
  `/tmp/opencode/c10-analyze.log`.
- `flutter test --coverage --reporter expanded`: **594 passed, zero failed**;
  `/tmp/opencode/c10-full-tests.log`. This is the app suite, not the package suite.
- `CHROME_EXECUTABLE=/usr/bin/google-chrome flutter test -d chrome test/twin_list_screen_test.dart test/c7_detail_screen_test.dart test/c8_gateway_detail_tabs_test.dart test/c8_temporal_panel_test.dart test/c8_twin_detail_history_test.dart test/c9_patch_metadata_test.dart test/c10_ui_integration_test.dart packages/kite_ui/test --reporter expanded`:
  **72 passed, zero failed**; `/tmp/opencode/c10-chrome.log`.
  The C10 matrix covers **390×844, 1024×768, 1366×768, 1920×1080**, both vi/en,
  both light/dark, keyboard focus, Gateway two-tab/catalog/history flows and
  direct owner Sensor Twin editing. Additional tests verify raw duplicate
  microsecond rows, µs units, safe stale errors/Request ID, metadata validation,
  explicit retry of definite errors, uncertainty/reopen/reconciliation and
  refreshed Gateway/catalog values. These are automated Chrome **fixture**
  widget tests, not real-auth deployment journeys or screenshot certification.
- `flutter test packages/kite_ui/test test/c8_kite_temporal_chart_test.dart --coverage --coverage-package '^kite_ui$' --coverage-path /tmp/opencode/c10-kite-ui.lcov --reporter expanded`:
  **6 passed, zero failed**; `/tmp/opencode/c10-package-tests.log`. Includes
  package-internal tooltip callback and nonfinite-chart regressions.
- `git diff --check`: PASS. The three unrelated files have an empty diff.
  Tracked and untracked scope reviewed. No pubspec/lockfile/CI/backend edits.
  Security grep found no app `shadcn_ui`/`fl_chart` imports, debug printing,
  browser persistence or new realtime/MQTT/legacy-history calls in the reviewed
  Twin/history implementation. Existing transport tests exercise read-only
  bounded 401 retries and verify that PATCH/POST/PUT/DELETE are not replayed.

### Measured line coverage (not inferred from test counts)

App source: final `coverage/lcov.info`; package source:
`/tmp/opencode/c10-kite-ui.lcov`. For tracked app files, intersect LCOV `DA`
lines with added/replaced new-side ranges from `git diff --unified=0`; for new
app files, use all instrumented lines. Exclude generated localization files,
tests and documentation. This measures the **C6–C10 working diff**, not only
C10's last edits. Full extraction: `/tmp/opencode/c10-coverage-summary.txt`.

| Scope | Hit / instrumented lines | Coverage |
|---|---:|---:|
| Changed/new app logic | 1942 / 2121 | 91.56% |
| Package temporal chart (separate report) | 183 / 193 | 94.82% |
| Metadata edit notifier (whole new file) | 164 / 172 | 95.35% |
| Metadata dialog (whole new file) | 197 / 222 | 88.74% |
| Temporal notifier (whole new file) | 63 / 69 | 91.30% |
| Temporal controls / panel / table | 195/220; 205/255; 84/84 | 88.64%; 80.39%; 100% |
| Twin list / detail notifiers | 79/79; 69/69 | 100%; 100% |

The only changed/new app file below 80% is the two-line shared launcher default
(`1/2`, 50%): the no-implementation fallback is not called by composition tests;
the real application override and Gateway launch are exercised. Coverage is
line coverage, not branch, fuzz, load or live-authorization certification. No
test or lint was skipped/disabled to reach these results.

### C10 file handover

Code corrected by C10 (in addition to preserving the inherited C6–C9 files):

```text
lib/app.dart
lib/core/auth/permissions.dart
lib/features/digital_twin/data/digital_twin_dto.dart
lib/features/digital_twin/data/digital_twin_repository.dart
lib/features/digital_twin/data/twin_detail.dart
lib/features/digital_twin/presentation/edit_metadata_dialog.dart
lib/features/digital_twin/presentation/twin_detail_screen.dart
lib/features/digital_twin/presentation/twin_list_screen.dart
lib/features/digital_twin/providers/metadata_edit_provider.dart
lib/features/digital_twin/providers/temporal_history_provider.dart
lib/features/digital_twin/providers/twin_list_provider.dart
lib/features/gateways/presentation/gateway_detail_screen.dart
lib/features/gateways/providers/gateway_detail_provider.dart
lib/features/gateways/providers/gateway_list_provider.dart
lib/shared/widgets/metadata_edit_launcher.dart
lib/shared/widgets/temporal_history_controls.dart
lib/shared/widgets/temporal_history_panel.dart
lib/shared/widgets/temporal_history_table.dart
packages/kite_ui/lib/src/temporal_chart.dart
lib/l10n/app_en.arb
lib/l10n/app_vi.arb
lib/l10n/app_localizations.dart                 (generated)
lib/l10n/app_localizations_en.dart              (generated)
lib/l10n/app_localizations_vi.dart              (generated)
```

New tests: `test/c10_security_regression_test.dart`,
`test/c10_temporal_safety_test.dart`, `test/c10_ui_integration_test.dart`,
`packages/kite_ui/test/temporal_chart_test.dart`, `test/adaptive_datetime_picker_test.dart`.
Updated fixtures/assertions: `test/c8_gateway_detail_tabs_test.dart`,
`test/c8_regression_query_and_chart_test.dart`, `test/c8_temporal_dto_test.dart`,
`test/c8_temporal_provider_test.dart`, `test/c9_patch_metadata_test.dart`,
`test/digital_twin_repository_test.dart`.
Documentation: `README.md`, this report, and local ignored `AGENTS.md`.

- **Adaptive DateTime & Local Timezone Enhancement (2026-10-23):**
  Added `pickAdaptiveDateTime`, `parseStrictLocalDate`, `formatLocalIsoDate`, and
  `formatTimezoneOffset` in `TemporalHistoryControls`. Date/time inputs display and
  accept user local time, while converting to UTC ISO8601 timestamps before
  transmitting queries to the backend Go REST API. Start and end fields include
  calendar picker buttons using standard Calendar mode and desktop-adaptive
  input/dial time picker. Tested via `test/adaptive_datetime_picker_test.dart`
  with 11 tests passing on both VM and Chrome.
  
- **Telemetry Chart & Table Ergonomics Enhancement (2026-10-23):**
  - Tooltip: Hovering on aggregated chart displays only series values (Avg, Min, Max)
    without repetitive timestamps; raw mode displays only the point value (e.g. `25.5 °C`)
    without extraneous text.
  - Line color: Minimum line updated from faint `c.secondary` to high-visibility `Color(0xFF0284C7)`.
  - Chart X-axis: Synchronized to user's local timezone (`toLocal()`); switches to date
    format (`dd/MM`) instead of hour when data spans multiple days (`rangeSeconds > 86400`).
  - Table: Data inspection table (`TemporalHistoryTable`) formats timestamps in user's
    local timezone with timezone offset in the column header (`Thời gian (UTC+07:00)`).
  - All other dates (sensor/user/gateway creation dates) left untouched. Verified with 605 full tests
    and 15 Chrome widget tests passing.

**Handover state:** implementation and automated regression verification
complete for C10; live multi-role and release/production acceptance incomplete
for the explicitly recorded reasons above. Stop at C10.
