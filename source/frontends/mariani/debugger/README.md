# Mariani Debugger

Mariani now has some basic support for the AppleWin debugger.

## Quick Start

You can bring up the debugger by selecting Window → Show Debugger or pressing the `F7` key. Here's a quick tour of the main screen.

<img width="800" alt="debugger-main" src="https://github.com/sh95014/AppleWin/assets/95387068/3b990131-831f-4b4c-8840-95b4c7b39b35">

The big pane on the left is the disassembly listings. The columns from left to right display:

- Whether a breakpoint is set at this address. In the screenshot, a white number over a red square indicates that the numbered breakpoint is enabled and active.
- The memory address
- Whether a bookmark is set at this address. Bookmarks are likewise numbered.
- The opcodes of the instruction at this address
- A human-readable symbol for this address, if available
- The disassembled instructions
- Convenient interpretations of the instructions, such as an immediate value in decimal form

Here are the available features, from the top:

- The controls along the top lets you jump to an address by symbol or by bookmark.
- Clicking on the breakpoint or address columns will enable or disable a breakpoint at the address.
- Clicking on a symbol cell will add a new user symbol at the address.
- Right-clicking an address will bring up additional optinos, including clearing a breakpoint.
- The buttons along the bottom let you run, pause, or single-step through the program.
- The Debugger Command Line lets you issue commands to the AppleWin debugger.
- The inspector pane on the right displays items of interest at a glance, including register values and system state.
- The theme picker lets you quickly change the display theme of the debugger.
- The console provides full access to the AppleWin debugger:

<img width="800" alt="debugger-console" src="https://github.com/sh95014/AppleWin/assets/95387068/c1ef0f67-4816-4d97-83cd-00ef2cd926a2">

## Caveats

Some AppleWin debugger commands don't really make sense in a multi-window GUI environment. Please let me know if there are command-line interactions that aren't reflected in the graphical interface.
