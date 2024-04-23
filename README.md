# Godot SCML Importer

Godot is an awesome engine. Anyone using it deserves to be able to use the excellent resource and tools that exist along-side it. 
One of these is Spriter from BrashMonkey. I had access to a number of animated character that I wanted to use with Godot and
I didn't want to need to recreate the animations that I already had. This is why I wrote this addon and have decided to share it.

## Usage
 * install plugin
 * enable plugin
 * import scml along with images maintaining the relativity that the SCML expects
 * open the scml file in godot using the FileSystem dock
 * adjust import settings using the godot import tab (first animation from file chosen as rest pose unless specified)

## Tested/supported
 * Godot
	 * 3.1.1 (< 0.8.0)
	 * 4.0, 4.1 (0.9.0)
 * Spriter SCML generator versions
	 * r11
 
# Known limitations

## Not currently supported
 * absolute values as found in e.g. generator version b5.95 that the GreyGuy sample comes with
 * eventline (not sure what use case these serve - haven't investigated)
 * object types other than bone and the regular object (sprites)
 * all interpolation is currently assumed to be linear - other interpolations aren't supported for values
 * looping values isn't interpreted

# Changelog

### 0.9.1

* Ignore eventline when present for now to at least partially support the files
* Ignore points to prevent them from breaking things till support can be considered
* Adjust visibility of parts that might not be present in all animations to have them not be shown when not expected.

### 0.9.0

* Use rotation instead of rotation_degrees - this means that the key/values are now editable for the animations
* Move rotation calculus to use radians instead of degrees to avoid going back and forth between the two
* Introduce ability to control whether wrapping interpolation should be used for looped animations on import (defaults to off)
* Introduce ability to pick looping mode on import
