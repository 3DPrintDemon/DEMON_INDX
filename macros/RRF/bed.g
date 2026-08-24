; bed.g - iterative 3-point leadscrew levelling using the INDX load-cell probe
;
; Run by G32. Z MUST already be homed (run homez first) so all points share one Z frame.
; Do NOT re-home / re-datum between points - the leadscrew solve uses the DIFFERENCES between
; the point heights, so a mid-sequence re-datum erases the tilt.
;
; The probe settings (speed, dive heights, averaging) come from the M558 in config.g; this
; macro does not change them. The load cell tares automatically at the start of every probing
; move. G30 P{n} moves to the point, dives from the configured dive height and records it; the
; last point adds S3 to solve and adjust the 3 leadscrews (M671 geometry).
;
; The pass repeats up to maxpass times, stopping early once the pre-correction deviation
; (move.calibration.initial.deviation - the tilt measured that pass) is below tol.

if move.axes[2].homed = false
  abort "bed.g: home Z first (homez) - the points must share one Z frame."
if global.INDX_State = -1
  abort "bed.g: no tool loaded - the nozzle probes the bed."
if global.INDX_LC_calibrated = false
  abort "bed.g: load cell not calibrated (run INDX_LC_CALIBRATE)."

; probe points (near each leadscrew) - keep in sync with M671 in config.g
var px = {-115, 0, 115}
var py = {-100, 118, -100}
var np = #var.px

var dbg = exists(global.INDX_LC_DEBUG) ? global.INDX_LC_DEBUG : 0
var tol     = 0.05                  ; mm; stop once the measured corner deviation is below this
var maxpass = 5                     ; safety cap on levelling passes
var i = 0
var pass = 0
var done = false

; A pre-level bed can sit below the Z=0 datum at the corners. G30 probing ignores the M208
; Z min; the G1 positioning moves use H2 so they are allowed below it too, without changing
; any global limit.

while var.pass < var.maxpass
  ; --- one 3-point pass ---
  set var.i = 0
  while var.i < var.np
    ; Move to the point here rather than letting G30 P do it, then pause. Dragging the filament
    ; feed tube loads the cell as the head travels, and probing immediately on arrival reports a
    ; false trigger. The dwell lets that settle before the probing move tares and starts.
    G90
    G1 H2 Z5 F1200
    G1 X{var.px[var.i]} Y{var.py[var.i]} F12000
    G4 S0.5
    if var.i < var.np - 1
      G30 P{var.i} X{var.px[var.i]} Y{var.py[var.i]} Z-99999
    else
      G30 P{var.i} X{var.px[var.i]} Y{var.py[var.i]} Z-99999 S3
    set var.i = var.i + 1

  ; --- pass complete: S3 has levelled and reported the pre-correction deviation ---
  if var.dbg > 0
    echo {"bed.g pass " ^ (var.pass + 1) ^ ": deviation " ^ move.calibration.initial.deviation ^ " mm"}
  if abs(move.calibration.initial.deviation) < var.tol
    set var.done = true
    break
  set var.pass = var.pass + 1

; lift clear
G90
G1 H2 Z5 F1200

if var.dbg > 0
  if var.done
    echo {"bed.g: levelled, deviation " ^ move.calibration.initial.deviation ^ " mm"}
  else
    echo {"bed.g: still " ^ move.calibration.initial.deviation ^ " mm after " ^ var.maxpass ^ " passes"}
