# duolingo DESIGN.md

> Auto-generated design system — reverse-engineered via static analysis by skillui.
> Frameworks: None detected
> Colors: 1 · Fonts: 2 · Components: 0
> Icon library: not detected · State: not detected
> Primary theme: light · Dark mode toggle: no · Motion: expressive

## Visual Reference

**Match this design exactly** — study colors, fonts, spacing, and component shapes before writing any UI code.

![duolingo Homepage](../screenshots/homepage.png)

---

## 1. Visual Theme & Atmosphere

This is a **light-themed** interface with a neutral, approachable feel. The light background emphasizes content clarity. Typography pairs **KaTeX_AMS** for display/headings with **KaTeX_Caligraphic** for body text, creating clear visual hierarchy through type contrast. Spacing follows a **4px base grid** (compact density), with scale: 2, 4, 6, 8, 10, 12, 14, 16px. Motion is expressive — spring physics, layout animations, and staggered reveals are part of the visual language.

---

## 2. Color Palette & Roles

| Token | Hex | Role | Use |
|---|---|---|---|
| web-ui_button-border-color | `#00b086` | success | Success states, positive indicators |

### CSS Variable Tokens

```css
--__internal__border-radius: var(--web-ui_button-border-radius,12px);
--__internal__border-radius: var(--web-ui_button-border-radius,8px);
--__internal__border-radius: var(--web-ui_button-border-radius,16px);
--__internal__border-radius: var(--web-ui_button-border-radius,8px);
--__internal__border-radius: var(--web-ui_button-border-radius,12px);
--__internal__switchable__border-color: var(--__internal__border-color);
--__internal__border-radius: var(--web-ui_button-border-radius,8px);
--web-ui_popover-border-radius: 5px;
--web-ui_button-border-radius: 16px;
--web-ui_button-border-radius: 12px;
--web-ui_button-background-color: rgb(var(--color-iguana));
--web-ui_button-border-color: rgb(var(--color-blue-jay));
--web-ui_button-background-color: rgb(var(--color-owl));
--web-ui_button-border-color: rgb(var(--color-blue-jay));
--web-ui_button-border-color: rgb(var(--color-blue-jay));
--web-ui_button-background-color: rgb(var(--color-facebook));
--web-ui_button-border-color: rgb(var(--color-facebook-dark));
--web-ui_button-background-color: rgb(var(--color-bee));
--web-ui_button-background-color-disabled: rgb(var(--color-bee),0.4);
--web-ui_button-border-color: rgb(var(--color-camel));
```


---

## 3. Typography Rules

**Font Stack:**
- **KaTeX_Caligraphic** — Heading 1, Heading 2, Heading 3
- **KaTeX_AMS** — Body, Caption

**Font Sources:**

```css
@font-face {
  font-family: "KaTeX_AMS";
  src: url("https://d35aaqx5ub95lt.cloudfront.net/vendor/73ea273a72f4aca30ca528cf9117470a.woff2") format("woff2");
  font-weight: 400;
}
@font-face {
  font-family: "KaTeX_Caligraphic";
  src: url("https://d35aaqx5ub95lt.cloudfront.net/vendor/a1abf90dfd72792a577a5a43382bb0e4.woff2") format("woff2");
  font-weight: 700;
}
@font-face {
  font-family: "KaTeX_Caligraphic";
  src: url("https://d35aaqx5ub95lt.cloudfront.net/vendor/d6484fce1ef428d5bd94a903d7973395.woff2") format("woff2");
  font-weight: 400;
}
@font-face {
  font-family: "KaTeX_Fraktur";
  src: url("https://d35aaqx5ub95lt.cloudfront.net/vendor/931d67ea207ab37ee693ff155ff4d7a6.woff2") format("woff2");
  font-weight: 700;
}
@font-face {
  font-family: "KaTeX_Fraktur";
  src: url("https://d35aaqx5ub95lt.cloudfront.net/vendor/172d3529b26f8cedef6b5ddef7546e02.woff2") format("woff2");
  font-weight: 400;
}
@font-face {
  font-family: "KaTeX_Main";
  src: url("https://d35aaqx5ub95lt.cloudfront.net/vendor/39890742bc957b368704509bb2f4163c.woff2") format("woff2");
  font-weight: 700;
}
@font-face {
  font-family: "KaTeX_Main";
  src: url("https://d35aaqx5ub95lt.cloudfront.net/vendor/fe2176f79edaa716e6212cca53949439.woff2") format("woff2");
  font-weight: 400;
}
@font-face {
  font-family: "KaTeX_Math";
  src: url("https://d35aaqx5ub95lt.cloudfront.net/vendor/dcbcbd93bac0470b462db6f9708a658c.woff2") format("woff2");
  font-weight: 700;
}
@font-face {
  font-family: "KaTeX_Math";
  src: url("https://d35aaqx5ub95lt.cloudfront.net/vendor/6d3d25f4820d0da8f01fa3d2c7cbb8c2.woff2") format("woff2");
  font-weight: 400;
}
@font-face {
  font-family: "KaTeX_SansSerif";
  src: url("https://d35aaqx5ub95lt.cloudfront.net/vendor/95591a929f0d32aa282a90ba5acf81f0.woff2") format("woff2");
  font-weight: 700;
}
@font-face {
  font-family: "KaTeX_SansSerif";
  src: url("https://d35aaqx5ub95lt.cloudfront.net/vendor/7d393d382f3e7fb1c637280a90a3434b.woff2") format("woff2");
  font-weight: 400;
}
@font-face {
  font-family: "KaTeX_Script";
  src: url("https://d35aaqx5ub95lt.cloudfront.net/vendor/c81d1b2a4b75d3eded6059a210910a6b.woff2") format("woff2");
  font-weight: 400;
}
@font-face {
  font-family: "KaTeX_Size1";
  src: url("https://d35aaqx5ub95lt.cloudfront.net/vendor/6eec866c69313624be6061a5c86f0944.woff2") format("woff2");
  font-weight: 400;
}
@font-face {
  font-family: "KaTeX_Size2";
  src: url("https://d35aaqx5ub95lt.cloudfront.net/vendor/2960900c4f271311eb36d175a209aa0a.woff2") format("woff2");
  font-weight: 400;
}
@font-face {
  font-family: "KaTeX_Size3";
  src: url("https://d35aaqx5ub95lt.cloudfront.net/vendor/e1951519f6f0596f735635e962d5b82c.woff2") format("woff2");
  font-weight: 400;
}
@font-face {
  font-family: "KaTeX_Size4";
  src: url("https://d35aaqx5ub95lt.cloudfront.net/vendor/e418bf257af1052628d8c981d158674c.woff2") format("woff2");
  font-weight: 400;
}
@font-face {
  font-family: "KaTeX_Typewriter";
  src: url("https://d35aaqx5ub95lt.cloudfront.net/vendor/c295e7f71970f03c0549228b1c18120a.woff2") format("woff2");
  font-weight: 400;
}
```

| Role | Font | Size | Weight |
|---|---|---|---|
| Heading 1 | KaTeX_Caligraphic | 64px | 700 |
| Heading 2 | KaTeX_Caligraphic | 48px | 700 |
| Heading 3 | KaTeX_Caligraphic | 36px | 700 |
| Body | KaTeX_AMS | 15px | 400 |
| Caption | KaTeX_AMS | 14px | 400 |

**Typographic Rules:**
- Limit to 2 font families max per screen
- Use **KaTeX_Caligraphic** for body/UI text, **KaTeX_AMS** for display/headings
- Maintain consistent hierarchy: no more than 3-4 font sizes per screen
- Headings use bold (600-700), body uses regular (400)
- Line height: 1.5 for body text, 1.2 for headings
- Use color and opacity for secondary hierarchy, not additional font sizes


---

## 4. Component Stylings

No components detected. Scan `src/components/` or `components/` to populate this section.

---

## 5. Layout Principles

- **Base spacing unit:** 4px
- **Spacing scale:** 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24
- **Border radius:** .15em, 2px, 5px, 6px, 8px, 12px, inherit, 7px, 16px, 18%, 18px, 30%, 98px
- **Max content width:** 1065px

**Spacing as Meaning:**
| Spacing | Use |
|---|---|
| 4-8px | Tight: related items within a group |
| 12-16px | Medium: between groups |
| 24-32px | Wide: between sections |
| 48px+ | Vast: major section breaks |


---

## 6. Depth & Elevation

### Flat — subtle depth hints

- `0 2px 0`
- `0 2px 0 var(--__internal__border-color)`

### Raised — cards, buttons, interactive elements

- `0 var(--__internal__lip-width)0`
- `0 3px 0 1px`
- `inset 0 0 0 3px var(--latex-blank-border-color-light,rgb(var(--color-blue-jay)))`

### Z-Index Scale

`1, 2, 10, 100, 300, 310, 315, 322, 324`



---

## 7. Animation & Motion

This project uses **expressive motion**. Animations are an integral part of the experience.

### CSS Animations

- `@keyframes qnlsp`
- `@keyframes tj_TT`
- `@keyframes _2xhhK`
- `@keyframes _3wL1o`
- `@keyframes EJauM`
- `@keyframes _2nQ30`
- `@keyframes _2tb0b`
- `@keyframes lIsSW`

### Motion Guidelines

- Duration: 150-300ms for micro-interactions, 300-500ms for page transitions
- Easing: `ease-out` for enters, `ease-in` for exits
- Always respect `prefers-reduced-motion`


---

## 8. Do's and Don'ts

### Do's

- Pair **KaTeX_Caligraphic** (body) with **KaTeX_AMS** (display) — these are the only allowed fonts
- Follow the **4px** spacing grid for all margins, padding, and gaps
- Use the defined shadow tokens for elevation — see Section 6
- Use border-radius from the scale: .15em, 2px, 5px, 6px, 8px

### Don'ts

- Don't introduce colors outside this palette — extend the design tokens first
- Don't introduce additional font families beyond KaTeX_Caligraphic and KaTeX_AMS
- Don't use arbitrary spacing values — stick to multiples of 4px
- Don't create custom box-shadow values outside the system tokens
- Don't use arbitrary border-radius values — pick from the defined scale
- Don't use backdrop-blur or blur effects

### Anti-Patterns (detected from codebase)

- No blur or backdrop-blur effects
- No zebra striping on tables/lists


---

## 9. Responsive Behavior

| Name | Value | Source |
|---|---|---|
| sm | 530px | css |
| md | 699px | css |
| md | 700px | css |
| md | 768px | css |
| lg | 980px | css |
| xl | 1065px | css |
| xl | 1080px | css |
| 2xl | 1440px | css |

**Approach:** Use `@media (min-width: ...)` queries matching the breakpoints above.


---

## 10. Agent Prompt Guide

Use these as starting points when building new UI:

### Build a Card

```
Background: var(--surface)
Border: 1px solid var(--border)
Radius: inherit
Padding: 16px
Font: KaTeX_Caligraphic
Use shadow tokens from Section 6.
```

### Build a Button

```
Primary: bg var(--accent), text white
Ghost: bg transparent, border var(--border)
Padding: 8px 16px
Radius: inherit
Hover: opacity 0.9 or lighter shade
Focus: ring with var(--accent)
```

### Build a Page Layout

```
Background: var(--background)
Max-width: 1065px, centered
Grid: 4px base
Responsive: mobile-first, breakpoints from Section 9
```

### Build a Stats Card

```
Surface: var(--surface)
Label: var(--text-muted) (muted, 12px, uppercase)
Value: var(--text-primary) (primary, 24-32px, bold)
Status: use success/warning/danger from Section 2
```

### Build a Form

```
Input bg: var(--background)
Input border: 1px solid var(--border)
Focus: border-color var(--accent)
Label: var(--text-muted) 12px
Spacing: 16px between fields
Radius: inherit
```

### General Component

```
1. Read DESIGN.md Sections 2-6 for tokens
2. Colors: only from palette
3. Font: KaTeX_Caligraphic, type scale from Section 3
4. Spacing: 4px grid
5. Components: match patterns from Section 4
6. Elevation: shadow tokens
```
