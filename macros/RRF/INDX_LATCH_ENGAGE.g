; INDX_LATCH_ENGAGE - extra latch engage (E+3)
;
; A short slow E move after a tool pickup to guarantee the latch is fully engaged
; during Z-offset calibration. The latch must already be closed.

if global.INDX_State = -1
  abort "INDX_LATCH_ENGAGE: latch is open - close it first (INDX_CLOSE)."

var cet = heat.coldExtrudeTemperature
var crt = heat.coldRetractTemperature
if var.cet > 0
  M302 P1

; Variables from BONDTECH
var engage_e        = 3.0
var engage_feedrate = 300

M83
M906 E600
G1 E{var.engage_e} F{var.engage_feedrate}
M400

if var.cet > 0
  M302 P0 S{var.cet} R{var.crt}
