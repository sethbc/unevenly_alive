-- unevenly_alive.lua
-- a feverish but beautiful time-animal
-- by you + chatgpt

engine.name = "PolySub" -- lush & stable enough to stay beautiful

local musicutil = require "musicutil"
local softcut = softcut
local arc_device = arc.connect()
local crow_connected = false

-- ---------- STATE ----------
local s = {
  started = false,
  base_midi = 60,      -- learned center
  mode = "ionian",     -- starting mood; will morph
  scale = {},          -- active scale degrees (diatonic + color tones)
  spread = 5,          -- harmonic risk (E3)
  trust = 0.4,         -- harmonic center bias (E2)
  memory_age = 0.3,    -- smear/forget (E1)
  micro = 0.04,        -- microtonal drift in semitones
  heart = 0.11,        -- internal pulse (in beats) for organism updates
  obeys_time_drag = 0.6,
  last_offer_t = 0,
  amp = 0.3,
  pan = 0,
  rev = 0.28,
  del = 0.22,
}

local ui = { blink = 0, breathe = 0, fever = 0, k1_held = false }
local arc_connected = false

-- ---------- UTIL ----------
local function lerp(a,b,t) return a + (b-a) * t end
local function clamp(x,a,b) return math.max(a, math.min(b, x)) end
local function rnd(a,b) return a + (b-a) * math.random() end
local function sign(x) return x < 0 and -1 or 1 end

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
  local pool = {}
  for i=1,#degrees do table.insert(pool, degrees[i]) end
  -- add beautiful color tones depending on risk
  if s.spread > 3 then table.insert(pool, 14) end -- 9th
  if s.spread > 4 then table.insert(pool, 17) end -- 11th
  if s.spread > 5 then table.insert(pool, 9)  end -- 6th
  s.scale = pool
end

local function choose_note()
  -- center vs risk: biased roulette
  local bias = clamp(1.2 - s.trust, 0.1, 1.0)
  local deg = s.scale[math.random(#s.scale)]
  local octave = math.floor(rnd(-1, 2))
  local n = s.base_midi + deg + (12 * octave)

  -- pull toward center by trust
  n = lerp(n, s.base_midi, s.trust * 0.6)

  -- micro drift: always small, keeps it pretty
  n = n + rnd(-s.micro, s.micro)

  -- limit spread gracefully
  n = clamp(n, s.base_midi - (7 + s.spread), s.base_midi + (9 + s.spread))
  return n
end

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

  -- Also trigger Just Friends via Crow if connected
  if crow_connected then
    -- Convert MIDI to V/oct (MIDI 60 = C4 = 1V, so 0V = MIDI 48/C3)
    local voct = (midi - 60) / 12.0
    -- Map amplitude to JF level (0-5V range)
    local jf_level = amp * 5.0
    -- Use play_note for polyphonic voice allocation
    crow.ii.jf.play_note(voct, jf_level)
  end
end

-- ---------- SOFTCUT MEMORY (misremembering) ----------
local function softcut_setup()
  audio.level_adc_cut(1.0)
  audio.level_eng_cut(1.0)
  for i=1,2 do
    softcut.enable(i,1)
    softcut.buffer(i, i) -- use both buffers
    softcut.level(i, 0.9)
    softcut.level_input_cut(1, i, 1.0)
    softcut.level_input_cut(2, i, 0.0)
    softcut.rec(i, 1)
    softcut.rec_level(i, 0.45) -- gentle imprint
    softcut.pre_level(i, 0.85 - s.memory_age*0.5) -- higher age -> more smear
    softcut.loop(i, 1)
    softcut.loop_start(i, 0)
    softcut.loop_end(i, 8 + i) -- different lengths to avoid loops aligning
    softcut.rate(i, (i==1 and 1.0 or 0.997)) -- slow phasing
    softcut.fade_time(i, 0.15 + s.memory_age*0.3)
    softcut.position(i, 0)
    softcut.play(i, 1)
    softcut.pan(i, i==1 and -0.3 or 0.3)
    softcut.filter_dry(i, 0.1)
    softcut.post_filter_dry(i, 0.1)
  end
end

local function soften_memory()
  for i=1,2 do
    softcut.pre_level(i, clamp(0.85 - s.memory_age*0.5, 0.2, 0.9))
    softcut.fade_time(i, clamp(0.15 + s.memory_age*0.35, 0.05, 1.2))
  end
end

-- ---------- ARC VISUALIZATION ----------
local function arc_redraw()
  if not arc_connected then return end

  arc_device:all(0)

  -- Ring 1: Age/Dissolve (E1) - smeared, breathing glow
  local age_pos = math.floor(s.memory_age * 64)
  for i=1,age_pos do
    local brightness = 4 + math.floor(ui.breathe * 8)
    arc_device:led(1, i, brightness)
  end

  -- Ring 2: Trust/Anchor (E2) - stable, centered
  local trust_pos = math.floor(s.trust * 64)
  for i=1,trust_pos do
    local brightness = 8 + math.floor(s.trust * 7)
    arc_device:led(2, i, brightness)
  end

  -- Ring 3: Risk (E3) - feverish, jittery
  local risk_pos = math.floor((s.spread / 8) * 64)
  for i=1,risk_pos do
    local jitter = ui.fever > 0.5 and math.random(0,3) or 0
    local brightness = 6 + math.floor(ui.fever * 6) + jitter
    arc_device:led(3, i, clamp(brightness, 0, 15))
  end

  arc_device:refresh()
end

-- ---------- ORGANISM ----------
local function organism_breathe()
  while true do
    -- heartbeat pace varies slightly with risk/age
    local beat = s.heart + (s.spread*0.01) + rnd(-0.03, 0.03)
    clock.sleep(beat)

    -- gentle pan drift, small amp fever
    s.pan = clamp(s.pan + rnd(-0.08,0.08), -0.5, 0.5)
    s.amp = clamp(s.amp + rnd(-0.02,0.02) + s.spread*0.002 - s.trust*0.003, 0.18, 0.42)

    -- spontaneous apparition: more likely if ignored; never harsh
    local idle = util.time() - s.last_offer_t
    local p = clamp(0.08 + idle*0.006 + s.spread*0.02 - s.trust*0.03, 0.05, 0.55)
    if math.random() < p then
      local n = choose_note()
      polysub_voice(1, n, rnd(0.5, 2.4), s.amp, s.pan)
      -- optional upper harmony (carefully)
      if math.random() < 0.35 + s.spread*0.04 then
        polysub_voice(2, n + (math.random() < 0.5 and 7 or 12), rnd(0.4, 1.8), s.amp*0.7, -s.pan*0.8)
      end
    end

    -- slow mood drift across sibling modes (kept pretty)
    if math.random() < 0.1 + s.spread*0.01 - s.trust*0.02 then
      local modes = {"ionian","lydian","mixolydian","dorian"} -- friendly palette
      s.mode = modes[math.random(#modes)]
      build_scale()
    end

    ui.breathe = 0.8*ui.breathe + 0.2*rnd(0.2,1.0)
    ui.fever   = clamp(ui.fever + (s.spread*0.002) - (s.trust*0.003), 0, 1)
    redraw()
    arc_redraw()
  end
end

-- ---------- INPUT & “OFFERS” ----------
local function capture_offer()
  -- mark the moment and let softcut imprint
  s.last_offer_t = util.time()
  -- set base key from input analysis proxy (simplified: sample the currently heard pitch?)
  -- since we’re not doing pitch detection here (kept simple),
  -- let E2 anchor base_midi later; the organism will still sound great without it.
end

local function invite_response()
  local n = choose_note()
  polysub_voice(3, n, rnd(0.6, 2.2), s.amp*0.85, -s.pan)
  if math.random() < 0.4 then
    polysub_voice(4, n-5, rnd(0.5, 1.6), s.amp*0.6, s.pan*0.6)
  end
end

-- ---------- ARC INPUT ----------
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

-- ---------- NORNS LIFECYCLE ----------
function init()
  params:add_separator("unevenly / alive")
  params:add_control("base_note","seed center", controlspec.MIDINOTE)
  params:set_action("base_note", function(v) s.base_midi = math.floor(v) end)
  params:set("base_note", 60)

  audio.level_cut(1.0)
  audio.level_eng(1.0)
  audio.rev_on()
  audio.level_eng_rev(clamp(0.2 + s.memory_age*0.2, 0.1, 0.5))
  audio.level_tape(0.0)
  -- Note: norns doesn't have built-in audio.delay_on/level_delay_send
  -- Delay effect is handled by softcut buffers instead

  -- Initialize PolySub global parameters
  engine.ampRel(0.9)
  engine.level(0.3)
  engine.cut(2200)
  engine.shape(0.2)
  engine.timbre(0.5)

  build_scale()
  softcut_setup()

  -- Arc setup (optional device)
  if arc_device then
    arc_connected = true
    arc_device.delta = arc_delta
    print("Arc connected")
  else
    print("Arc not found (optional)")
  end

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

  clock.run(organism_breathe)
  s.started = true
  redraw()
  arc_redraw()
end

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
  elseif n==2 then -- Trust / Anchor
    s.trust = clamp(s.trust + d*0.01, 0, 1)
  elseif n==3 then -- Risk
    s.spread = clamp(s.spread + d*0.02, 1, 8)
    build_scale()
  end
  redraw()
end

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

-- ---------- TINY, CRYPTIC UI ----------
local gfx = require "screen"
function redraw()
  screen.clear()
  screen.aa(1)
  screen.level(2)

  -- organism glyph: a breathing, off-center oval that fuzzes with fever
  local cx = 64 + math.sin(util.time()*0.37)*6
  local cy = 32 + math.cos(util.time()*0.21)*4
  local r  = 10 + s.trust*6 + ui.breathe*4
  for i=1,6 do
    local jitter = (ui.fever*2) + rnd(-0.6,0.6)
    screen.circle(cx + rnd(-1,1), cy + rnd(-1,1), r + jitter + i*0.6)
    screen.stroke()
  end

  -- tiny runes (not labels)
  screen.level(1)
  screen.move(5,60);  screen.text("age")
  screen.move(40,60); screen.text("trust")
  screen.move(85,60); screen.text("risk")

  -- subtle meters
  screen.level(3)
  screen.move(5,64);  screen.line_rel(s.memory_age*30,0); screen.stroke()
  screen.move(40,64); screen.line_rel(s.trust*30,0);      screen.stroke()
  screen.move(85,64); screen.line_rel((s.spread/8)*40,0); screen.stroke()

  screen.update()
end

function cleanup()
  -- let it die quietly
end