# Monomythic Brand Identity System
## AI Transformation Through the Hero's Journey

Version 1.0 | November 2025

---

## Table of Contents

1. [Brand Essence](#brand-essence)
2. [Visual System](#visual-system)
3. [Color Palette](#color-palette)
4. [Typography](#typography)
5. [Texture & Pattern Library](#texture--pattern-library)
6. [Iconography](#iconography)
7. [Layout Principles](#layout-principles)
8. [Brand Voice](#brand-voice)
9. [Messaging Framework](#messaging-framework)
10. [Application Examples](#application-examples)
11. [Implementation Guidelines](#implementation-guidelines)
12. [Asset Checklist](#asset-checklist)

---

## Brand Essence

### Positioning Statement
Monomythic guides organizations through AI transformation using Joseph Campbell's Hero's Journey framework—turning technological disruption into meaningful evolution.

### Brand Archetype
**The Sage Explorer** — Wisdom meets adventure. Evidence-based guidance for uncharted territory.

### Design Philosophy
"Romantic Expedition" — The aesthetic of 18th-19th century exploration: engraved brass instruments, hand-drawn cartography, navy captain's logs. Where empirical observation meets mythological depth.

### Core Values
- **Mythological Depth**: Every transformation follows archetypal patterns
- **Evidence-Based**: Data and research over buzzwords
- **Stoic Pragmatism**: Clear-eyed about challenges, committed to the journey
- **Navigational Precision**: Clear maps through unclear territory

---

## Visual System

### Design Language
The visual system evokes **scientific expedition equipment** from the age of exploration:
- Engraved brass sextants and compasses
- Hand-drawn survey maps with careful annotations
- Naval charts with depth soundings
- Field journals with precise observations
- Etched glass and polished instruments

### Visual Hierarchy
1. **Primary**: Navy depths + brass gold highlights
2. **Secondary**: Engraved textures and cartographic line work
3. **Tertiary**: Parchment tones and sepia accents

---

## Color Palette

### Primary Colors

**Deep Navy** — The Unknown Waters
```
HEX: #0A1628
RGB: 10, 22, 40
CMYK: 75, 45, 0, 84
Pantone: 533 C

Usage: Primary backgrounds, body text, dominant brand color
Represents: Depth, the unknown, the journey ahead
```

**Brass Gold** — The Compass Point
```
HEX: #C9A661
RGB: 201, 166, 97
CMYK: 0, 17, 52, 21
Pantone: 466 C

Usage: Accents, highlights, CTAs, key insights
Represents: Guidance, value, illumination
```

### Secondary Colors

**Storm Grey** — The Overcast Sky
```
HEX: #4A5568
RGB: 74, 85, 104
CMYK: 29, 18, 0, 59

Usage: Secondary text, dividers, subtle backgrounds
```

**Parchment** — The Chart Paper
```
HEX: #F4EFE6
RGB: 244, 239, 230
CMYK: 0, 2, 6, 4

Usage: Light backgrounds, callout sections, contrast panels
```

**Sepia Ink** — The Navigator's Notes
```
HEX: #6B5744
RGB: 107, 87, 68
CMYK: 0, 19, 36, 58

Usage: Annotation text, subtle elements, aged effects
```

### Accent Colors

**Verdigris** — Aged Brass Patina
```
HEX: #5C8D89
RGB: 92, 141, 137
CMYK: 35, 0, 3, 45

Usage: Secondary highlights, success states, journey milestones
```

**Coral Red** — Warning Markers
```
HEX: #C84B31
RGB: 200, 75, 49
CMYK: 0, 62, 76, 22

Usage: Urgent information, challenges, thresholds (sparingly)
```

### Color Relationships

**Duotone Combinations:**
- Navy (#0A1628) + Brass Gold (#C9A661) — Primary brand duotone
- Navy (#0A1628) + Verdigris (#5C8D89) — Secondary duotone
- Storm Grey (#4A5568) + Sepia Ink (#6B5744) — Subdued duotone

**Gradients:**
```css
/* The Depths */
background: linear-gradient(180deg, #0A1628 0%, #1A2F4A 100%);

/* Brass Shimmer */
background: linear-gradient(135deg, #C9A661 0%, #A68B56 100%);

/* Twilight Navigation */
background: linear-gradient(180deg, #0A1628 0%, #5C8D89 100%);
```

### Accessibility Standards
- All text combinations meet WCAG AA standards minimum
- Navy + Brass Gold: AA for large text, use white for body text
- Parchment + Navy: AAA for all text sizes
- Contrast ratio targets: AA (4.5:1), AAA (7:1)

---

## Typography

### Type Philosophy
Combining **classical serif authority** with **technical precision**. Like a naval captain's log annotated by a skilled cartographer.

### Primary Typeface: Freight Text Pro

**Usage**: Headlines, hero text, key statements

```
Freight Text Pro Book — Body copy, comfortable reading
Freight Text Pro Medium — Subheadings, emphasis
Freight Text Pro Bold — Headlines, strong statements
```

**Characteristics:**
- Classical proportions with modern clarity
- Excellent readability at display sizes
- Subtle bracketing suggests engraved letterforms
- Professional without being corporate

**Alternate (Free)**: Libre Baskerville
- Google Fonts alternative
- Similar classical proportions

### Secondary Typeface: IBM Plex Mono

**Usage**: Data, technical content, annotations, code

```
IBM Plex Mono Regular — Technical body text
IBM Plex Mono Medium — Highlighted data
IBM Plex Mono SemiBold — Technical headers
```

**Characteristics:**
- Evokes scientific instruments and precise measurement
- Excellent for displaying frameworks and methodologies
- Clear distinction from primary typeface
- Open-source and widely available

### Tertiary Typeface: Source Sans 3

**Usage**: UI elements, captions, metadata

```
Source Sans 3 Regular — UI text, small labels
Source Sans 3 SemiBold — UI emphasis, buttons
```

**Characteristics:**
- Clean, neutral, highly legible
- Excellent at small sizes
- Web-optimized
- Complements without competing

### Type Scale

Based on 1.250 (Major Third) modular scale:

```
Hero Display: 64px / 4rem (Freight Text Bold)
H1: 51px / 3.2rem (Freight Text Bold)
H2: 41px / 2.56rem (Freight Text Medium)
H3: 33px / 2.05rem (Freight Text Medium)
H4: 26px / 1.64rem (Freight Text Book)
Body Large: 20px / 1.25rem (Freight Text Book)
Body: 16px / 1rem (Freight Text Book)
Body Small: 13px / 0.8rem (Source Sans 3)
Caption: 10px / 0.64rem (Source Sans 3)
```

### Line Heights
```
Display: 1.1
Headings: 1.2
Body: 1.6
Technical: 1.5
```

### Type Pairings

**Exploration Headlines:**
```
HEADING: Freight Text Pro Bold, 51px, Navy, 1.2 line-height
SUBHEAD: IBM Plex Mono Medium, 16px, Brass Gold, uppercase, 1.5 line-height
BODY: Freight Text Pro Book, 16px, Storm Grey, 1.6 line-height
```

**Data Displays:**
```
LABEL: IBM Plex Mono Regular, 13px, Sepia Ink, uppercase
VALUE: IBM Plex Mono SemiBold, 26px, Navy
UNIT: IBM Plex Mono Regular, 16px, Storm Grey
```

**Storytelling Layouts:**
```
CHAPTER: Source Sans 3 SemiBold, 13px, Brass Gold, uppercase, tracked +0.1em
TITLE: Freight Text Pro Bold, 41px, Navy
NARRATIVE: Freight Text Pro Book, 20px, Navy, 1.6 line-height
```

---

## Texture & Pattern Library

### Engraved Brass Effect

**Technical Specs:**
```css
.engraved-brass {
  background: linear-gradient(135deg, #C9A661 0%, #A68B56 100%);
  position: relative;
  overflow: hidden;
}

.engraved-brass::before {
  content: '';
  position: absolute;
  inset: 0;
  background-image:
    repeating-linear-gradient(
      0deg,
      rgba(0,0,0,0.03) 0px,
      transparent 1px,
      transparent 2px,
      rgba(0,0,0,0.03) 3px
    ),
    repeating-linear-gradient(
      90deg,
      rgba(0,0,0,0.03) 0px,
      transparent 1px,
      transparent 2px,
      rgba(0,0,0,0.03) 3px
    );
  mix-blend-mode: multiply;
}

.engraved-brass::after {
  content: '';
  position: absolute;
  inset: 0;
  background: radial-gradient(
    ellipse at 30% 30%,
    rgba(255,255,255,0.3),
    transparent 50%
  );
  mix-blend-mode: overlay;
}
```

### Cartographic Line Work

**Cross-Hatch Pattern:**
```css
.cartographic-hatch {
  background-color: #F4EFE6;
  background-image:
    repeating-linear-gradient(
      45deg,
      transparent,
      transparent 10px,
      rgba(10,22,40,0.03) 10px,
      rgba(10,22,40,0.03) 11px
    ),
    repeating-linear-gradient(
      -45deg,
      transparent,
      transparent 10px,
      rgba(10,22,40,0.03) 10px,
      rgba(10,22,40,0.03) 11px
    );
}
```

**Survey Grid:**
```css
.survey-grid {
  background-color: #0A1628;
  background-image:
    linear-gradient(rgba(201,166,97,0.1) 1px, transparent 1px),
    linear-gradient(90deg, rgba(201,166,97,0.1) 1px, transparent 1px);
  background-size: 50px 50px;
}
```

### Nautical Rope Border

```css
.rope-border {
  border: 3px solid #C9A661;
  border-image: repeating-linear-gradient(
    45deg,
    #C9A661 0,
    #C9A661 10px,
    #A68B56 10px,
    #A68B56 20px
  ) 3;
  position: relative;
}
```

### Compass Rose Pattern

**SVG Pattern:**
```svg
<pattern id="compass-rose" x="0" y="0" width="200" height="200" patternUnits="userSpaceOnUse">
  <circle cx="100" cy="100" r="2" fill="#C9A661" opacity="0.3"/>
  <line x1="100" y1="90" x2="100" y2="110" stroke="#C9A661" stroke-width="0.5" opacity="0.2"/>
  <line x1="90" y1="100" x2="110" y2="100" stroke="#C9A661" stroke-width="0.5" opacity="0.2"/>
  <line x1="93" y1="93" x2="107" y2="107" stroke="#C9A661" stroke-width="0.5" opacity="0.1"/>
  <line x1="107" y1="93" x2="93" y2="107" stroke="#C9A661" stroke-width="0.5" opacity="0.1"/>
</pattern>
```

### Paper Texture Overlay

```css
.parchment-texture {
  background: #F4EFE6;
  position: relative;
}

.parchment-texture::before {
  content: '';
  position: absolute;
  inset: 0;
  background-image: url('data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMjAwIiBoZWlnaHQ9IjIwMCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48ZmlsdGVyIGlkPSJub2lzZSI+PGZlVHVyYnVsZW5jZSB0eXBlPSJmcmFjdGFsTm9pc2UiIGJhc2VGcmVxdWVuY3k9IjAuOSIgbnVtT2N0YXZlcz0iNCIgLz48L2ZpbHRlcj48cmVjdCB3aWR0aD0iMTAwJSIgaGVpZ2h0PSIxMDAlIiBmaWx0ZXI9InVybCgjbm9pc2UpIiBvcGFjaXR5PSIwLjA1IiAvPjwvc3ZnPg==');
  opacity: 0.4;
  pointer-events: none;
}
```

### Depth Contours (Topographic)

```css
.depth-contours {
  background: #0A1628;
  background-image:
    radial-gradient(ellipse at center, transparent 20%, rgba(201,166,97,0.05) 40%, transparent 60%),
    radial-gradient(ellipse at center, transparent 40%, rgba(201,166,97,0.03) 60%, transparent 80%);
}
```

---

## Iconography

### Style Guidelines

**Visual Principles:**
- Line-based, engraved aesthetic
- 2px stroke weight for primary elements
- 1px stroke weight for details
- Navy (#0A1628) or Brass Gold (#C9A661) only
- No fills except for emphasis points
- 24x24px base grid
- Corner radius: 2px maximum

**Conceptual Approach:**
Icons should feel like **instruments of navigation and measurement**:
- Sextants, compasses, telescopes
- Chart elements (waypoints, routes, markers)
- Journey symbols (thresholds, paths, destinations)
- Measurement tools (scales, rulers, protractors)

### Core Icon Set

**Hero's Journey Stages:**

1. **Ordinary World** — Simple house outline with foundation lines
2. **Call to Adventure** — Horn or bell with radiating lines
3. **Refusal of Call** — Closed door with crossbar
4. **Meeting the Mentor** — Lantern or guiding star
5. **Crossing Threshold** — Gateway arch with passage beyond
6. **Tests & Allies** — Mountain path with waypoints
7. **Approach** — Ascending stairway or climbing path
8. **Ordeal** — Storm clouds with lightning (simplified)
9. **Reward** — Treasure chest or discovered artifact
10. **Road Back** — Winding path downward
11. **Resurrection** — Phoenix outline or rising sun
12. **Return with Elixir** — Container with essence/light

**Navigation Tools:**
- Compass (primary logo mark)
- Sextant
- Telescope
- Map with coordinates
- Anchor
- Ship's wheel
- Hourglass
- Quill and inkwell

**AI & Transformation:**
- Neural network (as constellation)
- Data flows (as trade winds)
- Algorithms (as mathematical instruments)
- Learning (as charted courses)

### Icon Construction Grid

```
24x24px canvas
2px padding on all sides
20x20px safe area
2px stroke weight
1px detail elements
No curve smoothing
45° and 90° angles preferred
Circular elements: 18px, 12px, 6px diameters
```

### SVG Template

```svg
<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <g stroke="#0A1628" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
    <!-- Icon elements here -->
  </g>
</svg>
```

### Usage Rules

- Minimum size: 16px (detail may be lost below this)
- Maximum size: 128px (consider illustration instead)
- Always maintain aspect ratio
- Pair with labels at small sizes
- Use consistent stroke color within context
- Allow breathing room (minimum 8px clearance)

---

## Layout Principles

### The Expedition Grid

Based on **chart and logbook layouts** from nautical navigation:

**Grid System: 12-column with journey zones**

```
┌─────────────────────────────────────────────┐
│  NAVIGATION HEADER                          │
├─────────────────────────────────────────────┤
│                                             │
│  [8 cols]              [4 cols]             │
│  PRIMARY CONTENT       COMPASS              │
│  The journey           Wayfinding           │
│  narrative             Context              │
│                        Insights             │
│                                             │
├─────────────────────────────────────────────┤
│  CHART FOOTER / LEGEND                      │
└─────────────────────────────────────────────┘
```

### Spacing System

**Base unit: 8px**

```
Space-1: 8px   — Tight elements
Space-2: 16px  — Related groups
Space-3: 24px  — Section padding
Space-4: 32px  — Component spacing
Space-5: 48px  — Section breaks
Space-6: 64px  — Major divisions
Space-7: 96px  — Hero spacing
Space-8: 128px — Extra large breaks
```

### The Navigator's Eye

**Visual weight hierarchy for page scanning:**

1. **The Compass** (Primary CTA / Key insight) — Brass gold, largest
2. **The Heading** (Where we're going) — Navy, bold, prominent
3. **The Chart** (The strategic view) — Visual elements, diagrams
4. **The Log** (The detailed narrative) — Body text
5. **The Annotations** (Supporting details) — Captions, metadata

### Card Styles

**Standard Expedition Card:**
```css
.expedition-card {
  background: #F4EFE6;
  border: 1px solid rgba(10, 22, 40, 0.1);
  border-radius: 4px;
  padding: 24px;
  box-shadow:
    0 1px 3px rgba(10, 22, 40, 0.1),
    0 1px 2px rgba(10, 22, 40, 0.06);
}

.expedition-card:hover {
  border-color: #C9A661;
  box-shadow:
    0 4px 6px rgba(10, 22, 40, 0.1),
    0 2px 4px rgba(10, 22, 40, 0.06);
  transform: translateY(-2px);
  transition: all 0.3s ease;
}
```

**Brass Instrument Card:**
```css
.brass-card {
  background: linear-gradient(135deg, #C9A661 0%, #A68B56 100%);
  color: #0A1628;
  border-radius: 4px;
  padding: 32px;
  position: relative;
  overflow: hidden;
}

.brass-card::before {
  /* Engraved texture from Texture Library */
}
```

**Deep Chart Card:**
```css
.chart-card {
  background: #0A1628;
  color: #F4EFE6;
  border: 1px solid rgba(201, 166, 97, 0.2);
  border-radius: 4px;
  padding: 24px;
}
```

### Section Dividers

**Horizon Line:**
```css
.horizon-divider {
  height: 1px;
  background: linear-gradient(
    90deg,
    transparent,
    rgba(201, 166, 97, 0.3) 20%,
    rgba(201, 166, 97, 0.3) 80%,
    transparent
  );
  margin: 48px 0;
}
```

**Ornamental Break:**
```html
<div class="section-break">
  <svg width="48" height="24" viewBox="0 0 48 24">
    <circle cx="24" cy="12" r="3" fill="#C9A661"/>
    <line x1="0" y1="12" x2="18" y2="12" stroke="#C9A661" stroke-width="1"/>
    <line x1="30" y1="12" x2="48" y2="12" stroke="#C9A661" stroke-width="1"/>
  </svg>
</div>
```

### Responsive Breakpoints

```css
/* Mobile: Condensed Log */
$mobile: 320px - 767px;

/* Tablet: Chart View */
$tablet: 768px - 1023px;

/* Desktop: Full Navigation */
$desktop: 1024px - 1439px;

/* Large: Expedition Display */
$large: 1440px+;
```

**Behavior:**
- Mobile: Single column, stacked navigation
- Tablet: 2-column hybrid, collapsible nav
- Desktop: Full grid, persistent sidebar
- Large: Wide content max-width 1200px, generous margins

---

## Brand Voice

### Tone Principles

**Stoic Pragmatism**
- Acknowledge difficulty without dramatizing it
- Clear-eyed about challenges
- Committed to the path forward
- Calm authority, not hype

**Evidence-Based Authority**
- Reference research, case studies, frameworks
- "According to..." not "We believe..."
- Data over opinions
- Cite Joseph Campbell, organizational theory, AI research

**Mythological Depth**
- Universal patterns, not corporate jargon
- Archetypal language (threshold, mentor, ordeal)
- Timeless narrative structures
- Connect technology to human story

**Navigational Clarity**
- Precise language
- Clear next steps
- Defined frameworks
- No buzzword fog

### Voice Characteristics

| Do | Don't |
|---|---|
| "Every transformation follows a pattern" | "Leverage synergies for disruption" |
| "The threshold moment when..." | "Cutting-edge paradigm shift" |
| "Research shows that 70% of AI implementations..." | "AI will revolutionize everything" |
| "Your organization stands at the call to adventure" | "You need to innovate or die" |
| "Let's chart your course" | "Let's ideate some solutions" |

### Vocabulary Framework

**Preferred Terms:**
- Journey, expedition, passage
- Navigate, chart, map
- Threshold, ordeal, return
- Pattern, archetype, cycle
- Guide, mentor, pathfinder
- Evidence, research, framework
- Transform (verb), transformation (outcome)

**Avoid:**
- Disrupt, leverage, synergy
- Game-changer, revolutionary
- Bleeding-edge, next-gen
- Ideate, solutionizing
- Low-hanging fruit
- Move the needle
- Circle back, touch base

### The Anti-Buzzword Filter

When writing about AI:

**Instead of:** "AI-powered solutions"
**Say:** "Machine learning systems that..."

**Instead of:** "Digital transformation"
**Say:** "Integrating AI into your operations"

**Instead of:** "Thought leader"
**Say:** "Practitioner" or "researcher"

**Instead of:** "Best practices"
**Say:** "Proven approaches" or "research-backed methods"

---

## Messaging Framework

### Core Message Architecture

**Primary Message:**
"Most AI transformations fail because organizations treat them as technology projects. They're actually hero's journeys—and every journey needs a guide."

**Supporting Messages:**

1. **The Pattern Recognition**
   "For thousands of years, humans have followed the hero's journey pattern through transformation. Your AI journey is no different."

2. **The Guide Role**
   "You don't need a vendor. You need a mentor who's walked this path and knows the terrain."

3. **The Evidence Base**
   "We combine Joseph Campbell's frameworks with organizational research and AI implementation data."

### Hero's Journey Applied to AI

**Stage-by-Stage Messaging:**

**1. Ordinary World**
"Your organization today—successful but sensing that AI will reshape your industry."

**2. Call to Adventure**
"The signal appears: competitors moving, customers expecting, technology enabling."

**3. Refusal of Call**
"Reasonable resistance: 'We're not a tech company,' 'It's too risky,' 'We don't have the talent.'"

**4. Meeting the Mentor**
"This is where we enter: experienced guides who understand both the mythological pattern and the technical reality."

**5. Crossing the Threshold**
"The commitment point: pilot project, budget allocation, team formation. No turning back."

**6. Tests, Allies, Enemies**
"Data quality issues, skeptical stakeholders, integration challenges. Building your fellowship."

**7. Approach to the Inmost Cave**
"The deep work: changing processes, retraining teams, confronting organizational identity."

**8. The Ordeal**
"The crisis point in every transformation: the moment of doubt, the setback, the fear."

**9. Reward (Seizing the Sword)**
"The breakthrough: the AI system works, the efficiency gain is real, the insight emerges."

**10. The Road Back**
"Scaling from pilot to production. Making the temporary permanent."

**11. Resurrection**
"The organization emerges transformed: new capabilities, new confidence, new culture."

**12. Return with the Elixir**
"Sustained value: measurable ROI, competitive advantage, organizational wisdom."

### Service Description Framework

**Discovery Expedition (Assessment)**
"A 4-week journey to map your organization's readiness, identify high-value opportunities, and chart your transformation path."

**What we do:**
- Current state assessment across 8 dimensions
- AI opportunity identification using proprietary framework
- Readiness gap analysis
- Detailed transformation roadmap

**Deliverable:**
Your organization's Expedition Chart: a detailed map showing where you are, where you're going, and the route to get there.

**Guided Transformation (Implementation Support)**
"Ongoing mentorship through the journey: from threshold crossing to return with the elixir."

**What we do:**
- Strategic guidance at each journey stage
- Mythological pattern recognition
- Obstacle navigation support
- Leadership coaching through transformation

**Deliverable:**
Monthly navigation sessions, crisis response, and continuous adjustment to your expedition plan.

### Case Study Storytelling Template

```markdown
## [Company Name]'s Journey: [Transformation Focus]

### The Ordinary World
[Where they started. What was working. What they sensed coming.]

### The Call
[The moment they knew they had to transform. Market signal, competitive threat, or internal opportunity.]

### Crossing the Threshold
[Their commitment point. What they invested. What they risked.]

### Tests and Ordeals
[The real challenges. What nearly derailed them. The crisis points.]

### The Guide's Role
[How Monomythic provided navigation. Specific frameworks, insights, interventions.]

### The Return
[Where they are now. Measurable outcomes. What they learned. What they gained beyond ROI.]

### The Elixir
[The lasting value: new capabilities, cultural change, competitive position.]

**By the Numbers:**
- [Metric 1]
- [Metric 2]
- [Metric 3]

**Journey Duration:** [Timeline]
**Organization Size:** [Scale]
**Industry:** [Sector]
```

---

## Application Examples

### Website Hero Section

**Desktop Layout (1440px):**

```
┌────────────────────────────────────────────────────────────┐
│                                                            │
│  [LOGO]                                       SERVICES  APPROACH  CONTACT │
│                                                            │
├────────────────────────────────────────────────────────────┤
│                                                            │
│                    [Compass Icon - Brass, 64px]           │
│                                                            │
│              Transform Your Organization                   │
│              Through the Hero's Journey                    │
│                                                            │
│   Most AI transformations fail because organizations       │
│   treat them as technology projects. They're actually      │
│   hero's journeys—and every journey needs a guide.         │
│                                                            │
│         [Chart Your Course →]                              │
│                                                            │
│                                                            │
└────────────────────────────────────────────────────────────┘
Background: Navy (#0A1628) with subtle depth contours
Text: Parchment (#F4EFE6)
Button: Brass gold with engraved effect
```

**CSS Specifications:**

```css
.hero-section {
  background: #0A1628;
  background-image: radial-gradient(
    ellipse at 50% 60%,
    rgba(92, 141, 137, 0.1) 0%,
    transparent 50%
  );
  min-height: 100vh;
  display: flex;
  flex-direction: column;
  justify-content: center;
  align-items: center;
  padding: 96px 24px;
  text-align: center;
}

.hero-icon {
  width: 64px;
  height: 64px;
  margin-bottom: 32px;
  stroke: #C9A661;
  animation: gentle-rotate 20s linear infinite;
}

@keyframes gentle-rotate {
  from { transform: rotate(0deg); }
  to { transform: rotate(360deg); }
}

.hero-title {
  font-family: 'Freight Text Pro', 'Libre Baskerville', serif;
  font-size: 64px;
  font-weight: 700;
  color: #F4EFE6;
  line-height: 1.1;
  margin-bottom: 24px;
  max-width: 800px;
}

.hero-subtitle {
  font-family: 'Freight Text Pro', 'Libre Baskerville', serif;
  font-size: 20px;
  color: rgba(244, 239, 230, 0.8);
  line-height: 1.6;
  margin-bottom: 48px;
  max-width: 600px;
}

.hero-cta {
  display: inline-flex;
  align-items: center;
  gap: 12px;
  padding: 16px 32px;
  background: linear-gradient(135deg, #C9A661 0%, #A68B56 100%);
  color: #0A1628;
  font-family: 'Source Sans 3', sans-serif;
  font-size: 16px;
  font-weight: 600;
  text-decoration: none;
  border-radius: 4px;
  border: none;
  cursor: pointer;
  transition: all 0.3s ease;
  position: relative;
  overflow: hidden;
}

.hero-cta::before {
  content: '';
  position: absolute;
  inset: 0;
  background-image:
    repeating-linear-gradient(
      45deg,
      transparent,
      transparent 2px,
      rgba(0,0,0,0.05) 2px,
      rgba(0,0,0,0.05) 4px
    );
}

.hero-cta:hover {
  transform: translateY(-2px);
  box-shadow: 0 8px 16px rgba(201, 166, 97, 0.3);
}
```

### Service Cards

**Three-Column Layout:**

```html
<div class="services-grid">
  <div class="service-card">
    <div class="service-icon">
      <!-- Sextant SVG -->
    </div>
    <h3>Discovery Expedition</h3>
    <p class="service-duration">4 weeks</p>
    <p>Map your organization's readiness and identify high-value AI opportunities.</p>
    <a href="#" class="service-link">Learn more →</a>
  </div>

  <div class="service-card">
    <div class="service-icon">
      <!-- Compass SVG -->
    </div>
    <h3>Guided Transformation</h3>
    <p class="service-duration">Ongoing</p>
    <p>Strategic mentorship through every stage of your AI journey.</p>
    <a href="#" class="service-link">Learn more →</a>
  </div>

  <div class="service-card">
    <div class="service-icon">
      <!-- Telescope SVG -->
    </div>
    <h3>Navigator Intensive</h3>
    <p class="service-duration">2 days</p>
    <p>Leadership workshop on guiding your organization through transformation.</p>
    <a href="#" class="service-link">Learn more →</a>
  </div>
</div>
```

```css
.services-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(320px, 1fr));
  gap: 32px;
  padding: 64px 24px;
  max-width: 1200px;
  margin: 0 auto;
}

.service-card {
  background: #F4EFE6;
  border: 1px solid rgba(10, 22, 40, 0.1);
  border-radius: 4px;
  padding: 32px;
  transition: all 0.3s ease;
}

.service-card:hover {
  border-color: #C9A661;
  transform: translateY(-4px);
  box-shadow: 0 8px 16px rgba(10, 22, 40, 0.1);
}

.service-icon {
  width: 48px;
  height: 48px;
  margin-bottom: 24px;
  stroke: #C9A661;
}

.service-card h3 {
  font-family: 'Freight Text Pro', serif;
  font-size: 26px;
  color: #0A1628;
  margin-bottom: 8px;
}

.service-duration {
  font-family: 'IBM Plex Mono', monospace;
  font-size: 13px;
  color: #6B5744;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  margin-bottom: 16px;
}

.service-card p {
  font-family: 'Freight Text Pro', serif;
  font-size: 16px;
  color: #4A5568;
  line-height: 1.6;
  margin-bottom: 24px;
}

.service-link {
  font-family: 'Source Sans 3', sans-serif;
  font-size: 16px;
  font-weight: 600;
  color: #C9A661;
  text-decoration: none;
  display: inline-flex;
  align-items: center;
  gap: 8px;
  transition: gap 0.3s ease;
}

.service-link:hover {
  gap: 12px;
}
```

### Consulting Deck Template

**Slide Master Layout:**

```
┌──────────────────────────────────────────────┐
│                                              │
│  [MONOMYTHIC LOGO]                    [##]  │
│                                              │
│                                              │
│          SLIDE TITLE                         │
│          In Freight Text Pro Bold            │
│                                              │
│   Content area with clear hierarchy          │
│   - Bullet points in Freight Text Book       │
│   - Data in IBM Plex Mono                    │
│   - Diagrams with brass accents              │
│                                              │
│                                              │
│  ─────────────────────────────────────────  │
│  SESSION NAME • CLIENT NAME • DATE           │
└──────────────────────────────────────────────┘

Dimensions: 16:9 (1920x1080 or 1280x720)
Background: Navy gradient
Text: Parchment
Accents: Brass gold
```

**Slide Types:**

**1. Title Slide**
```
Background: Deep navy with depth contours
Logo: Top left, white version
Title: Center, 64px Freight Text Bold
Subtitle: 20px Freight Text Book
Accent: Brass horizontal line above title
```

**2. Section Divider**
```
Background: Brass gradient with engraved texture
Icon: 128px, navy, centered above text
Section Name: 51px Freight Text Bold, navy, uppercase
No other content
```

**3. Content Slide (Standard)**
```
Title: 41px Freight Text Bold, left-aligned
Body: 20px Freight Text Book, left-aligned
Bullets: Brass gold circles
Accent bar: 4px brass gold, left edge
Max 5 bullets per slide
```

**4. Data Visualization**
```
Chart background: Transparent or parchment panel
Axis labels: IBM Plex Mono 13px
Data labels: IBM Plex Mono 16px
Primary data: Brass gold
Secondary data: Verdigris
Grid lines: Navy 20% opacity
```

**5. Hero's Journey Stage**
```
Large stage icon: 96px, brass gold, top center
Stage name: IBM Plex Mono 16px, uppercase, centered
Stage description: 26px Freight Text Medium, centered
Context text: 16px Freight Text Book
```

**6. Quote/Insight**
```
Large quote mark: 128px Freight Text, brass gold, 10% opacity
Quote text: 33px Freight Text Book Italic, centered
Attribution: IBM Plex Mono 13px, right-aligned
Background: Subtle spotlight effect
```

### Email Signature

```html
<table cellpadding="0" cellspacing="0" border="0" style="font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif; font-size: 14px; color: #0A1628;">
  <tr>
    <td style="padding-right: 20px; border-right: 2px solid #C9A661;">
      <img src="[compass-icon-url]" width="64" height="64" alt="Monomythic" />
    </td>
    <td style="padding-left: 20px;">
      <div style="font-weight: 600; font-size: 16px; margin-bottom: 4px;">[Your Name]</div>
      <div style="color: #6B5744; font-size: 13px; margin-bottom: 8px;">Guide | Monomythic</div>
      <div style="margin-bottom: 4px;">
        <a href="mailto:[email]" style="color: #C9A661; text-decoration: none;">[email]</a>
      </div>
      <div style="margin-bottom: 8px;">
        <a href="[website]" style="color: #C9A661; text-decoration: none;">monomythic.ai</a>
      </div>
      <div style="color: #6B5744; font-size: 12px; font-style: italic;">
        AI transformation through the hero's journey
      </div>
    </td>
  </tr>
</table>
```

### Social Media Templates

**LinkedIn Post Header:**
```
1200 x 627px
Background: Navy gradient
Compass icon: 120px, centered top
Headline: 41px Freight Text Bold, white, centered
Subhead: 20px Freight Text Book, parchment 80%, centered
Accent: Brass horizontal line
Logo: Bottom right corner
```

**Twitter/X Card:**
```
1200 x 675px
Background: Brass gradient with engraved texture
Icon: 80px, navy, top left
Quote or insight: 33px Freight Text Medium, navy
Attribution: IBM Plex Mono 13px
```

**Instagram Quote Card:**
```
1080 x 1080px (square)
Background: Navy with compass rose pattern
Quote: 41px Freight Text Book, parchment, centered
Large quotation marks in brass
Logo: Bottom center
```

---

## Implementation Guidelines

### Design Token Structure

**Recommended format: JSON or CSS Custom Properties**

```json
{
  "color": {
    "brand": {
      "navy": {
        "value": "#0A1628",
        "type": "color"
      },
      "brass": {
        "value": "#C9A661",
        "type": "color"
      }
    },
    "semantic": {
      "background": {
        "primary": "{color.brand.navy}",
        "secondary": "{color.neutral.parchment}",
        "elevated": "{color.neutral.storm}"
      },
      "text": {
        "primary": "{color.brand.navy}",
        "secondary": "{color.neutral.storm}",
        "inverse": "{color.neutral.parchment}"
      },
      "accent": {
        "primary": "{color.brand.brass}",
        "secondary": "{color.accent.verdigris}"
      }
    }
  },
  "typography": {
    "font-family": {
      "serif": "'Freight Text Pro', 'Libre Baskerville', serif",
      "mono": "'IBM Plex Mono', monospace",
      "sans": "'Source Sans 3', sans-serif"
    },
    "font-size": {
      "hero": "4rem",
      "h1": "3.2rem",
      "h2": "2.56rem",
      "h3": "2.05rem",
      "h4": "1.64rem",
      "body-large": "1.25rem",
      "body": "1rem",
      "body-small": "0.8rem",
      "caption": "0.64rem"
    },
    "line-height": {
      "display": 1.1,
      "heading": 1.2,
      "body": 1.6,
      "technical": 1.5
    }
  },
  "spacing": {
    "1": "8px",
    "2": "16px",
    "3": "24px",
    "4": "32px",
    "5": "48px",
    "6": "64px",
    "7": "96px",
    "8": "128px"
  },
  "border-radius": {
    "small": "2px",
    "medium": "4px",
    "large": "8px"
  }
}
```

### CSS Custom Properties

```css
:root {
  /* Colors - Brand */
  --color-navy: #0A1628;
  --color-brass: #C9A661;
  --color-brass-dark: #A68B56;

  /* Colors - Neutral */
  --color-storm: #4A5568;
  --color-parchment: #F4EFE6;
  --color-sepia: #6B5744;

  /* Colors - Accent */
  --color-verdigris: #5C8D89;
  --color-coral: #C84B31;

  /* Typography */
  --font-serif: 'Freight Text Pro', 'Libre Baskerville', serif;
  --font-mono: 'IBM Plex Mono', monospace;
  --font-sans: 'Source Sans 3', sans-serif;

  --font-size-hero: 4rem;
  --font-size-h1: 3.2rem;
  --font-size-h2: 2.56rem;
  --font-size-h3: 2.05rem;
  --font-size-h4: 1.64rem;
  --font-size-body-lg: 1.25rem;
  --font-size-body: 1rem;
  --font-size-body-sm: 0.8rem;
  --font-size-caption: 0.64rem;

  /* Spacing */
  --space-1: 8px;
  --space-2: 16px;
  --space-3: 24px;
  --space-4: 32px;
  --space-5: 48px;
  --space-6: 64px;
  --space-7: 96px;
  --space-8: 128px;

  /* Effects */
  --shadow-sm: 0 1px 3px rgba(10, 22, 40, 0.1), 0 1px 2px rgba(10, 22, 40, 0.06);
  --shadow-md: 0 4px 6px rgba(10, 22, 40, 0.1), 0 2px 4px rgba(10, 22, 40, 0.06);
  --shadow-lg: 0 10px 15px rgba(10, 22, 40, 0.1), 0 4px 6px rgba(10, 22, 40, 0.05);

  /* Transitions */
  --transition-fast: 0.15s ease;
  --transition-base: 0.3s ease;
  --transition-slow: 0.5s ease;
}
```

### Figma Component Structure

**Recommended organization:**

```
📁 Monomythic Design System
├── 📄 Cover & Introduction
├── 🎨 Foundation
│   ├── Colors (with color styles)
│   ├── Typography (with text styles)
│   ├── Spacing Grid
│   └── Effects & Shadows
├── 🧩 Components
│   ├── Buttons
│   │   ├── Primary (Brass)
│   │   ├── Secondary (Navy Outline)
│   │   └── Ghost (Text only)
│   ├── Cards
│   │   ├── Expedition Card
│   │   ├── Brass Instrument
│   │   └── Deep Chart
│   ├── Navigation
│   │   ├── Header
│   │   ├── Footer
│   │   └── Mobile Menu
│   ├── Forms
│   │   ├── Input Fields
│   │   ├── Textareas
│   │   └── Select Dropdowns
│   └── Icons (components with variants)
├── 📐 Patterns
│   ├── Hero Sections
│   ├── Service Grids
│   ├── Journey Diagrams
│   └── Testimonials
└── 📱 Templates
    ├── Landing Page
    ├── Service Page
    ├── Case Study
    └── Contact
```

**Component Properties:**

**Button Component:**
```
Variants:
- Type: Primary, Secondary, Ghost
- Size: Small (40px), Medium (48px), Large (56px)
- State: Default, Hover, Active, Disabled

Auto-layout: Horizontal, 12px gap
Padding: 16px 32px (Medium)
Border radius: 4px
```

**Card Component:**
```
Variants:
- Style: Expedition, Brass, Chart
- Size: Small (280px), Medium (360px), Large (480px)

Auto-layout: Vertical, 24px gap
Padding: 32px
Border radius: 4px
```

### Font Loading

**Web Font Loading Strategy:**

```html
<!-- In <head> -->
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>

<!-- Libre Baskerville (free alternative) -->
<link href="https://fonts.googleapis.com/css2?family=Libre+Baskerville:wght@400;700&display=swap" rel="stylesheet">

<!-- IBM Plex Mono -->
<link href="https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;500;600&display=swap" rel="stylesheet">

<!-- Source Sans 3 -->
<link href="https://fonts.googleapis.com/css2?family=Source+Sans+3:wght@400;600&display=swap" rel="stylesheet">
```

**Font Face (Self-hosted):**

```css
@font-face {
  font-family: 'Freight Text Pro';
  src: url('/fonts/FreightTextPro-Book.woff2') format('woff2'),
       url('/fonts/FreightTextPro-Book.woff') format('woff');
  font-weight: 400;
  font-style: normal;
  font-display: swap;
}

@font-face {
  font-family: 'Freight Text Pro';
  src: url('/fonts/FreightTextPro-Bold.woff2') format('woff2'),
       url('/fonts/FreightTextPro-Bold.woff') format('woff');
  font-weight: 700;
  font-style: normal;
  font-display: swap;
}
```

### Performance Optimization

**Image Assets:**
- Logo: SVG format, optimized paths
- Icons: SVG sprite sheet
- Textures: PNG with transparency, max 2MB
- Photos: WebP with JPEG fallback
- Patterns: CSS-generated when possible

**Responsive Images:**
```html
<picture>
  <source
    srcset="hero-1920.webp 1920w, hero-1280.webp 1280w, hero-640.webp 640w"
    type="image/webp"
  />
  <img
    src="hero-1280.jpg"
    srcset="hero-1920.jpg 1920w, hero-1280.jpg 1280w, hero-640.jpg 640w"
    sizes="100vw"
    alt="Monomythic - AI Transformation"
  />
</picture>
```

---

## Asset Checklist

### Required Visual Assets

**Logos:**
- [ ] Primary logo (full compass + wordmark) - SVG
- [ ] Logo mark only (compass) - SVG
- [ ] Wordmark only - SVG
- [ ] White version for dark backgrounds
- [ ] Navy version for light backgrounds
- [ ] Brass gold version for special uses
- [ ] Monochrome version
- [ ] Favicon (32x32, 16x16, ICO format)
- [ ] Apple touch icon (180x180)

**Icons:**
- [ ] Complete Hero's Journey stage icons (12 total) - SVG
- [ ] Navigation tool icons (8 total) - SVG
- [ ] AI transformation icons (8 total) - SVG
- [ ] UI icons (arrows, close, menu, etc.) - SVG
- [ ] Social media icons - SVG

**Patterns & Textures:**
- [ ] Engraved brass texture - PNG with alpha
- [ ] Cartographic cross-hatch - SVG pattern
- [ ] Survey grid - SVG pattern
- [ ] Compass rose repeating pattern - SVG
- [ ] Parchment texture overlay - PNG with alpha
- [ ] Depth contour gradients - CSS or SVG

**Brand Photography Style:**
- [ ] Style guide for commissioned photography
- [ ] Image treatment specifications (duotone process)
- [ ] Sample treated images

**Illustration Style:**
- [ ] Hero's Journey diagram template
- [ ] Transformation framework diagrams
- [ ] Process flow templates

### Document Templates

**Internal:**
- [ ] Consulting deck master (PowerPoint + Keynote)
- [ ] Proposal template
- [ ] Case study template
- [ ] Workshop materials template
- [ ] Email signature HTML

**External:**
- [ ] Website design files (Figma)
- [ ] Social media templates (Instagram, LinkedIn, Twitter)
- [ ] Business cards (print-ready PDF)
- [ ] Letterhead (digital + print)

### Code & Implementation:**
- [ ] CSS stylesheet with all variables
- [ ] Design tokens JSON
- [ ] Component library starter (React/Vue/HTML)
- [ ] SVG sprite sheet
- [ ] Icon font (optional alternative)

### Brand Guidelines:**
- [x] This brand book (PDF export)
- [ ] Quick reference card (1-page)
- [ ] Logo usage guidelines (separate document)
- [ ] Partner co-branding guidelines

---

## Quick Reference Card

### At a Glance

**Colors:**
- Navy #0A1628 + Brass Gold #C9A661 = Primary duotone
- Parchment #F4EFE6 for light backgrounds
- Storm Grey #4A5568 for secondary text

**Fonts:**
- Headlines: Freight Text Pro Bold (or Libre Baskerville)
- Body: Freight Text Pro Book
- Technical: IBM Plex Mono
- UI: Source Sans 3

**Voice:**
- Stoic, evidence-based, mythologically grounded
- "Journey" not "project"
- "Guide" not "vendor"
- No buzzwords

**Aesthetic:**
- Romantic expedition (18th-19th century exploration)
- Engraved brass instruments
- Hand-drawn cartography
- Naval precision

**Core Message:**
"AI transformations are hero's journeys. Every journey needs a guide."

---

## Appendix: Resources

### Inspiration References

**Historical:**
- British Admiralty charts, 1795-1850
- Brass navigation instruments from maritime museums
- Captain's logs and ship journals
- Geographic survey maps from exploration era

**Contemporary:**
- Moleskin notebook aesthetic
- Modern cartography with vintage influence
- National Geographic expedition photography
- Precision instrument design (Leica, Hasselblad)

### Font Acquisition

**Freight Text Pro:**
- Purchase: MyFonts, Adobe Fonts, or directly from GarageFonts
- Cost: ~$45 per weight
- Weights needed: Book, Medium, Bold

**Free Alternatives:**
- Libre Baskerville (Google Fonts) - Very similar classical proportions
- Crimson Pro (Google Fonts) - Alternative with more weights
- Source Serif Pro (Adobe Fonts) - More modern but free

**IBM Plex Mono:**
- Free and open source
- Download: IBM Plex GitHub or Google Fonts

**Source Sans 3:**
- Free and open source
- Download: Adobe Fonts or Google Fonts

### Color Psychology Context

**Navy (#0A1628):**
Associated with: Depth, trust, stability, intelligence, authority, the unknown
Avoids: Corporate blue clichés by going deeper, almost black

**Brass Gold (#C9A661):**
Associated with: Guidance, illumination, value, tradition, craftsmanship
Avoids: Luxury gold clichés by being muted, aged, instrumental

**Together:**
Evokes precision instruments that guide through darkness—exactly the right metaphor for AI transformation consulting.

### Technical Implementation Notes

**Browser Support:**
- CSS Custom Properties: IE11+ (use PostCSS for fallbacks)
- CSS Grid: All modern browsers
- SVG: Universal support
- WebP images: 96%+ (provide JPEG fallbacks)

**Accessibility:**
- All color combinations tested for WCAG AA minimum
- Navy + Brass: Use white text, not brass, for body copy
- Focus states: 2px brass outline with 2px offset
- Icon alt text required for all non-decorative icons

**Performance Targets:**
- First Contentful Paint: <1.8s
- Largest Contentful Paint: <2.5s
- Cumulative Layout Shift: <0.1
- Font loading: Use font-display: swap

---

## Version History

**Version 1.0** — November 2025
- Initial brand identity system
- Complete visual specifications
- Voice and messaging framework
- Implementation guidelines
- Application examples

---

## Contact & Feedback

This is a living document. As Monomythic evolves, so will this brand system.

**For questions about brand usage:**
[Your contact information]

**For technical implementation support:**
[Technical contact or link to resources]

**For requesting new assets or templates:**
[Asset request process]

---

*"The cave you fear to enter holds the treasure you seek."*
— Joseph Campbell

Your brand identity is your compass. Use it well.
