| SPDX-License-Identifier: GPL-2.0-or-later
| LFO preset shuffle (Digitone II OS 1.12): a POOL destination for synth-track LFOs.
| A synth track whose LFO1, LFO2 or LFO3 has DEST = PRST:POOL (sound slot 65) and DEP != 0
| picks, for each sequencer trig without a manual preset lock, a preset-pool slot from that
| LFO's wave (the first of LFO1..3 aimed at POOL wins); DEP scales it to the pool (.scale).
| Phase advances per step of the track: SPD*MULT/128 cycles per 16 steps (Elektron), from
| the LFO's SPH at PLAY. MIDI tracks are left alone.
|@EDIT 400d87b8 4fefffcc48d77cfc jmp bentry 1
| POOL: dead record 17 (dnfw record 16, page 0xffffffff) becomes the destination
| PRST:POOL, page 12 (sound set, not MIDI), slot 65 (free in every machine; the
| engine map sends slot 65 to index 0, the same place DEST none's slot 0 goes).
|@DATA 401f87a0 ffffffff 0000000c
|@DATA 401f87a4 ffffffff 00000041
| default (and word 4) 0x3f00 -> 0: test 8 wrote 0x3f00 into every track's slot 65 at
| init, MIDI tracks included, and MIDI-track LFOs froze; test 7 leaves the slot 0
|@DATA 401f87a8 00003f00 00000000
|@DATA 401f87b0 00003f00 00000000
|@DATA 401f87b8 0040ffff ffffffff
|@DATA 401f87c4 00000000 00001e00
|@RAWSYM 401f87c8 402151f0 _ longname
|@RAWSYM 401f87d0 40211156 _ poolname
| group 12's short name, "SRC" (no record uses group 12) -> "PRST"
|@RAWSYM 401f7b20 4021ba46 _ prstname
| slot 65 -> POOL only for the DEST code. Placing the record in the sound set made
| MIDI-track LFOs freeze (bisect A1 froze, A2 didn't), through a caller we can't
| see in the emulator. So the sound set's slot -> entry (0x400dc18e) answers slot 65
| only when called through the +0x50 wrapper (return 0x4003675e) by one of the DEST
| sites below; every other caller gets 0, stock's answer for a free slot. 0x400dc18e
| is hooked directly (pslot): it keeps
| the builder's table entry for slot 65 cleared and answers 17 to the DEST callers.
|@EDIT 400dc18e 2f027264206f0008 jmp pslot 1
|@EDIT 400d8c16 223c0000048b4c014800206f004041f048342748003c6018 jmp bsound 9
	.text
cnt:	.space 64                 | per track: steps built since PLAY
seed:	.long 0x9e3779b9
poolname: .asciz "POOL"
prstname: .asciz "PRST"
longname: .asciz "Preset Pool"
	.balign 2

POOL = 0x4240dbcb
PSIZE = 1163
FORK1_RET = 0x400d91ee
POOLSLOT = 65
POOLID = 17
SNDSLOT65 = 0x42c65c40          | sound set table 0x42c65b3c, entry 65
MIDIMASK = 0x5cda               | kit word: bit t = track t is a MIDI track

| builder entry: count this track's step (fork 1's prebuild at PLAY resets it)
bentry:
	move.l 4(%sp),%d0             | track
	moveq #15,%d1
	cmp.l %d0,%d1
	bcs.s 2f
	movea.l 12(%sp),%a0           | kit (3rd argument)
	moveq #0,%d1
	move.b MIDIMASK(%a0),%d1
	lsl.l #8,%d1
	move.b MIDIMASK+1(%a0),%d1
	btst %d0,%d1                  | MIDI track: leave it alone
	bne.s 2f
	lea cnt,%a0
	lsl.l #2,%d0
	adda.l %d0,%a0
	move.l (%sp),%d1
	cmpi.l #FORK1_RET,%d1
	bne.s 1f
	clr.l (%a0)
	bra.s 2f
1:	addq.l #1,(%a0)
2:	lea -52(%sp),%sp
	movem.l %d2-%d7/%a2-%a6,(%sp)
	jmp 0x400d87c0

| rd16 off: d0 = big-endian word at off(a1), byte reads (sounds may sit at odd addresses)
	.macro rd16 off
	moveq #0,%d0
	move.b \off(%a1),%d0
	lsl.l #8,%d0
	move.b \off+1(%a1),%d0
	.endm

| no manual preset lock: d4 = track, a3 = record. Free: d0-d7, a0-a2, a4, a5 (restored by the builder's epilogue)
bsound:
	move.l #PSIZE,%d1
	move.l %d4,%d7                | d7 = track
	mulu.l %d4,%d1
	movea.l 64(%sp),%a0
	moveq #0,%d0                  | MIDI track (kit's MIDI mask): stock's choice, nothing else
	move.b MIDIMASK(%a0),%d0
	lsl.l #8,%d0
	move.b MIDIMASK+1(%a0),%d0
	lea 52(%a0,%d1.l),%a0         | a0 = the track's own sound (stock's choice)
	btst %d4,%d0
	bne.w .own
	movea.l %a0,%a1               | find the first of LFO1..3 aimed at POOL
	moveq #2,%d3
21:	rd16 0x1c                     | DEST (slot 8k+4)
	lsr.l #8,%d0
	moveq #POOLSLOT,%d1
	cmp.l %d1,%d0
	beq.s 22f
	lea 16(%a1),%a1               | next LFO: 8 slots on
	subq.l #1,%d3
	bpl.s 21b
	bra.w .own
22:	rd16 0x24                     | DEP (slot 8k+8)
	subi.l #0x4000,%d0
	beq.w .own
	move.l %d0,%d6                | d6 = depth, 1/256 units
	rd16 0x16                     | SPD (slot 8k+1)
	subi.l #0x4000,%d0
	move.l %d0,%d5                | d5 = speed, 1/256 units, signed
	rd16 0x18                     | MULT (slot 8k+2): index in the high byte
	lsr.l #8,%d0
	moveq #12,%d1
	cmp.l %d1,%d0
	bcs.s 3f
	sub.l %d1,%d0                 | the 120-BPM-fixed multipliers: same power of two
3:	moveq #1,%d1
	lsl.l %d0,%d1                 | d1 = MULT
	muls.l %d1,%d5
	asr.l #3,%d5                  | d5 = inc: phase per step in 1/65536 cycle = SPD*MULT/2048 cycles
	| pos = steps since PLAY
	lea cnt,%a2
	move.l %d7,%d0
	lsl.l #2,%d0
	move.l (%a2,%d0.l),%d2        | d2 = pos
	andi.l #0xffff,%d2
	| P = pos * |inc|: frac16 in d3, cycle in d4
	move.l %d5,%d0
	bpl.s 4f
	neg.l %d0
4:	move.l %d0,%d1
	andi.l #0xffff,%d1            | lo
	clr.w %d0
	swap %d0                      | hi
	mulu.l %d2,%d1                | pos*lo
	mulu.l %d2,%d0                | pos*hi
	move.l %d1,%d3
	andi.l #0xffff,%d3            | frac
	clr.w %d1
	swap %d1
	add.l %d1,%d0
	move.l %d0,%d4                | cycles
	tst.l %d5
	bpl.s 5f
	neg.l %d3
	neg.l %d4
5:	rd16 0x20                     | SPH (slot 8k+6): 0..127 in the high byte
	lsr.l #8,%d0
	andi.l #0x7f,%d0
	lsl.l #8,%d0
	add.l %d0,%d0                 | SPH * 512
	add.l %d0,%d3
	move.l %d3,%d0
	asr.l #8,%d0
	asr.l #8,%d0
	add.l %d0,%d4                 | carry into cycles
	andi.l #0xffff,%d3            | d3 = phase 0..65535
	rd16 0x1e                     | WAVE (slot 8k+5)
	lsr.l #8,%d0
	| d2 = w in -32768..32767
	moveq #0,%d1
	cmp.l %d1,%d0
	beq.s .tri
	moveq #1,%d1
	cmp.l %d1,%d0
	beq.s .sine
	moveq #2,%d1
	cmp.l %d1,%d0
	beq.w .sqr
	moveq #3,%d1
	cmp.l %d1,%d0
	beq.w .saw
	moveq #4,%d1
	cmp.l %d1,%d0
	beq.w .exp
	moveq #5,%d1
	cmp.l %d1,%d0
	beq.w .rmp
	bra.w .rnd
.tri:	bsr.w tri
	bra.w .scale
.sine:	bsr.w tri                     | w = (3x - x^3)/2, x = tri
	move.l %d2,%d0
	muls.l %d0,%d0
	asr.l #8,%d0
	asr.l #7,%d0                  | x^2 / 32768
	muls.l %d2,%d0
	asr.l #8,%d0
	asr.l #7,%d0                  | x^3 / 32768^2
	move.l %d2,%d1
	add.l %d1,%d1
	add.l %d2,%d1                 | 3x
	sub.l %d0,%d1
	asr.l #1,%d1
	move.l %d1,%d2
	bra.w .scale
.sqr:	move.l #32767,%d2
	cmpi.l #32768,%d3
	bcs.w .scale
	move.l #-32768,%d2
	bra.w .scale
.saw:	move.l #32768,%d2
	sub.l %d3,%d2
	cmpi.l #32767,%d2
	ble.w .scale
	move.l #32767,%d2
	bra.w .scale
.exp:	move.l #65535,%d2
	sub.l %d3,%d2
	mulu.l %d2,%d2
	clr.w %d2
	swap %d2
	lsr.l #1,%d2
	bra.w .scale
.rmp:	move.l %d3,%d2
	lsr.l #1,%d2
	bra.w .scale
.rnd:	move.l %d4,%d2                | hash(cycle, track)
	eor.l %d7,%d2
	move.l seed,%d0
	mulu.l %d0,%d2
	move.l %d2,%d0
	swap %d0
	eor.l %d0,%d2
	move.l #0x45d9f3b,%d0
	mulu.l %d0,%d2
	swap %d2
	ext.l %d2
	ext.l %d2
	bra.w .scale
| test 6: DEP scales to the pool. P = the number of filled pool slots (named), counted
| in slot order and skipping empty ones. S = ceil(|DEP| / 128 * P) of them are used,
| so DEP 127.98 uses all P. The wave's full swing is cut into S+1 equal bins; the
| middle bin (m = S/2 rounded down) is the track's own sound, the bins below it the
| 1st..m-th filled slots, the bins above it the (m+1)-th..S-th. Negative DEP mirrors.
| DEP 0 -> off.
.scale:	addi.l #32768,%d2             | u = 0..65535
	move.l %d6,%d5
	bpl.s 7f
	neg.l %d5                     | |DEP| raw, 1..16384
7:	tst.l %d5
	beq.w .own
	movea.l #POOL+4,%a1           | count filled slots
	moveq #0,%d4                  | P
	move.l #127,%d1
12:	tst.b (%a1)
	beq.s 13f
	addq.l #1,%d4
13:	lea PSIZE(%a1),%a1
	subq.l #1,%d1
	bpl.s 12b
	tst.l %d4
	beq.w .own
	move.l %d5,%d0                | S = ceil(|DEP| * P / 16384), at most P
	mulu.l %d4,%d0
	addi.l #16383,%d0
	moveq #14,%d1
	lsr.l %d1,%d0
	cmp.l %d4,%d0
	ble.s 14f
	move.l %d4,%d0
14:	move.l %d0,%d5                | d5 = S
	addq.l #1,%d0                 | S+1 bins
	mulu.l %d0,%d2
	clr.w %d2
	swap %d2                      | idx = 0..S
	tst.l %d6
	bpl.s 15f
	neg.l %d2
	add.l %d5,%d2                 | mirrored: S - idx
15:	move.l %d5,%d1
	lsr.l #1,%d1                  | m
	cmp.l %d1,%d2
	beq.w .own
	bhi.s 16f
	addq.l #1,%d2                 | below: n = idx + 1
16:	movea.l #POOL,%a1             | find the n-th filled slot (n in d2)
	move.l #127,%d1
17:	tst.b 4(%a1)
	beq.s 18f
	subq.l #1,%d2
	beq.s 19f
18:	lea PSIZE(%a1),%a1
	subq.l #1,%d1
	bpl.s 17b
	bra.w .own
19:	movea.l %a1,%a0
.own:	move.l %a0,60(%a3)
	jmp 0x400d8c46

| tri: d3 phase -> d2 in -32768..32767 (0 -> 0, 1/4 -> +1, 3/4 -> -1)
tri:	move.l %d3,%d2
	cmpi.l #16384,%d2
	bcs.s 1f
	cmpi.l #49152,%d2
	bcs.s 2f
	add.l %d2,%d2
	subi.l #131072,%d2
	rts
1:	add.l %d2,%d2
	bra.s 3f
2:	add.l %d2,%d2
	neg.l %d2
	addi.l #65536,%d2
3:	cmpi.l #32767,%d2
	ble.s 4f
	move.l #32767,%d2
4:	rts

| ---------------------------------------------------------------- pslot
| param_set_slot_to_id(slot, type, filter), entered by jmp from 0x400dc18e. Frame: 0 the
| caller's return (0x4003675e for the +0x50 wrapper), 4..12 the arguments, 16..24 the
| two words the wrapper's +0x28 calls leave, 24 d2, 28 a2, 32 the wrapper's caller (the
| bus build measured it at 52, behind the dispatcher's 20 bytes).
pslot:
	clr.l SNDSLOT65               | the builder's slot 65 -> 17: nobody reads it from the table
	moveq #POOLSLOT,%d0
	cmp.l 4(%sp),%d0
	bne.s 3f
	move.l (%sp),%d0
	cmpi.l #0x4003675e,%d0        | through the vtable wrapper?
	bne.s 3f
	move.l 32(%sp),%d0            | the wrapper's own caller
	lea destrets,%a0
1:	move.l (%a0)+,%d1
	beq.s 3f
	cmp.l %d1,%d0
	bne.s 1b
	moveq #POOLID,%d0             | a DEST site asking about slot 65: POOL
	rts
3:	move.l %d2,-(%sp)             | not ours: the displaced stock instructions, then on
	moveq #100,%d1
	movea.l 8(%sp),%a0
	jmp 0x400dc196
	.balign 4
destrets:
	.long 0x40039596              | browser enumeration (slots 0..100)
	.long 0x40039938, 0x4003995c, 0x400399ba, 0x40039a08   | DEST validity / step (DEST >> 8)
	.long 0x40039b5a, 0x40039b7e, 0x40039bdc, 0x40039c2a
	.long 0x40039d7c, 0x40039da0, 0x40039e28
	.long 0x400c26e2              | DEST box draw (DEST >> 8)
	.long 0x400c2a46              | group step
	.long 0x4010783a, 0x40107a88, 0x40107d90, 0x40107e00   | browser open / confirm
	.long 0

| exported names for the sites (mod.json)
	.globl shf_bentry
	.set shf_bentry, bentry
	.globl shf_bsound
	.set shf_bsound, bsound
	.globl shf_longname
	.set shf_longname, longname
	.globl shf_poolname
	.set shf_poolname, poolname
	.globl shf_prstname
	.set shf_prstname, prstname
	.globl shf_pslot
	.set shf_pslot, pslot
