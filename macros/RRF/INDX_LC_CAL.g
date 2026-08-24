; INDX_LC_CAL - compute the load-cell scale (M558 V, grams per count) under the known force
;
; Guard-only: performs NO motion. Run AFTER INDX_TARE, with a passive tool seated by hand
; and the latch fully seated via INDX_CLOSE_CAL. Full sequence: see INDX_TARE header.
;
; Reads the RAW cell reading under the seated force the same way INDX_TARE does: send M558.4
; (tare) and read the latched baseline from sensors.probes[0].value[1]. The tool board latches
; that baseline from a rolling average of the RAW ADC value, so it is an absolute count.
;
; This matters because between probing moves the board continuously tracks the baseline to
; follow thermal drift, and a step such as locking a tool decays out of the tared reading
; (value[0]) within about 1.5 seconds. Measuring value[0] gives a delta near zero and a
; nonsense scale; the latched baseline is immune to it and has no timing constraint.
;
; Averages it, and computes:
;   scale (g/count) = -(locking_force / (mean_loaded - INDX_LC_offset))
; Two checks run before anything is stored, and they mean different things: the reading must
; move at all (a dead or disconnected cell), and the resulting scale must be plausible (the
; cell responded, but the tool is not properly seated or the locking force is wrong).
;
; The result must fall inside global.INDX_LC_scale_limits (magnitude). If it does not, the
; macro aborts WITHOUT changing the stored scale and sets INDX_LC_calibrated = false, so a bad
; reading cannot end up driving the probe. Otherwise it stores the value in global.INDX_LC_scale,
; applies it to load-cell probe K0 with M558 V, and sets INDX_LC_calibrated = true.
;
; SIGN: the firmware needs the force to read POSITIVE when the nozzle is pushed toward the bed
; (sensors.probes[0].loadCell.force in DWC). Locking a tool pulls the latch against the cell, which
; loads it in the OPPOSITE direction to bed contact, so the ratio measured here is negated to
; give the probing sign. INDX_LC_CALIBRATE confirms this on the machine and can invert it if a
; particular head is built the other way round.
;
; Optional S parameter overrides the locking force in grams (default global.INDX_LC_locking_force):
;   M98 P"INDX_LC_CAL.g" S1600      (P and R cannot be used as parameter letters)

; --- required globals ---
if !exists(global.INDX_LC_offset) || !exists(global.INDX_LC_scale) || !exists(global.INDX_LC_samples) || !exists(global.INDX_LC_locking_force) || !exists(global.INDX_LC_calibrated)
  abort "INDX_LC_CAL: load cell globals missing. INDX_variables.g must run from config.g first."
if !exists(global.INDX_LC_scale_limits)
  abort "INDX_LC_CAL: global.INDX_LC_scale_limits missing. Re-run INDX_variables.g."

; --- preconditions (no motion, just guards) ---
if move.axes[0].homed = false || move.axes[1].homed = false
  abort "INDX_LC_CAL: home X and Y first (G28 X Y)."
if global.INDX_State = -1
  abort "INDX_LC_CAL: latch is open. Seat a tool by hand and run INDX_CLOSE_CAL first."

; known locking force: S param overrides the global
var grams = exists(param.S) ? param.S : global.INDX_LC_locking_force
if var.grams <= 0
  abort "INDX_LC_CAL: locking force must be > 0 g."
var dbg = exists(global.INDX_LC_DEBUG) ? global.INDX_LC_DEBUG : 0

; The unloaded baseline is not persisted across reboots, precisely so that this check bites: a
; baseline captured days ago would be stale, because the raw zero of the cell drifts with
; temperature, and the resulting scale error would be small enough to pass the range check
; below while still being wrong. INDX_TARE must have run in this session.
if global.INDX_LC_offset = 0
  abort "INDX_LC_CAL: no unloaded baseline. Run INDX_OPEN with no tool, then INDX_TARE, before calibrating."

var samples = global.INDX_LC_samples
if var.samples < 1
  set var.samples = 1

; --- settle, then average under load ---
G4 P500

var i = 0
var reading = 0.0
var sum = 0.0
var vmin = 0.0
var vmax = 0.0

while var.i < var.samples
  M558.4 K0                        ; latch the raw rolling average as the baseline
  G4 P100                          ; let the ~50ms rolling average refresh before the next latch
  set var.reading = sensors.probes[0].value[1]
  set var.sum = var.sum + var.reading
  if var.i = 0
    set var.vmin = var.reading
    set var.vmax = var.reading
  else
    if var.reading < var.vmin
      set var.vmin = var.reading
    if var.reading > var.vmax
      set var.vmax = var.reading
  set var.i = var.i + 1
  G4 P50

var mean  = var.sum / var.samples
var delta = var.mean - global.INDX_LC_offset

; --- dead cell check: did the reading move at all? ---
; This catches a load cell that is not responding while its ADC still converts happily - a
; broken or disconnected cell reads a steady value, so the delta collapses to noise. It is
; deliberately NOT a "is the force plausible" check; the scale range check below does that.
;
; Sizing the threshold: the raw ADC noise is about +/-50 counts, a tare latches a 64-sample
; rolling average of it (so about +/-6 counts), and this macro averages INDX_LC_samples of
; those, leaving a few counts. 100 counts clears that and the thermal drift between running
; INDX_TARE and this macro, while sitting far below any genuine reading - the largest scale
; allowed by INDX_LC_scale_limits still needs locking_force/scale_max counts, e.g. 1600g at
; 0.5 g/count = 3200 counts, so a working cell is at least 30x above this threshold.
var min_delta = 100    ; counts; below this the cell is not responding at all
if abs(var.delta) < var.min_delta
  set global.INDX_LC_calibrated = false
  abort {"INDX_LC_CAL: load cell not responding - reading moved only " ^ var.delta ^ " counts (unloaded " ^ global.INDX_LC_offset ^ ", loaded " ^ var.mean ^ "). Check the load cell wiring and the C pin in the M558 in config.g."}

; --- compute the scale ---
; negated because locking loads the cell opposite to bed contact (see SIGN in the header)
var scale = -(var.grams / var.delta)

; --- sanity check the result before storing it ---
; A plausible scale for this cell sits within global.INDX_LC_scale_limits (magnitude, sign
; ignored). Outside that range the reading did not come from a properly seated tool - a partial
; seat, a cell fault, or the wrong locking force - and using it would give a wildly wrong probe
; trigger force. The stored scale is left untouched and the cell is marked uncalibrated so
; nothing probes with a bad value.
var lo = global.INDX_LC_scale_limits[0]
var hi = global.INDX_LC_scale_limits[1]
if abs(var.scale) < var.lo || abs(var.scale) > var.hi
  set global.INDX_LC_calibrated = false
  echo {"INDX_LC_CAL: computed " ^ var.scale ^ " g/count from " ^ var.delta ^ " counts at " ^ var.grams ^ " g."}
  abort {"INDX_LC_CAL: scale outside the allowed range " ^ var.lo ^ " to " ^ var.hi ^ " g/count. Scale NOT updated, cell marked uncalibrated. Check the tool is fully seated and INDX_CLOSE_CAL locked it."}

; --- store and APPLY the scale to load-cell probe K0 ---
set global.INDX_LC_scale = var.scale
set global.INDX_LC_calibrated = true
M558 K0 V{global.INDX_LC_scale}

if var.dbg > 0
  echo {"INDX_LC_CAL: loaded mean = " ^ var.mean ^ " counts  (spread " ^ (var.vmax - var.vmin) ^ ")"}
  echo {"INDX_LC_CAL: delta = " ^ var.delta ^ " counts at " ^ var.grams ^ " g  ->  M558 V = " ^ var.scale ^ " g/count"}
  echo "INDX_LC_CAL: applied M558 K0 V. Verify the force sign (see header), persist with INDX_WRITE_STATE, then homez."
