; INDX_CLOSE - tool-change lock (E+11)
;
; Normal tool-loading lock. Does NOT seat the heavier calibration force - use
; INDX_CLOSE_CAL for load-cell calibration.
;

if global.INDX_State > -1
  abort "INDX_CLOSE: already flagged closed (global.INDX_State > -1)."

var cet = heat.coldExtrudeTemperature
var crt = heat.coldRetractTemperature
if var.cet > 0
  M302 P1

; Variables from BONDTECH
var full_lock_e = 11.0

M83
M906 E600
G1 E{var.full_lock_e} F1500
M400

if var.cet > 0
  M302 P0 S{var.cet} R{var.crt}

set global.INDX_State = 99   ; closed; tool identity set by the tool-change macro later
