# Book Recommendation Chat - Comprehensive Design Document

## Executive Summary

A conversational book discovery interface that leverages Epilogue's existing chat infrastructure, recommendation engine, and voice capabilities to create a natural, personalized book discovery experience.

**Core Insight**: Users have rich reading data (library, highlights, notes, ambient sessions) that can power deeply personalized recommendations through natural conversation.

---

## 1. CONVERSATION DESIGN

### 1.1 First Message (System Greeting)

The greeting adapts based on user's library state:

**New User (Empty Library)**
```
👋 Hi! I'm here to help you discover your next great read.

I can recommend books based on:
• What you're in the mood for  
• Authors or books you've loved
• Themes or topics you're curious about
• Even just a vibe or feeling

What kind of book are you looking for?
```

**Returning User (Has Library)**
```
📚 Ready to find your next book?

I've noticed you enjoy [genre/pattern from library].
I can suggest something similar, or help you explore
something completely different.

What sounds good right now?
```

**User with Recent Reading Activity**
```
✨ Back for more!

I see you just finished [Recent Book]. That was a [tone]  
read about [theme]. Want something in a similar vein,
or ready for a change of pace?
```

### 1.2 Conversation Flow Strategy

#### Progressive Disclosure Pattern
```
User's First Message
    ↓
┌─────────────────────────────────┐
│ Is intent clear enough?         │
│ - Specific book/author mentioned│
│ - Clear genre/theme/mood        │
│ - "Something like X"            │
└─────────────────────────────────┘
         ↓ YES                ↓ NO
    RECOMMEND           ASK CLARIFYING QUESTION
                             ↓
                        Get 1-2 details
                             ↓
                        RECOMMEND
```

#### Clarifying Question Strategy

**Ask ONE question at a time, not a questionnaire:**

❌ Bad (Interview-style):
```
"What genre do you prefer? Fiction or non-fiction?
What's your favorite author? What themes interest you?"
```

✅ Good (Conversational):
```
"Are you thinking fiction or non-fiction?"

[User: "Fiction"]

"Nice! What kind of mood - something gripping and  
fast-paced, or more literary and contemplative?"
```

#### Question Types by Vagueness Level

| User Request | Response Strategy |
|--------------|-------------------|
| "Something good" | Ask: Fiction vs. Non-fiction, then mood |
| "A mystery" | Recommend 3-4 immediately, mention variety (cozy vs. noir vs. psychological) |
| "Like Agatha Christie" | Recommend immediately, no questions |
| "I'm bored" | Ask: Escape from reality, or learn something new? |
| "Surprise me" | Use library analysis, recommend unexpected pick with strong reasoning |

### 1.3 Handling Vague Requests

**Philosophy**: Two-question maximum before recommending. Users want suggestions, not interviews.

**Example Flow:**
```
User: "I need something good to read"
