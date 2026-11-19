| SPDX-License-Identifier: GPL-2.0-or-later
| BLOCKS, linear-groove blocking (Digitone II OS 1.12).
| A track P whose BLOCKS row has bit S blocks S's sequencer trigs on the same step:
| when P fires (an unmuted sequencer note-on, not a layered copy) at nominal step
| time T, S's sequencer note-on with nominal time T (record +8, before micro-timing)
| is dropped by the ISR's own skip path.
|@RAW 40027bca 6000e954 6000e964
|@EDIT 4002651e 42822f084eb9400db8fc588f4a8067027401 jsr gate 6
	.text
hidx:	.space 16                 | per track: next history slot (0..3)
hist:	.space 16*16              | per track: last 4 fired nominal times
enable:	.long 1
flag:	.long 0                    | the layering screen is on its BLOCKS page
title:	.asciz "%s CHOKES..."
	.balign 2

KIT = 0x800052a0
SOUND = 1163                  | live sound stride in a RAM kit
ROW0 = 52 + 0x14 + 200        | sound 0 + value array + slot 100
SROW0 = 60 + 28 + 2*107       | stored kit: sound 0 + value block + id 107
SSOUND = 359
QHEAD = 0x44645228
FPMUTE = -116
PMUTE = 0x4058f888

| gate: replaces "d2 = skip_test(record)"; record in a0; must leave d3-d7/a2-a6 intact
gate:
	move.l %a0,-(%sp)
	jsr 0x400db8fc
	movea.l (%sp)+,%a0
	moveq #0,%d2
	tst.l %d0
	bne.w .skip
	lea -24(%sp),%sp
	movem.l %d3-%d6/%a2-%a3,(%sp)
	movea.l %a0,%a2               | a2 = record R
	moveq #1,%d0
	cmp.l 4(%a2),%d0              | note-on only
	bne.w .done
	move.l 56(%a2),%d0
	btst #17,%d0                  | layered copy: never blocked, never counts
	bne.w .done
	move.l 16(%a2),%d3            | d3 = S
	moveq #15,%d0
	cmp.l %d3,%d0
	bcs.w .done
	move.l 8(%a2),%d4             | d4 = T
	tst.l enable
	beq.w .record
| d5 = primaries of S: P != S whose BLOCKS row (sound P, live slot 100) has bit S
	moveq #0,%d5
	movea.l KIT,%a0
	lea ROW0(%a0),%a0
	moveq #0,%d6                  | P
1:	cmp.l %d6,%d3
	beq.s 2f
	moveq #0,%d0
	move.b (%a0),%d0
	lsl.l #8,%d0
	move.b 1(%a0),%d0
	btst %d3,%d0
	beq.s 2f
	bset %d6,%d5
2:	lea SOUND(%a0),%a0
	addq.l #1,%d6
	moveq #16,%d0
	cmp.l %d6,%d0
	bne.s 1b
	move.l FPMUTE(%fp),%d0
	move.w PMUTE,%d1
	andi.l #0xffff,%d1
	or.l %d1,%d0
	not.l %d0
	and.l %d0,%d5
	beq.w .record
| d6 = tracks that fire at T: history
	moveq #0,%d6
	lea hist,%a0
	moveq #0,%d1                  | P
3:	btst %d1,%d5
	beq.s 4f
	move.l %d1,%d0
	lsl.l #4,%d0
	lea (%a0,%d0.l),%a1
	cmp.l (%a1)+,%d4
	beq.s 5f
	cmp.l (%a1)+,%d4
	beq.s 5f
	cmp.l (%a1)+,%d4
	beq.s 5f
	cmp.l (%a1)+,%d4
	bne.s 4f
5:	bset %d1,%d6
4:	addq.l #1,%d1
	moveq #16,%d0
	cmp.l %d1,%d0
	bne.s 3b
	and.l %d5,%d6
	bne.s .block
| the rest of R's own time group (R's +104 chain)
	movea.l 104(%a2),%a1
	moveq #64,%d1
	bsr.s .chain
	bne.s .block
| every pending node in the scheduler queue
	movea.l QHEAD,%a3
	move.l #96,-(%sp)             | node cap
6:	move.l %a3,%d0
	beq.s 7f
	subq.l #1,(%sp)
	bmi.s 7f
	movea.l 8(%a3),%a1
	moveq #64,%d1
	bsr.s .chain
	bne.s 8f
	movea.l 16(%a3),%a3
	bra.s 6b
8:	addq.l #4,%sp
	bra.s .block
7:	addq.l #4,%sp
| not blocked: S fired at T
.record:
	lea hidx,%a0
	moveq #0,%d0
	move.b (%a0,%d3.l),%d0
	move.l %d0,%d1
	addq.l #1,%d1
	andi.l #3,%d1
	move.b %d1,(%a0,%d3.l)
	lea hist,%a0
	move.l %d3,%d1
	lsl.l #4,%d1
	add.l %d1,%a0
	move.l %d4,(%a0,%d0.l*4)
	bra.s .done
.block:
	moveq #1,%d2
.done:
	movem.l (%sp),%d3-%d6/%a2-%a3
	lea 24(%sp),%sp
	rts
.skip:
	moveq #1,%d2
	rts

| chain: a1 = first record, d1 = cap; Z clear (ne) if a record of a primary in d5
| fires at d4 (sequencer note-on, not a copy). clobbers d0,d1,a1
.chain:
9:	move.l %a1,%d0
	beq.s 10f
	subq.l #1,%d1
	bmi.s 10f
	cmp.l 8(%a1),%d4
	bne.s 11f
	moveq #1,%d0
	cmp.l 4(%a1),%d0
	bne.s 11f
	cmp.l 20(%a1),%d0
	bne.s 11f
	move.l 56(%a1),%d0
	btst #17,%d0
	bne.s 11f
	move.l 16(%a1),%d0
	cmpi.l #15,%d0
	bhi.s 11f
	btst %d0,%d5
	bne.s 12f
11:	movea.l 104(%a1),%a1
	bra.s 9b
10:	moveq #0,%d0
	rts
12:	moveq #1,%d0
	rts

| ---------- storage: BLOCKS row of track P = live sound P slot 100 <-> stored sound P id 107
| sound deserializer entry 0x400dd34e: keep the live row across a single-sound load
|@EDIT 400dd34e 4fefffe048d77c1c jmp sdes 1
sdes:
	movea.l 4(%sp),%a0
	move.l %a0,%d0
	beq.s 1f
	moveq #0,%d1
	move.b 220(%a0),%d1
	lsl.l #8,%d1
	move.b 221(%a0),%d1
	move.l %d1,-(%sp)
	move.l 12(%sp),-(%sp)
	move.l 12(%sp),-(%sp)
	bsr.s 1f
	addq.l #8,%sp
	move.l (%sp)+,%d1
	movea.l 4(%sp),%a0
	move.b %d1,221(%a0)
	lsr.l #8,%d1
	move.b %d1,220(%a0)
	rts
1:	lea -32(%sp),%sp
	movem.l %d2-%d4/%a2-%a6,(%sp)
	jmp 0x400dd356

| kit stored -> RAM (0x400ddf52): rows from the stored sounds. a2 stored kit, a3 RAM kit
|@EDIT 400ddf52 486a281847eb5d20 jmp kload 1
kload:
	lea SROW0(%a2),%a0
	lea ROW0(%a3),%a1
	moveq #15,%d1
1:	move.b (%a0),(%a1)
	move.b 1(%a0),1(%a1)
	lea SSOUND(%a0),%a0
	lea SOUND(%a1),%a1
	subq.l #1,%d1
	bpl.s 1b
	pea 10264(%a2)
	lea 23840(%a3),%a3
	jmp 0x400ddf5a

| kit RAM -> stored (0x400de0bc): rows into the stored sounds. a2 stored kit, a3 RAM kit
|@EDIT 400de0bc 2f02486b5d20 jmp ksave 0
ksave:
	lea SROW0(%a2),%a0
	lea ROW0(%a3),%a1
	moveq #15,%d1
1:	move.b (%a1),(%a0)
	move.b 1(%a1),1(%a0)
	lea SSOUND(%a0),%a0
	lea SOUND(%a1),%a1
	subq.l #1,%d1
	bpl.s 1b
	move.l %d2,-(%sp)
	pea 23840(%a3)
	jmp 0x400de0c2

| ---------- the TRACK LAYERING screen: a third page, BLOCKS
| constructor (0x4010fcfe): page 0, three pages
|@EDIT 4010fcfe 42aa01747002 jmp vinit 0
vinit:
	clr.l 372(%a2)
	clr.l flag
	bsr.s settitle
	moveq #3,%d0
	jmp 0x4010fd04
| UP/DOWN page change (0x401105b0)
|@EDIT 401105b0 254101742f0a jmp vpage 0
vpage:
	move.l %d1,372(%a2)
	clr.l flag
	moveq #2,%d0
	cmp.l %d1,%d0
	bne.s 1f
	move.l %d0,flag
1:	bsr.s settitle
	move.l %a2,-(%sp)
	jmp 0x401105b6
| title text follows the flag (clobbers d0, a0, a1)
settitle:
	lea title+3,%a0
	lea chokes,%a1
	tst.l flag
	beq.s 1f
	lea blocks,%a1
1:	moveq #5,%d0
2:	move.b (%a1)+,(%a0)+
	subq.l #1,%d0
	bpl.s 2b
	rts
chokes:	.ascii "CHOKES"
blocks:	.ascii "BLOCKS"
	.balign 2
| draw: pages 1 and 2 both draw the grid page (0x4010ff62: bne -> nops)
|@RAW 4010ff62 66000120 4e714e71
| its title from our buffer (0x4010ff92 pea "%s CHOKES...")
|@RAWSYM 4010ff92 48794021fdcf 4879 title
| cell toggle (0x401102a8): page 1 as stock; page 2 toggles BLOCKS with no layering exclusion
|@EDIT 401102a8 7201b2806638 jmp vtoggle 0
vtoggle:
	moveq #1,%d1
	cmp.l %d0,%d1
	bne.s 1f
	jmp 0x401102ae
1:	moveq #2,%d1
	cmp.l %d0,%d1
	bne.s 2f
	jmp 0x401102c2
2:	jmp 0x401102e6
| cell glyph (0x401103a2): page 2 shows only BLOCKS (on: 49, off: 1)
|@EDIT 401103a2 7201b28066e2 jmp vglyph 0
vglyph:
	moveq #1,%d1
	cmp.l %d0,%d1
	bne.s 1f
	jmp 0x401103a8
1:	moveq #2,%d1
	cmp.l %d0,%d1
	beq.s 2f
	jmp 0x4011038a
2:	move.l %a2,-(%sp)
	move.l %d3,-(%sp)
	move.l %d4,-(%sp)
	jsr (%a4)
	lea 12(%sp),%sp
	tst.b %d0
	beq.s 3f
	jmp 0x401103d4
3:	jmp 0x4011039e

| choke getter 0x40031758(kitobj, src, dest) -> BLOCKS when the screen is on page 2
|@EDIT 40031758 2f0a246f0008 jmp bget 0
bget:
	tst.l flag
	bne.s 1f
	move.l %a2,-(%sp)
	movea.l 8(%sp),%a2
	jmp 0x4003175e
1:	move.l %a2,-(%sp)
	movea.l 8(%sp),%a2
	movea.l (%a2),%a0
	move.l %a2,-(%sp)
	movea.l 52(%a0),%a0
	jsr (%a0)
	addq.l #4,%sp
	tst.l %d0
	beq.s 2f
	movea.l %d0,%a0
	move.l 12(%sp),%d1            | src
	move.l #SOUND,%d0
	mulu.l %d0,%d1
	adda.l %d1,%a0
	moveq #0,%d0
	move.b ROW0(%a0),%d0
	lsl.l #8,%d0
	move.b ROW0+1(%a0),%d0
	move.l 16(%sp),%d1            | dest
	lsr.l %d1,%d0
	moveq #1,%d1
	and.l %d1,%d0
2:	movea.l (%sp)+,%a2
	rts

| choke setter 0x400316b8(kitobj, src, dest, on) -> BLOCKS when the screen is on page 2
|@EDIT 400316b8 4fefffec48d70c1c jmp bset 1
bset:
	tst.l flag
	bne.s 1f
	lea -20(%sp),%sp
	movem.l %d2-%d4/%a2-%a3,(%sp)
	jmp 0x400316c0
1:	lea -12(%sp),%sp
	movem.l %d2-%d3/%a2,(%sp)
	movea.l 16(%sp),%a2           | kitobj
	movea.l (%a2),%a0
	move.l %a2,-(%sp)
	movea.l 52(%a0),%a0
	jsr (%a0)
	addq.l #4,%sp
	tst.l %d0
	beq.s 3f
	movea.l %d0,%a0
	move.l 20(%sp),%d1            | src
	move.l #SOUND,%d0
	mulu.l %d0,%d1
	adda.l %d1,%a0
	lea ROW0(%a0),%a0
	moveq #0,%d2
	move.b (%a0),%d2
	lsl.l #8,%d2
	move.b 1(%a0),%d2
	move.l 24(%sp),%d1            | dest
	moveq #1,%d3
	lsl.l %d1,%d3
	tst.b 31(%sp)                 | on (byte of the 4th argument)
	beq.s 2f
	or.l %d3,%d2
	bra.s 4f
2:	not.l %d3
	and.l %d3,%d2
4:	move.b %d2,1(%a0)
	lsr.l #8,%d2
	move.b %d2,(%a0)
	movea.l (%a2),%a0             | notify(kitobj, 0), as stock's setter ends
	clr.l -(%sp)
	move.l %a2,-(%sp)
	movea.l 80(%a0),%a0
	jsr (%a0)
	addq.l #8,%sp
3:	movem.l (%sp),%d2-%d3/%a2
	lea 12(%sp),%sp
	rts

| exported names for the sites (mod.json)
	.globl blk_bget
	.set blk_bget, bget
	.globl blk_bset
	.set blk_bset, bset
	.globl blk_gate
	.set blk_gate, gate
	.globl blk_kload
	.set blk_kload, kload
	.globl blk_ksave
	.set blk_ksave, ksave
	.globl blk_sdes
	.set blk_sdes, sdes
	.globl blk_title
	.set blk_title, title
	.globl blk_vglyph
	.set blk_vglyph, vglyph
	.globl blk_vinit
	.set blk_vinit, vinit
	.globl blk_vpage
	.set blk_vpage, vpage
	.globl blk_vtoggle
	.set blk_vtoggle, vtoggle
