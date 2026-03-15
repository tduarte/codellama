# UI Visual Bugs and Improvements

Based on review of:
- `screenshots/02-command-palette.png`
- `screenshots/03-skills-sheet.png`
- `screenshots/04-settings-general.png`
- `screenshots/05-settings-mcp-servers.png`
- `screenshots/06-settings-skills.png`

## Command Palette (`screenshots/02-command-palette.png`)

- [ ] **[P0] Clamp oversized result content**
  - One result row renders a long block of text and breaks list-item height.
  - Apply strict row layout: title + capped subtitle (`lineLimit`), no full-body rendering.

- [ ] **[P2] Improve row information hierarchy**
  - Current metadata chips and text weights compete for attention.
  - Standardize title/subtitle/chip styles and vertical rhythm.

- [ ] **[P3] Tune modal sizing for readability**
  - Very tall rows dominate the modal and push footer controls down.
  - Cap row height, keep list scrolling internal, and tune modal max height.

## Skills Sheet (`screenshots/03-skills-sheet.png`)

- [ ] **[P1] Strengthen left pane empty state**
  - Left panel looks blank and low-contrast, making structure unclear.
  - Add pane header, empty-state helper text, and stronger pane divider/background.

- [ ] **[P2] Improve modal focus separation**
  - Background remains visually busy under the sheet.
  - Slightly increase backdrop dim/blur to focus attention on the modal.

## Settings - General (`screenshots/04-settings-general.png`)

- [ ] **[P2] Normalize spacing density**
  - Form sections feel too spread out for the window size.
  - Reduce vertical gaps and align row heights across sections.

- [ ] **[P2] Rework Save action placement**
  - Save button feels detached at bottom-right with excess whitespace.
  - Use sticky footer action bar or inline dirty-state controls near edited content.

## Settings - MCP Servers (`screenshots/05-settings-mcp-servers.png`)

- [ ] **[P2] Enhance empty-state usefulness**
  - Screen is mostly empty with minimal guidance.
  - Add helper steps (what MCP is, how to add first server) and quick actions.

- [ ] **[P3] Improve visual balance of centered state**
  - Current centered block feels small against large empty canvas.
  - Increase content block prominence (icon/text sizing, container treatment).

## Settings - Skills (`screenshots/06-settings-skills.png`)

- [ ] **[P1] Fix detached toolbar controls**
  - Floating controls at top-left (`+`, trash, split) feel disconnected from Settings nav.
  - Integrate into left panel header or hide/re-map controls in Settings context.

- [ ] **[P2] Clarify relationship between Settings tab and embedded Skills UI**
  - Two navigation systems are visible at once, creating chrome ambiguity.
  - Consolidate to one primary control surface in this context.

- [ ] **[P2] Improve empty state clarity**
  - “No Skill Selected” is clear, but surrounding layout still feels unfinished.
  - Add contextual next steps and stronger pane affordance.

## Cross-Screen Consistency

- [ ] **[P2] Harmonize tab icon/text visual weights (`04`, `05`, `06`)**
  - Active/inactive states are subtle and icon sizing is inconsistent.
  - Increase selected-state contrast and align icon typography scale.

## Suggested Implementation Order

1. `[P0]` Command palette overflow fix.
2. `[P1]` Skills controls/chrome fixes (`03`, `06`).
3. `[P2]` Settings layout and empty-state improvements (`04`, `05`, `06`).
4. `[P2]` Cross-screen consistency pass.
5. `[P3]` Modal and visual polish.
