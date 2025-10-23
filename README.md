# **unevenly_alive.lua**

*A feverish, tonal time-animal that ages in place*

## What it is

* **Lives on its own clock** (not yours).
* **Learns the key from your first notes/chords**, then wanders within a *safe-but-unstable* harmonic field.
* **Never loops**; instead it **misremembers** through smeared softcut layers.
* **Beautiful by design**: consonant cores with tense extensions (9ths/11ths/6ths), slow microtonal drift, shimmering reverb/delay.
* **You can’t “play” parameters** — only *provoke* its nervous system.

## Controls (feel, not parameters)

### Norns Encoders & Keys

* `E1` — **Age / Dissolve** (pushes it to smear & forget; increases memory corrosion)
* `E2` — **Trust / Anchor** (briefly narrows to the current center; adds consonant bias)
* `E3` — **Risk** (widens harmonic spread and emotional volatility)
* `K1` (hold) + `E1` — **Time drag** (nudges its internal time—may obey or resist)
* `K2` — **Offer tone** (captures your live input into its memory)
* `K3` — **Invite response** (encourages a harmonic apparition to emerge now)

### Monome Arc (optional)

If you have a **monome Arc** connected, it provides visual feedback and tactile control:

* **Ring 1** — Age / Dissolve (breathing glow intensifies with memory smear)
* **Ring 2** — Trust / Anchor (stable, centered light)
* **Ring 3** — Risk (feverish, jittery glow responds to emotional volatility)

The Arc is **completely optional** — the script works perfectly without it, but adds a beautiful tactile/visual layer if present.

### Monome Crow + Just Friends (optional)

If you have a **monome Crow** connected to **Whimsical Raps Just Friends** via i2c, the script will automatically route voices to Just Friends in synthesis mode:

* Voices are sent polyphonically using JF's automatic voice allocation
* Pitch follows the same harmonic logic (V/oct conversion)
* Amplitude maps to JF's level control (0-5V range)
* Just Friends becomes an **external voice** for the time-animal

**Setup:** Connect Crow to norns via USB, connect Crow to Just Friends via i2c. The script will detect Crow and enable Just Friends automatically.

This is **completely optional** — the script works perfectly with just PolySub, but JF adds a beautiful analog texture layer.

### Monome Grid (optional)

If you have a **monome Grid** connected, it provides deep visual and tactile control over the organism's harmonic structure and behavior. The interface adapts to your grid size:

#### 128 Grid (8x16 or similar) Layout:

* **Row 1** — Custom scale degrees (toggle 12 semitones in/out)
* **Row 2** — Toggle custom scale mode (col 14)
* **Row 3** — Mode selection (ionian, dorian, phrygian, lydian, mixolydian, aeolian, locrian)
* **Row 4** — Manual note triggering (2-octave chromatic range)
* **Row 6** — Age/Dissolve slider (visual feedback)
* **Row 7** — Trust/Anchor slider
* **Row 8** — Risk slider (glows with fever)

#### 256 Grid (16x16) Layout:

* **Rows 1-2** — Custom scale degrees (larger, double-height buttons)
* **Row 3** — Toggle custom scale (col 14), Clear custom scale (col 16)
* **Row 4** — Mode selection (7 modes, spaced wider)
* **Rows 6-9** — Manual note triggering (4-octave chromatic range!)
* **Row 11** — Age/Dissolve slider
* **Row 12** — Trust/Anchor slider
* **Row 13** — Risk slider with fever visualization
* **Row 15** — Organism interaction zone
  - **Left half (1-8)**: Provoke (trigger response + increase volatility)
  - **Right half (9-16)**: Calm (increase trust + reduce risk)

#### Grid Features:

* **Custom Scale Building**: Toggle individual semitones to create your own scale pool (overrides mode-based scales when enabled)
* **Manual Performance**: Trigger specific notes while the organism continues its autonomous behavior
* **Visual Feedback**: All parameters show live state with LED brightness
* **Tactile Control**: Sliders provide immediate, hands-on parameter adjustment
* **Organism Interaction** (256 only): Physical zones to provoke or calm the creature

The Grid is **completely optional** — the script works perfectly without it, but adds a powerful layer of control while maintaining the anti-instrumental philosophy (you're still influencing, not commanding).

> Plug an instrument/mic into input 1. Keep levels tasteful; this wants headroom.

---

## Installation

From maiden:
```
;install https://github.com/sethbc/unevenly_alive
```

Or manually copy the `unevenly_alive` folder to `~/dust/code/`.

## How to “play” it (without playing it)

* Feed it **soft chords, dyads, or single tones** into Input 1. Tap **K2** occasionally to “offer” yourself.
* When you want it to **answer**, tap **K3**. Don’t spam.
* Turn **E1** slowly to **age** the memory (more smear, more bloom).
* Turn **E2** when it’s drifting too far — it will **remember beauty** again.
* Turn **E3** when you want **fever** — it gets tense but keeps a halo.
* Hold **K1** while nudging **E1** to **drag time** a touch; it might rebel.

## Make it even prettier (optional tweaks)

* In `polysub_voice()`, raise `engine.release` caps to lengthen tails.
* Increase `audio.level_rev()` a hair if your room is dry.
* Lower `s.micro` if you want less detune shimmer; raise to taste (≤ 0.07 semitones stays lovely).

## If you want pitch-following later

We kept it minimal/robust. If you want it to **truly learn your key** in real-time, add a lightweight pitch follower (e.g., `chuck`/`aubio` external or a small polling analysis) and set `s.base_midi` on detection peaks. The organism logic stays the same.

---

If you’d like, tell me your I/O setup and I’ll pre-tune input gains and reverb/delay levels. Or I can generate a variant that uses **MollyThePoly** for a more choir-like gloss.
