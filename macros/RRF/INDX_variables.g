; INDX_variables.g - all INDX global variables (RRF load-cell probe firmware)
;
; Called from config.g (M98 P"INDX_variables.g") AFTER the hardware configuration, including
; after the M558/G31 that create the load-cell probe.
;
; Can also be run by hand at any time to pick up edits made to this file: every variable is
; declared if missing and otherwise SET to the value below, so a manual run refreshes the
; globals without a restart. Values saved by INDX_WRITE_STATE are restored afterwards, so
; calibration survives the refresh.
;
; Firmware model: the load cell is probe type P12. M558 V sets the scale in grams per raw ADC
; count; G31 P sets the trigger force in GRAMS; the firmware tares the cell automatically at
; the start of every probing move, so probing needs no manual tare.

; variables for tool changes
if !exists(global.INDX_tool_clearance_y)
  global INDX_tool_clearance_y = 0
else
  set global.INDX_tool_clearance_y = 0
if !exists(global.INDX_trigger_offset)
  global INDX_trigger_offset = 5.0    ; mm; trigger_y = dock_y + this
else
  set global.INDX_trigger_offset = 5.0
if !exists(global.INDX_dock_y)
  global INDX_dock_y = -26            ; mm; TEST dock Y - set to your seated-tool Y
else
  set global.INDX_dock_y = -26

; INDX States:
;  -1 = Open / no tool
;  0,1,2 etc = Closed with that tool loaded
if !exists(global.INDX_State)
  global INDX_State = -1 ; initialise as open (overridden below if persisted)
else
  set global.INDX_State = -1

; variables that modify the speeds for tool changes
if !exists(global.INDX_TC_SPEED)
  global INDX_TC_SPEED = 24000 ; Highest safe toolchange feedrate
else
  set global.INDX_TC_SPEED = 24000
if !exists(global.INDX_TC_ACCEL)
  global INDX_TC_ACCEL = 10000 ; Highest safe toolchange acceleration
else
  set global.INDX_TC_ACCEL = 10000

; Speed mode in use (1.0 = Full speed "SPORT", 0.7 = "NORMAL", 0.3 = "STEALTH")
if !exists(global.INDX_TC_MODE)
  global INDX_TC_MODE = 1.0
else
  set global.INDX_TC_MODE = 1.0

; Load cell calibration (these are overwritten by the saved state restored at the end)
if !exists(global.INDX_LC_offset)
  global INDX_LC_offset = 0  ; raw unloaded baseline (counts), set by INDX_TARE; used only during calibration
else
  set global.INDX_LC_offset = 0
if !exists(global.INDX_LC_scale)
  global INDX_LC_scale = 0.11  ; grams per raw count = the M558 V value; set by INDX_LC_CAL, applied to the probe below
else
  set global.INDX_LC_scale = 0.11
if !exists(global.INDX_LC_scale_limits)
  global INDX_LC_scale_limits = {0.05, 0.5} ; g/count; min and max ACCEPTABLE MAGNITUDE of the calibrated scale (sign ignored)
else
  set global.INDX_LC_scale_limits = {0.05, 0.5}
if !exists(global.INDX_LC_locking_force)
  global INDX_LC_locking_force = 1600 ; known cal force (g) provided by Bondtech
else
  set global.INDX_LC_locking_force = 1600
if !exists(global.INDX_LC_samples)
  global INDX_LC_samples = 16 ; reads averaged per tare/cal
else
  set global.INDX_LC_samples = 16
if !exists(global.INDX_LC_calibrated)
  global INDX_LC_calibrated = false ; guard, set true by INDX_LC_CAL
else
  set global.INDX_LC_calibrated = false

; Load cell Z probing (firmware auto-tares each probe; G31 P is grams, M558 V is g/count)
if !exists(global.INDX_LC_trigger_grams)
  global INDX_LC_trigger_grams = 50  ; g; probe trigger force above the auto-tare -> feeds G31 K0 P (40-70 g reasonable)
else
  set global.INDX_LC_trigger_grams = 50
if !exists(global.INDX_LC_preload_lo)
  global INDX_LC_preload_lo = 0      ; g; low edge of the M558 U preload window; the preload is SIGNED
else
  set global.INDX_LC_preload_lo = 0
if !exists(global.INDX_LC_preload_hi)
  global INDX_LC_preload_hi = 0      ; g; high edge; if hi <= lo the window is DISABLED. Bracket the observed preload
else
  set global.INDX_LC_preload_hi = 0

; Probe motion (speed, dive heights and averaging) is set by the M558 in config.g, not here.

; Mesh area, in PROBE coordinates, shared by both probes. mesh.g shifts the Y window for the
; SZP by however much the coil offset demands, so only one set of numbers is needed here.
if !exists(global.INDX_mesh_min)
  global INDX_mesh_min = {-100, -110}   ; mm; X and Y minimum of the probed area
else
  set global.INDX_mesh_min = {-100, -110}
if !exists(global.INDX_mesh_max)
  global INDX_mesh_max = {100, 90}      ; mm; X and Y maximum of the probed area
else
  set global.INDX_mesh_max = {100, 90}
if !exists(global.INDX_mesh_spacing)
  global INDX_mesh_spacing = 30         ; mm; default point spacing. Pass I10 for a fine SZP scan
else
  set global.INDX_mesh_spacing = 30

; homez probe point
if !exists(global.INDX_LC_probe_fuzz)
  global INDX_LC_probe_fuzz = 0     ; mm; if >0, randomly offset the probe XY from centre by +/- this (spreads bed wear; 0 = always centre)
else
  set global.INDX_LC_probe_fuzz = 0
if !exists(global.INDX_probe_x)
  global INDX_probe_x = 0           ; mm; homez probe point X in machine coords (bed centre); homez targets this minus the probe XY offset
else
  set global.INDX_probe_x = 0
if !exists(global.INDX_probe_y)
  global INDX_probe_y = 0           ; mm; homez probe point Y in machine coords (bed centre)
else
  set global.INDX_probe_y = 0
; 1 = operational macros echo progress to console; 0 = quiet (M291 dialogs + errors still show).
; This is the default only. indx-state.g restores whatever was last saved by INDX_WRITE_STATE,
; so a debug session survives a reboot or a manual re-run of this file.
if !exists(global.INDX_LC_DEBUG)
  global INDX_LC_DEBUG = 0
else
  set global.INDX_LC_DEBUG = 0

; Restore values persisted by INDX_WRITE_STATE (overrides the defaults above)
if fileexists("0:/sys/indx-state.g")
  M98 P"0:/sys/indx-state.g"

; --- apply the calibration + probe settings to load-cell probe K0 ---
; indx-state.g applies the calibrated scale with M558 V, which configures the existing probe
; without re-creating it, so config.g's G31 survives. The lines below cover the case where no
; saved state exists, and make the trigger force and preload window follow the globals above.
; Re-applying G31 here also repairs the probe if something re-created it - any M558 with a P
; parameter resets G31 to firmware defaults of 500 threshold and 0.7mm trigger height.
if global.INDX_LC_calibrated
  M558 K0 V{global.INDX_LC_scale}
G31 K0 P{global.INDX_LC_trigger_grams} X0 Y0 Z0
if global.INDX_LC_preload_hi > global.INDX_LC_preload_lo
  M558 K0 U{global.INDX_LC_preload_lo}:{global.INDX_LC_preload_hi}
