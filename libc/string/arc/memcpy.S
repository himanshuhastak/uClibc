/*
 * Copyright (C) 2013, 2014-2015, 2017 Synopsys, Inc. (www.synopsys.com)
 * Copyright (C) 2007 ARC International (UK) LTD
 *
 * Licensed under the LGPL v2.1 or later, see the file COPYING.LIB in this tarball.
 */

#include <sysdep.h>

#if !defined(__ARC700__) && !defined(__ARCHS__)
#error "Neither ARC700 nor ARCHS is defined!"
#endif

ENTRY(memcpy)

#ifdef __ARC700__
/* This memcpy implementation does not support objects of 1GB or larger -
   the check for alignment does not work then.  */
/* We assume that most sources and destinations are aligned, and
   that also lengths are mostly a multiple of four, although to a lesser
   extent.  */
	or	r3,r0,r1
	asl_s	r3,r3,30
	mov_s	r5,r0
	brls.d	r2,r3,.Lcopy_bytewise
	sub.f	r3,r2,1
	ld_s	r12,[r1,0]
	asr.f	lp_count,r3,3
	bbit0.d	r3,2,.Lnox4
	bmsk_s	r2,r2,1
	st.ab	r12,[r5,4]
	ld.a	r12,[r1,4]
.Lnox4:
	lppnz	.Lendloop
	ld_s	r3,[r1,4]
	st.ab	r12,[r5,4]
	ld.a	r12,[r1,8]
	st.ab	r3,[r5,4]
.Lendloop:
	breq	r2,0,.Last_store
	ld	r3,[r5,0]
#ifdef __LITTLE_ENDIAN__
	add3	r2,-1,r2
	; uses long immediate
	xor_s	r12,r12,r3
	bmsk	r12,r12,r2
        xor_s	r12,r12,r3
#else /* BIG ENDIAN */
	sub3	r2,31,r2
	; uses long immediate
        xor_s	r3,r3,r12
        bmsk	r3,r3,r2
        xor_s	r12,r12,r3
#endif /* ENDIAN */
.Last_store:
	j_s.d	[blink]
	st	r12,[r5,0]

	.balign	4
.Lcopy_bytewise:
	jcs	[blink]
	ldb_s	r12,[r1,0]
	lsr.f	lp_count,r3
	bhs_s	.Lnox1
	stb.ab	r12,[r5,1]
	ldb.a	r12,[r1,1]
.Lnox1:
	lppnz	.Lendbloop
	ldb_s	r3,[r1,1]
	stb.ab	r12,[r5,1]
	ldb.a	r12,[r1,2]
	stb.ab	r3,[r5,1]
.Lendbloop:
	j_s.d	[blink]
	stb	r12,[r5,0]
#endif /* __ARC700__ */

#ifdef __ARCHS__
#ifdef __LITTLE_ENDIAN__
# define SHIFT_1(RX,RY,IMM)	asl	RX, RY, IMM	; <<
# define SHIFT_2(RX,RY,IMM)	lsr	RX, RY, IMM	; >>
# define MERGE_1(RX,RY,IMM)	asl	RX, RY, IMM
# define MERGE_2(RX,RY,IMM)
# define EXTRACT_1(RX,RY,IMM)	and	RX, RY, 0xFFFF
# define EXTRACT_2(RX,RY,IMM)	lsr	RX, RY, IMM
#else
# define SHIFT_1(RX,RY,IMM)	lsr	RX, RY, IMM	; >>
# define SHIFT_2(RX,RY,IMM)	asl	RX, RY, IMM	; <<
# define MERGE_1(RX,RY,IMM)	asl	RX, RY, IMM	; <<
# define MERGE_2(RX,RY,IMM)	asl	RX, RY, IMM	; <<
# define EXTRACT_1(RX,RY,IMM)	lsr	RX, RY, IMM
# define EXTRACT_2(RX,RY,IMM)	lsr	RX, RY, 0x08
#endif

#if defined(__LL64__) || defined(__ARC_LL64__)
# define PREFETCH_READ(RX)	prefetch [RX, 56]
# define PREFETCH_WRITE(RX)	prefetchw [RX, 64]
# define LOADX(DST,RX)		ldd.ab	DST, [RX, 8]
# define STOREX(SRC,RX)		std.ab	SRC, [RX, 8]
# define ZOLSHFT		5
# define ZOLAND			0x1F
#else
# define PREFETCH_READ(RX)	prefetch [RX, 28]
# define PREFETCH_WRITE(RX)	prefetchw [RX, 32]
# define LOADX(DST,RX)		ld.ab	DST, [RX, 4]
# define STOREX(SRC,RX)		st.ab	SRC, [RX, 4]
# define ZOLSHFT		4
# define ZOLAND			0xF
#endif

	prefetch  [r1]		; Prefetch the read location
	prefetchw [r0]		; Prefetch the write location
	mov.f	0, r2
;;; if size is zero
	jz.d	[blink]
	mov	r3, r0		; don't clobber ret val

;;; if size <= 8
	cmp	r2, 8
	bls.d	@.Lsmallchunk
	mov.f	lp_count, r2

	and.f	r4, r0, 0x03
	rsub	lp_count, r4, 4
	lpnz	@.Laligndestination
	;; LOOP BEGIN
	ldb.ab	r5, [r1,1]
	sub	r2, r2, 1
	stb.ab	r5, [r3,1]
.Laligndestination:

;;; Check the alignment of the source
	and.f	r4, r1, 0x03
	bnz.d	@.Lsourceunaligned

;;; CASE 0: Both source and destination are 32bit aligned
;;; Convert len to Dwords, unfold x4
	lsr.f	lp_count, r2, ZOLSHFT
	lpnz	@.Lcopy32_64bytes
	;; LOOP START
	LOADX (r6, r1)
	PREFETCH_READ (r1)
	PREFETCH_WRITE (r3)
	LOADX (r8, r1)
	LOADX (r10, r1)
	LOADX (r4, r1)
	STOREX (r6, r3)
	STOREX (r8, r3)
	STOREX (r10, r3)
	STOREX (r4, r3)
.Lcopy32_64bytes:

	and.f	lp_count, r2, ZOLAND ;Last remaining 31 bytes
.Lsmallchunk:
	lpnz	@.Lcopyremainingbytes
	;; LOOP START
	ldb.ab	r5, [r1,1]
	stb.ab	r5, [r3,1]
.Lcopyremainingbytes:

	j	[blink]
;;; END CASE 0

.Lsourceunaligned:
	cmp	r4, 2
	beq.d	@.LunalignedOffby2
	sub	r2, r2, 1

	bhi.d	@.LunalignedOffby3
	ldb.ab	r5, [r1, 1]

;;; CASE 1: The source is unaligned, off by 1
	;; Hence I need to read 1 byte for a 16bit alignment
	;; and 2bytes to reach 32bit alignment
	ldh.ab	r6, [r1, 2]
	sub	r2, r2, 2
	;; Convert to words, unfold x2
	lsr.f	lp_count, r2, 3
	MERGE_1 (r6, r6, 8)
	MERGE_2 (r5, r5, 24)
	or	r5, r5, r6

	;; Both src and dst are aligned
	lpnz	@.Lcopy8bytes_1
	;; LOOP START
	ld.ab	r6, [r1, 4]
	prefetch [r1, 28]	;Prefetch the next read location
	ld.ab	r8, [r1,4]
	prefetchw [r3, 32]	;Prefetch the next write location

	SHIFT_1	(r7, r6, 24)
	or	r7, r7, r5
	SHIFT_2	(r5, r6, 8)

	SHIFT_1	(r9, r8, 24)
	or	r9, r9, r5
	SHIFT_2	(r5, r8, 8)

	st.ab	r7, [r3, 4]
	st.ab	r9, [r3, 4]
.Lcopy8bytes_1:

	;; Write back the remaining 16bits
	EXTRACT_1 (r6, r5, 16)
	sth.ab	r6, [r3, 2]
	;; Write back the remaining 8bits
	EXTRACT_2 (r5, r5, 16)
	stb.ab	r5, [r3, 1]

	and.f	lp_count, r2, 0x07 ;Last 8bytes
	lpnz	@.Lcopybytewise_1
	;; LOOP START
	ldb.ab	r6, [r1,1]
	stb.ab	r6, [r3,1]
.Lcopybytewise_1:
	j	[blink]

.LunalignedOffby2:
;;; CASE 2: The source is unaligned, off by 2
	ldh.ab	r5, [r1, 2]
	sub	r2, r2, 1

	;; Both src and dst are aligned
	;; Convert to words, unfold x2
	lsr.f	lp_count, r2, 3
#ifdef __BIG_ENDIAN__
	asl.nz	r5, r5, 16
#endif
	lpnz	@.Lcopy8bytes_2
	;; LOOP START
	ld.ab	r6, [r1, 4]
	prefetch [r1, 28]	;Prefetch the next read location
	ld.ab	r8, [r1,4]
	prefetchw [r3, 32]	;Prefetch the next write location

	SHIFT_1	(r7, r6, 16)
	or	r7, r7, r5
	SHIFT_2	(r5, r6, 16)

	SHIFT_1	(r9, r8, 16)
	or	r9, r9, r5
	SHIFT_2	(r5, r8, 16)

	st.ab	r7, [r3, 4]
	st.ab	r9, [r3, 4]
.Lcopy8bytes_2:

#ifdef __BIG_ENDIAN__
	lsr.nz	r5, r5, 16
#endif
	sth.ab	r5, [r3, 2]

	and.f	lp_count, r2, 0x07 ;Last 8bytes
	lpnz	@.Lcopybytewise_2
	;; LOOP START
	ldb.ab	r6, [r1,1]
	stb.ab	r6, [r3,1]
.Lcopybytewise_2:
	j	[blink]

.LunalignedOffby3:
;;; CASE 3: The source is unaligned, off by 3
;;; Hence, I need to read 1byte for achieve the 32bit alignment

	;; Both src and dst are aligned
	;; Convert to words, unfold x2
	lsr.f	lp_count, r2, 3
#ifdef __BIG_ENDIAN__
	asl.ne	r5, r5, 24
#endif
	lpnz	@.Lcopy8bytes_3
	;; LOOP START
	ld.ab	r6, [r1, 4]
	prefetch [r1, 28]	;Prefetch the next read location
	ld.ab	r8, [r1,4]
	prefetchw [r3, 32]	;Prefetch the next write location

	SHIFT_1	(r7, r6, 8)
	or	r7, r7, r5
	SHIFT_2	(r5, r6, 24)

	SHIFT_1	(r9, r8, 8)
	or	r9, r9, r5
	SHIFT_2	(r5, r8, 24)

	st.ab	r7, [r3, 4]
	st.ab	r9, [r3, 4]
.Lcopy8bytes_3:

#ifdef __BIG_ENDIAN__
	lsr.nz	r5, r5, 24
#endif
	stb.ab	r5, [r3, 1]

	and.f	lp_count, r2, 0x07 ;Last 8bytes
	lpnz	@.Lcopybytewise_3
	;; LOOP START
	ldb.ab	r6, [r1,1]
	stb.ab	r6, [r3,1]
.Lcopybytewise_3:
	j	[blink]
#endif /* __ARCHS__ */

#ifdef __ARCV3__

#if defined (__ARC64_M128__)
	lsrl.f	r12, r2, 6	; Check size < 64bytes
	beq.d	@.L_write_1_bytes
	movl	r3, r0
.L_write_64_bytes:
	lddl.ab	r4r5, [r1, +16]
	lddl.ab	r6r7, [r1, +16]
	lddl.ab	r8r9, [r1, +16]
	lddl.ab	r10r11, [r1, +16]
	stdl.ab	r4r5, [r3, +16]
	stdl.ab	r6r7, [r3, +16]
	stdl.ab	r8r9, [r3, +16]
	dbnz.d	r12, @.L_write_64_bytes
	stdl.ab	r10r11, [r3, +16]
.L_write_1_bytes:
	;; Handle anything between 15bytes < size < 64bytes
	;; The algorithm has two phases:
	;; - copy 16, 32, or 48 bytes of data using 128bit ops
	;; - copy the remaining 15 bytes of data using a single stdl/lddl pair
	bmsk.f	r2, r2, 5	; Check size == 0
	jeq.d	[blink]
	lsr.f	r12, r2, 4	; Check size < 16bytes
	beq.d	@1f
	xor	r12, r12, 3
	;; R12 can be 3,2, or 1, which are indicating how much data we should
	;; copy: 3 -> 48bytes, 2 -> 32bytes, 1 -> 16bytes.
	;; Zero case shouldn't happen as we check for it above.
	;; Then I use the BI instructions to implement the following code
	;; switch ($R12)
	;;  case 3:
	;;    lddl RA, ...
	;;    stdl RA, ...
	;;  case 2:
	;;    lddl RA, ...
	;;    stdl RA, ...
	;;  case 1:
	;;    lddl RA, ...
	;;    stdl RA, ...
	;;  case 0:
	;;    break
	;; N.B the BI instruction works the other way than I expected, namely
	;; BI's entry 0 is the closest to instruction, hence I need to bit
	;; invert R12 to get the desired behaviour (done by above XOR).
	asl	r12,r12,1
	bi	[r12]
	lddl.ab	r4r5, [r1, +16]
	stdl.ab	r4r5, [r3, +16]
	lddl.ab	r6r7, [r1, +16]
	stdl.ab	r6r7, [r3, +16]
	lddl.ab	r8r9, [r1, +16]
	stdl.ab	r8r9, [r3, +16]
	bmsk.f	r2, r2, 3	; Check size == 0
	jeq.d	[blink]
	subl	r2, r2, 16
	;; We are still having 15 bytes top to transfer, exactly like in the
	;; case of below byte-by-byte transfer.  However, we already transfered
	;; at least 16bytes before, thus, we can create a new 16byte load which
	;; re-reads parts of the already transfer data AND the remaining up to
	;; 15 bytes of data still to be transfered.
	;; The position of the window is controlled by the $r12 which is the
	;; complement of the number of remaining bytes.
	addl	r3, r3, r2
	lddl	r4r5, [r1, r2]
	j_s.d	[blink]
	stdl	r4r5, [r3]
1:
	;; Anything size < 16 we go byte by byte.
	ldb.ab	r4, [r1, +1]
	dbnz.d	r2, @1b
	stb.ab	r4, [r3, +1]
	j_s	[blink]

; The generic 64-bit implementation without any frills.
#elif defined (__ARC64_ARCH64__) || defined (__ARC64_LL64__)
; R0: dest
; R1: source
; R2: count
; ret (R0): dest
; clobber: r1, r3, r4r5, r6r7, r8r9, r10r11, r13
	LSRP.f	r12, r2, 5		; counter for 32-byte chunks
	beq.d	@.L_write_31_bytes
	MOVP	r3, r0			; do not clobber the "dest"
.L_write_32_bytes:
	LD64.ab	r4, [r1, +8]
	LD64.ab	r6, [r1, +8]
	LD64.ab	r8, [r1, +8]
	LD64.ab	r10,[r1, +8]
	ST64.ab	r4, [r3, +8]
	ST64.ab	r6, [r3, +8]
	ST64.ab	r8, [r3, +8]
	dbnz.d	r12, @.L_write_32_bytes
	ST64.ab	r10, [r3, +8]
	bmsk_s	r2, r2, 4

.L_write_31_bytes:
	bbit0.d	r2, 2, @1f
	lsr	r12, r2, 3
	ld.ab	r4, [r1, 4]
	st.ab	r4, [r3, 4]
1:
	bbit0.d	r2, 1, @1f
	xor	r12, r12, 3
	ldh.ab	r4, [r1, 2]
	sth.ab	r4, [r3, 2]
1:
	bbit0.d	r2, 0, @1f
	asl	r12, r12, 1
	ldb.ab	r4, [r1, 1]
	stb.ab	r4, [r3, 1]
1:
	bi	[r12]
	LD64.ab	r4, [r1, 8]
	ST64.ab	r4, [r3, 8]
	LD64.ab	r4, [r1, 8]
	ST64.ab	r4, [r3, 8]
	LD64.ab	r4, [r1, 8]
	ST64.ab	r4, [r3, 8]

	j_s	[blink]
#elif defined (__ARC64_ARCH32__)

	lsr.f	r11, r2, 4		; counter for 16-byte chunks
	beq.d	@.L_write_15_bytes
	mov	r3, r0			; work on a copy of "r0"
.L_write_16_bytes:
	ld.ab	r4, [r1, 4]
	ld.ab	r5, [r1, 4]
	ld.ab	r6, [r1, 4]
	ld.ab	r7, [r1, 4]
	st.ab	r4, [r3, 4]
	st.ab	r5, [r3, 4]
	st.ab	r6, [r3, 4]
	dbnz.d	r11, @.L_write_16_bytes
	st.ab	r7, [r3, 4]
	bmsk_s	r2, r2, 3

.L_write_15_bytes:
	bbit0.d	r2, 1, @1f
	lsr	r11, r2, 2
	ldh.ab	r4, [r1, 2]
	sth.ab	r4, [r3, 2]
1:
	bbit0.d	r2, 0, @1f
	xor	r11, r11, 3
	ldb.ab	r4, [r1, 1]
	stb.ab	r4, [r3, 1]
1:
	asl	r11, r11, 1
	bi	[r11]
	ld.ab	r4,[r1, 4]
	st.ab	r4,[r3, 4]
	ld.ab	r4,[r1, 4]
	st.ab	r4,[r3, 4]
	ld	r4,[r1]
	st	r4,[r3]

	j_s	[blink]

#endif
#endif /* __ARCV3__ */

END(memcpy)
libc_hidden_def(memcpy)
