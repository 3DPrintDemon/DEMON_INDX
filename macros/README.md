# DEMON INDX MACROS

These differ from the stock Bondtech ones a little here & there but essentially they're mostly the same in their function.

Most changes are to help facilitate the dock sensors. All macro files found here need to be installed & used together. If you don't have any dock sensors thats ok as they are dormant by default in the modified index.cfg file.

These macros also require [KAMP_LiTE](https://github.com/3DPrintDemon/KAMP_LiTE/releases/tag/v1.0)

<br>

# DEMON DISCORD!

Come & join the community! We've launched Demon Discord, help us start building a fantastic user focused resource for help & support from other users, or simply chat & show off your machine & your latest prints!

<p align="left">
    <img width="500" alt="Demon_Discord" src="/images/Demon_Discord.png" />
    <https://discord.gg/KEbxw22AD4>
</p>

[https://discord.gg/KEbxw22AD4](https://discord.gg/KEbxw22AD4)

<br>

# DESIGNED FOR USE WITH INDX DEMON DOCKS!

>[!NOTE]
> These macros can be used without dock sensors just as normal! You will need at minimum the indx.cfg & indx-tc-macros.cfg files for standard operation. The rest are required if you do have dock sensors.


Add dock sensing to your INDX system! Use this modified standard INDX dock so installs & dock placement DO NOT change! You just need a MCU to manage the docks & a cable run from the docks to said MCU.

<img width="4032" height="3024" alt="INDX DEMON DOCK" src="/images/Demon_Dock.jpeg" />

This system allows active tool sensing with load cell confirmation for all attached docks with simple & accurate switch connection to a non-critical MCU. 

DEMON_DOCKS will auto scan for empty docks at startup & disable sensing for those docks. They can be added back into active docks (or removed again) at runtime by command/macro button. The docks can be set to warn only of a potential problem, raise errors if not printing, PAUSE the print if printing, emergency stop if not printing, or emergency stop when printing. 

The load cell dock/undock confirmation can be set on/off at runtime.

The system warns of:

- Undocked tools at startup that will be ignored
- ignored docks during tool changes
- inactive tools undocked at any time
- problems during non-printing operations
- load cell readings out of range
- docking failures - printing & non-printing
- pickup (undocking) failures - printing & non-printing

DEMON_DOCKS then takes specified actions for each type of occurrence.

It can even pause a tool change while printing if a problem is detected!

<br>

### Download [DEMON DOCKS here!](https://github.com/3DPrintDemon/DEMON_INDX/tree/main/DEMON%20Docks)

<br>

# Important Slicer Setting

For these macros to work effectively you need to go to your Printer Settings / Multilateral tab & check "Tool change on wipe tower"

<img width="729" height="541" alt="Orca Purge" src="/images/Slicer.png" />

# Slicer Machine G-code For DEMON_INDX_EXTRAS.cfg


These are the sections to add to ORCA slicer:

Machine Start G-code:
```
SET_PRINT_STATS_INFO TOTAL_LAYER=[total_layer_count]
M104 S0  ; Stops the slicer from sending temp waits separately
M140 S0
_TOOL_CHECK_START
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
CHANGE_TOOL TOOL={next_extruder} TEMP={nozzle_temperature[next_extruder]}
M400
```

Pause G-code:
```
PAUSE
```
