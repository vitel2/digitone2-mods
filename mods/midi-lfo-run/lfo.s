| SPDX-License-Identifier: GPL-2.0-or-later
| MIDI LFO run (Digitone II OS 1.12): MIDI-track LFOs in FRE/TRG mode keep running after a
| project change without a note trig, and send their CCs unless the transport is stopped.
|
| The stock bug: after a new project (and in projects loaded after it) the MIDI-track LFO lanes
| are left with their stopped flags set (lane +36/+38, 0x44640498 + 120*track + 40*lane), and
| only a note on the track clears them; the LFO's value is frozen until then.

	.text

| site 0x40137770, the lane tick's two mvsb loads (MODE, WAVE) -> jsr mlr_lane ; nop.
| %a4 = the lane's parameters, %a3 = the lane's flags (+36). %d1 is scratch here (the
| lane tick sets it again at 0x40137794 before reading it); %d0 holds the waveform's value.
	.globl mlr_lane
mlr_lane:
	mvs.b 46(%a4),%d7             | MODE (what stock loads here)
	mvs.b 42(%a4),%d3             | WAVE
	moveq #1,%d1
	cmp.l %d7,%d1
	bcs.s 1f                      | ONE, HALF, HOLD: stock
	clr.b (%a3)                   | FRE, TRG: never left stopped
	clr.b 2(%a3)
1:	rts

| site 0x4012a340, the destination-enabled check, int f(track, dest): its first two
| instructions -> jmp mlr_gate. Called from the LFO loop (it returns to 0x4012ae2a) while the
| transport is stopped (0x42c5b918 == 0; 1 playing, 2 paused), it answers "not enabled", so the
| LFO's CC is not sent. Every other call (notes, queued parameter changes) runs stock.
	.globl mlr_gate
mlr_gate:
	move.l (%sp),%d0
	cmpi.l #0x4012ae2a,%d0
	bne.s 2f
	tst.l 0x42c5b918
	bne.s 2f
	moveq #0,%d0
	rts
2:	move.l 8(%sp),%d1             | the two instructions the jmp displaced
	addi.l #-25,%d1
	jmp 0x4012a34a
