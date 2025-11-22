## 2. RECOMMENDATION INTELLIGENCE

### 2.1 Signals for Recommendations (Priority Order)

#### Tier 1: Explicit User Input (Highest Priority)
1. **Books/Authors Mentioned in Chat**
   - "I loved [Book]" → Find similar books
   - "I like [Author]" → Recommend their other works + similar authors
   
2. **Stated Preferences**
   - Genre, mood, themes mentioned in conversation
   - Length preferences ("short", "epic")
   - Pace preferences ("fast-paced", "contemplative")

#### Tier 2: Library Analysis (Strong Signal)
3. **Books in Library**
   - Analyze genres, authors, publication eras
   - Identify patterns user may not realize
   - Use `LibraryTasteAnalyzer.swift` (already exists)

4. **Reading Progress**
   - Completed books (finished → enjoyed)
   - Abandoned books (low progress → didn't resonate)
   - Currently reading (active interests)

5. **User Ratings**
   - Books rated 4-5 stars → find similar
   - Books rated 1-2 stars → avoid similar

#### Tier 3: Engagement Data (Medium Signal)
6. **Highlights & Quotes**
   - Analyze themes in highlighted passages
   - Books with many highlights → strong engagement
   - Quote content reveals interests
   
   Example: User highlights philosophical passages → recommend thoughtful fiction

7. **Notes Content**
   - Topics user reflects on
   - Questions they ask
   - Connections they make

8. **Ambient Session Activity**
   - Books discussed in detail → strong interest in that style
   - Topics questioned → curiosity signals
   - Time spent per book

#### Tier 4: Contextual Signals (Lower Priority)
9. **Time/Season**
   - Summer → lighter reads, beach reads
   - Winter → cozy mysteries, long epics
   - Weekend → shorter books
   
10. **Recent Recommendations Rejected**
    - Learn from "not interested" patterns
    - Avoid similar suggestions

### 2.2 Recommendation Reasoning Framework

**Every recommendation must include WHY it's suggested.**

#### Reasoning Templates:

**Library-Based:**
```
"Since you enjoyed [Book from Library], which explores [theme],
you might love [Recommendation]. It shares [similarity] but
approaches it through [different angle]."
```

**Mood-Based:**
```
"For that [mood] vibe you're after, [Recommendation] is perfect.
It's [description] with [appeal factor]."
```

**Contrast-Based:**
```
"You mentioned wanting something different from [recent read].
[Recommendation] is a complete departure - it's [how it's different]
while still being [quality they care about]."
```

**Pattern-Discovery:**
```
"I noticed you gravitate toward [pattern user might not realize].
[Recommendation] fits that perfectly with [specific example]."
```

**Exploratory:**
```
"You said surprise you. Based on [signal], I think you'll enjoy  
stepping into [new territory]. [Recommendation] is [description]."
```

### 2.3 Recommendation Variety Strategy

**Never recommend just one book.** Provide 3-4 options with variety:

**Variety Dimensions:**
1. **Familiarity Spectrum**: Safe pick → Slight stretch → Bold departure
2. **Recency**: Classic → Modern → Brand new release
3. **Length**: Quick read → Standard → Epic
4. **Tone**: Light → Balanced → Heavy/Dense

**Example Set:**
```
Based on your love of thoughtful fiction:

1. **The Remains of the Day** by Kazuo Ishiguro
   [Safe Pick] A masterclass in subtle emotion, like the quiet
   introspection in books you've highlighted.

2. **Tomorrow, and Tomorrow, and Tomorrow** by Gabrielle Zevin  
   [Slight Stretch] Contemporary, but deeply philosophical about
   creativity and friendship.

3. **Piranesi** by Susanna Clarke
   [Bold Departure] Experimental and weird, but beautiful prose
   that rewards slow reading.

Which direction appeals to you?
```

### 2.4 Handling "I've Already Read That"

**Strategy: Use as Learning Opportunity**

```
Great taste! Since you've read [Book]:

1. What did you think of it?
   [Gather sentiment to refine future recommendations]

2. [If positive] Then you'll probably enjoy [Similar Book]
   [If negative] Let me try a different angle - [Different Book]
```

**Implementation:**
- Store "already read" in conversation memory
- Check against library before recommending
- But still OK to suggest if it fits perfectly (they might want reminder)

### 2.5 Balancing Familiar vs. Discovery

**User Preference Detection:**

| User Signal | Interpretation | Strategy |
|-------------|----------------|----------|
| "Like [Specific Book]" | Wants familiarity | Recommend close matches (80% similar) |
| "Something different" | Wants discovery | Recommend departures (40% similar) |
| "Surprise me" | Trusts your judgment | Use taste profile for unexpected pick |
| "My favorite genre is X" | Sticking to comfort zone | 2 in-genre + 1 adjacent genre |

**Default Mix (if no preference stated):**
- 2 familiar (comfortable choices)
- 1 slight stretch (same genre, different style)
- 1 discovery (different genre, shared appeal)

### 2.6 The "Why" Explanation Philosophy

**Bad Explanation (Generic):**
❌ "This is a great mystery novel with good reviews."

**Good Explanation (Personalized):**
✅ "You highlighted passages about memory and identity in [Book You Read].
This explores similar questions through a murder mystery framework."

**Great Explanation (Insight + Personalization):**
✅ "I noticed 80% of books in your library feature unreliable narrators.
This takes that device to wild extremes while being genuinely funny."

**Components of Good "Why":**
1. **Reference to user's data** (library, highlights, stated preference)
2. **Specific appeal factor** (not just "good" but "what makes it good")
3. **How it fits their request** (explicit connection)
4. **Unique angle** (what makes this recommendation special)

### 2.7 Recommendation Scoring Algorithm

**Conceptual Model for Ranking Recommendations:**

```
Score = (
    explicit_match * 3.0 +        // Matches stated request
    library_similarity * 2.0 +     // Similar to their books
    engagement_signal * 1.5 +      // Highlighted themes match
    recency_factor * 1.0 +         // Newer books slight boost
    popularity_factor * 0.5 +      // Well-regarded books
    diversity_bonus * 1.0          // Avoids echo chamber
) - already_recommended_penalty * 2.0
```

**Diversity Bonus:**
- If all current recommendations same genre → boost different genre
- If all same author → boost different author
- If all same decade → boost different era

### 2.8 Using Existing Services

**Leverage These Existing Components:**

1. **RecommendationEngine** (`RecommendationEngine.swift`)
   - Already generates recommendations from taste profile
   - Use as fallback for "surprise me" requests
   
2. **LibraryTasteAnalyzer** (`LibraryTasteAnalyzer.swift`)
   - Extracts genre preferences, author patterns, themes
   - Use to initialize conversation with context
   
3. **RecommendationCache** (`RecommendationCache.swift`)
   - Cache recommendations for 30 days
   - Refresh if library grows 25%+
   
4. **TrendingBooksService** (`TrendingBooksService.swift`)
   - Use for "what's popular" requests
   - Curated bestseller lists

5. **BookEnrichmentService**
   - Enrich recommendations with metadata
   - Get smart synopsis, themes, characters

**New Service Needed:**
- **ConversationalRecommendationService** - Wraps existing services with conversational context

