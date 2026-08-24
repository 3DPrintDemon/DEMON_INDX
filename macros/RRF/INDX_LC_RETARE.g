; INDX_LC_RETARE - zero the reported load cell force immediately
;
; Guard-only: performs NO motion.
;
; Probing never needs this. The firmware tares the cell at the start of every probing move, and
; between moves the baseline tracks slow drift by itself, so a step change such as locking or
; unlocking a tool is absorbed on its own within a few seconds. M558.4 latches the current
; reading as the new baseline straight away instead of waiting for that, which is useful at the
; end of a calibration or tool change so the force shown in DWC reads zero at once.
;
; Run with the tool in its resting state and clear of the bed: whatever load is on the cell at
; that moment becomes the new zero, and is then reported as sensors.probes[0].loadCell.preload,
; which is what the M558 U window checks.

if sensors.probes[0].type != 12
  abort "INDX_LC_RETARE: probe 0 is not a load cell probe (M558 P12) - check config.g."

var dbg = exists(global.INDX_LC_DEBUG) ? global.INDX_LC_DEBUG : 0

M558.4 K0

if var.dbg > 0
  echo {"INDX_LC_RETARE: tared. force " ^ sensors.probes[0].loadCell.force ^ " g, preload " ^ sensors.probes[0].loadCell.preload ^ " g"}
