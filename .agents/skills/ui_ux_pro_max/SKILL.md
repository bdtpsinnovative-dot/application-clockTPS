---
name: ui-ux-pro-max
description: UI/UX design intelligence for web and mobile. Searchable local database with 84 styles, 192 color palettes, 74 font pairings, 192 product types, 98 UX guidelines, 104 icon entries, 16 GSAP motion presets, and 25 chart types across 22 stacks.
---

# UI/UX Pro Max - Design Intelligence

Searchable database of UI/UX design rules with priority-based recommendations: 84 styles, 192 color palettes, 74 font pairings, 192 product types with reasoning rules, 98 UX guidelines, 104 icon entries, 16 GSAP motion presets, and 25 chart types across 22 technology stacks.

---

## When to Apply
Use this Skill when the task involves UI structure, visual design decisions, interaction patterns, or user experience quality control: designing new pages, creating/refactoring UI components, choosing color/typography/spacing/layout systems, reviewing UI for UX/accessibility/consistency, implementing navigation/animation/responsive behavior, or improving perceived quality and usability.

Skip it for pure backend logic, API/database design, non-visual performance work, infrastructure/DevOps, or non-visual scripts — unless the task changes how something looks, feels, moves, or is interacted with.

---

## Rule Categories by Priority
Follow priority 1→10 to decide which category to focus on first; use `--domain <Domain>` to query full details. The full rule text for every category lives in `references/quick-reference.md` — read it on demand rather than loading it every time.

| Priority | Category | Impact | Domain | Key Checks (Must Have) | Anti-Patterns (Avoid) |
| :---: | :--- | :---: | :---: | :--- | :--- |
| **1** | Accessibility | **CRITICAL** | ux | Contrast 4.5:1, Alt text, Keyboard nav, Aria-labels | Removing focus rings, Icon-only buttons without labels |
| **2** | Touch & Interaction | **CRITICAL** | ux | Min size 44×44px, 8px+ spacing, Loading feedback | Reliance on hover only, Instant state changes (0ms) |
| **3** | Performance | **HIGH** | ux | WebP/AVIF, Lazy loading, Reserve space (CLS < 0.1) | Layout thrashing, Cumulative Layout Shift |
| **4** | Style Selection | **HIGH** | style, product | Match product type, Consistency, SVG icons (no emoji) | Mixing flat & skeuomorphic randomly, Emoji as icons |
| **5** | Layout & Responsive | **HIGH** | ux | Mobile-first breakpoints, Viewport meta, No horizontal scroll | Horizontal scroll, Fixed px container widths, Disable zoom |
| **6** | Typography & Color | **MEDIUM** | typography, color | Base 16px, Line-height 1.5, Semantic color tokens | Text < 12px body, Gray-on-gray, Raw hex in components |
| **7** | Animation | **MEDIUM** | ux, gsap | Duration 150–300ms, Motion conveys meaning, Spatial continuity | Decorative-only animation, Animating width/height, No reduced-motion |
| **8** | Forms & Feedback | **MEDIUM** | ux | Visible labels, Error near field, Helper text, Progressive disclosure | Placeholder-only label, Errors only at top, Overwhelm upfront |
| **9** | Navigation Patterns | **HIGH** | ux | Predictable back, Bottom nav ≤5, Deep linking | Overloaded nav, Broken back behavior, No deep links |
| **10** | Charts & Data | **LOW** | chart | Legends, Tooltips, Accessible colors | Relying on color alone to convey meaning |

*For the full rule list per category (all ~98 UX guidelines with rationale), read `references/quick-reference.md`. For app-specific polish rules (icons, touch feedback, dark mode contrast, safe areas) and the canonical pre-delivery checklist, read `references/pro-rules.md`.*

---

## Running the search tool
The search script lives inside this skill's own directory, not the project directory. Always invoke it by its full path — do not assume a particular working directory:

```bash
python "${CLAUDE_PLUGIN_ROOT}/.claude/skills/ui-ux-pro-max/scripts/search.py" "<query>" --domain <domain>
```
*If python is not found, try `python3`, then `py -3`. Requires Python 3.x, no external dependencies.*

---

## Workflow

### Step 1: Analyze User Requirements
Extract from the user request:
* **Product type:** SaaS, e-commerce, portfolio, dashboard, entertainment, tool, productivity, or hybrid
* **Target audience & context:** age group, usage context (commute, leisure, work)
* **Style keywords:** playful, vibrant, minimal, dark mode, content-first, immersive, etc.
* **Stack:** detect from the project — check package.json deps (`react`/`next`/`vue`/`svelte`/`nuxt`/`@angular`), `pubspec.yaml` (Flutter), `*.xcodeproj`/`Package.swift` (SwiftUI), `composer.json` (Laravel), or React Native markers (`app.json` + `react-native` dep). If nothing is detectable, ask the user or default to `html-tailwind`.

### Step 2: Generate Design System (REQUIRED for new pages/projects)
Always start with `--design-system` to get comprehensive recommendations with reasoning:
```bash
python "${CLAUDE_PLUGIN_ROOT}/.claude/skills/ui-ux-pro-max/scripts/search.py" "<product_type> <industry> <keywords>" --design-system [-p "Project Name"]
```
This searches product/style/color/landing/typography domains in parallel, applies reasoning rules from `ui-reasoning.csv`, and returns pattern, style, colors, typography, effects, and anti-patterns to avoid.

### Step 2b: Persist Design System (Master + Overrides Pattern)
To save the design system for retrieval across sessions, add `--persist` and always pass `--output-dir` pointed at the project root:
```bash
python "${CLAUDE_PLUGIN_ROOT}/.claude/skills/ui-ux-pro-max/scripts/search.py" "<query>" --design-system --persist -p "Project Name" --output-dir "<project-root>"
```
This creates:
* `design-system/<project-slug>/MASTER.md` — Global Source of Truth
* `design-system/<project-slug>/pages/` — Folder for page-specific overrides

With a page-specific override, add `--page "dashboard"` to also create `design-system/<project-slug>/pages/dashboard.md`.

*Note: If `design-system/<project-slug>/MASTER.md` already exists, `--persist` skips writing and leaves it untouched unless you also pass `--force`.*

### Step 2c: Design Dials (optional)
Three optional 1-10 sliders that tune `--design-system` output without changing your query. Add any combination of them to the same command:
```bash
python "${CLAUDE_PLUGIN_ROOT}/.claude/skills/ui-ux-pro-max/scripts/search.py" "<query>" --design-system --variance <1-10> --motion <1-10> --density <1-10>
```

| Dial | Low (1-3) | Mid (4-7) | High (8-10) |
| :--- | :--- | :--- | :--- |
| `--variance` | Centered / minimal (biases toward Minimalism-style categories) | Balanced / modern | Bold / asymmetric (biases toward Brutalism, Bento Grids) |
| `--motion` | Subtle micro-interactions | Standard scroll/stagger motion | Complex choreography (pin, Flip, SplitText) |
| `--density` | Spacious (24-96px spacing scale) | Standard (16-64px, current default) | Dense/dashboard (8-32px spacing scale) |

* `--motion` attaches a ready-to-use GSAP snippet pulled from `--domain gsap`, matched to the resolved tier.
* `--density` overrides the `--space-*` CSS variable table in the MASTER.md output.

### Step 3: Supplement with Detailed Searches (as needed)
```bash
python "${CLAUDE_PLUGIN_ROOT}/.claude/skills/ui-ux-pro-max/scripts/search.py" "<keyword>" --domain <domain> [-n <max_results>]
```

| Need | Domain | Example |
| :--- | :--- | :--- |
| Product type patterns | `product` | `--domain product "entertainment social"` |
| More style options | `style` | `--domain style "glassmorphism dark"` |
| Color palettes | `color` | `--domain color "entertainment vibrant"` |
| Font pairings | `typography` | `--domain typography "playful modern"` |
| Individual Google Fonts | `google-fonts` | `--domain google-fonts "sans serif popular variable"` |
| Chart recommendations | `chart` | `--domain chart "real-time dashboard"` |
| UX best practices | `ux` | `--domain ux "animation accessibility"` |
| Landing page structure | `landing` | `--domain landing "hero social-proof"` |
| Icon recommendations | `icons` | `--domain icons "navigation outline"` |
| GSAP animation presets | `gsap` | `--domain gsap "scroll reveal stagger"` |
| React/Next.js performance | `react` | `--domain react "rerender memo list"` |
| App/native interface guidelines | `web` | `--domain web "accessibilityLabel touch safe-areas"` |

### Step 4: Stack Guidelines
```bash
python "${CLAUDE_PLUGIN_ROOT}/.claude/skills/ui-ux-pro-max/scripts/search.py" "<keyword>" --stack <stack>
```
*Available stacks: react, nextjs, vue, svelte, astro, nuxtjs, nuxt-ui, angular, laravel, swiftui, react-native, flutter, jetpack-compose, html-tailwind, shadcn, threejs, javafx, wpf, winui, avalonia, uno, uwp.*

---

## Troubleshooting
* **If a search returns 0 results:** Do not fabricate output. Retry once with broader/different keywords (try product + style separately). If still empty, fall back to the built-in defaults and state this explicitly to the user.
