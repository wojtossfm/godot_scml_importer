# Godot SCML Importer

Godot is an awesome engine. Anyone using it deserves to be able to use the excellent resource and tools that exist along-side it. 
ne of these is Spriter from BrashMonkey. I had access to a number of animated character that I wanted to use with Godot and
I didn't want to need to recreate the animations that I already had.

## Usage
 * install plugin
 * enable plugin
 * import scml along with images maintaining the relativity that the SCML expects
 * open the scml file in godot using the FileSystem dock
 * adjust import settings using the godot import tab (first animation from file chosen as rest pose unless specified)

## Tested/supported
 * Godot
     * 3.1.1
 * Spriter SCML generator versions
     * r11
 
# Not currently supported
 * absolute values as found in e.g. generator version b5.95 that the GreyGuy sample comes with
