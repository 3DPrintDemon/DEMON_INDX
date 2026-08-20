# DEMON INDX MACROS

These differ from the stock Bondtech ones a little here & there but essentially they're mostly the same in their function.

Most changes are to help facilitate the dock sensors. All macro files found here need to be installed & used together. If you don't have any dock sensors thats ok as they are dormant by default in the modified index.cfg file.

These macros also require [KAMP_LiTE](https://github.com/3DPrintDemon/KAMP_LiTE/releases/tag/v1.0)


# Slicer Machine G-code For DEMON_INDX_EXTRAS.cfg

These are the sections to add to ORCA slicer:

Machine Start G-code:
```
SET_PRINT_STATS_INFO TOTAL_LAYER=[total_layer_count]
M104 S0  ; Stops the slicer from sending temp waits separately
M140 S0
PRINT_START EXTRUDER=[nozzle_temperature_initial_layer] TOOL={initial_tool} BED=[bed_temperature_initial_layer_single]
```

Machine End G-code:
```
PRINT_END
```

Before Layer Change G-code:
```
;[layer_z]
G92 E0
```

After Layer Change G-code:
```
;[layer_z]
SET_PRINT_STATS_INFO CURRENT_LAYER={layer_num + 1}
M117 Layer {layer_num+1}/[total_layer_count] : {filament_settings_id[0]}
```

Filament Change G-code:
```
T{next_extruder}
```

Pause G-code:
```
PAUSE
```
