---
version: alpha
name: Clock in TPS Design System
description: Official design system tokens and rationale for Clock in TPS Flutter app.
colors:
  workBlue: "#2563EB"
  workSky: "#0EA5E9"
  workBackground: "#F8FAFC"
  workText: "#1E293B"
  workMuted: "#94A3B8"
  primary: "#0EB7A8"
  onPrimary: "#FFFFFF"
  surface: "#FFFFFF"
  onSurface: "#10233F"
  successBg: "#DCFCE7"
  successFg: "#15803D"
  warningBg: "#FEF3C7"
  warningFg: "#B45309"
  dangerBg: "#FEE2E2"
  dangerFg: "#B91C1C"
  pendingBg: "#EFF6FF"
  pendingFg: "#1D4ED8"
  errorBg: "#FFEBEE"
  errorFg: "#C62828"
  holidayBg: "#FFEBEE"
  holidayFg: "#C62828"
  infoSky: "#0EA5E9"
  offsiteDot: "#3B82F6"
  lateDot: "#F59E0B"
  absentDot: "#EF4444"
  onTimeDot: "#22C55E"
typography:
  clockDisplay:
    fontFamily: Prompt
    fontSize: 48px
    fontWeight: 700
    lineHeight: 1.0
    letterSpacing: -1px
  screenTitle:
    fontFamily: Prompt
    fontSize: 16px
    fontWeight: 600
    lineHeight: 1.2
  cardSectionTitle:
    fontFamily: Prompt
    fontSize: 16px
    fontWeight: 600
    lineHeight: 1.2
  headerSubtitle:
    fontFamily: Prompt
    fontSize: 14px
    fontWeight: 400
    lineHeight: 1.2
  bodyLarge:
    fontFamily: Prompt
    fontSize: 16px
    fontWeight: 500
    lineHeight: 1.4
  bodyMedium:
    fontFamily: Prompt
    fontSize: 14px
    fontWeight: 400
    lineHeight: 1.4
  caption:
    fontFamily: Prompt
    fontSize: 12px
    fontWeight: 400
    lineHeight: 1.3
  buttonLabel:
    fontFamily: Prompt
    fontSize: 16px
    fontWeight: 600
    lineHeight: 1.2
  statusBadge:
    fontFamily: Prompt
    fontSize: 12px
    fontWeight: 600
    lineHeight: 1.0
  feedbackBanner:
    fontFamily: Prompt
    fontSize: 14px
    fontWeight: 600
    lineHeight: 1.3
  drawerUserName:
    fontFamily: Prompt
    fontSize: 18px
    fontWeight: 700
    lineHeight: 1.2
  profileFullName:
    fontFamily: Prompt
    fontSize: 21px
    fontWeight: 700
    lineHeight: 1.2
rounded:
  sm: 12px
  md: 14px
  lg: 20px
  xl: 24px
  full: 99px
spacing:
  xs: 4px
  sm: 8px
  md: 12px
  lg: 16px
  xl: 20px
  xxl: 28px
  hero: 56px
components:
  card:
    backgroundColor: "{colors.surface}"
    rounded: "{rounded.xl}"
    padding: "{spacing.xl}"
  button-primary:
    backgroundColor: "{colors.workBlue}"
    textColor: "{colors.onPrimary}"
    rounded: "{rounded.sm}"
    height: 48px
  button-dashboard:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.workBlue}"
    rounded: "{rounded.sm}"
    height: 56px
  input-field:
    backgroundColor: "#F5F7FA"
    rounded: "{rounded.sm}"
    padding: 16px
  status-badge:
    rounded: "{rounded.full}"
    padding: 12px
  app-bar:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.onSurface}"
---

## Overview

Architectural Trust meets Industrial Cleanliness. The Clock in TPS design system delivers a highly structured, reliable, and accessible interface suited for workplace operations and factory environments. The UI focuses on clean surfaces, clear alignment, and high readability under varying lighting conditions.

## Colors

The system uses corporate blue and sky tones as anchors for main themes, supported by clean light backgrounds and explicit semantic colors to display status:

- **Primary Colors:**
  - `workBlue` (`#2563EB`): The main brand voice. Drives primary action states and navigation highlighting.
  - `workSky` (`#0EA5E9`): Used alongside `workBlue` in header gradients to inject modern vibrancy.
- **Backgrounds:**
  - `workBackground` (`#F8FAFC`): Soft off-white to reduce eye strain.
  - `surface` (`#FFFFFF`): Standard container background.
- **Status Contrast Rules:**
  - Every status badge is backed by a specific color contrast pairing (e.g., active status is `#DCFCE7` background with `#15803D` foreground text) to comply with readability guidelines without needing translation logic.

## Typography

Rooted strictly in the `Prompt` font family (via Google Fonts). Renders both Thai and English content cleanly:

- **Hierarchy:** High-impact bold weights (w700) are reserved for numeric clock displays and page headers. Labels and section subtitles use w600 for clear structural division.
- **Body & Inputs:** Rest on clean w400 and w500 weights to preserve whitespace density.
- **Line Heights:** Configured relative to their font sizes to prevent vertical wrapping collisions.

## Layout

A signature top gradient header shapes the app structure:

- **Banner:** Standardized `WorkHeader` with top safe-area automatically calculated.
- **Overlapping Pattern:** Content cards are translated upward by `Offset(0, -28)` or `Offset(0, -46)` to overlap the gradient header banner, anchoring user attention directly on screen actions.
- **Symmetrical Margins:** Always keep a horizontal spacing margin of `20px` at screen boundaries.

## Elevation & Depth

Visual depth distinguishes static views from interactive regions:

- **Default Container:** Cards float with a subtle, diffuse drop shadow: `Color(0x0D0F172A), blurRadius: 10, offset: (0, 3)`.
- **Primary Dashboard Button:** Enforces an elevated state (`elevation: 8`) to emphasize time-tracking actions.
- **Overlays:** Full-screen loading, scanning interfaces, and modal views are blocked with a translucent background layer to isolate the task flow.

## Shapes

Shapes reflect stability and precision:

- **Stability Curve:** Form fields and action buttons use a clean `rounded.sm (12px)` corner radius.
- **Card Enclosures:** Main sections use `rounded.xl (24px)` corner radii.
- **Pills & Circles:** Badges and the user avatar utilize `rounded.full (99px)` for circular boundaries.

## Components

The system features standard modular blocks:

- **WorkHeader:** Top gradient anchor with navigation hooks.
- **WorkCard:** Padded, rounded containers for all data lists.
- **StatusBadge:** Inline state pill labels.
- **InputFields:** Light-filled textual form entries.
- **AppDrawer:** Left sidebar navigation containing user identity context and sign-out actions.
- **Face Scanner Overlay:** Custom viewport circular cutout for liveness check alignment.

## Do's and Don'ts

### Do
- Always overlay cards over the gradient header using translate offsets.
- Keep the typography seed family to `Prompt` for all text blocks.
- Explicitly pair status badge text with their designated background/foreground tokens.
- Maintain a minimum vertical height of 48px on all click targets.
- Dispose timers and hardware controllers during component disposal.

### Don't
- Use solid fills or arbitrary gradients for the top `WorkHeader` banner.
- Add animation transitions to `IndexedStack` switches; tabs must snap immediately.
- Use raw values for padding, margins, or shapes that fall outside the defined spacing and rounded tokens.
- Hide error messages behind silent app states; always surface hardware/permission errors clearly in Thai.
