# Conversation Flow Examples

Real-world scenarios showing how the conversational recommendation system would work in practice.

---

## Scenario 1: The Undecided Reader

**Context**: User opens ForYouSheet, has diverse library (Tolkien, McCarthy, Weir, Rowling)

```
╭─────────────────────────────╮
│ 💭 System                   │
│                             │
│ What are you in the         │
│ mood for today?             │
╰─────────────────────────────╯

    ╭─────────────────────────╮
    │ 🗣️ You                  │
    │                         │
    │ Not sure, something     │
    │ good                    │
    ╰─────────────────────────╯

╭─────────────────────────────╮
│ 💭 System                   │
│                             │
│ I can work with that! Your  │
│ library shows you love epic │
│ fantasy like Tolkien, but   │
│ also lighter reads like     │
│ Weir.                       │
│                             │
│ Want something that blends  │
│ both? Or lean one way?      │
╰─────────────────────────────╯

Quick replies appear:
┌─────────────────────────────┐
│  Epic & immersive          │
└─────────────────────────────┘
┌─────────────────────────────┐
│  Light & fun               │
└─────────────────────────────┘
┌─────────────────────────────┐
│  Surprise me               │
└─────────────────────────────┘

    ╭─────────────────────────╮
    │ 🗣️ You                  │
    │                         │
    │ Light & fun             │
    ╰─────────────────────────╯

╭─────────────────────────────╮
│ 💭 System                   │
│                             │
│ Perfect! After loving       │
│ Project Hail Mary, here are │
│ 3 books I think you'd love: │
╰─────────────────────────────╯

╔═══════════════════════════════╗
║ [Cover] The Martian          ║
║ Andy Weir                    ║
║                               ║
║ Weir's first novel—same wit, ║
║ more grounded, and absolutely ║
║ page-turning.                 ║
║                               ║
║ [Add] [Pass]                  ║
╚═══════════════════════════════╝

╔═══════════════════════════════╗
║ [Cover] Recursion             ║
║ Blake Crouch                  ║
║                               ║
║ Mind-bending sci-fi with that ║
║ same "one more chapter" feel  ║
║                               ║
║ [Add] [Pass]                  ║
╚═══════════════════════════════╝

╔═══════════════════════════════╗
║ [Cover] The Kaiju             ║
║ Preservation Society          ║
║ John Scalzi                   ║
║                               ║
║ Funny sci-fi with heart, just ║
║ like Weir but more sarcastic  ║
║                               ║
║ [Add] [Pass]                  ║
╚═══════════════════════════════╝
```

---

## Scenario 2: The Mood-Driven Reader

**Context**: Evening, user just finished an intense book (Blood Meridian)

```
╭─────────────────────────────╮
│ 💭 System                   │
│                             │
│ I see you just finished     │
│ Blood Meridian. That's a    │
│ heavy one.                  │
│                             │
│ Need something lighter, or  │
│ want to stay in that        │
│ intensity?                  │
╰─────────────────────────────╯

    ╭─────────────────────────╮
    │ 🗣️ You                  │
    │                         │
    │ Definitely lighter      │
    ╰─────────────────────────╯

╭─────────────────────────────╮
│ 💭 System                   │
│                             │
│ Smart choice for evening    │
│ reading. How about          │
│ something cozy?             │
╰─────────────────────────────╯

[Book Card: "The House in the Cerulean Sea"]
"After McCarthy's darkness, this is
like a warm hug. Cozy fantasy with
heart, humor, and hope. Perfect
evening read."

[Add to Library] [Pass]

    ╭─────────────────────────╮
    │ 🗣️ You                  │
    │                         │
    │ [Taps "Pass"]           │
    ╰─────────────────────────╯

╭─────────────────────────────╮
│ 💭 System                   │
│                             │
│ Too whimsical? Want         │
│ something with more bite?   │
╰─────────────────────────────╯

    ╭─────────────────────────╮
    │ 🗣️ You                  │
    │                         │
    │ Yeah, something with    │
    │ more substance          │
    ╰─────────────────────────╯

╭─────────────────────────────╮
│ 💭 System                   │
│                             │
│ Got it. How about this:     │
╰─────────────────────────────╯

[Book Card: "Station Eleven" by Emily St. John Mandel]
"Post-apocalyptic but hopeful. Literary
like McCarthy, but gentler. Beautiful
prose about art and humanity surviving."

[Add to Library] [Pass]

    ╭─────────────────────────╮
    │ 🗣️ You                  │
    │                         │
    │ [Taps "Add to Library"] │
    ╰─────────────────────────╯

╭─────────────────────────────╮
│ 💭 System                   │
│                             │
│ Great choice! I think       │
│ you'll really connect with  │
│ this one.                   │
│                             │
│ Want another                │
│ recommendation, or all set? │
╰─────────────────────────────╯

┌─────────────────────────────┐
│  One more                  │
└─────────────────────────────┘
┌─────────────────────────────┐
│  I'm good, thanks          │
└─────────────────────────────┘
```

---

## Scenario 3: The Specific Request

**Context**: User has a clear idea of what they want

```
╭─────────────────────────────╮
│ 💭 System                   │
│                             │
│ What are you in the         │
│ mood for today?             │
╰─────────────────────────────╯

    ╭─────────────────────────╮
    │ 🗣️ You                  │
    │                         │
    │ I want a good biography │
    ╰─────────────────────────╯

╭─────────────────────────────╮
│ 💭 System                   │
│                             │
│ Nice! I notice you haven't  │
│ read many biographies yet.  │
│                             │
│ What kind of person         │
│ interests you? Artist,      │
│ leader, scientist?          │
╰─────────────────────────────╯

    ╭─────────────────────────╮
    │ 🗣️ You                  │
    │                         │
    │ Someone interesting,    │
    │ maybe an artist         │
    ╰─────────────────────────╯

╭─────────────────────────────╮
│ 💭 System                   │
│                             │
│ Based on your love of       │
│ Tolkien and epic            │
│ storytelling, I have        │
│ someone perfect:            │
╰─────────────────────────────╯

[Book Card: "Leonardo da Vinci" by Walter Isaacson]
"Given your appreciation for creative
minds, you'll love Isaacson's portrait
of the ultimate Renaissance man.
Reads like a novel."

[Add to Library] [Pass]
```

---

## Scenario 4: The Holiday Reader

**Context**: Mid-December, user opens ForYouSheet

```
╭─────────────────────────────╮
│ 💭 System                   │
│                             │
│ Holidays are coming up!     │
│                             │
│ Looking for something       │
│ festive, or just a great    │
│ winter read?                │
╰─────────────────────────────╯

Quick replies:
┌─────────────────────────────┐
│  Something festive         │
└─────────────────────────────┘
┌─────────────────────────────┐
│  Just a good book          │
└─────────────────────────────┘
┌─────────────────────────────┐
│  Gift ideas                │
└─────────────────────────────┘

    ╭─────────────────────────╮
    │ 🗣️ You                  │
    │                         │
    │ Gift ideas              │
    ╰─────────────────────────╯

╭─────────────────────────────╮
│ 💭 System                   │
│                             │
│ Smart! Who are you          │
│ shopping for?               │
│                             │
│ Friend, parent, partner,    │
│ or someone else?            │
╰─────────────────────────────╯

    ╭─────────────────────────╮
    │ 🗣️ You                  │
    │                         │
    │ A friend who loves      │
    │ fantasy                 │
    ╰─────────────────────────╯

╭─────────────────────────────╮
│ 💭 System                   │
│                             │
│ Perfect! Since you know     │
│ great fantasy (Tolkien,     │
│ Jordan), here's what I'd    │
│ gift:                       │
╰─────────────────────────────╯

[Book Card: "Piranesi" by Susanna Clarke]
"Beautifully strange fantasy that
feels like a gift itself. Gorgeous
prose, mysterious world, deeply
moving. Fantasy readers love this."

[Add to Library] [Pass]
```

---

## Scenario 5: The Picky Reader

**Context**: User passes on multiple recommendations

```
╭─────────────────────────────╮
│ 💭 System                   │
│                             │
│ What are you in the         │
│ mood for today?             │
╰─────────────────────────────╯

    ╭─────────────────────────╮
    │ 🗣️ You                  │
    │                         │
    │ Something surprising    │
    ╰─────────────────────────╯

╭─────────────────────────────╮
│ 💭 System                   │
│                             │
│ I like where your head's    │
│ at. Let me try this:        │
╰─────────────────────────────╯

[Book Card: "The Night Circus"]
[User taps "Pass"]

╭─────────────────────────────╮
│ 💭 System                   │
│                             │
│ Not quite right? How about  │
│ something weirder:          │
╰─────────────────────────────╯

[Book Card: "Piranesi"]
[User taps "Pass"]

╭─────────────────────────────╮
│ 💭 System                   │
│                             │
│ Okay, I'm sensing you want  │
│ something really different  │
│ from your usual. Am I going │
│ too literary? Too fantasy?  │
│                             │
│ Help me understand what     │
│ "surprising" means to you.  │
╰─────────────────────────────╯

    ╭─────────────────────────╮
    │ 🗣️ You                  │
    │                         │
    │ I want something        │
    │ completely different    │
    │ from what I normally    │
    │ read. Maybe non-fiction?│
    ╰─────────────────────────╯

╭─────────────────────────────╮
│ 💭 System                   │
│                             │
│ Ah! That IS surprising for  │
│ you—you've read mostly      │
│ fiction. Let me find        │
│ something that'll blow      │
│ your mind:                  │
╰─────────────────────────────╯

[Book Card: "Sapiens" by Yuval Noah Harari]
"Given your love of epic stories
(Tolkien, Jordan), this tells the
grandest epic of all: humanity's
story. Reads like fiction, but real."

[Add to Library] [Pass]

    ╭─────────────────────────╮
    │ 🗣️ You                  │
    │                         │
    │ [Taps "Add to Library"] │
    ╰─────────────────────────╯

╭─────────────────────────────╮
│ 💭 System                   │
│                             │
│ Yes! I had a feeling that   │
│ would click. Sometimes      │
│ stepping outside our usual  │
│ taste leads to the best     │
│ discoveries.                │
╰─────────────────────────────╯
```

---

## Scenario 6: Ambient Mode Integration

**Context**: User opens Ambient Mode with no book selected

```
[Ambient Mode - Generic State]

╭─────────────────────────────╮
│ Ready to talk about your    │
│ reading, answer questions,  │
│ or help you discover        │
│ something new.              │
╰─────────────────────────────╯

[User taps microphone and says:]
"What should I read next?"

╭─────────────────────────────╮
│ 💭 Detecting...             │
│ Question about              │
│ recommendations             │
╰─────────────────────────────╯

[System transitions to recommendation mode]

╭─────────────────────────────╮
│ Let's find you something    │
│ great! What kind of mood    │
│ are you in?                 │
╰─────────────────────────────╯

[User says:]
"I want something intense and gripping"

╭─────────────────────────────╮
│ Intense and gripping—I see  │
│ you loved Blood Meridian.   │
│ Want something with that    │
│ same raw power?             │
╰─────────────────────────────╯

[User says:]
"Yes exactly"

╭─────────────────────────────╮
│ Perfect. This should hit    │
│ you hard:                   │
╰─────────────────────────────╯

[Book Card appears in ambient mode]
"No Country for Old Men" by Cormac McCarthy

[User can continue conversation via voice or switch to text]
```

---

## Scenario 7: Series Continuation

**Context**: User finished "The Fellowship of the Ring" (but hasn't read The Two Towers yet)

```
╭─────────────────────────────╮
│ 💭 System                   │
│                             │
│ I see you just finished     │
│ Fellowship of the Ring!     │
│                             │
│ Ready for The Two Towers,   │
│ or want a break from        │
│ Middle-earth?               │
╰─────────────────────────────╯

    ╭─────────────────────────╮
    │ 🗣️ You                  │
    │                         │
    │ I want a break first    │
    ╰─────────────────────────╯

╭─────────────────────────────╮
│ 💭 System                   │
│                             │
│ Smart move—sometimes you    │
│ need to breathe before      │
│ diving back into epic       │
│ fantasy.                    │
│                             │
│ Want something short and    │
│ different to cleanse your   │
│ palate?                     │
╰─────────────────────────────╯

    ╭─────────────────────────╮
    │ 🗣️ You                  │
    │                         │
    │ Yeah, something         │
    │ completely different    │
    ╰─────────────────────────╯

╭─────────────────────────────╮
│ 💭 System                   │
│                             │
│ Here's a quick, brilliant   │
│ read that's nothing like    │
│ Tolkien:                    │
╰─────────────────────────────╯

[Book Card: "The Ocean at the End of the Lane" by Neil Gaiman]
"Short, modern, and magical in a
completely different way. Quick read
(~180 pages), then you can return to
Middle-earth refreshed."

[Add to Library] [Pass]
```

---

## Scenario 8: The Overwhelmed Reader

**Context**: User has 50+ books in "Want to Read" status

```
╭─────────────────────────────╮
│ 💭 System                   │
│                             │
│ I notice you have 50+ books │
│ in your "Want to Read" list.│
│                             │
│ Want help picking which one │
│ to start with?              │
╰─────────────────────────────╯

    ╭─────────────────────────╮
    │ 🗣️ You                  │
    │                         │
    │ Yes! I can't decide     │
    ╰─────────────────────────╯

╭─────────────────────────────╮
│ 💭 System                   │
│                             │
│ Let me look at your list... │
│                             │
│ Based on what you've been   │
│ loving lately, I'd start    │
│ with this one:              │
╰─────────────────────────────╯

[Book Card: One of their existing "Want to Read" books]
"This matches your current mood
perfectly. You added it 3 months ago
after reading Project Hail Mary—
now's the time!"

[Move to Currently Reading] [Keep in Want to Read]
```

---

## Key Patterns Observed

### 1. Progressive Questioning
- Start broad ("What are you in the mood for?")
- Narrow based on response
- Ask clarifying questions when needed

### 2. Context Awareness
- Recent reading activity
- Time of day/year
- Library composition
- Reading patterns

### 3. Personality Traits
- Confident but not pushy
- Knowledgeable without pretension
- Personal ("you loved X")
- Empathetic ("That's a heavy one")

### 4. Refinement Loop
- Accept feedback gracefully
- Adjust based on passes
- Ask clarifying questions
- Don't repeat rejected suggestions

### 5. Natural Language
- No robotic responses
- Conversational tone
- Acknowledges user state
- Uses natural transitions

---

## Conversation Length Guidelines

### Ideal Flow
- **Opening**: 1 message (system question)
- **Clarification**: 1-2 turns (if needed)
- **Presentation**: 1 recommendation
- **Refinement**: 0-3 turns (based on user feedback)
- **Total**: 3-7 turns maximum before reset

### When to Reset
- After 10+ turns (conversation getting too long)
- After 5+ rejected recommendations (not hitting the mark)
- User explicitly requests fresh start
- User switches to different mood/genre entirely

### Conversation Timeouts
- **5 minutes idle**: Gentle prompt ("Still looking?")
- **10 minutes idle**: Save state, dismiss sheet
- **24 hours later**: Fresh conversation (don't remember previous)

