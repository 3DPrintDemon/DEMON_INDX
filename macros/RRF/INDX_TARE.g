; INDX_TARE - capture the empty-head baseline for load-cell CALIBRATION
;
; Guard-only: performs NO motion. This is a CALIBRATION step only. At runtime the
; firmware auto-tares at the start of every probing move, so no manual tare is needed
; for homing/probing - this macro exists purely to measure the unloaded reference the
; scale calculation needs.
;
; Full calibration sequence (each named step is a separate macro):
;   1. G28 X Y            ; Z is NOT homed yet - it needs the calibrated cell
;   2. INDX_OPEN          ; latch open, NO tool mounted
;   3. INDX_TARE          ; this macro - stores the unloaded baseline
;   4. (seat a passive tool on the Smart Head by hand)
;   5. INDX_CLOSE_CAL     ; locks + seats the full ~1600 g force onto the cell
;   6. INDX_LC_CAL        ; computes grams/count (M558 V) against the known force
;   7. SAVE / persist     ; via INDX_WRITE_STATE
;
; Stores the unloaded RAW cell reading in global.INDX_LC_offset. INDX_LC_CAL subtracts this
; from the loaded reading to get the counts-per-force delta.
;
; The reading is taken by sending M558.4 (tare) and then reading the resulting baseline from
; sensors.probes[0].value[1]. That is important: the tool board latches the baseline from a
; rolling average of the RAW ADC value, so it is an absolute count, unaffected by the tracking
; described below.
;
; Do NOT use value[0] for this. Between probing moves the board continuously tracks the
; baseline to follow thermal drift, and a step such as locking a tool decays out of value[0]
; within about 1.5 seconds - a calibration based on it measures almost nothing.

; --- required globals ---
if !exists(global.INDX_LC_offset) || !exists(global.INDX_LC_samples)
  abort "INDX_TARE: load cell globals missing. INDX_variables.g must run from config.g first."

; --- preconditions (no motion, just guards) ---
if move.axes[0].homed = false || move.axes[1].homed = false
  abort "INDX_TARE: home X and Y first (G28 X Y)."
if global.INDX_State != -1
  abort "INDX_TARE: latch must be OPEN with NO tool. Run INDX_OPEN first (global.INDX_State must be -1)."

var samples = global.INDX_LC_samples
if var.samples < 1
  set var.samples = 1
var dbg = exists(global.INDX_LC_DEBUG) ? global.INDX_LC_DEBUG : 0

; --- settle, then average several latched baselines ---
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

var mean = var.sum / var.samples
set global.INDX_LC_offset = var.mean

if var.dbg > 0
  echo {"INDX_TARE: offset = " ^ var.mean ^ " counts  (mean of " ^ var.samples ^ " reads, spread " ^ (var.vmax - var.vmin) ^ ")"}
  echo "INDX_TARE: done. Seat a passive tool by hand, run INDX_CLOSE_CAL, then INDX_LC_CAL."
