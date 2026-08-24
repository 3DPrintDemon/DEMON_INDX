; INDX_OPEN - plain latch open (E-11)
;
; The open used by tool pickup and by load-cell calibration - a plain E-11 with
; no Y wiggle. To release a tool seated in its dock use INDX_UNLOCK_DANCE.

if global.INDX_State = -1
  abort "INDX_OPEN: already flagged open (global.INDX_State = -1)."

var cet = heat.coldExtrudeTemperature
var crt = heat.coldRetractTemperature
if var.cet > 0
  M302 P1

; Variables from BONDTECH
var full_open_e = -11.0

M83
M906 E600
G1 E{var.full_open_e} F1500
M400

if var.cet > 0
  M302 P0 S{var.cet} R{var.crt}

set global.INDX_State = -1
