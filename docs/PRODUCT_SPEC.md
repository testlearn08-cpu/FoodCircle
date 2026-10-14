# FoodCircle — Product Spec (INFERRED — not the handoff)

> ## ⚠️ This is not the product spec. It is a record of what was guessed in its absence.
>
> Written when the referenced "v0.2 prototype / development handoff" had been missing across
> **four** working sessions. Every line here is inferred from standard Flutter/Supabase practice,
> the shipped schema, and the app's one-line description.
>
> The real handoff (documents `01`–`11`) supersedes this entirely. The moment it arrives, this file
> is either replaced by it or corrected against it — see
> [`handoff/RECONCILIATION.md`](handoff/RECONCILIATION.md) for the inventory of assumptions to
> check, and note in particular that this document says **nothing about location, notifications or
> offline behaviour**, while the handoff devotes `05_LOCATION_NOTIFICATIONS_AND_OFFLINE.md` to exactly
> those.
>
> Treat the sections below as *provisional*, not as approved scope. Nothing in `lib/` should be
> treated as evidence that any of it was agreed.

---

## 1. What it is

**FoodCircle is a private-feeling recipe box that a group of people can share.** You write down
what you actually cook, decide who can see it, and cook from what the people around you cook.

The name is the product: the value is the **circle**, not a global recipe firehose. A user should be
able to answer *"what can I make tonight?"* from recipes by people they trust, not from a million
strangers.

**Job to be done:** *"I want to remember and reuse the food I make, share it with my people, and
find something to cook from theirs."*

## 2. Users

| Persona | Wants | Frequency |
|---|---|---|
| **Cook** (primary) | Write down a recipe in under 2 minutes, on a phone, standing in a kitchen | Weekly |
| **Browser** (primary) | Look at tonight's options from people they know; save what looks good | Daily, 2–5 min |
| **Circle keeper** (later) | Keep a family / flat / class group's recipes in one place | Monthly |

## 3. Core objects

| Object | Fields | Visibility |
|---|---|---|
| **Profile** | username, display name, avatar, bio | Public to signed-in users; username/avatar public |
| **Recipe** | title, description, **image**, servings, prep/cook minutes, difficulty, `ingredients[]`, `steps[]`, tags, `is_public`, author | Public **or** private to author (v0.3). *(matches the RLS already shipped)* |
| **Save** | user ↔ recipe | Private to the user *(v0.3)* |
| **Circle** | name, members, recipes shared into it | Members only — **v0.4, deferred** |

Fields marked in `supabase/migrations/001` but not in this spec: none. Fields in this spec but not
in the schema (`image`, `servings`, times, `difficulty`, `tags`) are exactly what migration `004`
adds in Phase 1.

## 4. Screens and flows

**S1 · Sign in / Sign up** — email + password. Signed-out users can still browse public recipes.
`[assumption]` no OAuth in v0.3; email confirmation via Supabase default.

**S2 · Feed** *(home)* — reverse-chronological list of public recipes: photo left, title, author,
time + difficulty chips. Pull to refresh; scrolls forever. Empty state invites the first recipe.

**S3 · Recipe detail** — photo, title, author, servings/time/difficulty, then ingredients and steps.
Actions: **Save** (heart/bookmark), **Share** (system share of a link), **Edit**/**Delete** for the owner.

**S4 · Recipe editor** — create and edit share one screen. Photo upload, title, description, servings,
times, difficulty, free-text tags, ingredients list, steps list. Validates before saving; says what is
missing. Saving is possible with an empty photo. **[assumption]** one photo per recipe in v0.3.

**S5 · Search** *(inside the feed)* — by title and ingredient text, filtered by tag. **[assumption]**
no AI/semantic search.

**S6 · Profile** — avatar, display name, bio, "my recipes", "saved". Editing your own profile
(including avatar upload) is the only write action here.

**S7 · Settings** *(thin)* — sign out, delete account. **[assumption]** delete account ships in v0.3
because an app that stores user content without it is not shippable.

**Primary journey (must work end to end before Phase 3 starts):**
sign up → land on feed → create a recipe with a photo → see it at the top of the feed → open it →
edit it → sign out → sign in → it is still there → save someone else's recipe → find it under
"saved".

## 5. Privacy model, in plain language

| Rule | Enforced by |
|---|---|
| Anyone, signed in or not, can read public recipes | RLS `recipes_read_public` |
| A private recipe is readable only by its author | RLS `recipes_read_public` |
| Only an author can create, edit or delete their recipes | RLS `recipes_*_own` |
| Anyone can read profiles; only you can edit yours | RLS `profiles_*_own` (+ signup trigger) |
| **No client can ever read another user's email address** | `auth.users` is not exposed; the `public.auth_users` view stays deleted |
| Recipe images are readable by anyone with the link; only the owner can upload or replace theirs | Storage policies, migration `005` |
| `service_role` never touches a client build | Build-time config, anon key only |

## 6. Scope boundary

**In v0.3** — S1–S7, one photo per recipe, save/favourite, search by title/ingredient/tag, public and
private recipes, avatar upload, account deletion.

**Deliberately out of v0.3** — comments, likes, followers, notifications, circles/groups, realtime,
offline mode, video, nutrition data, meal planning, shopping lists, recipe import from a URL, i18n,
iOS release pipeline.

**Explicitly v0.4** — circles (the actual product bet): a circle owns recipes, membership is by invite,
and the feed gains a "my circles" tab. Schema sketch: `circles`, `circle_members(role)`,
`recipe_circles(recipe_id, circle_id)` + RLS helper `is_circle_member(circle_id)`.

## 7. Non-functional requirements

- **Responsive by contract:** phone (bottom bar), tablet (compact rail), desktop/web (extended rail).
  Already implemented and tested; every new screen must work at 360 px and at 1440 px.
- **Every list has three states:** loading (skeleton), empty (with a call to action), error (retry).
  No spinner-forever screens.
- **Accessibility:** every interactive element has a label; text scales to 200% without clipping.
- **Performance:** feed first paint < 2 s on a mid-range phone over 4G; images resized before upload.
- **Security:** RLS is the only authorization boundary — the client is assumed hostile. Never rely on
  hiding a button.

## 8. Definition of done for v0.3

1. The primary journey in §4 completes on web, Android and iOS without a crash.
2. Every privacy rule in §5 has an executed test, not a string match.
3. CI is green on analyze + test + web build + APK build + database behaviour tests.
4. A second person can sign up on a fresh device and share a recipe with the first.

## 9. Decisions to confirm

> These questions were addressed to the wrong person: the same questions are almost certainly
> already answered in `10_DECISIONS_AND_OPEN_GATES.md`. Do not answer these here.

- [ ] Circle-first framing (§1) or global-feed framing?
- [ ] Email + password only, or also Google / Apple sign-in at v0.3?
- [ ] One photo per recipe is enough for v0.3?
- [ ] Public recipes by default when creating a recipe, or private by default?
- [ ] Is "save/favourite" needed in v0.3, or is it v0.4 scope?
- [ ] Account deletion in v0.3 (spec says yes)?
- [ ] Anything in §6's "out" list that actually must be in?
