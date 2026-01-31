# Starter Issues to Create

These are concrete, well-scoped issues suitable for new contributors. Create these as GitHub issues with the `good first issue` label.

---

## 1. Add unit tests for PacketFramer

**Title**: Add unit tests for USB packet framing logic

**Description**: The `PacketFramer` class in `lib/core/packet_framer.dart` handles USB serial packet framing with 0x94/0xC3 markers. It currently lacks comprehensive unit tests.

**Acceptance Criteria**:

- [ ] Test valid packet encoding with start/end markers
- [ ] Test packet decoding with correct boundary detection
- [ ] Test handling of malformed packets (missing markers, truncated data)
- [ ] Test edge cases: empty payload, maximum payload size
- [ ] All tests pass with `flutter test`

---

## 2. Document Riverpod provider dependency graph

**Title**: Create provider dependency documentation

**Description**: The app uses Riverpod 3.x with many interdependent providers in `lib/providers/app_providers.dart`. New contributors need a visual or textual guide to understand provider relationships.

**Acceptance Criteria**:

- [ ] Create `docs/PROVIDERS.md` with a list of core providers
- [ ] Document which providers depend on which
- [ ] Include a simple dependency diagram (ASCII or Mermaid)
- [ ] Note which providers trigger device communication

---

## 3. Add missing SPDX headers to test files

**Title**: Add GPL-3.0 SPDX headers to test files

**Description**: Source files in `lib/` have SPDX license headers, but test files in `test/` may be missing them. All Dart files should have consistent headers.

**Acceptance Criteria**:

- [ ] Audit all `.dart` files in `test/` directory
- [ ] Add SPDX header to any file missing it
- [ ] Header format: `// SPDX-License-Identifier: GPL-3.0-or-later`
- [ ] Verify with `flutter analyze` (no new warnings)

---

## 4. Improve error messages in BLE connection failures

**Title**: Add user-friendly error messages for BLE connection states

**Description**: When BLE connection fails, the error messages shown to users could be more helpful. Review `lib/core/ble_transport.dart` and related UI for opportunities to clarify error states.

**Acceptance Criteria**:

- [ ] Identify current error message locations
- [ ] Propose clearer messages for: device not found, connection timeout, disconnection
- [ ] Update strings without changing connection logic
- [ ] Test on both iOS and Android simulators

---

## 5. Add integration test for message send/receive flow

**Title**: Add integration test for messaging flow

**Description**: Create an integration test that verifies the message composition and display flow using mock data. This does not require a real device.

**Acceptance Criteria**:

- [ ] Test creates a mock message
- [ ] Test verifies message appears in message list
- [ ] Test verifies message metadata (timestamp, sender) displays correctly
- [ ] Test runs with `flutter test integration_test/`

---

## 6. Clean up unused imports across codebase

**Title**: Remove unused imports from Dart files

**Description**: Over time, some imports may have become unused. Run analysis and clean up any unused imports to reduce noise.

**Acceptance Criteria**:

- [ ] Run `dart fix --apply` to auto-fix simple cases
- [ ] Manually review any remaining unused import warnings
- [ ] Verify `flutter analyze` shows no unused import warnings
- [ ] Do not remove imports from generated files (`lib/generated/`)

---

## 7. Add widget tests for NodeAvatar component

**Title**: Add widget tests for NodeAvatar

**Description**: The `NodeAvatar` widget in `lib/core/widgets/` is used throughout the app to display node identities. It should have widget tests covering its rendering states.

**Acceptance Criteria**:

- [ ] Test renders correctly with valid node data
- [ ] Test renders fallback for missing/null node
- [ ] Test handles long node names gracefully
- [ ] Test accessibility (semantic labels present)

---

## 8. Document automation trigger types

**Title**: Document available automation triggers and actions

**Description**: The automation system supports various triggers (`nodeOnline`, `batteryLow`, etc.) and actions. Create documentation explaining each type for users and contributors.

**Acceptance Criteria**:

- [ ] Create `docs/AUTOMATIONS.md`
- [ ] List all trigger types with descriptions
- [ ] List all action types with descriptions
- [ ] Include one example automation configuration
- [ ] Reference the `AutomationEngine` source file
