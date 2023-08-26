# AppleScript Support

Mariani now supports some AppleScript commands and properties:

**reboot** *v* : Reboot the emulator<br/>
`reboot`

**insert** *v* : Insert disk in drive<br/>
`insert` text : File name of disk<br/>
`into` Drive : Disk drive

**type** *v* : Type on the keyboard<br/>
`type` text : String

**take screenshot** *v* : Take a screenshot<br/>
`take screenshot`

**Application** *n* : Mariani's top-level scripting object<br/>
<sub>ELEMENTS</sub><br/>
contains Slots.<br/>
<sub>PROPERTIES</sub><br/>
**display** (VT\_MONO\_CUSTOM/‌VT\_COLOR\_IDEALIZED/‌VT\_COLOR\_VIDEOCARD\_RGB/‌VT\_COLOR\_MONITOR\_NTSC/‌VT\_COLOR\_TV/‌VT\_MONO\_TV/‌VT\_MONO\_AMBER/‌VT\_MONO\_GREEN/‌VT\_MONO\_WHITE) : Display type<br/>

**Slot** *n* : I/O slot<br/>
<sub>ELEMENTS</sub><br/>
contains Drives; contained by Applications.<br/>
<sub>PROPERTIES</sub><br/>
**card** (text) : I/O card inserted in slot

**Drive** *n* : Disk drive<br/>
<sub>ELEMENTS</sub><br/>
contained by Slots.<br/>
<sub>PROPERTIES</sub><br/>
**disk** (text) : Disk in drive

**DisplayType** *enum* : Video display type
- **VT\_MONO\_CUSTOM** : Monochrome (Custom)
- **VT\_COLOR\_IDEALIZED** : Color (Composite Idealized)
- **VT\_COLOR\_VIDEOCARD\_RGB** : Color (RGB Card/Monitor)
- **VT\_COLOR\_MONITOR\_NTSC** : Color (Composite Monitor)
- **VT\_COLOR\_TV** : Color TV
- **VT\_MONO\_TV** : B&W TV
- **VT\_MONO\_AMBER** : Monochrome (Amber)
- **VT\_MONO\_GREEN** : Monochrome (Green)
- **VT\_MONO\_WHITE** : Monochrome (White)

I'm a total beginner with both scripting support and AppleScript itself, so let me know if this can be improved.
