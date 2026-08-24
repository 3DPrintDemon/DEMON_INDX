; INDX_CLOSE_CAL - load-cell calibration lock (full seat)
;
; Drives the latch onto a hand-seated passive tool and seats the full ~1600 g
; locking force against the load cell. Run before INDX_LC_CAL. INDX_CLOSE is the
; lighter lock used for normal tool changes.

if global.INDX_State > -1
  abort "INDX_CLOSE_CAL: already flagged closed (global.INDX_State > -1)."

var cet = heat.coldExtrudeTemperature
var crt = heat.coldRetractTemperature
if var.cet > 0
  M302 P1

; Variables from BONDTECH
var full_lock_e   = 11.0
var seat_e        = 10.0
var seat_feedrate = 300

M83
M906 E600
G1 E{var.full_lock_e} F1500
G1 E{var.seat_e} F{var.seat_feedrate}    ; slow seat to full locking force
M400

if var.cet > 0
  M302 P0 S{var.cet} R{var.crt}

set global.INDX_State = 99
