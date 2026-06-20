---
name: streaksapp-design
description: Design system skill for streaksapp. Activate when building UI components, pages, or any visual elements. Provides exact color tokens, typography scale, spacing grid, component patterns, and craft rules. Read references/DESIGN.md before writing any CSS or JSX.
---

# streaksapp Design System

You are building UI for **streaksapp**. Dark-themed, neutral palette, sans-serif typography (Helvetica Neue), standard density on a 5px grid.

## Visual Reference

**IMPORTANT**: Study ALL screenshots below before writing any UI. Match colors, typography, spacing, layout, and motion exactly as shown.

### Homepage

![streaksapp Homepage](screenshots/homepage.png)

> Read `references/DESIGN.md` for full token details.

## Design Philosophy

- **Layered depth** — use shadow tokens to create a sense of physical layering. Each elevation level has a specific shadow.
- **Gradient accents** — gradients are used thoughtfully for emphasis, not decoration.
- **Type pairing** — Helvetica Neue for body/UI text, Roboto Condensed for headings/display. Never introduce a third typeface.
- **standard density** — 5px base grid. Every dimension is a multiple of 5.
- **neutral palette** — the color temperature runs neutral, matching the sans-serif typography.
- **Subtle motion** — transitions smooth state changes. Keep durations under 300ms, use ease-out curves.

## Color System

### Core Palette

| Role | Token | Hex | Use |
|------|-------|-----|-----|
| Background | `--background` | `#000000` | Page/app background |
| Surface | `--surface` | `#333333` | Cards, panels, modals |
| Text Primary | `--text-primary` | `#ffffff` | Headings, body text |
| Text Muted | `--text-muted` | `#777777` | Captions, placeholders |
| Border | `--border` | `#555555` | Dividers, card borders |

### Status Colors

| Status | Hex | Use |
|--------|-----|-----|
| Success | `#3c763d` | Confirmations, positive trends |
| Warning | `#8a6d3b` | Caution states, pending items |
| Danger | `#f9f2f4` | Errors, destructive actions |

### Extended Palette

- `#337ab7`
- `#a94442`
- `#e8e8e8` — Light surface or highlight color
- `#31708f`
- `#999999`
- `#fcf8e3` — Light surface or highlight color
- `#dddddd`
- `#dff0d8` — Light surface or highlight color

## Typography

### Font Stack

- **Helvetica Neue** — Heading 1, Heading 2, Heading 3
- **Roboto Condensed** — Body, Caption
- **Menlo** — Code

### Font Sources

```css
@font-face {
  font-family: "Roboto Condensed";
  src: url("fonts/RobotoCondensed-Bold.ttf") format("truetype");
  font-weight: 700;
}
@font-face {
  font-family: "Roboto Condensed";
  src: url("fonts/RobotoCondensed-Regular.ttf") format("truetype");
  font-weight: 400;
}
```

### Type Scale

| Role | Family | Size | Weight |
|------|--------|------|--------|
| Heading 1 | Helvetica Neue | 74px | 700 |
| Heading 2 | Helvetica Neue | 72px | 700 |
| Heading 3 | Helvetica Neue | 63px | 700 |
| Body | Roboto Condensed | 18px | 400 |
| Caption | Roboto Condensed | 12px | 400 |
| Code | Menlo | 14px | 400 |

### Typography Rules

- Body/UI: **Helvetica Neue**, Headings: **Roboto Condensed** — these are the only display fonts
- Max 3-4 font sizes per screen
- Headings: weight 600-700, body: weight 400
- Use color and opacity for text hierarchy, not additional font sizes
- Line height: 1.5 for body, 1.2 for headings

## Spacing & Layout

### Base Grid: 5px

Every dimension (margin, padding, gap, width, height) must be a multiple of **5px**.

### Spacing Scale

`5, 10, 15, 20, 25, 30, 35, 40, 50, 60, 80, 90` px

### Spacing as Meaning

| Spacing | Use |
|---------|-----|
| 2.5-5px | Tight: related items within a group |
| 10px | Medium: between groups |
| 15-20px | Wide: between sections |
| 30px+ | Vast: major section breaks |

### Border Radius

Scale: `.1em, .25em, 1px, 3px, 4px, 5px, 6px, 8px, 10px, 15px`
Default: `5px`

### Container

Max-width: `1150px`, centered with auto margins.

### Breakpoints

| Name | Value |
|------|-------|
| md | 767px |
| md | 768px |
| lg | 769px |
| lg | 991px |
| lg | 992px |
| xl | 1199px |
| xl | 1200px |

Mobile-first: design for small screens, layer on responsive overrides.

## Component Patterns

### Card

```css
.card {
  background: #333333;
  border: 1px solid #555555;
  border-radius: 5px;
  padding: 20px;
  box-shadow: inset 0 1px 1px rgba(0,0,0,.075),0 0 8px rgba(102,175,233,.6);
}
```

```html
<div class="card">
  <h3>Card Title</h3>
  <p>Card content goes here.</p>
</div>
```

### Button

```css
/* Primary */
.btn-primary {
  background: #444444;
  color: #ffffff;
  border-radius: 5px;
  padding: 10px 20px;
  font-weight: 500;
  transition: opacity 150ms ease;
}
.btn-primary:hover { opacity: 0.9; }

/* Ghost */
.btn-ghost {
  background: transparent;
  border: 1px solid #555555;
  color: #ffffff;
  border-radius: 5px;
  padding: 10px 20px;
}
```

```html
<button class="btn-primary">Get Started</button>
<button class="btn-ghost">Learn More</button>
```

### Input

```css
.input {
  background: #000000;
  border: 1px solid #555555;
  border-radius: 5px;
  padding: 10px 15px;
  color: #ffffff;
  font-size: 14px;
}
.input:focus { border-color: var(--accent); outline: none; }
```

```html
<input class="input" type="text" placeholder="Search..." />
```

### Badge / Chip

```css
.badge {
  display: inline-flex;
  align-items: center;
  padding: 5px 10px;
  border-radius: 9999px;
  font-size: 12px;
  font-weight: 500;
  background: #333333;
  color: #777777;
}
```

```html
<span class="badge">New</span>
<span class="badge">Beta</span>
```

### Modal / Dialog

```css
.modal-backdrop { background: rgba(0, 0, 0, 0.6); }
.modal {
  background: #333333;
  border: 1px solid #555555;
  border-radius: 15px;
  padding: 30px;
  max-width: 480px;
  width: 90vw;
  box-shadow: 0 6px 12px rgba(0,0,0,.175);
}
```

```html
<div class="modal-backdrop">
  <div class="modal">
    <h2>Dialog Title</h2>
    <p>Dialog content.</p>
    <button class="btn-primary">Confirm</button>
    <button class="btn-ghost">Cancel</button>
  </div>
</div>
```

### Table

```css
.table { width: 100%; border-collapse: collapse; }
.table th {
  text-align: left;
  padding: 10px 15px;
  font-weight: 500;
  font-size: 12px;
  color: #777777;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  border-bottom: 1px solid #555555;
}
.table td {
  padding: 15px;
  border-bottom: 1px solid #555555;
}
```

```html
<table class="table">
  <thead><tr><th>Name</th><th>Status</th><th>Date</th></tr></thead>
  <tbody>
    <tr><td>Item One</td><td>Active</td><td>Jan 1</td></tr>
    <tr><td>Item Two</td><td>Pending</td><td>Jan 2</td></tr>
  </tbody>
</table>
```

### Navigation

```css
.nav {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 15px 20px;
  border-bottom: 1px solid #555555;
}
.nav-link {
  color: #777777;
  padding: 10px 15px;
  border-radius: 5px;
  transition: color 150ms;
}
.nav-link:hover { color: #ffffff; }
```

```html
<nav class="nav">
  <a href="/" class="nav-link active">Home</a>
  <a href="/about" class="nav-link">About</a>
  <a href="/pricing" class="nav-link">Pricing</a>
  <button class="btn-primary" style="margin-left: auto">Get Started</button>
</nav>
```

## Page Structure

The following page sections were detected:

- **Hero** — Hero/banner section with headline and CTAs
- **Footer** — Page footer with links and info (6 items)
- **Faq** — FAQ/accordion section

When building pages, follow this section order and structure.

## Animation & Motion

This project uses **subtle motion**. Transitions smooth state changes without calling attention.

### CSS Animations

- `progress-bar-stripes`
- `fa-spin`

### Motion Tokens

- **Duration scale:** `0.3s`, `.35s`, `150ms`, `200ms`, `300ms`, `600ms`
- **Easing functions:** `ease-in-out`, `linear`, `ease`, `ease-out`

### Motion Guidelines

- **Duration:** Use values from the duration scale above. Short (0.3s) for micro-interactions, long (600ms) for page transitions
- **Easing:** Use `ease-in-out` as the default easing curve
- **Direction:** Elements enter from bottom/right, exit to top/left
- **Reduced motion:** Always respect `prefers-reduced-motion` — disable animations when set

## Depth & Elevation

### Shadow Tokens

- Subtle: `inset 0-1px 0 rgba(0,0,0,.25)`
- Subtle: `inset 0 1px 1px rgba(0,0,0,.075)`
- Subtle: `inset 0 1px 0 rgba(255,255,255,.1)`
- Subtle: `inset 0 1px 0 rgba(255,255,255,.1),0 1px 0 rgba(255,255,255,.1)`
- Subtle: `inset 0 1px 2px rgba(0,0,0,.1)`
- Subtle: `inset 0-1px 0 rgba(0,0,0,.15)`

### Z-Index Scale

`2, 3, 5, 10, 15, 990, 1000, 1030, 1040, 1050, 1060, 1070`

Use these exact values — never invent z-index values.

## Anti-Patterns (Never Do)

- **No blur effects** — no backdrop-blur, no filter: blur()
- **No zebra striping** — tables and lists use borders for separation
- **No invented colors** — every hex value must come from the palette above
- **No arbitrary spacing** — every dimension is a multiple of 5px
- **No extra fonts** — only Helvetica Neue and Roboto Condensed and Menlo are allowed
- **No arbitrary border-radius** — use the scale: .1em, .25em, 1px, 3px, 4px, 5px, 6px, 8px, 10px, 15px
- **No opacity for disabled states** — use muted colors instead

## Workflow

1. **Read** `references/DESIGN.md` before writing any UI code
2. **Pick colors** from the Color System section — never invent new ones
3. **Set typography** — Helvetica Neue, Roboto Condensed, Menlo only, using the type scale
4. **Build layout** on the 5px grid — check every margin, padding, gap
5. **Match components** to patterns above before creating new ones
6. **Apply elevation** — use shadow tokens
7. **Validate** — every value traces back to a design token. No magic numbers.

## Brand Spec

- **Favicon:** `/apple-touch-icon-180x180.png`
- **Site URL:** `https://streaksapp.com`
- **Brand typeface:** Helvetica Neue

## Quick Reference

```
Background:     #000000
Surface:        #333333
Text:           #ffffff / #777777
Accent:         (not extracted)
Border:         #555555
Font:           Helvetica Neue
Spacing:        5px grid
Radius:         5px
Components:     2 detected
```

## When to Trigger

Activate this skill when:
- Creating new components, pages, or visual elements for streaksapp
- Writing CSS, Tailwind classes, styled-components, or inline styles
- Building page layouts, templates, or responsive designs
- Reviewing UI code for design consistency
- The user mentions "streaksapp" design, style, UI, or theme
- Generating mockups, wireframes, or visual prototypes

---

# Full Reference Files

> Every output file is embedded below. Claude has full design system context from /skills alone.

## Design System Tokens (DESIGN.md)

# streaksapp DESIGN.md

> Auto-generated design system — reverse-engineered via static analysis by skillui.
> Frameworks: None detected
> Colors: 20 · Fonts: 3 · Components: 2
> Icon library: not detected · State: not detected
> Primary theme: dark · Dark mode toggle: no · Motion: subtle

## Visual Reference

**Match this design exactly** — study colors, fonts, spacing, and component shapes before writing any UI code.

![streaksapp Homepage](../screenshots/homepage.png)

---

## 1. Visual Theme & Atmosphere

This is a **dark-themed** interface with a neutral tone. Depth is expressed through layered shadows and subtle surface color variation. Typography pairs **Roboto Condensed** for display/headings with **Helvetica Neue** for body text, creating clear visual hierarchy through type contrast. Spacing follows a **5px base grid** (standard density), with scale: 5, 10, 15, 20, 25, 30, 35, 40px. Motion is subtle — smooth transitions (150-300ms) ease state changes without drawing attention.

---

## 2. Color Palette & Roles

| Token | Hex | Role | Use |
|---|---|---|---|
| background | `#000000` | background | Page background, darkest surface |
| surface | `#333333` | surface | Card and panel backgrounds |
| text-primary | `#ffffff` | text-primary | Headings and body text |
| text-muted | `#777777` | text-muted | Captions, placeholders, secondary info |
| border | `#555555` | border | Dividers, card borders, outlines |
| danger | `#f9f2f4` | danger | Error states, destructive actions |
| success | `#3c763d` | success | Success states, positive indicators |
| warning | `#8a6d3b` | warning | Warning states, caution indicators |
| info | `#337ab7` | info | Informational highlights |
| unknown | `#a94442` | unknown | Palette color |
| unknown | `#e8e8e8` | unknown | Palette color |
| unknown | `#31708f` | unknown | Palette color |
| unknown | `#999999` | unknown | Palette color |
| unknown | `#fcf8e3` | unknown | Palette color |
| unknown | `#dddddd` | unknown | Palette color |
| unknown | `#dff0d8` | unknown | Palette color |
| unknown | `#f2dede` | unknown | Palette color |
| unknown | `#cccccc` | unknown | Palette color |
| unknown | `#23527c` | unknown | Palette color |
| unknown | `#286090` | unknown | Palette color |


---

## 3. Typography Rules

**Font Stack:**
- **Helvetica Neue** — Heading 1, Heading 2, Heading 3
- **Roboto Condensed** — Body, Caption
- **Menlo** — Code

**Font Sources:**

```css
@font-face {
  font-family: "Roboto Condensed";
  src: url("fonts/RobotoCondensed-Bold.ttf") format("truetype");
  font-weight: 700;
}
@font-face {
  font-family: "Roboto Condensed";
  src: url("fonts/RobotoCondensed-Regular.ttf") format("truetype");
  font-weight: 400;
}
```

| Role | Font | Size | Weight |
|---|---|---|---|
| Heading 1 | Helvetica Neue | 74px | 700 |
| Heading 2 | Helvetica Neue | 72px | 700 |
| Heading 3 | Helvetica Neue | 63px | 700 |
| Body | Roboto Condensed | 18px | 400 |
| Caption | Roboto Condensed | 12px | 400 |
| Code | Menlo | 14px | 400 |

**Typographic Rules:**
- Limit to 3 font families max per screen
- Use **Helvetica Neue** for body/UI text, **Roboto Condensed** for display/headings
- Maintain consistent hierarchy: no more than 3-4 font sizes per screen
- Headings use bold (600-700), body uses regular (400)
- Line height: 1.5 for body text, 1.2 for headings
- Use color and opacity for secondary hierarchy, not additional font sizes


---

## 4. Component Stylings

### Layout (1)

**Footer** — `html`

### Media (1)

**Image** — `html`



---

## 5. Layout Principles

- **Base spacing unit:** 5px
- **Spacing scale:** 5, 10, 15, 20, 25, 30, 35, 40, 50, 60, 80, 90
- **Border radius:** .1em, .25em, 1px, 3px, 4px, 5px, 6px, 8px, 10px, 15px
- **Max content width:** 1150px

**Spacing as Meaning:**
| Spacing | Use |
|---|---|
| 2.5-5px | Tight: related items within a group |
| 10px | Medium: between groups |
| 15-20px | Wide: between sections |
| 30px+ | Vast: major section breaks |


---

## 6. Depth & Elevation

### Flat — subtle depth hints

- `inset 0-1px 0 rgba(0,0,0,.25)`
- `inset 0 1px 1px rgba(0,0,0,.075)`
- `inset 0 1px 0 rgba(255,255,255,.1)`

### Raised — cards, buttons, interactive elements

- `inset 0 1px 1px rgba(0,0,0,.075),0 0 8px rgba(102,175,233,.6)`
- `inset 0 1px 1px rgba(0,0,0,.075),0 0 6px #67b168`
- `inset 0 1px 1px rgba(0,0,0,.075),0 0 6px #c0a16b`

### Floating — dropdowns, popovers, modals

- `0 6px 12px rgba(0,0,0,.175)`
- `0 3px 9px rgba(0,0,0,.5)`
- `0 5px 15px rgba(0,0,0,.5)`

### Z-Index Scale

`2, 3, 5, 10, 15, 990, 1000, 1030, 1040, 1050, 1060, 1070`



---

## 7. Animation & Motion

This project uses **subtle motion**. Transitions smooth state changes without demanding attention.

### CSS Animations

- `@keyframes progress-bar-stripes`
- `@keyframes fa-spin`

### Motion Guidelines

- Duration: 150-300ms for micro-interactions, 300-500ms for page transitions
- Easing: `ease-out` for enters, `ease-in` for exits
- Always respect `prefers-reduced-motion`


---

## 8. Do's and Don'ts

### Do's

- Use `#000000` as the primary page background
- Pair **Helvetica Neue** (body) with **Roboto Condensed** (display) — these are the only allowed fonts
- Follow the **5px** spacing grid for all margins, padding, and gaps
- Use the defined shadow tokens for elevation — see Section 6
- Use border-radius from the scale: .1em, .25em, 1px, 3px, 4px
- Reuse existing components from Section 4 before creating new ones

### Don'ts

- Don't introduce colors outside this palette — extend the design tokens first
- Don't introduce additional font families beyond Helvetica Neue and Roboto Condensed and Menlo
- Don't use arbitrary spacing values — stick to multiples of 5px
- Don't create custom box-shadow values outside the system tokens
- Don't use arbitrary border-radius values — pick from the defined scale
- Don't duplicate component patterns — check Section 4 first
- Don't use backdrop-blur or blur effects

### Anti-Patterns (detected from codebase)

- No blur or backdrop-blur effects
- No zebra striping on tables/lists


---

## 9. Responsive Behavior

| Name | Value | Source |
|---|---|---|
| md | 767px | css |
| md | 768px | css |
| lg | 769px | css |
| lg | 991px | css |
| lg | 992px | css |
| xl | 1199px | css |
| xl | 1200px | css |

**Approach:** Use `@media (min-width: ...)` queries matching the breakpoints above.


---

## 10. Agent Prompt Guide

Use these as starting points when building new UI:

### Build a Card

```
Background: #333333
Border: 1px solid #555555
Radius: 5px
Padding: 20px
Font: Helvetica Neue
Use shadow tokens from Section 6.
```

### Build a Button

```
Primary: bg var(--accent), text white
Ghost: bg transparent, border #555555
Padding: 10px 20px
Radius: 5px
Hover: opacity 0.9 or lighter shade
Focus: ring with var(--accent)
```

### Build a Page Layout

```
Background: #000000
Max-width: 1150px, centered
Grid: 5px base
Responsive: mobile-first, breakpoints from Section 9
```

### Build a Stats Card

```
Surface: #333333
Label: #777777 (muted, 12px, uppercase)
Value: #ffffff (primary, 24-32px, bold)
Status: use success/warning/danger from Section 2
```

### Build a Form

```
Input bg: #000000
Input border: 1px solid #555555
Focus: border-color var(--accent)
Label: #777777 12px
Spacing: 20px between fields
Radius: 5px
```

### General Component

```
1. Read DESIGN.md Sections 2-6 for tokens
2. Colors: only from palette
3. Font: Helvetica Neue, type scale from Section 3
4. Spacing: 5px grid
5. Components: match patterns from Section 4
6. Elevation: shadow tokens
```

## Bundled Fonts (fonts/)

The following font files are bundled in the `fonts/` directory:

- `fonts/RobotoCondensed-Black.ttf`
- `fonts/RobotoCondensed-Bold.ttf`
- `fonts/RobotoCondensed-ExtraBold.ttf`
- `fonts/RobotoCondensed-ExtraLight.ttf`
- `fonts/RobotoCondensed-Light.ttf`
- `fonts/RobotoCondensed-Medium.ttf`
- `fonts/RobotoCondensed-Regular.ttf`
- `fonts/RobotoCondensed-SemiBold.ttf`
- `fonts/RobotoCondensed-Thin.ttf`

Use these local font files in `@font-face` declarations instead of fetching from Google Fonts.

## Homepage Screenshots (screenshots/)

![homepage.png](screenshots/homepage.png)

