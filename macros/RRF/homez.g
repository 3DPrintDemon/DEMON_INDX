; homez - Z home with the INDX load-cell probe
;
; One probe at the configured probe point sets the Z datum. The probe settings (speed, dive
; heights, and how many probes are averaged per point) come from the M558 in config.g; this
; macro does not change them. The load cell tares automatically at the start of every probing
; move, so no manual tare is needed.
;
; A tool MUST be loaded (the nozzle is the probe contact). X and Y must be homed.

if move.axes[0].homed = false || move.axes[1].homed = false
  abort "homez: home X and Y first (G28 X Y)."
if global.INDX_State = -1
  abort "homez: no tool loaded - the nozzle probes the bed."
if global.INDX_LC_calibrated = false
  abort "homez: load cell not calibrated (run INDX_LC_CALIBRATE)."

; Sanity check the probe's G31 settings. Re-creating a probe - any M558 with a P parameter -
; resets G31 to firmware defaults (threshold 500, trigger height 0.7mm), and nothing complains.
; For the load cell the threshold is a force in grams and the trigger height must be close to
; zero, because the nozzle is touching the bed when it triggers. A small non-zero value is
; legitimate - it compensates for deflection under the trigger force - so allow +/-0.1mm, which
; still catches the 0.7mm default. Left unnoticed this probes at ten times the intended force
; and sets the datum 0.7mm out.
if sensors.probes[0].threshold != global.INDX_LC_trigger_grams
  abort {"homez: probe threshold is " ^ sensors.probes[0].threshold ^ "g, expected " ^ global.INDX_LC_trigger_grams ^ "g. G31 has been reset - run M98 P""INDX_variables.g""."}
if abs(sensors.probes[0].triggerHeight) > 0.1
  abort {"homez: probe trigger height is " ^ sensors.probes[0].triggerHeight ^ "mm, expected near 0. G31 has been reset - run M98 P""INDX_variables.g""."}

var dbg = exists(global.INDX_LC_DEBUG) ? global.INDX_LC_DEBUG : 0

; Clear any active height map first. Mesh compensation shifts Z by the map value at the current
; XY, so homing with it enabled sets the datum on the compensated surface rather than the real
; bed. Reload the map with G29 S1 (or re-run G29) after homing.
; G32 does not need this - the firmware clears the map itself when leadscrew levelling runs.
G29 S2

; probe point = configured bed centre (global.INDX_probe_x/y, machine coords) minus the probe
; XY offset so the PROBE lands there (for the load cell the offset is 0).
var px = (exists(global.INDX_probe_x) ? global.INDX_probe_x : 0) - sensors.probes[0].offsets[0]
var py = (exists(global.INDX_probe_y) ? global.INDX_probe_y : 0) - sensors.probes[0].offsets[1]

; optional XY fuzz: offset the probe point by +/- fuzz so the bed is not always tapped at the
; same spot (spreads wear). 0 = always the configured point.
var fuzz = 0.0
if exists(global.INDX_LC_probe_fuzz)
  set var.fuzz = global.INDX_LC_probe_fuzz
var fx = var.px
var fy = var.py
if var.fuzz > 0
  set var.fx = {var.px + (random(2001) - 1000) / 1000.0 * var.fuzz}
  set var.fy = {var.py + (random(2001) - 1000) / 1000.0 * var.fuzz}

; position over the (optionally fuzzed) probe point near bed centre
G91
G1 H2 Z5 F600
G90
G1 X{var.fx} Y{var.fy} F12000

; probe and set the Z datum
G30
if var.dbg > 0
  echo {"homez: Z datum set. preload " ^ sensors.probes[0].loadCell.preload ^ " g"}

; verification (debug only): one more probe in the corrected datum - should read ~0.
;
; G30 sets the machine Z coordinate to the G31 trigger height, so this should read the trigger
; height - zero for the load cell, since the nozzle is on the bed when it triggers. A reading of
; 0.7 means G31 is at its firmware default, which the guard above now catches.
;
; Note the two probes are not the same operation: the G30 above taps up to the M558 A count and
; averages, while G30 S-1 taps exactly once. A disagreement of a few microns is expected.
if var.dbg > 0
  G90
  G1 Z2 F600
  G30 S-1
  echo {"homez: verify Z = " ^ move.axes[2].machinePosition ^ " mm (expect ~0), user " ^ move.axes[2].userPosition ^ " mm"}

; lift clear of the bed, then park 1 mm inside the configured X and Y minimum limits
G90
G1 Z5 F600
G1 X{move.axes[0].min + 1} Y{move.axes[1].min + 1} F12000

; Reload the height map cleared at the start, so normal operation ends with mesh compensation
; active again. Commented out until the mesh investigation is finished.
;G29 S1
