# AppleScript Support

Mariani now supports some AppleScript commands and properties:

**reboot** *v* : Reboot the emulator
: `reboot`

**insert** *v* : Insert disk in drive
: `insert` text : File name of disk
: `into` Drive : Disk drive

**type** *v* : Type on the keyboard
: `type` text : String

**take screenshot** *v* : Take a screenshot
: `take screenshot`

**Application** *n* : Mariani's top-level scripting object
######elements######
contains Slots.
######properties######
**display** (VT\_MONO\_CUSTOM/‌VT\_COLOR\_IDEALIZED/‌VT\_COLOR\_VIDEOCARD\_RGB/‌VT\_COLOR\_MONITOR\_NTSC/‌VT\_COLOR\_TV/‌VT\_MONO\_TV/‌VT\_MONO\_AMBER/‌VT\_MONO\_GREEN/‌VT\_MONO\_WHITE) : Display type

**Slot** *n* : I/O slot
######elements######
contains Drives; contained by Applications.
######properties######
**card** (text) : I/O card inserted in slot

**Drive** *n* : Disk drive
######elements######
contained by Slots.
######properties######
**disk** (text) : Disk in drive

**DisplayType** *enum* : Video display type
**VT\_MONO\_CUSTOM** : Monochrome (Custom)
**VT\_COLOR\_IDEALIZED** : Color (Composite Idealized)
**VT\_COLOR\_VIDEOCARD\_RGB** : Color (RGB Card/Monitor)
**VT\_COLOR\_MONITOR\_NTSC** : Color (Composite Monitor)
**VT\_COLOR\_TV** : Color TV
**VT\_MONO\_TV** : B&W TV
**VT\_MONO\_AMBER** : Monochrome (Amber)
**VT\_MONO\_GREEN** : Monochrome (Green)
**VT\_MONO\_WHITE** : Monochrome (White)

I'm a total beginner with both scripting support and AppleScript itself, so let me know if this can be improved.
