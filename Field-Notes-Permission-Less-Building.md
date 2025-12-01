# Field Notes from the In-Between
## A Journey to Permission-Less Building

*By Kris Puckett*

---

## I Was Terrified

Let me start there. Not with the framework, not with the methodology, not with the success story.

I was terrified.

I'm a designer. I've spent my career making things look good, thinking about user flows, arguing about pixels. And one day I had this idea for an app - Epilogue, a reading tracker that felt as beautiful as the books it would hold.

But I couldn't build it. Not really. I could design every pixel, but I couldn't ship it.

The traditional path was clear: find an engineer, convince them to build it, compromise on the vision, wait months for iterations. Or don't build it at all.

Then AI coding tools showed up, and everyone started saying "designers can code now!" But that felt like a lie. I couldn't code. I didn't know Swift from Python from JavaScript. I'd tried learning to code before - multiple times - and bounced off it every time.

So when people said "just use AI to build it," I heard: "just do the thing you've always been terrified of, except now with a robot."

Great. Still terrifying.

---

## The Question That Changed Everything

Six months ago, I was staring at yet another tutorial about SwiftUI, feeling like an imposter, about to give up again.

And I had this stupid, simple thought:

**What if I just... asked?**

Not "learned enough to know what to ask."
Not "studied until I deserved to ask."
Just... asked.

"I want to build an iOS app that tracks books I'm reading. Where do I start?"

And Claude (the AI) just... told me. In plain English. No jargon. No assumption I knew anything.

"Okay, let's create a SwiftUI project. Here's the code for a simple book list..."

Wait, that's it? I can just... ask?

**"I don't know how to make the book covers look good on dark backgrounds."**

"Let's extract colors from the cover and create an atmospheric gradient..."

**"I don't know how to save data between app launches."**

"We'll use SwiftData. Here's how to set up a Book model..."

**"I don't know how to add camera-based quote capture."**

"We can use Vision framework for OCR. Let me show you..."

Every time I hit something I didn't know - which was constantly - I just... asked.

And it worked.

Not because I suddenly became an engineer. But because **the bottleneck was never coding ability. It was permission to not know.**

---

## What I Learned on the Road

I'm still learning. I'm still in the in-between - not a designer anymore, not an engineer either, something else that doesn't have a name yet.

But I've walked far enough down this path to see some things more clearly now. These aren't prescriptions. They're field notes. Things I've found that might help if you're walking a similar road.

### Field Note #1: You Don't Need to Know How, You Need to Know What

I kept waiting to "know enough to code." That was the trap.

I didn't need to know how SwiftUI rendering works. I needed to know **what** I wanted: "When someone taps a book, show the detail view with an atmospheric background based on the cover colors."

The clearer I got about **what** (behavior, feeling, user experience), the less **how** (syntax, frameworks, architecture) mattered.

My designer brain was already fluent in "what." I just didn't realize that was the superpower.

### Field Note #2: "I Don't Know" Became My Most Powerful Tool

Early on, I'd try to hide what I didn't know. Ask questions carefully so the AI wouldn't realize I was clueless.

Then I realized: the AI doesn't judge. And being specific about what I don't know gets better results.

**Vague:** "The colors aren't working."

**Specific:** "I don't understand why the Silmarillion is showing a green gradient when the cover is predominantly blue. Looking at the console logs, both colors are detected, but green is being selected. I don't know how the color selection algorithm works, but can we prioritize blue?"

The second version gets me a real solution. And I learned something in the process.

**Being clear about what you don't know is more valuable than pretending expertise.**

### Field Note #3: Fear Doesn't Go Away, But It Changes Shape

I'm still scared. Just differently.

Month 1: "What if I can't do this at all?"
Month 2: "What if my code is garbage?"
Month 3: "What if real engineers see this and laugh?"
Month 6: "What if I ship this and it breaks for users?"

The fear evolved, but it didn't disappear. I just learned to walk with it.

Aragorn didn't stop being afraid when he accepted the crown. He just decided the calling was bigger than the fear.

Same here. The vision for Epilogue was bigger than my fear of not knowing how to build it.

### Field Note #4: The Conversation Is the Code

I thought "learning to code" meant memorizing syntax and patterns.

What I actually do is have conversations:

**Me:** "The atmospheric background should feel immersive, like you're inside the world of the book. Think ambient, enhanced colors - not desaturated, more like... alive."

**AI:** "Got it. Let me create a gradient system that boosts saturation and uses smooth blending..."

**Me:** "Perfect, but the blue is too intense. Can we make it more teal?"

**AI:** "Adjusting the hue toward cyan..."

**Me:** "Yes! That's it."

The code happened, but what I did was **describe, refine, and decide**. Those are design skills.

I didn't become an engineer. I became a designer who can execute through conversation.

### Field Note #5: You Learn by Building, Not Studying

I tried tutorials. I tried courses. I bounced off every time.

What worked: building something I actually cared about.

Every feature I shipped taught me something:
- The book list taught me state management
- The atmospheric backgrounds taught me async processing
- The camera OCR taught me iOS frameworks
- The glass effects taught me (painfully) how iOS 26 rendering works

I didn't set out to "learn async/await." I set out to "make color extraction not freeze the UI," and async/await was the answer.

**Build the thing you want to exist. The learning is a side effect.**

### Field Note #6: Engineers Aren't the Enemy, They're Allies

I was afraid engineers would gatekeep. Some do. Most don't.

What I found: when you show up with working code and ask "how can I make this better?", most engineers are genuinely helpful.

I've had engineers review my code and say "this is actually pretty good - here's how you could make it more maintainable."

Not "you shouldn't be doing this."
Not "leave this to the professionals."
Just: "here's how to do it better."

Turns out, engineers mostly care about solving problems and building good things. If you're doing that, you're a colleague, not an imposter.

### Field Note #7: Permission-Less Doesn't Mean Reckless

I ship without asking permission. But I'm not reckless.

I don't ship security-critical features alone. I don't ignore performance. I don't skip testing.

I just don't wait for permission to *try*.

I build, I test obsessively, I ask for review, I iterate. Then I ship.

The difference: **I'm in motion by default. I stop when I need help, not until I get permission to start.**

---

## The In-Between

Here's where I am now:

I've shipped Epilogue. It's in the App Store. Real people use it. It has 14,000+ lines of Swift code that I "wrote" (via conversation with AI).

It has features I'm genuinely proud of:
- Camera-based quote capture with OCR
- Siri integration ("Hey Siri, add a quote to my book")
- Custom color extraction that makes every book feel unique
- iOS 26 liquid glass effects that feel *expensive*

But I'm not "done learning." I'm not a capital-E Engineer. I'm still in the in-between.

Some days I feel like a fraud. Other days I feel like I've unlocked a superpower.

Most days, I feel like **someone who had an idea and refused to let "I don't know how" be the reason it didn't exist.**

---

## The Path Forward (For You, Maybe)

I don't have a prescriptive framework for you. I don't have "5 steps to ship your app."

What I have is an invitation:

**If you have an idea that you've been waiting for permission to build - from a boss, from an engineer, from yourself - what if you just... started asking?**

Not "learned to code first."
Not "found the perfect co-founder."
Not "waited until you felt ready."

Just: **asked the AI how to build it, and started walking.**

You'll be scared. I still am.
You'll feel like an imposter. I still do.
You'll hit things you don't know. Constantly.

But **"I don't know" isn't a wall anymore. It's a question.**

And questions have answers.

---

## Practical Field Notes (If You Want to Try)

If you're curious about walking this path, here's what actually helped me:

### Starting Out

**Week 1: Build something tiny**
- Pick the smallest version of your idea (a single screen, one feature)
- Ask the AI: "I want to build [thing]. Where do I start?"
- Don't try to understand everything - just follow along and see it work
- Goal: Prove to yourself that "I don't know how" isn't a blocker

**Week 2: Build something you'll actually use**
- Not a tutorial project - something you genuinely want
- When you hit "I don't know," be specific: "I don't know how to make X happen. Here's what I want it to do..."
- Test it obsessively - you'll catch issues fast
- Goal: Ship something you use daily

**Week 3-4: Add features, iterate**
- Start small: "Add a settings screen"
- Get bolder: "Add camera integration"
- Keep asking: "I don't know how to make the camera view look good..."
- Goal: Build confidence through repetition

### When You Get Stuck

**The debugging conversation:**

❌ "It's broken."
✅ "The Silmarillion shows a green gradient, but the cover is blue. Here's what I'm seeing in the console... I don't know why green is being selected over blue."

❌ "The colors are wrong."
✅ "I want the background to feel atmospheric, like ambient light. Right now it's too desaturated. Can we enhance the saturation while keeping it subtle?"

**Be specific about what you see and what you want. Admit what you don't know. The AI works better that way.**

### When You Feel Like an Imposter

You will. I do. Here's what helps:

**Remember:**
- Conductors don't play every instrument, they create symphonies
- Directors don't operate cameras, they make films
- **You're not writing every line of code, you're building a product**

**The work you're doing:**
- Conceiving the vision
- Specifying every behavior
- Making hundreds of micro-decisions
- Debugging when things break
- Testing obsessively
- Shipping to real users

**That's real work. The AI is a tool, not a replacement for your judgment.**

### When to Ask for Help

**Build solo when:**
- It's 0→1 exploration (new idea, rapid iteration)
- It's design-heavy (UI, interactions, feel)
- You understand the desired behavior clearly
- It's your first time and you're learning

**Collaborate with engineers when:**
- It's security-critical (payments, auth, user data)
- It's performance-critical (scale, optimization)
- It affects other systems/teams
- You've been stuck for more than a few hours

**The rule: Try first. Ask for help when you need it. Don't wait for permission to try.**

### Tools I Use

**AI Coding Assistants:**
- Claude (conversational, great for "I don't know" questions)
- GitHub Copilot (inline suggestions while coding)
- Cursor (AI-native code editor)

**For Epilogue specifically:**
- Xcode (iOS development)
- SwiftUI (Apple's UI framework)
- Git (version control - I just ask AI for the commands)

**The tools matter less than the approach: "I don't know how to do this. Can you help me?"**

---

## What This Means (Maybe)

I'm still figuring out what this means for me. Designer? Engineer? Something else?

I've settled on: **someone who builds the things they imagine.**

The title matters less than the ability.

But I think this moment - where AI can translate intent into code - changes something fundamental:

**The person with the vision can now be the person who ships.**

Not because we became engineers.
Because **the bottleneck shifted from ability to articulate clearly.**

And designers are already fluent in articulating vision, behavior, and experience.

We just didn't realize that was enough.

---

## Where I'm Heading

I'm still in the in-between. Still learning. Still scared sometimes.

But I can see the path more clearly now.

I'm becoming someone who:
- Has ideas and ships them (without waiting for permission)
- Iterates at the speed of thought (not the speed of sprint planning)
- Maintains uncompromising quality (because I control the whole experience)
- Helps others see they can do this too (hence this talk)

Not a thought leader. Not a guru. Just **a designer who learned to ask instead of wait.**

And I'm inviting you to walk this road too.

Not because I have all the answers.
But because **I've walked far enough to know: the path exists, and you can walk it.**

---

## The Question

Here's what I want to leave you with:

**What have you been waiting for permission to build?**

Not "what will you build someday when you learn to code."
Not "what would you build if you had an engineer."

**What do you want to exist so badly that you're willing to walk into the unknown and just... ask?**

Because here's what I learned:

"I don't know how" isn't a wall.
It's an invitation.

"I don't know how to build an iOS app."
*Can you show me?*

"I don't know how to extract colors from images."
*Can you help me figure it out?*

"I don't know how to ship this without breaking everything."
*Can we test it and iterate?*

**Every "I don't know" is just the beginning of a conversation.**

And conversations lead to code.
And code leads to products.
And products lead to... whatever comes next.

I'm still finding out.

Want to walk this road with me?

---

## Appendix: Real Examples from the Journey

### Example 1: The Color Extraction Fear

**The moment:**
I wanted Epilogue to have atmospheric backgrounds based on book cover colors. But I had *no idea* how color extraction works.

**The old me:**
"I need to find an engineer who knows color theory and iOS image processing."

**The new me:**
"I don't know how to extract dominant colors from an image. Can you help me build this?"

**What happened:**
Claude explained ColorCube algorithms, OKLAB color space, and 3D histograms. I understood maybe 30% of the explanation.

But I understood 100% of: "Here's the code. Test it with these books."

**The result:**
It worked. Lord of the Rings showed red and gold. The Odyssey showed teal. It was magical.

Then The Silmarillion showed green instead of blue. I didn't know why.

So I asked: "I don't understand why green is prioritized over blue. Here's what the console shows..."

We iterated. We fixed it. I learned something about color role assignment.

**I didn't become a color theory expert. I became someone who could ship color extraction and debug it when it broke.**

### Example 2: The iOS 26 Glass Effect Mystery

**The moment:**
iOS 26 introduced liquid glass effects. I wanted them in Epilogue. They looked amazing in Apple's demos.

I added `.glassEffect()` to my cards. Nothing happened.

**The conversation:**

**Me:** "The glass effects aren't working. The cards just look flat."

**AI:** "Are you applying `.background()` before `.glassEffect()`?"

**Me:** "Yes, I'm using `.background(Color.white.opacity(0.1))` to give it something to work with."

**AI:** "That's the issue. iOS 26's liquid glass breaks with ANY background modifier before it. Remove the `.background()` completely."

**Me:** "But won't it need something to apply glass to?"

**AI:** "No, iOS 26's `.glassEffect()` is self-contained. Just apply it directly."

**Me:** *Tests* "Holy shit, that worked."

**What I learned:**
Not "how iOS 26 rendering works." But: **"No backgrounds before glass effects, ever."**

I documented it in my project notes: "iOS 26 Liquid Glass - NO .background() before .glassEffect()"

**Now I know that pattern. I can use it. I can teach it.**

I didn't need to understand *why*. I needed to know *what works*.

### Example 3: The "I Shouldn't Be Doing This" Moment

**The moment:**
Three months in, I showed Epilogue to a senior iOS engineer friend.

I was terrified. My code was probably garbage. He'd tell me I was doing everything wrong.

**What happened:**

**Him:** "Wait, you built this? Can I see the code?"

**Me:** *Sweating* "Yeah, but it's probably a mess..."

**Him:** *Reviews for 10 minutes* "This is actually pretty clean. You're using SwiftData correctly. The async image loading is solid. I'd extract this color extraction into a separate service class, and you could optimize the list rendering a bit, but... this is good."

**Me:** "Really?"

**Him:** "Yeah. Where'd you learn iOS development?"

**Me:** "I... didn't? I just asked Claude when I didn't know something."

**Him:** "Huh. Well, it works."

**What I learned:**
The imposter syndrome was in my head. The code was fine. Not perfect, but fine.

**And "fine" ships.**

### Example 4: The Camera OCR "I Have No Idea" Conversation

**The moment:**
I wanted users to capture quotes by pointing their camera at a book page.

I had *zero* idea how OCR works. Zero idea how iOS camera integration works.

**The conversation:**

**Me:** "I want to add a feature where users can capture quotes with their camera. I have no idea how to do this."

**AI:** "We can use Apple's Vision framework for text recognition. Here's how to set it up..."

**Me:** "Okay, but I want it to feel polished. Live preview, text should be highlighted as it's detected, freeze frame when they capture."

**AI:** "Let me build that out. We'll need a camera view controller, a Vision text request, and overlays for highlighting..."

**Me:** *Tests initial version* "This is incredible, but it's merging two-column text into one block. Newspapers and textbooks won't work."

**AI:** "We need to detect column layout. Let me adjust the text recognition to handle multi-column..."

**Me:** *Tests* "Perfect. Now how do I let them edit the text if OCR is wrong?"

**AI:** "Add an edit view after capture..."

**The result:**
A fully working camera quote capture feature. With multi-column support. And editing.

**I have no idea how Vision framework actually works internally. But I shipped a working OCR feature.**

---

## Acknowledgments

This journey exists because:
- **AI made it possible** for someone like me to ship without traditional engineering skills
- **The Epilogue users** who tested early versions and gave honest feedback
- **The engineers** who reviewed my code and helped me get better instead of gatekeeping
- **The designers on Twitter/LinkedIn** who messaged me saying "you inspired me to try"

To the designers who are curious: You can do this. Not because you'll become an engineer, but because **you already have the most important skill: knowing what you want to build.**

The rest is just asking.

---

*These are field notes from an ongoing journey. I'm still learning. I'm still in the in-between. But I'm walking, and the path is becoming clearer.*

*If this resonated with you, I'd love to hear about your journey:*
*Twitter/X: @krispuckett*
*Epilogue (the app this journey created): [App Store]*
*Monomythic Consultancy: [Website]*

---

**A note on AI and attribution:**

Everything in this document came from my experience building Epilogue. The code was written through conversation with AI (primarily Claude and GitHub Copilot). The ideas, decisions, and journey are mine.

I'm not hiding the AI's role - it's central to the story. But I'm also not diminishing my role. **The AI translated my vision into code. The vision, the product, and the obsessive iteration until it felt right - that was me.**

If you're wondering whether you can claim credit for something you built with AI: **Yes. You directed every decision, solved every problem, and shipped a real thing. That's real work.**

---

*Last updated: November 2025*
*Written from somewhere in the in-between*
