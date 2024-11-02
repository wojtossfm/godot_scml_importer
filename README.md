# Godot SCML Importer

Godot is an awesome engine. Anyone using it deserves to be able to use the excellent resource and tools that exist along-side it. 
One of these is Spriter from BrashMonkey. I had access to a number of animated characters that I wanted to use with Godot and
I didn't want to need to recreate the animations that I already had. This caused me to write this addon and share it so as to
hopefully empower other godot users with the ability to use it.

## Usage
 * install plugin
 * enable plugin
 * import scml along with images maintaining the relativity that the SCML expects
 * open the scml file in godot using the FileSystem dock
 * adjust import settings using the godot import tab (first animation from file chosen as rest pose unless specified)

## Tested/supported
 * Godot
	 * 3.1.1 (< 0.8.0)
	 * 4.0, 4.1, 4.2 (0.9.1)
	 * 4.3 (0.9.2)
 * Spriter SCML generator versions
	 * r11

> [!TIP]
> When upgrading to 0.9.2 you might need to manually adjust/reset your import settings on any scml files you already have in your project.
> The main difference/change is the playback speed needs to be set to 1 instead of 3 in order to have the animation speed match
> the animation speed that was originally expected.
 
# Known limitations

## Not currently supported
 * absolute values as found in e.g. generator version b5.95 that the GreyGuy sample comes with
 * eventline (not sure what use case these serve - haven't investigated)
 * object types other than bone and the regular object (sprites)
 * all interpolation is currently assumed to be linear - other interpolations aren't supported for values
 * character map support

## Known implementation quirks
 * Bone scale animations will not work as expected due to how the scale handling is implemented in the plugin. Currently not expected to change as not expecting it to be a common concern for users (at least not reported).

# Changelog

### 0.9.2

 * support looping value to avoid looping animations that aren't meant to loop
 * fix issue with negative y scale on bones - this was leading to incorrect placement of child nodes
 * fix logic that was incorrectly adding keyframes using the mainline key times for the reference timeline key values
 * fix optimisation logic that would incorrectly remove the last keyframe from a chain of similar values leading to incorrect animations
 * adjust "leaf" bones to not attempt to automatically calculate length to avoid generating a warning on import
 * issue a warning if importing an SCML file that is not generated with "r11"
 * fix animation speed issue - treat times as being in ms and set default playback speed on import to 1
 * add support for adjust z-index as needed by animations

### 0.9.1

* Ignore eventline when present for now to at least partially support the files
* Ignore points to prevent them from breaking things till support can be considered
* Adjust visibility of parts that might not be present in all animations to have them not be shown when not expected.

### 0.9.0

* Use rotation instead of rotation_degrees - this means that the key/values are now editable for the animations
* Move rotation calculus to use radians instead of degrees to avoid going back and forth between the two
* Introduce ability to control whether wrapping interpolation should be used for looped animations on import (defaults to off)
* Introduce ability to pick looping mode on import
