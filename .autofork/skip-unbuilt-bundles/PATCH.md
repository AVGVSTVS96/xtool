Skip a dependency's resource bundle when the build didn't make one, instead of failing the pack.

The planner walks every target a package declares, but a target that a package trait or a platform condition leaves out is never built, so it has no bundle. FluidAudio built with `traits: []` is one: its TTS resources target is declared but switched off, and `xtool dev` stopped with "The file doesn't exist" for `FluidAudio_LuxTtsG2pResources.bundle`. Binary targets that SwiftPM didn't copy are already skipped the same way.

Once the planner leaves out targets the build skips, this patch is done.
