| SPDX-License-Identifier: GPL-2.0-or-later
| MIDI-track LFO3 (OS 1.12).
	.text
ids:	.long 0x23, 0x24, 0x26            | MIDI LFO views: LFO1, LFO2, new id 38
	.long 0                           | pad
| descriptor for view 38: +0 name, +4 title, then nine parameter ids (44 bytes)
desc:	.long 0, 0
	.long 95, 104, 97, 98, 99, 101, 102, 103, 0

| --- view-id -> descriptor lookup, hooked at 0x400c25e4 (replaces moveq #44,%d1; mulsl %d1,%d0)
| on entry d0 = id, or -1 if id > 36; 4(sp) = the id as passed
lookup:
	move.l 4(%sp),%d1
	cmpi.l #38,%d1
	bne.s 1f
	| copy the name string pointer from view 6 (synth LFO3: "LFO3") and the title from view 0x24 ("LFO")
	lea desc,%a0
	move.l 0x42433c00+6*44,%d0
	move.l %d0,(%a0)
	move.l 0x42433c00+0x24*44+4,%d0
	move.l %d0,4(%a0)
	move.l %a0,%d0
	rts
1:	moveq #44,%d1
	muls.l %d1,%d0
	addi.l #0x42433c00,%d0
	rts

| --- MidiParameterSet value-validity: add the LFO3 DEST branch (record flag bit 16, mask 0x600),
| hooked at 0x40039d86 (12 bytes: push d2; jsr (a3); addq #4; btst #17; beq.s)
valid:
	move.l %d2,-(%sp)
	jsr (%a3)
	addq.l #4,%sp
	btst #17,%d0
	bne.s 2f
	move.l %d2,-(%sp)
	jsr (%a3)
	addq.l #4,%sp
	btst #16,%d0
	beq.s 3f
	asr.l #8,%d3
	movea.l (%a2),%a0
	move.l %d3,-(%sp)
	move.l %a2,-(%sp)
	movea.l 80(%a0),%a0
	jsr (%a0)
	pea 0x600
	move.l %d0,-12(%fp)
	jmp 0x40039da8
2:	jmp 0x40039d92
3:	jmp 0x40039de4

| --- MidiParameterSet value stepper (vtable +0x20, 0x40039eb8): pick the LFO3 DEST mask too,
| hooked at 0x40039f00 (12 bytes: movew #0xe00,d0; btst #17,d2; bnes; clrl d0)
step:
	move.w #0xe00,%d0
	btst #17,%d2
	bne.s 4f
	move.w #0x600,%d0
	btst #16,%d2
	bne.s 4f
	clr.l %d0
4:	jmp 0x40039f0c

| exported names for the sites (mod.json)
	.globl ml3_ids
	.set ml3_ids, ids
	.globl ml3_lookup
	.set ml3_lookup, lookup
	.globl ml3_valid
	.set ml3_valid, valid
	.globl ml3_step
	.set ml3_step, step
