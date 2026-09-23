# Passenger App — POC

A white-label AI passenger companion for the airport journey. Built to the Asana brief
*Fly+ Passenger App* (Fly+ Designs) and the accompanying
*Passenger App — Product Architecture, Experience & POC Scope*.

The mental model is the brief's: **Now → Next → Ask → Act**.

## Run it

```bash
xcodegen generate
open FlyPlusPassenger.xcodeproj
```

Or straight to the simulator:

```bash
xcodebuild -project FlyPlusPassenger.xcodeproj -scheme FlyPlusPassenger \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath ./build/DD build
xcrun simctl install booted ./build/DD/Build/Products/Debug-iphonesimulator/Passenger.app
xcrun simctl launch booted com.flyplus.passenger
```

> A new file under `Sources/` needs `xcodegen generate` before it will compile.

## The 3-minute demo

1. **Scan boarding pass** → *Continue*. No account, just a flight (§7).
2. **Home** — JED → LHR, SV117 on time, boarding in 47 min, Gate 32 · 8 min walk, "You're on schedule."
3. Tap **"I want to pray first"** — the hero interaction. The reply reasons about location,
   boarding time, walking time and the gate, then offers the route.
4. **Take me there** → multi-stop navigation: You → Prayer Room (~10 min) → Gate 32, with
   turn-by-turn and boarding time kept on screen throughout.
5. Ask **"Can you deliver my bags home?"** → service card → confirmation → booked.
6. **More → Deployment → JED Assistant** — the same screens, a different brand.

`More → Demo controls` skips time forward and fires a gate change, since the POC has no live feeds.

## How it is put together

```
Sources/
  Tenant.swift          white-label config: brand, assistant identity, capabilities, catalogue
  Theme.swift           type scale, metrics, the @Environment(\.tenant) key
  Models/               Flight + JourneyStage + PassengerContext; the airport graph and POIs
  Engine/
    TimingEngine        available = boarding − now − walk − 15 min reserve   (authoritative)
    RoutingEngine       Dijkstra, multi-stop, derived turn-by-turn
    Assistant           intent → { speech, cards, UI command }
    JourneyStore        @Observable app state + simulated journey clock
  Views/                Home · Navigate · Explore · More · assistant · cards · service flow
```

Three rules hold the design together:

1. **The platform is authoritative about time, the assistant only phrases it.** No view and no
   assistant branch computes a duration; everything comes from `TimingEngine`.
2. **Conversation controls the interface.** A response carries an `AssistantCommand` — open
   navigation, open Explore, start a service flow — so asking changes the screen rather than
   adding a chat bubble.
3. **Nothing names a brand.** Every colour and label comes from `Tenant`. `#207CE1` appears
   exactly once, in `Tenant.flyPlus`.

The airport graph's edge distances are in metres and are **load-bearing**: they are tuned so the
brief's stated walk times (8 min to the gate, 2 to the prayer room, 3 to coffee, 5 to the lounge)
are derived by the router rather than written as copy.

## What is deliberately not built

Per §30 and §22 of the brief, the POC does not depend on:

- real indoor positioning, BLE, live queues, AODB or airline integration;
- real speech recognition — the mic opens a proper Listening state, and spoken phrases are
  offered as chips rather than a faked transcription;
- Arabic strings. Layout is RTL-tolerant and the language row is present, marked *soon*.

Swapping any POC provider for a production one should not change the experience layer:
replace `RoutingEngine` for indoor routing, or `Assistant.resolve` for an LLM, and the views,
cards and commands above them stay as they are.
