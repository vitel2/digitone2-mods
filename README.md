# Digitone II mods (OS 1.12)

Four [elekloader](https://github.com/elekloader/elekloader) mods for the Elektron Digitone II, OS 1.12. Each one is a separate `.elemod`; install any combination from the [elekloader Mod Shop](https://elekloader.github.io/shop/), which patches your own copy of the stock firmware in the browser. These files contain no Elektron firmware.

| Mod | What it does |
|---|---|
| [MIDI LFO run](mods/midi-lfo-run) | Fixes MIDI-track LFOs freezing after a new project until a note trig plays; stops their CCs while the transport is stopped |
| [BLOCKS](mods/blocks) | A BLOCKS page in TRACK LAYERING: one track's trig drops another's on the same step (linear grooves) |
| [LFO preset shuffle (POOL)](mods/lfo-preset-shuffle) | A POOL LFO destination: each trig plays a preset-pool slot chosen by the LFO |
| [MIDI LFO3](mods/midi-lfo3) | A third LFO on MIDI tracks |

All four can be installed together. None of them needs another.

---

## MIDI LFO run

**The stock bug.** On OS 1.12, after you create a new project, the LFOs on MIDI tracks stop sending until a *note* trig plays on that track. Tapping the track's trig key also restarts them. Lock-only (green) trigs don't. If you only use a MIDI track for LFO modulation, it stays frozen.

**With this mod.** MIDI-track LFOs in **FRE** and **TRG** mode run without any trig. Their CCs are sent while the transport is **playing** or **paused** and stop when it is **stopped**. That second part is a change from stock: stock sends them while stopped as well. **ONE**, **HALF** and **HOLD** are unchanged.

Sites: the lane update (0x40137770) and the LFO send loop's destination check (0x4012a340).

## BLOCKS

Linear-groove blocking, for breakbeat-style programming where only one of two sounds plays on any step.

- **FUNC + 3** (SETUP) → **TRACK LAYERING**. Press **DOWN** twice to get from *TRACK n WILL TRIGGER…* past *CHOKES…* to the new **TRACK n BLOCKS…** page.
- Light a track's key there and the current track blocks it. When the current track plays a sequencer trig, the blocked track's sequencer trig on the same step is dropped.
- Any track can block any other, lower- or higher-numbered. Layered copies of a trig are never blocked and never block.
- Blocks are saved with the pattern's kit.

## LFO preset shuffle (POOL)

Adds a destination, **PRST › Preset Pool** (shown as **POOL**), to synth-track LFO1, LFO2 and LFO3.

- Aim an LFO at POOL and set **DEP** above 0. Each sequencer trig without a manual preset lock then plays a **preset-pool slot** chosen from the LFO's wave. The wave is set by **SPD**, **MULT**, **WAVE** and **SPH**.
- The phase moves per sequencer step, not in real time: SPD × MULT / 128 cycles per 16 steps. It restarts from SPH on PLAY.
- **DEP** sets how many of the filled pool slots are used; at full depth, all of them. Empty slots are skipped.
  - The middle of the wave's swing plays the track's own sound.
  - The lower part of the swing plays the earlier filled slots, and the upper part the later ones.
  - Negative DEP reverses the order.
- If more than one LFO points at POOL, the first one (LFO1, then LFO2, then LFO3) is used.
- MIDI tracks are never shuffled.

## MIDI LFO3

Adds a third LFO to MIDI tracks. On a MIDI track, the LFO page has a third page, **LFO (3/3)**. It has the same controls as LFO1 and LFO2: SPD, MULT, FADE, DEST, WAVE, SPH, MODE and DEP. DEST can be any MIDI-track destination, CCs included. LFO3 is saved with the project like the other two.

---

## Building

Each folder under `mods/` is an elekloader mod source: `mod.json` plus an m68k assembly file. With elekloader checked out and an m68k binutils/gcc on the path:

```
python3 -m elekloader.sdk.build mods/blocks --stock Digitone_II_OS1.12.syx --out out
python3 -m elekloader.lint out/blocks-1.0.elemod --stock Digitone_II_OS1.12.syx --with core-dn2.elemod
```

The stock OS file is yours to supply. It is not part of this repository.

## Licence

GPL-2.0-or-later. See [LICENSE](LICENSE).

Not affiliated with or endorsed by Elektron. Modified firmware is used at your own risk.
