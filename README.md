# Fly+ Passenger — AI companion (POC)

A mobile-first AI passenger companion where the assistant drives the interface
rather than sitting in a chat tab. SwiftUI, Swift 6, iOS 26, generated with
XcodeGen — the same shape as `flyplus-agentapp`.

```bash
brew install xcodegen      # if you don't have it
xcodegen generate
open FlyPlusPassenger.xcodeproj
```

## What this is

The twelve P0 screens from the UX research, plus the proposed thirteenth
(change and disruption), built as a running app against the fixed demo story:

> JED → LHR · Saudia SV117 · Gate 32 · boarding 17:55 · departure 18:40 ·
> passenger already airside.

| # | Screen | Where it lives |
|---|--------|----------------|
| 01 | Journey setup | `Screens/JourneySetupView.swift` |
| 02 | Journey Home | `Screens/HomeView.swift` |
| 03 | Voice — listening | `Screens/AssistantSheet.swift` |
| 04 | Voice — processing | `Screens/AssistantSheet.swift` |
| 05 | Voice — response | `Screens/AssistantSheet.swift` |
| 06 | Contextual flight response | `Screens/MiscScreens.swift` |
| 07 | "What should I do next?" | `Models/AssistantBrain.swift` → recommendation + nearby |
| 08 | Indoor route overview | `Screens/NavigationScreens.swift` |
| 09 | Turn-by-turn | `Screens/NavigationScreens.swift` |
| 10 | Multi-stop route | `Screens/NavigationScreens.swift` |
| 11 | Service flow | `Screens/ServiceScreens.swift` |
| 12 | Action confirmation | `Screens/ServiceScreens.swift` |
| 13 | Change & disruption | `Screens/MiscScreens.swift` + inline on Home |

## The decisions this code encodes

**Four tabs, and Services is not one of them.** Home · Navigate · Ask ·
Explore · More, with the microphone in the centre slot. Services surface
contextually, from Home, Explore, the assistant and journey events. Help is a
destination the assistant can open, not a settings row. A permanent Services
tab would turn a journey product into a marketplace.

**Timing is deterministic, never the model's guess.** Everything the passenger
acts on comes out of `TimingEngine`:

```
available = boarding − now − walk − buffer     (buffer = 15 minutes)
```

The assistant may *say* the result, but it never computes it — which is why the
assistant and Home can never disagree about when to leave.

**The response kit is a contract.** `ResponseComponent` is a closed enum of the
thirteen things the assistant is allowed to draw. Adding a kind of answer is a
compile-time decision. A generator that can only return a confirmation card
cannot accidentally spend someone's money in a sentence.

**Voice is a sheet over the journey, not a full screen.** The gate, the
countdown and the route stay live behind it (`presentationBackgroundInteraction`),
because the passenger is asking about what is on screen. Text is a genuine
equal, not a fallback: "Type instead" is present in every voice state.

**No mandatory sign-up.** Entry is flight number plus date, or a boarding-pass
scan. Sign-in appears at the payment step and nowhere earlier.

**Fly+ branding only.** The white-label requirement in the brief's addendum is
out of scope for this iteration, on Yousri's direction. There is no tenant
configuration layer to remove later — it was never built.

## Native components

The UI is built from platform controls rather than lookalikes: `TabView`/`Tab`,
`NavigationStack`, `GroupBox` with a custom `GroupBoxStyle` for cards,
`LabeledContent` for label/value rows, `Form`/`Section`/`Picker`/`Toggle` for
settings, `.searchable` for Explore, `ContentUnavailableView` for empty and
failure states, `ProgressView`, `DatePicker`, segmented `Picker` for the
service step, `.sheet` with `presentationDetents` for the assistant, and
`Canvas` for the floor plan. The wrappers in `Components/Primitives.swift`
(`PrimaryButton`, `SecondaryButton`, `ShortcutChip`) apply tint and sizing in
one place on top of `.borderedProminent` / `.bordered` — they do not replace
the platform control.

## What is mocked, and what is not

Mocked, in keeping with the rest of the Fly+ family: **all of the data.** There
is no networking anywhere in this app — no URLSession, no API client, no auth.
The flight, the POIs, the floor plan, the routes, the service catalogue and the
OTP (`000000`) are hardcoded. Speech recognition is simulated: the listening
state streams a partial transcript rather than opening a microphone, so the
state machine and the escape hatches are what get exercised.

Not mocked: the arithmetic, the journey state machine, the response kit, and
every failure state the research asks for — low confidence, out of scope, no
speech, no network, uncertain indoor position.

**The demo clock** starts at 17:08 and runs in real time, so states advance on
their own during a walkthrough. More → Demo controls resets it, jumps to any
journey state, fires the gate change, and toggles uncertain positioning.

## Arabic and RTL

Journey Home and the shared chrome are fully translated; deeper screens fall
back to English and More says so. Switching to العربية in More flips
`layoutDirection` for the whole app, so the layout is exercised against real
Arabic strings rather than checked later. Components are flexible-height and
use leading/trailing, because Arabic needs vertical room and translations run
roughly 30% longer.

## Known gaps

- **Not built in Xcode.** This was written in a Linux container with no iOS
  toolchain, so nothing here has been compiled or run. Treat the first `xcodegen
  generate && build` as the real review.
- Turn-by-turn advances on a button rather than on position, because there is
  no indoor positioning to advance against.
- Spoken output and haptics on turns are specified but not wired; the written
  answer is the source of truth in this build.
- `Add to Wallet` and `Share arrival` on the flight screen are inert.
