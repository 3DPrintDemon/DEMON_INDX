; mesh.g - bed mesh with either probe, selected by the K parameter
;
; RRF runs this file when G29 is sent with no S parameter, and passes any parameters through:
;   G29        -> SZP scanning probe (default)
;   G29 K1     -> SZP scanning probe
;   G29 K0     -> INDX load cell, i.e. the nozzle touches the bed at each point
;
; Each probe needs its own grid, so the grid is set here rather than in config.g: M557 defines
; one grid at a time, and the SZP normally uses a finer pitch than the load cell because it does
; not have to touch the bed so its quicker. The M557 in config.g is only the power-up default.
;
; The grid can be overridden per run, so a print start script can mesh just the area it needs:
;   G29 K0 X{-50,50} Y{-40,40} S25
;   X{min,max}  grid limits in X       (array of 2; defaults below if omitted)
;   Y{min,max}  grid limits in Y       (array of 2; defaults below if omitted)
;   I<spacing>  point spacing in mm, applied to both axes (defaults below if omitted)
;   J<spacing>  optional Y spacing; when given, I sets the X spacing only
;   F"name.csv" optional extra copy of the height map, for keeping a series of runs apart. The
;               per-probe copy below is written as well, so heightmap_loadcell.csv is always the
;               most recent load cell run whatever F was given
;
; X and Y take two values and must be written as arrays, e.g. X{-50,50}. I and J take a single
; value each: I{30,20} is NOT accepted, use I30 J20.
;
; Use I, not S, for the spacing when calling this through G29: G29 reads S as its own
; subfunction number (S0 probe, S1 load, S2 clear...), so a spacing in S never reaches this
; file and G29 fails with "Bad or missing parameter".
;
; The firmware moves the head so the PROBE is over each grid point, using the G31 X/Y offsets,
; so the grids below are in probe coordinates and each one must be reachable by that probe.
; The SZP sits behind the nozzle, so its grid can extend further back and less far forward.
;
; Height maps written, so the last run of each probe is always available for comparison:
;   heightmap.csv            the run that just finished - this is the active map
;   heightmap_loadcell.csv   the last load cell run
;   heightmap_SZP.csv        the last SZP run
;
; X and Y must be homed and a tool must be loaded: both routes establish the Z datum with the
; load cell, which needs the nozzle.

; --- grid defaults come from INDX_variables.g, one set for both probes ---
; global.INDX_mesh_min / INDX_mesh_max are {X,Y} in probe coordinates, INDX_mesh_spacing is mm.
; The SZP window is derived from them below, so there is nothing per-probe to keep in step.
var szp_range = 1.7                ; mm; M558.1 calibration scan range
var clearance = 2                  ; mm; margin kept off the axis end stops

var probe = exists(param.K) ? param.K : 1
if var.probe != 0 && var.probe != 1
  abort "mesh.g: K must be 0 (INDX load cell) or 1 (SZP)."
; fail clearly if the requested probe is not configured on this machine, rather than part way
; through a scan. sensors.probes only counts up to the highest probe defined by an M558.
if #sensors.probes <= var.probe
  abort {"mesh.g: probe K" ^ var.probe ^ " does not exist on this machine. Only " ^ #sensors.probes ^ " probe(s) are configured - check the M558 commands in config.g."}
if sensors.probes[var.probe].type = 0
  abort {"mesh.g: probe K" ^ var.probe ^ " is type 0 (none), so it is declared but not usable. Check its M558 in config.g."}
if var.probe = 0 && sensors.probes[0].type != 12
  abort {"mesh.g: probe K0 is type " ^ sensors.probes[0].type ^ ", expected 12 (load cell)."}
if move.axes[0].homed = false || move.axes[1].homed = false
  abort "mesh.g: home X and Y first (G28 X Y)."
if global.INDX_State = -1
  abort "mesh.g: no tool loaded - the Z datum is set by nozzle contact."
if global.INDX_LC_calibrated = false
  abort "mesh.g: load cell not calibrated (run INDX_LC_CALIBRATE)."

var dbg = exists(global.INDX_LC_DEBUG) ? global.INDX_LC_DEBUG : 0

; --- resolve the grid: the shared area, adjusted for this probe, then any X/Y/I/J parameters ---
var x0 = global.INDX_mesh_min[0]
var x1 = global.INDX_mesh_max[0]
var y0 = global.INDX_mesh_min[1]
var y1 = global.INDX_mesh_max[1]
var sx = global.INDX_mesh_spacing
var sy = var.sx
var oy = sensors.probes[var.probe].offsets[1]
var shift = 0.0

; The grid is in probe coordinates, so the head goes to (point - offset). The load cell offset is
; zero and needs nothing. The SZP coil sits behind the nozzle, so the head runs out of travel at
; the front of the area long before the coil does. Slide the whole Y window back by the least
; amount that makes the front reachable, which keeps the probed area the same size rather than
; shrinking it. With the coil at +35.1 and Y min -132 that moves -110:90 to -94.9:105.1.
if var.oy != 0
  set var.shift = move.axes[1].min + var.clearance + var.oy - var.y0
  if var.shift > 0
    set var.y0 = var.y0 + var.shift
    set var.y1 = var.y1 + var.shift
; X and Y must be arrays of two. Do not try to detect that with exists(#param.X): the #
; operator throws a parse error on a single value rather than reporting false, so testing it
; is what breaks. A single value here fails with a parse error on this line.
if exists(param.X)
  if #param.X != 2
    abort "mesh.g: X must be two values, e.g. X{-50,50}."
  set var.x0 = param.X[0]
  set var.x1 = param.X[1]
if exists(param.Y)
  if #param.Y != 2
    abort "mesh.g: Y must be two values, e.g. Y{-40,40}."
  set var.y0 = param.Y[0]
  set var.y1 = param.Y[1]
; Spacing: I for both axes, J to override Y separately. Single values, no arrays.
if exists(param.I)
  set var.sx = param.I
  set var.sy = param.I
if exists(param.J)
  set var.sy = param.J
if var.x1 <= var.x0 || var.y1 <= var.y0
  abort "mesh.g: grid limits must be ascending."
if var.sx <= 0 || var.sy <= 0
  abort "mesh.g: grid spacing must be greater than zero."
; whether the limits came from the globals or from parameters, the head still has to reach them
if var.y0 - var.oy < move.axes[1].min || var.y1 - var.oy > move.axes[1].max
  abort {"mesh.g: probe K" ^ var.probe ^ " cannot reach Y" ^ var.y0 ^ " to Y" ^ var.y1 ^ " - the head would need Y" ^ (var.y0 - var.oy) ^ " to Y" ^ (var.y1 - var.oy) ^ ", outside the axis limits."}

; Clear any active height map before probing, so the new map is measured against the real bed
; and not on top of the old one.
G29 S2
M557 X{var.x0,var.x1} Y{var.y0,var.y1} S{var.sx,var.sy}
if var.dbg > 0
  echo {"mesh.g: probe K" ^ var.probe ^ " grid X" ^ var.x0 ^ ":" ^ var.x1 ^ " Y" ^ var.y0 ^ ":" ^ var.y1 ^ " S" ^ var.sx ^ ":" ^ var.sy}

if var.probe = 0
  ; --- INDX load cell: the nozzle probes each grid point ---
  ; Level the bed (G32) first: the built-in grid probe dives from the configured dive height
  ; above Z=0, so a badly tilted bed puts the far points out of range.
  if move.axes[2].homed = false
    abort "mesh.g: home Z first (homez), then level the bed (G32)."
  G90
  G1 Z5 F600
else
  ; --- SZP: set the Z datum with the load cell, then calibrate the coil against it ---
  G90
  G1 Z5 F600
  G1 X{global.INDX_probe_x} Y{global.INDX_probe_y} F12000
  G30                              ; home Z here by nozzle contact (probe 0)
  ; put the SZP coil over the exact spot Z was just homed at (sign reversed to move the head
  ; the opposite way to the probe offset)
  G91
  G1 Y{-sensors.probes[1].offsets[1]} F12000
  ; scan height follows G31 K1 Z (sensors.probes[1].triggerHeight), so changing the trigger
  ; height in config.g moves the calibration and scan heights with it
  G90
  G1 Z{sensors.probes[1].triggerHeight + 0.5} F600   ; approach from above, to take out backlash
  M558.1 K1 S{var.szp_range}       ; calibrate the SZP against this datum
  G1 Z{sensors.probes[1].triggerHeight} F600

; probe the grid: writes heightmap.csv and enables mesh compensation
G29 S0 K{var.probe}

; keep a per-probe copy as well, so the last run of each is always on the card
if var.probe = 0
  G29 S3 P"heightmap_loadcell.csv"
else
  G29 S3 P"heightmap_SZP.csv"

; and a named copy if one was asked for, so a series of runs can be kept apart
if exists(param.F)
  G29 S3 P{param.F}

; lift clear and park 1 mm inside the configured X and Y minimum limits
G90
G1 Z5 F600
G1 X{move.axes[0].min + 1} Y{move.axes[1].min + 1} F12000

if var.dbg > 0
  echo {"mesh.g: done. Active map heightmap.csv, copy saved for probe K" ^ var.probe}
