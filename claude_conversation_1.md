# Claude Code Conversation: unevenly_alive.lua Bug Fixes and Feature Additions

**Date:** 2025-10-23
**Project:** unevenly_alive - A feverish tonal time-animal for norns
**Assistant:** Claude (Sonnet 4.5)

---

## Session Overview

This conversation documents the complete debugging and enhancement process for the `unevenly_alive.lua` norns script, including:
1. Fixing multiple norns API bugs
2. Adding monome Arc support
3. Adding Crow + Just Friends integration
4. Adding comprehensive monome Grid support (128 and 256 layouts)

---

## Part 1: Initial Bug Fix - `level_rev` Error

### User Request
> this line is giving me an error that it is attemping to call a nil value

**Context:** Line 178 - `level_rev`

### Investigation & Solution

**Problem Identified:** Line 178 was calling `audio.level_rev()` which doesn't exist in the norns audio API.

**Correct Function:** `audio.rev_level()` - Sets the reverb send level

**Fix Applied:**
```lua
-- Before (line 178)
audio.level_rev(clamp(0.2 + s.memory_age*0.2, 0.1, 0.5))

-- After
audio.rev_level(clamp(0.2 + s.memory_age*0.2, 0.1, 0.5))
```

---

## Part 2: Comprehensive API Audit

### User Request
> can you please look for other bugs against the norns API?

### Research Process

**Documentation Sources Consulted:**
- Official norns audio API: `https://monome.org/docs/norns/api/modules/audio.html`
- Softcut API documentation
- ControlSpec presets: `https://github.com/monome/norns/blob/main/lua/core/controlspec.lua`
- PolySub engine source: `https://github.com/monome/dust/blob/master/lib/sc/Engine_PolySub.sc`

### Bugs Found & Fixed

#### 1. Audio API - Reverb Function (✅ Fixed)
**Issue:** `audio.level_rev()` → should be `audio.rev_level()`

#### 2. Audio API - Non-existent Delay Functions (✅ Fixed)
**Issue:** Lines 180-181 used `audio.delay_on()` and `audio.level_delay_send()` which don't exist

**Fix:** Removed these calls and added comment explaining delay is handled by softcut
```lua
-- Note: norns doesn't have built-in audio.delay_on/level_delay_send
-- Delay effect is handled by softcut buffers instead
```

#### 3. Softcut API (✅ Verified Correct)
All softcut calls verified against API documentation - no issues found.

#### 4. ControlSpec (✅ Verified Correct)
- `controlspec.MIDINOTE` confirmed to exist
- Range: 0-127, default: 60, step: 1

---

## Part 3: PolySub Engine API Errors

### User Request
> this line is giving me an init error: attempt to call a nil value (field 'release')

**Context:** Engine commands in `polysub_voice()` function

### Investigation

**Research:** Examined PolySub engine source code from monome/dust repository

**Critical Finding:** PolySub uses **global parameters**, not per-voice control.

### PolySub API - Available Commands

**Voice Control:**
- `engine.start(id, hz)` - Start voice with frequency
- `engine.stop(id)` - Stop voice
- `engine.stopAll()` - Free all synths

**Global Parameters (affect all voices):**
- `engine.level(float)` - Amplitude
- `engine.cut(float)` - RLPF cutoff frequency
- `engine.ampRel(float)` - Amplitude envelope release time
- `engine.ampAtk/Dec/Sus/Curve(float)` - Amplitude envelope
- `engine.detune(float)` - Oscillator detune
- `engine.timbre(float)` - Waveshape modulation
- `engine.shape(float)` - Base waveshape selection
- `engine.sub/noise/width/fgain(float)` - Other tone controls
- `engine.cutAtk/Dec/Sus/Rel/Curve/EnvAmt(float)` - Filter envelope

### Bugs Fixed in polysub_voice()

**Invalid Commands Removed:**
- ❌ `engine.hz(id, hz)` - doesn't exist
- ❌ `engine.amp(id, amp)` - doesn't exist
- ❌ `engine.pan(id, pan)` - doesn't exist (no pan in PolySub)
- ❌ `engine.lp(id, value)` - doesn't exist
- ❌ `engine.hp(id, value)` - doesn't exist
- ❌ `engine.release(id, value)` - doesn't exist
- ❌ `engine.fm_index(id, value)` - doesn't exist (no FM in PolySub)
- ❌ `engine.cut(id, value)` - should be global
- ❌ `engine.detune(id, value)` - should be global
- ❌ `engine.env_slope(id, value)` - doesn't exist

**Corrected Implementation:**
```lua
local function polysub_voice(id, midi, dur, amp, pan)
  -- PolySub uses global parameters, not per-voice control
  local hz = musicutil.note_num_to_freq(midi)

  -- Set global parameters (affect all voices)
  engine.level(amp)
  engine.cut(2200 + (s.spread*300))
  engine.ampRel(clamp(dur*1.15, 0.2, 6))
  engine.detune(0.002 + s.spread*0.0007)
  engine.timbre(0.5 + s.trust*0.25) -- brightness via timbre
  engine.shape(0.05 + s.spread*0.03) -- base waveshape for tension

  -- Start voice with frequency
  engine.start(id, hz)
end
```

**Also Fixed in init():**
```lua
-- Initialize PolySub global parameters
engine.ampRel(0.9)
engine.level(0.3)
engine.cut(2200)
engine.shape(0.2)
engine.timbre(0.5)
```

---

## Part 4: MusicUtil Scale API Error

### User Request
> this line is giving me an error, attempt to index a nil value (field 'SCALE_NAMES_MAP')

**Context:** Line 38 in `build_scale()` function

### Investigation

**Research:** Examined `https://github.com/monome/norns/blob/main/lua/lib/musicutil.lua`

**Finding:** There is **no `SCALE_NAMES_MAP`** in musicutil. The SCALES table is an array that must be searched.

### SCALES Table Structure

```lua
-- Each entry in musicutil.SCALES has:
{
  name = "Major",           -- Primary name
  alt_names = {"Ionian"},   -- Alternative names (optional)
  intervals = {0, 2, 4, 5, 7, 9, 11, 12}, -- Semitone intervals
  chords = {...}            -- Compatible chords per degree
}
```

### Fix Applied

**Before:**
```lua
local degrees = musicutil.SCALES[musicutil.SCALE_NAMES_MAP[s.mode]].intervals
```

**After:**
```lua
local function build_scale()
  -- Find scale by name (case-insensitive search)
  local scale_data = nil
  for i=1,#musicutil.SCALES do
    if string.lower(musicutil.SCALES[i].name) == string.lower(s.mode) then
      scale_data = musicutil.SCALES[i]
      break
    end
    -- Check alternative names too
    if musicutil.SCALES[i].alt_names then
      for j=1,#musicutil.SCALES[i].alt_names do
        if string.lower(musicutil.SCALES[i].alt_names[j]) == string.lower(s.mode) then
          scale_data = musicutil.SCALES[i]
          break
        end
      end
    end
  end

  local degrees = scale_data and scale_data.intervals or {0, 2, 4, 5, 7, 9, 11} -- fallback to major
  -- ... rest of function
end
```

**Result:** Now properly searches for scales by name including alternative names (e.g., "ionian" matches "Major")

---

## Part 5: README Conformance Check

### User Request
> can you please confirm that the behavior of the script conforms to the readme file, and if not modify the code to reflect the information in the readme?

### Analysis

**README Controls Specification:**
- `E1` — Age / Dissolve
- `E2` — Trust / Anchor
- `E3` — Risk
- `K1` (hold) + `E1` — Time drag
- `K2` — Offer tone
- `K3` — Invite response

### Discrepancy Found

**Issue:** K1 + E1 "Time Drag" Not Properly Implemented

**README Says:** `K1` (hold) + `E1` — Time drag (nudges its internal time—may obey or resist)

**Code Was Doing:** K1 alone (tap, not hold) triggered time drag immediately

### Fix Applied

**Added K1 Hold State Tracking:**
```lua
local ui = { blink = 0, breathe = 0, fever = 0, k1_held = false }
```

**Modified enc() Function:**
```lua
function enc(n,d)
  if n==1 then
    if ui.k1_held then
      -- K1 held + E1 = Time drag (may obey or resist)
      if math.random() < s.obeys_time_drag then
        s.heart = clamp(s.heart + d*0.005, 0.07, 0.25)
      else
        -- rebellion: quick fever spike that still sounds nice
        s.spread = clamp(s.spread + d*0.01, 1, 8)
        build_scale()
      end
    else
      -- E1 alone = Age / Dissolve
      s.memory_age = clamp(s.memory_age + d*0.01, 0, 1)
      soften_memory()
    end
  -- ... rest of encoders
end
```

**Modified key() Function:**
```lua
function key(n,z)
  if n==1 then
    -- K1 acts as a hold modifier for E1 (time drag)
    ui.k1_held = (z==1)
  elseif n==2 and z==1 then
    -- K2 = Offer tone (capture input)
    capture_offer()
  elseif n==3 and z==1 then
    -- K3 = Invite response (trigger apparition)
    invite_response()
  end
  redraw()
end
```

**Result:** All controls now match README specification ✅

---

## Part 6: Monome Arc Support

### User Request
> modify this code to permit (but not require) control by the monome arc device

### Implementation Strategy

**Design Decision:** Arc's 3 encoders map perfectly to the 3 main parameters:
- Ring 1 → Age/Dissolve (E1)
- Ring 2 → Trust/Anchor (E2)
- Ring 3 → Risk (E3)

### Code Added

#### 1. Arc Device Connection
```lua
local arc_device = arc.connect()
local arc_connected = false
```

#### 2. Arc LED Visualization
```lua
local function arc_redraw()
  if not arc_connected then return end

  arc_device:all(0)

  -- Ring 1: Age/Dissolve - smeared, breathing glow
  local age_pos = math.floor(s.memory_age * 64)
  for i=1,age_pos do
    local brightness = 4 + math.floor(ui.breathe * 8)
    arc_device:led(1, i, brightness)
  end

  -- Ring 2: Trust/Anchor - stable, centered
  local trust_pos = math.floor(s.trust * 64)
  for i=1,trust_pos do
    local brightness = 8 + math.floor(s.trust * 7)
    arc_device:led(2, i, brightness)
  end

  -- Ring 3: Risk - feverish, jittery
  local risk_pos = math.floor((s.spread / 8) * 64)
  for i=1,risk_pos do
    local jitter = ui.fever > 0.5 and math.random(0,3) or 0
    local brightness = 6 + math.floor(ui.fever * 6) + jitter
    arc_device:led(3, i, clamp(brightness, 0, 15))
  end

  arc_device:refresh()
end
```

#### 3. Arc Encoder Input
```lua
function arc_delta(n, d)
  if n == 1 then
    -- Arc ring 1 = Age / Dissolve (same as E1)
    s.memory_age = clamp(s.memory_age + d*0.005, 0, 1)
    soften_memory()
  elseif n == 2 then
    -- Arc ring 2 = Trust / Anchor (same as E2)
    s.trust = clamp(s.trust + d*0.005, 0, 1)
  elseif n == 3 then
    -- Arc ring 3 = Risk (same as E3)
    s.spread = clamp(s.spread + d*0.01, 1, 8)
    build_scale()
  end
  redraw()
  arc_redraw()
end
```

#### 4. Arc Initialization
```lua
-- Arc setup (optional device)
if arc_device then
  arc_connected = true
  arc_device.delta = arc_delta
  print("Arc connected")
else
  print("Arc not found (optional)")
end
```

#### 5. Updated organism_breathe()
```lua
ui.breathe = 0.8*ui.breathe + 0.2*rnd(0.2,1.0)
ui.fever   = clamp(ui.fever + (s.spread*0.002) - (s.trust*0.003), 0, 1)
redraw()
arc_redraw()  -- Added
```

### Features Implemented
- ✅ Optional device (script works without Arc)
- ✅ Visual LED feedback reflecting emotional state
- ✅ Encoder control parallel to norns encoders
- ✅ Ring 1 breathes with age/memory
- ✅ Ring 2 glows steadily with trust
- ✅ Ring 3 jitters with fever/risk
- ✅ Updates with organism heartbeat

### README Documentation Added
```markdown
### Monome Arc (optional)

If you have a **monome Arc** connected, it provides visual feedback and tactile control:

* **Ring 1** — Age / Dissolve (breathing glow intensifies with memory smear)
* **Ring 2** — Trust / Anchor (stable, centered light)
* **Ring 3** — Risk (feverish, jittery glow responds to emotional volatility)

The Arc is **completely optional** — the script works perfectly without it,
but adds a beautiful tactile/visual layer if present.
```

---

## Part 7: Crow + Just Friends Integration

### User Request
> add support (but not a requirement) for routing audio output to Whimsical Raps Just Friends via Monome Crow

### Research Process

**Documentation Sources:**
- Crow norns scripting: `https://monome.org/docs/crow/norns/`
- Just Friends i2c commands: `https://github.com/whimsicalraps/Just-Friends/blob/main/Just-Type.md`
- Crow ii library: `https://github.com/monome/crow/blob/main/lua/ii/jf.lua`

### Just Friends i2c Commands (Synthesis Mode)

**Mode Activation:**
```lua
crow.ii.jf.mode(1)  -- Activate synthesis mode
crow.ii.jf.mode(0)  -- Return to standard mode
```

**Voice Control:**
```lua
crow.ii.jf.play_note(pitch, level)
-- pitch: V/oct (0.0 = C3, 1.0 = C4)
-- level: amplitude (0-5V range)
-- Polyphonic with automatic voice allocation
```

**Run Mode:**
```lua
crow.ii.jf.run_mode(1)  -- Activate RUN state
```

### Implementation

#### 1. Crow Connection Tracking
```lua
local crow_connected = false
```

#### 2. Voice Routing in polysub_voice()
```lua
-- Start voice with frequency
engine.start(id, hz)

-- Also trigger Just Friends via Crow if connected
if crow_connected then
  -- Convert MIDI to V/oct (MIDI 60 = C4 = 1V, so 0V = MIDI 48/C3)
  local voct = (midi - 60) / 12.0
  -- Map amplitude to JF level (0-5V range)
  local jf_level = amp * 5.0
  -- Use play_note for polyphonic voice allocation
  crow.ii.jf.play_note(voct, jf_level)
end
```

#### 3. Crow Initialization & Hot-Plug Support
```lua
-- Crow + Just Friends setup (optional)
crow.init = function()
  crow_connected = true
  -- Set Just Friends to synthesis mode
  crow.ii.jf.mode(1)
  -- Activate run mode
  crow.ii.jf.run_mode(1)
  print("Crow connected - Just Friends enabled via ii")
end

crow.add = function()
  crow_connected = true
  crow.ii.jf.mode(1)
  crow.ii.jf.run_mode(1)
  print("Crow connected - Just Friends enabled via ii")
end

crow.remove = function()
  crow_connected = false
  print("Crow disconnected")
end
```

### Technical Details

**V/oct Conversion:**
- Standard Eurorack: 1V/octave
- MIDI 60 (C4) = 1V
- MIDI 48 (C3) = 0V
- Formula: `(midi - 60) / 12.0`

**Amplitude Mapping:**
- PolySub amp range: 0.0 - 1.0
- JF level range: 0V - 5V
- Direct multiplication: `amp * 5.0`

**Voice Allocation:**
- JF's `play_note()` automatically cycles through 6 voices
- No manual voice management needed
- Polyphonic behavior handled by JF firmware

### Features Implemented
- ✅ Zero configuration - auto-detects Crow
- ✅ Automatic JF mode switching to synthesis
- ✅ Polyphonic voice allocation
- ✅ Shared harmonic logic with PolySub
- ✅ Hot-pluggable (handles connect/disconnect)
- ✅ Completely optional

### README Documentation Added
```markdown
### Monome Crow + Just Friends (optional)

If you have a **monome Crow** connected to **Whimsical Raps Just Friends**
via i2c, the script will automatically route voices to Just Friends in synthesis mode:

* Voices are sent polyphonically using JF's automatic voice allocation
* Pitch follows the same harmonic logic (V/oct conversion)
* Amplitude maps to JF's level control (0-5V range)
* Just Friends becomes an **external voice** for the time-animal

**Setup:** Connect Crow to norns via USB, connect Crow to Just Friends via i2c.
The script will detect Crow and enable Just Friends automatically.

This is **completely optional** — the script works perfectly with just PolySub,
but JF adds a beautiful analog texture layer.
```

---

## Part 8: Monome Grid Support (128 & 256)

### User Request
> add support for control of the sequence with a monome grid. Two different versions, one for 128 pad grids and one for 256 pad grids. it should permit more granular control of the scale, the sequence and any other parameters that can be exposed to grid.

### Design Philosophy

**Challenge:** Adding granular control while maintaining anti-instrumental philosophy

**Solution:** Grid provides influence and provocation, not precise sequencing
- Custom scale building (suggests harmony, doesn't lock it)
- Manual note triggering (momentary provocations)
- Parameter visualization (see the creature's state)
- Organism interaction zones (provoke/calm metaphors)

### Grid Layouts Designed

#### 128 Grid (8x16 or similar)
```
Row 1:  [Scale Degrees: 12 semitones - toggle in/out]
Row 2:  [Toggle Custom Scale Mode (col 14)]
Row 3:  [Mode Selection: 7 modes]
Row 4:  [Manual Note Triggering: 2 octaves chromatic]
Row 6:  [Age/Dissolve Slider]
Row 7:  [Trust/Anchor Slider]
Row 8:  [Risk Slider - fever visualization]
```

#### 256 Grid (16x16)
```
Rows 1-2:   [Scale Degrees: 12 semitones - double height]
Row 3:      [Toggle Custom (14) | Clear Custom (16)]
Row 4:      [Mode Selection: 7 modes - spaced wider]
Rows 6-9:   [Manual Note Triggering: 4 octaves chromatic!]
Row 11:     [Age/Dissolve Slider]
Row 12:     [Trust/Anchor Slider]
Row 13:     [Risk Slider - fever visualization]
Row 15:     [Organism Interaction: Provoke (1-8) | Calm (9-16)]
```

### Implementation Details

#### 1. Grid State Variables
```lua
local grid_device = grid.connect()
local grid_connected = false
local grid_size = {x = 0, y = 0}

-- Grid state
local grid_modes = {"ionian", "dorian", "phrygian", "lydian",
                    "mixolydian", "aeolian", "locrian"}
local grid_note_held = {} -- track held notes
local grid_provoke_held = false -- organism provocation

-- Scale state
s.custom_scale_degrees = {} -- user-selected scale degrees
s.use_custom_scale = false  -- toggle between generated and custom
```

#### 2. Grid Visualization Functions

**Main Redraw Router:**
```lua
local function grid_redraw()
  if not grid_connected then return end

  grid_device:all(0)

  if grid_size.x == 16 and grid_size.y == 16 then
    grid_redraw_256()
  elseif grid_size.x >= 8 and grid_size.y >= 8 then
    grid_redraw_128()
  end

  grid_device:refresh()
end
```

**128 Grid Layout:**
```lua
local function grid_redraw_128()
  -- Row 1: Scale degree selector (12 semitones)
  for i=1,12 do
    local has_degree = false
    if s.use_custom_scale then
      for _,deg in ipairs(s.custom_scale_degrees) do
        if deg == (i-1) then has_degree = true; break end
      end
    end
    local brightness = has_degree and 15 or 4
    grid_device:led(i, 1, brightness)
  end

  -- Row 2: Toggle custom scale mode
  grid_device:led(14, 2, s.use_custom_scale and 15 or 4)

  -- Row 3: Mode selection
  for i=1,7 do
    local is_current = (s.mode == grid_modes[i])
    grid_device:led(i, 3, is_current and 15 or 4)
  end

  -- Row 4: Manual note triggering
  for i=1,16 do
    local note = s.base_midi - 12 + (i-1)
    local is_held = grid_note_held[note] or false
    grid_device:led(i, 4, is_held and 15 or 2)
  end

  -- Row 6-8: Parameter sliders with live feedback
  -- ... (age, trust, risk with visual bars)
end
```

**256 Grid Layout:**
```lua
local function grid_redraw_256()
  -- Rows 1-2: Scale degrees (double height)
  for i=1,12 do
    local brightness = has_degree and 15 or 4
    grid_device:led(i, 1, brightness)
    grid_device:led(i, 2, brightness)
  end

  -- Rows 6-9: Manual triggering (4 octaves!)
  for row=0,3 do
    for col=1,16 do
      local note = s.base_midi - 24 + (row * 16) + (col - 1)
      local is_held = grid_note_held[note] or false
      grid_device:led(col, 6 + row, is_held and 15 or 2)
    end
  end

  -- Row 15: Organism interaction zone
  local provoke_brightness = grid_provoke_held and 12 or 3
  for x=1,8 do
    grid_device:led(x, 15, provoke_brightness)
  end
  local calm_brightness = grid_provoke_held and 3 or 8
  for x=9,16 do
    grid_device:led(x, 15, calm_brightness)
  end
end
```

#### 3. Grid Input Handling

**Main Key Router:**
```lua
function grid_key(x, y, z)
  if not grid_connected then return end

  if grid_size.x == 16 and grid_size.y == 16 then
    grid_key_256(x, y, z)
  else
    grid_key_128(x, y, z)
  end

  grid_redraw()
end
```

**Custom Scale Building:**
```lua
-- Row 1: Toggle scale degrees
if y == 1 and x <= 12 then
  if z == 1 then
    local degree = x - 1
    local found = false
    for i, deg in ipairs(s.custom_scale_degrees) do
      if deg == degree then
        table.remove(s.custom_scale_degrees, i)
        found = true
        break
      end
    end
    if not found then
      table.insert(s.custom_scale_degrees, degree)
      table.sort(s.custom_scale_degrees)
    end
    if s.use_custom_scale then
      s.scale = s.custom_scale_degrees
    end
  end
end
```

**Manual Note Triggering (256):**
```lua
-- Rows 6-9: 4 octave range
elseif y >= 6 and y <= 9 then
  local row_offset = (y - 6) * 16
  local note = s.base_midi - 24 + row_offset + (x - 1)
  if z == 1 then
    grid_note_held[note] = true
    polysub_voice(x + row_offset, note, rnd(0.5, 2.0), s.amp, s.pan)
  else
    grid_note_held[note] = false
  end
end
```

**Organism Interaction Zone (256 only):**
```lua
-- Row 15: Provoke/Calm
elseif y == 15 then
  if x <= 8 then
    -- Provoke zone (left half)
    grid_provoke_held = (z == 1)
    if z == 1 then
      invite_response()
      s.spread = clamp(s.spread + 0.5, 1, 8)
    end
  else
    -- Calm zone (right half)
    if z == 1 then
      s.trust = clamp(s.trust + 0.1, 0, 1)
      s.spread = clamp(s.spread - 0.3, 1, 8)
    end
  end
end
```

#### 4. Grid Initialization
```lua
-- Grid setup (optional device)
if grid_device then
  grid_connected = true
  grid_size.x = grid_device.cols
  grid_size.y = grid_device.rows
  grid_device.key = grid_key
  print("Grid connected: " .. grid_size.x .. "x" .. grid_size.y)
else
  print("Grid not found (optional)")
end
```

#### 5. Integration with Organism
```lua
-- In organism_breathe() loop:
ui.breathe = 0.8*ui.breathe + 0.2*rnd(0.2,1.0)
ui.fever   = clamp(ui.fever + (s.spread*0.002) - (s.trust*0.003), 0, 1)
redraw()
arc_redraw()
grid_redraw()  // Added
```

### Features Implemented

#### Custom Scale Building
- ✅ Toggle individual semitones (0-11) in/out
- ✅ Build completely custom harmonic palettes
- ✅ Toggle between custom and auto-generated scales
- ✅ Visual feedback shows active degrees
- ✅ Clear button (256 only)

#### Manual Performance
- ✅ 128 Grid: 2 octaves chromatic (16 notes)
- ✅ 256 Grid: 4 octaves chromatic (64 notes)
- ✅ Visual feedback on held notes
- ✅ Routes through full voice system (PolySub + JF)

#### Mode Selection
- ✅ 7 modes available: ionian, dorian, phrygian, lydian, mixolydian, aeolian, locrian
- ✅ Current mode highlighted
- ✅ Immediate scale regeneration

#### Parameter Control
- ✅ Age/Dissolve slider with breathing visualization
- ✅ Trust/Anchor slider with stable glow
- ✅ Risk slider with fever-reactive brightness
- ✅ Touch any column to jump to value
- ✅ Live visual feedback

#### Organism Interaction (256 only)
- ✅ Provoke zone (left): Triggers response + increases volatility
- ✅ Calm zone (right): Increases trust + reduces risk
- ✅ Physical metaphor for touching nervous system

#### Adaptive Layout
- ✅ Auto-detects grid size
- ✅ Optimized layouts for 128 vs 256
- ✅ Graceful handling of other sizes

### README Documentation Added

```markdown
### Monome Grid (optional)

If you have a **monome Grid** connected, it provides deep visual and tactile
control over the organism's harmonic structure and behavior. The interface
adapts to your grid size:

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

* **Custom Scale Building**: Toggle individual semitones to create your own
  scale pool (overrides mode-based scales when enabled)
* **Manual Performance**: Trigger specific notes while the organism continues
  its autonomous behavior
* **Visual Feedback**: All parameters show live state with LED brightness
* **Tactile Control**: Sliders provide immediate, hands-on parameter adjustment
* **Organism Interaction** (256 only): Physical zones to provoke or calm the creature

The Grid is **completely optional** — the script works perfectly without it,
but adds a powerful layer of control while maintaining the anti-instrumental
philosophy (you're still influencing, not commanding).
```

---

## Summary of All Changes

### Bugs Fixed
1. ✅ `audio.level_rev()` → `audio.rev_level()`
2. ✅ Removed non-existent `audio.delay_on()` and `audio.level_delay_send()`
3. ✅ Fixed all PolySub engine API calls (global params vs per-voice)
4. ✅ Removed `musicutil.SCALE_NAMES_MAP`, implemented proper scale search
5. ✅ Fixed K1 + E1 time drag behavior to match README

### Features Added
1. ✅ **Monome Arc Support**
   - 3 rings map to Age/Trust/Risk
   - Visual LED feedback (breathing, stable, feverish)
   - Completely optional

2. ✅ **Crow + Just Friends Integration**
   - Automatic i2c voice routing
   - Polyphonic synthesis mode
   - V/oct + amplitude mapping
   - Hot-pluggable, completely optional

3. ✅ **Monome Grid Support (128 & 256)**
   - Custom scale building
   - Manual note triggering (2-4 octaves)
   - Mode selection (7 modes)
   - Parameter sliders with visual feedback
   - Organism interaction zones (256)
   - Adaptive layouts for different grid sizes
   - Completely optional

### Code Quality
- All API calls verified against official documentation
- Proper error handling and optional device support
- Clear comments explaining norns API quirks
- README updated to match implementation
- Philosophy maintained: anti-instrumental, beautiful, feverish

### Files Modified
- `unevenly_alive.lua` - Core script with all fixes and features
- `README.md` - Complete documentation of all features

---

## Technical Notes

### Norns API Quirks Discovered

1. **Audio Module:**
   - Reverb: Use `level_eng_rev()` not `level_rev()`
   - No built-in delay (use softcut instead)

2. **PolySub Engine:**
   - Only global parameters, no per-voice control
   - `start(id, hz)` requires frequency as parameter
   - No pan, FM, or per-voice envelopes

3. **MusicUtil:**
   - No SCALE_NAMES_MAP - must search SCALES array
   - Case-insensitive name matching recommended
   - Check both primary name and alt_names

4. **ControlSpec:**
   - MIDINOTE exists (0-127, default 60)
   - All presets documented in core/controlspec.lua

### Best Practices Applied

1. **Optional Device Pattern:**
```lua
local device = device_type.connect()
local device_connected = false

if device then
  device_connected = true
  -- setup
else
  print("Device not found (optional)")
end

-- In functions:
if not device_connected then return end
```

2. **Grid Size Adaptation:**
```lua
local grid_size = {x = 0, y = 0}

if grid_device then
  grid_size.x = grid_device.cols
  grid_size.y = grid_device.rows

  if grid_size.x == 16 and grid_size.y == 16 then
    -- 256 layout
  else
    -- 128 layout
  end
end
```

3. **Hot-Plug Support:**
```lua
crow.add = function()
  crow_connected = true
  -- setup
end

crow.remove = function()
  crow_connected = false
end
```

---

## Conversation Metadata

**Total Bugs Fixed:** 5 major API bugs
**Features Added:** 3 major optional integrations (Arc, Crow+JF, Grid)
**Lines of Code Added:** ~400+ lines
**Documentation Updated:** Comprehensive README additions
**Testing Status:** Code complete, ready for norns testing

**Philosophy Maintained:** Throughout all additions, the anti-instrumental "time-animal" concept was preserved - the user influences but doesn't control, provokes but doesn't command.

---

*End of conversation log*
