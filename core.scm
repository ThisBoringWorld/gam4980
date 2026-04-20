(use-modules
 (srfi srfi-1)
 (srfi srfi-26)
 (ice-9 format)
 (sph lang sc))


;;; 65c02 emulation based on vrEmu6502 (MIT license) by Troy Schrapel.
;;;   https://github.com/visrealm/vrEmu6502
(define code.sc
  (let* ((macros '((CYCLES n) (set+ executed n)
                   EXIT (goto _exit)
                   NEXT (goto _next)
                   FLAG_N 0x80
                   FLAG_V 0x40
                   FLAG_U 0x20
                   FLAG_B 0x10
                   FLAG_D 0x08
                   FLAG_I 0x04
                   FLAG_Z 0x02
                   FLAG_C 0x01
                   NEGATIVE? (bit-and status FLAG_N)
                   OVERFLOW? (bit-and status FLAG_V)
                   DECIMAL? (bit-and status FLAG_D)
                   ZERO? (bit-and status FLAG_Z)
                   CARRY? (bit-and status FLAG_C)
                   CARRY (if* CARRY? 1 0)

                   (SET_BIT flag x) (set status (bit-and status (bit-not flag))
                                         status (bit-or status (* (not (not x)) flag)))
                   (SET_N x) (SET_BIT FLAG_N x)
                   (SET_V x) (SET_BIT FLAG_V x)
                   (SET_D x) (SET_BIT FLAG_D x)
                   (SET_I x) (SET_BIT FLAG_I x)
                   (SET_Z x) (SET_BIT FLAG_Z x)
                   (SET_C x) (SET_BIT FLAG_C x)
                   (SET_NZ x) (let* ((v uint8_t x))
                                (set status (bit-and status
                                                     (bit-not (bit-or FLAG_N FLAG_Z)))
                                     status (bit-or status (bit-and v FLAG_N))
                                     status (bit-or status (* (not v) FLAG_Z))))
                   (PUSH x) (begin (WRITE8 (bit-or 0x100 sp) x)
                                   (set- sp 1))
                   (POP x) (READ8 (bit-or 0x100 (sc-insert "++sp")))))
         (page-boundary
          (lambda (addr1 addr2)
            `(CYCLES (not (not (bit-and 0xff00 (bit-xor ,addr1 ,addr2)))))))
         (*ab '(set ea (READX16 pc)
                    pc (+ pc 2)))
         (*abx '(set et (READX16 pc)
                     ea (+ et ix)
                     pc (+ pc 2)))
         (*aby '(set et (READX16 pc)
                     ea (+ et iy)
                     pc (+ pc 2)))
         (*axp `(begin ,*abx ,(page-boundary 'et 'ea)))
         (*ayp `(begin ,*aby ,(page-boundary 'et 'ea)))
         (*imm '(set ea pc
                     pc (+ pc 1)))
         (*ind '(set ea (READ16 (READX16 pc))
                     pc (+ pc 1)))
         (*indx '(set ea (READ16 (+ (READX16 pc) ix))
                      pc (+ pc 1)))
         (*rel '(set ea (+ pc 1 (convert-type (READX8 pc) int8_t))
                     pc (+ pc 1)))
         (*xin '(set ea (READ16W (bit-and 0xff (+ (READX8 pc) ix)))
                     pc (+ pc 1)))
         (*yin '(set et (READ16W (READX8 pc))
                     pc (+ pc 1)
                     ea (+ et iy)))
         (*yip `(begin ,*yin ,(page-boundary 'et 'ea)))
         (*zp '(set ea (READX8 pc)
                    pc (+ pc 1)))
         (*zpi '(set ea (READ16W (READX8 pc))
                     pc (+ pc 1)))
         (*zpx '(set ea (bit-and (+ ix (READX8 pc)) 0xff)
                     pc (+ pc 1)))
         (*zpy '(set ea (bit-and (+ iy (READX8 pc)) 0xff)
                     pc (+ pc 1)))
         (*acc '(begin))
         (*imp '(begin))
         (*adcd '(begin
                   (CYCLES 1)
                   (set dt (READ8 ea))
                   (let* ((vu uint8_t (bit-and dt 0x0f))
                          (vt uint8_t (bit-shift-right (bit-and dt 0xf0) 4))
                          (au uint8_t (bit-and ac 0x0f))
                          (at uint8_t (bit-shift-right (bit-and ac 0xf0) 4))
                          (units uint8_t (+ vu au CARRY))
                          (tens uint8_t (+ vt at))
                          (tc uint8_t 0))
                     (when (> units 0x09)
                       (set tc 1
                            tens (+ tens 0x01)
                            units (+ units 0x06)))
                     (when (> tens 0x09)
                       (set+ tens 0x06))
                     (when (bit-and at 0x08)
                       (set at (bit-or at 0xf0)))
                     (when (bit-and vt 0x08)
                       (set vt (bit-or vt 0xf0)))
                     (let* ((res int8_t (convert-type (+ at vt tc) int8_t)))
                       (SET_V (or (< res -8) (> res 7)))
                       (SET_NZ (set ac (bit-or (bit-shift-left tens 4) (bit-and units 0x0f)))))
                     (SET_C (bit-and tens 0xf0)))))
         (*adc `(if DECIMAL?
                    ,*adcd
                    (begin
                      (set dt (READ8 ea)
                           et (+ ac dt CARRY))
                      (SET_C (> et 0xff))
                      (SET_V (bit-and (bit-xor ac et) (bit-xor dt et) 0x80))
                      (SET_NZ (set ac (convert-type et uint8_t))))))

         (*and '(begin
                  (set ac (bit-and ac (READ8 ea)))
                  (SET_NZ ac)))
         (*asl '(begin
                  (set dt (READ8 ea))
                  (SET_C (bit-and 0x80 dt))
                  (set dt (bit-shift-left dt 1))
                  (SET_NZ dt)
                  (WRITE8 ea dt)))
         (*asl/acc '(begin
                      (SET_C (bit-and 0x80 ac))
                      (set ac (bit-shift-left ac 1))
                      (SET_NZ ac)))
         (*bra `(begin
                  (CYCLES 1)
                  ,(page-boundary 'pc 'ea)
                  (set pc ea)))
         (*bcc `(when (not CARRY?) ,*bra))
         (*bcs `(when CARRY? ,*bra))
         (*beq `(when ZERO? ,*bra))
         (*bit '(begin
                  (set dt (READ8 ea))
                  (SET_V (bit-and dt 0x40))
                  (SET_N (bit-and dt 0x80))
                  (SET_Z (not (bit-and ac dt)))))
         (*bit/imm '(begin
                      (set dt (READ8 ea))
                      (SET_Z (not (bit-and ac dt)))))
         (*bmi `(when NEGATIVE? ,*bra))
         (*bne `(when (not ZERO?) ,*bra))
         (*bpl `(when (not NEGATIVE?) ,*bra))
         (*brk 'BRK_HOOK)
         (*bvc `(when (not OVERFLOW?) ,*bra))
         (*bvs `(when OVERFLOW? ,*bra))
         (*clc '(SET_C 0))
         (*cld '(SET_D 0))
         (*cli '(SET_I 0))
         (*clv '(SET_V 0))
         (*cmp '(begin
                  (set dt (bit-not (READ8 ea))
                       et (+ ac dt 1))
                  (SET_C (> et 0xff))
                  (SET_NZ (convert-type et uint8_t))))
         (*cpx '(begin
                  (set dt (bit-not (READ8 ea))
                       et (+ ix dt 1))
                  (SET_C (> et 0xff))
                  (SET_NZ (convert-type et uint8_t))))
         (*cpy '(begin
                  (set dt (bit-not (READ8 ea))
                       et (+ iy dt 1))
                  (SET_C (> et 0xff))
                  (SET_NZ (convert-type et uint8_t))))
         (*dec '(begin
                  (set dt (- (READ8 ea) 1))
                  (SET_NZ dt)
                  (WRITE8 ea dt)))
         (*dec/acc '(begin
                      (set- ac 1)
                      (SET_NZ ac)))
         (*dex '(begin
                  (set- ix 1)
                  (SET_NZ ix)))
         (*dey '(begin
                  (set- iy 1)
                  (SET_NZ iy)))
         (*eor '(begin
                  (set dt (READ8 ea)
                       ac (bit-xor ac dt))
                  (SET_NZ ac)))
         (*inc '(begin
                  (set dt (+ (READ8 ea) 1))
                  (SET_NZ dt)
                  (WRITE8 ea dt)))
         (*inc/acc '(begin
                      (set+ ac 1)
                      (SET_NZ ac)))
         (*inx '(begin
                  (set+ ix 1)
                  (SET_NZ ix)))
         (*iny '(begin
                  (set+ iy 1)
                  (SET_NZ iy)))
         (*jmp '(set pc ea))
         (*jsr '(begin
                  (set pc (- pc 1))
                  (PUSH (bit-shift-right pc 8))
                  (PUSH (bit-and pc 0xff))
                  (set pc ea)))
         (*lda '(begin
                  (set ac (READ8 ea))
                  (SET_NZ ac)))
         (*ldx '(begin
                  (set ix (READ8 ea))
                  (SET_NZ ix)))
         (*ldy '(begin
                  (set iy (READ8 ea))
                  (SET_NZ iy)))
         (*lsr '(begin
                  (set dt (READ8 ea))
                  (SET_C (bit-and 0x01 dt))
                  (set dt (bit-shift-right dt 1))
                  (SET_NZ dt)
                  (WRITE8 ea dt)))
         (*lsr/acc '(begin
                      (SET_C (bit-and 0x01 ac))
                      (set ac (bit-shift-right ac 1))
                      (SET_NZ ac)))
         (*nop '(begin))
         (*ldd '(READ8 ea))
         (*ora '(begin
                  (set ac (bit-or ac (READ8 ea)))
                  (SET_NZ ac)))
         (*pha '(PUSH ac))
         (*php '(PUSH (bit-or status FLAG_B FLAG_U)))
         (*phx '(PUSH ix))
         (*phy '(PUSH iy))
         (*pla '(SET_NZ (set ac (POP))))
         (*plp '(set status (bit-or (POP) FLAG_U FLAG_B)))
         (*plx '(SET_NZ (set ix (POP))))
         (*ply '(begin
                  (set iy (POP))
                  (SET_NZ iy)))
         (*rol '(begin
                  (set dt (READ8 ea)
                       et (bit-and dt 0x80)
                       dt (bit-or CARRY (bit-shift-left dt 1)))
                  (SET_C et)
                  (SET_NZ dt)
                  (WRITE8 ea dt)))
         (*rol/acc '(begin
                      (set dt (bit-and ac 0x80)
                           ac (bit-or CARRY (bit-shift-left ac 1)))
                      (SET_C dt)
                      (SET_NZ ac)))
         (*ror '(begin
                  (set dt (READ8 ea)
                       et (bit-and dt 0x01)
                       dt (bit-or (* 0x80 CARRY) (bit-shift-right dt 1)))
                  (SET_C et)
                  (SET_NZ dt)
                  (WRITE8 ea dt)))
         (*ror/acc '(begin
                      (set dt (bit-and ac 0x01)
                           ac (bit-or (* 0x80 CARRY) (bit-shift-right ac 1)))
                      (SET_C dt)
                      (SET_NZ ac)))
         (*rti '(set status (bit-or (POP) FLAG_U FLAG_B)
                     pc (POP)
                     pc (bit-or pc (bit-shift-left (POP) 8))))
         (*rts '(set pc (POP)
                     pc (bit-or pc (bit-shift-left (POP) 8))
                     pc (+ pc 1)))
         (*sbcd '(begin
                   (CYCLES 1)
                   (set dt (READ8 ea)
                        et (+ ac (bit-not dt) CARRY)
                        ea (- ac dt (not CARRY)))
                   (when (bit-and ea 0x8000)
                     (set- ea 0x60))
                   (when (bit-and (- (bit-and ac 0x0f) (bit-and dt 0x0f) (not CARRY)) 0x8000)
                     (set- ea 0x06))
                   (SET_V (bit-and (bit-xor ac et) (bit-xor (bit-not dt) et) 0x80))
                   (SET_NZ (convert-type ea uint8_t))
                   (SET_C (or (<= ea (convert-type ac uint16_t))
                              (= (bit-and ea 0xff0) 0xff0)))
                   (set ac (bit-and ea 0xff))))
         (*sbc `(if DECIMAL?
                    ,*sbcd
                    (begin
                      (set dt (bit-not (READ8 ea))
                           et (+ ac dt CARRY))
                      (SET_C (> et 0xff))
                      (SET_V (bit-and (bit-xor ac et) (bit-xor dt et) 0x80))
                      (set ac (convert-type et uint8_t))
                      (SET_NZ ac))))
         (*sec '(SET_C 1))
         (*sed '(SET_D 1))
         (*sei '(SET_I 1))
         (*sta '(WRITE8 ea ac))
         (*stx '(WRITE8 ea ix))
         (*sty '(WRITE8 ea iy))
         (*stz '(WRITE8 ea 0))
         (*tax '(SET_NZ (set ix ac)))
         (*tay '(SET_NZ (set iy ac)))
         (*tsx '(SET_NZ (set ix sp)))
         (*txa '(SET_NZ (set ac ix)))
         (*txs '(set sp ix))
         (*tya '(SET_NZ (set ac iy)))
         (*trb '(begin
                  (set dt (READ8 ea))
                  (WRITE8 ea (bit-and dt (bit-not ac)))
                  (SET_Z (not (bit-and dt ac)))))
         (*tsb '(begin
                  (set dt (READ8 ea))
                  (WRITE8 ea (bit-or dt ac))
                  (SET_Z (not (bit-and dt ac)))))
         (rmb (lambda (i)
                `(begin
                   (set dt (READ8 ea))
                   (WRITE8
                    ea (bit-and dt (bit-not (bit-shift-left 0x01 ,i)))))))
         (*rmb0 (rmb 0))
         (*rmb1 (rmb 1))
         (*rmb2 (rmb 2))
         (*rmb3 (rmb 3))
         (*rmb4 (rmb 4))
         (*rmb5 (rmb 5))
         (*rmb6 (rmb 6))
         (*rmb7 (rmb 7))
         (smb (lambda (i)
                `(begin
                   (set dt (READ8 ea))
                   (WRITE8
                    ea (bit-or dt (bit-shift-left 0x01 ,i))))))
         (*smb0 (smb 0))
         (*smb1 (smb 1))
         (*smb2 (smb 2))
         (*smb3 (smb 3))
         (*smb4 (smb 4))
         (*smb5 (smb 5))
         (*smb6 (smb 6))
         (*smb7 (smb 7))
         (bbr (lambda (i)
                `(begin
                   (set dt (READ8 ea))
                   (if (not (bit-and dt (bit-shift-left 0x01 ,i)))
                       (begin
                         ,*rel
                         (set pc ea))
                       (set+ pc 1)))))
         (*bbr0 (bbr 0))
         (*bbr1 (bbr 1))
         (*bbr2 (bbr 2))
         (*bbr3 (bbr 3))
         (*bbr4 (bbr 4))
         (*bbr5 (bbr 5))
         (*bbr6 (bbr 6))
         (*bbr7 (bbr 7))
         (bbs (lambda (i)
                `(begin
                   (set dt (READ8 ea))
                   (if (bit-and dt (bit-shift-left 0x01 ,i))
                       (begin
                         ,*rel
                         (set pc ea))
                       (set+ pc 1)))))
         (*bbs0 (bbs 0))
         (*bbs1 (bbs 1))
         (*bbs2 (bbs 2))
         (*bbs3 (bbs 3))
         (*bbs4 (bbs 4))
         (*bbs5 (bbs 5))
         (*bbs6 (bbs 6))
         (*bbs7 (bbs 7))
         (*stp '(begin))
         (*wai '(begin))
         (*err '(begin))

         (opcodes (list
                   *brk *imp 7 'EXIT
                   *ora *xin 6 'NEXT
                   *ldd *imm 2 'NEXT
                   *nop *imp 1 'NEXT
                   *tsb *zp 5 'NEXT
                   *ora *zp 3 'NEXT
                   *asl *zp 5 'NEXT
                   *rmb0 *zp 5 'NEXT
                   *php *imp 3 'NEXT
                   *ora *imm 2 'NEXT
                   *asl/acc *acc 2 'NEXT
                   *nop *imp 1 'NEXT
                   *tsb *ab 6 'NEXT
                   *ora *ab 4 'NEXT
                   *asl *ab 6 'NEXT
                   *bbr0 *zp 5 'NEXT
                   *bpl *rel 2 'EXIT
                   *ora *yip 5 'NEXT
                   *ora *zpi 5 'NEXT
                   *nop *imp 1 'NEXT
                   *trb *zp 5 'NEXT
                   *ora *zpx 4 'NEXT
                   *asl *zpx 6 'NEXT
                   *rmb1 *zp 5 'NEXT
                   *clc *imp 2 'NEXT
                   *ora *ayp 4 'NEXT
                   *inc/acc *acc 2 'NEXT
                   *nop *imp 1 'NEXT
                   *trb *ab 6 'NEXT
                   *ora *axp 4 'NEXT
                   *asl *axp 6 'NEXT
                   *bbr1 *zp 5 'NEXT
                   *jsr *ab 6 'EXIT
                   *and *xin 6 'NEXT
                   *ldd *imm 2 'NEXT
                   *nop *imp 1 'NEXT
                   *bit *zp 3 'NEXT
                   *and *zp 3 'NEXT
                   *rol *zp 5 'NEXT
                   *rmb2 *zp 5 'NEXT
                   *plp *imp 4 'NEXT
                   *and *imm 2 'NEXT
                   *rol/acc *acc 2 'NEXT
                   *nop *imp 1 'NEXT
                   *bit *ab 4 'NEXT
                   *and *ab 4 'NEXT
                   *rol *ab 6 'NEXT
                   *bbr2 *zp 5 'NEXT
                   *bmi *rel 2 'EXIT
                   *and *yip 5 'NEXT
                   *and *zpi 5 'NEXT
                   *nop *imp 1 'NEXT
                   *bit *zpx 4 'NEXT
                   *and *zpx 4 'NEXT
                   *rol *zpx 6 'NEXT
                   *rmb3 *zp 5 'NEXT
                   *sec *imp 2 'NEXT
                   *and *ayp 4 'NEXT
                   *dec/acc *acc 2 'NEXT
                   *nop *imp 1 'NEXT
                   *bit *abx 4 'NEXT
                   *and *axp 4 'NEXT
                   *rol *axp 6 'NEXT
                   *bbr3 *zp 5 'NEXT
                   *rti *imp 6 'EXIT
                   *eor *xin 6 'NEXT
                   *ldd *imm 2 'NEXT
                   *nop *imp 1 'NEXT
                   *ldd *zp 3 'NEXT
                   *eor *zp 3 'NEXT
                   *lsr *zp 5 'NEXT
                   *rmb4 *zp 5 'NEXT
                   *pha *imp 3 'NEXT
                   *eor *imm 2 'NEXT
                   *lsr/acc *acc 2 'NEXT
                   *nop *imp 1 'NEXT
                   *jmp *ab 3 'EXIT
                   *eor *ab 4 'NEXT
                   *lsr *ab 6 'NEXT
                   *bbr4 *zp 5 'NEXT
                   *bvc *rel 2 'EXIT
                   *eor *yip 5 'NEXT
                   *eor *zpi 5 'NEXT
                   *nop *imp 1 'NEXT
                   *ldd *zpx 4 'NEXT
                   *eor *zpx 4 'NEXT
                   *lsr *zpx 6 'NEXT
                   *rmb5 *zp 5 'NEXT
                   *cli *imp 2 'NEXT
                   *eor *ayp 4 'NEXT
                   *phy *imp 3 'NEXT
                   *nop *imp 1 'NEXT
                   *ldd *ab 8 'NEXT
                   *eor *axp 4 'NEXT
                   *lsr *axp 6 'NEXT
                   *bbr5 *zp 5 'NEXT
                   *rts *imp 6 'EXIT
                   *adc *xin 6 'NEXT
                   *ldd *imm 2 'NEXT
                   *nop *imp 1 'NEXT
                   *stz *zp 3 'NEXT
                   *adc *zp 3 'NEXT
                   *ror *zp 5 'NEXT
                   *rmb6 *zp 5 'NEXT
                   *pla *imp 4 'NEXT
                   *adc *imm 2 'NEXT
                   *ror/acc *acc 2 'NEXT
                   *nop *imp 1 'NEXT
                   *jmp *ind 6 'EXIT
                   *adc *ab 4 'NEXT
                   *ror *ab 6 'NEXT
                   *bbr6 *zp 5 'NEXT
                   *bvs *rel 2 'EXIT
                   *adc *yip 5 'NEXT
                   *adc *zpi 5 'NEXT
                   *nop *imp 1 'NEXT
                   *stz *zpx 4 'NEXT
                   *adc *zpx 4 'NEXT
                   *ror *zpx 6 'NEXT
                   *rmb7 *zp 5 'NEXT
                   *sei *imp 2 'NEXT
                   *adc *ayp 4 'NEXT
                   *ply *imp 4 'NEXT
                   *nop *imp 1 'NEXT
                   *jmp *indx 6 'EXIT
                   *adc *axp 4 'NEXT
                   *ror *axp 6 'NEXT
                   *bbr7 *zp 5 'NEXT
                   *bra *rel 2 'EXIT
                   *sta *xin 6 'NEXT
                   *ldd *imm 2 'NEXT
                   *nop *imp 1 'NEXT
                   *sty *zp 3 'NEXT
                   *sta *zp 3 'NEXT
                   *stx *zp 3 'NEXT
                   *smb0 *zp 5 'NEXT
                   *dey *imp 2 'NEXT
                   *bit/imm *imm 2 'NEXT
                   *txa *imp 2 'NEXT
                   *nop *imp 1 'NEXT
                   *sty *ab 4 'NEXT
                   *sta *ab 4 'NEXT
                   *stx *ab 4 'NEXT
                   *bbs0 *zp 5 'NEXT
                   *bcc *rel 2 'EXIT
                   *sta *yin 6 'NEXT
                   *sta *zpi 5 'NEXT
                   *nop *imp 1 'NEXT
                   *sty *zpx 4 'NEXT
                   *sta *zpx 4 'NEXT
                   *stx *zpy 4 'NEXT
                   *smb1 *zp 5 'NEXT
                   *tya *imp 2 'NEXT
                   *sta *aby 5 'NEXT
                   *txs *imp 2 'NEXT
                   *nop *imp 1 'NEXT
                   *stz *ab 4 'NEXT
                   *sta *abx 5 'NEXT
                   *stz *abx 5 'NEXT
                   *bbs1 *zp 5 'NEXT
                   *ldy *imm 2 'NEXT
                   *lda *xin 6 'NEXT
                   *ldx *imm 2 'NEXT
                   *nop *imp 1 'NEXT
                   *ldy *zp 3 'NEXT
                   *lda *zp 3 'NEXT
                   *ldx *zp 3 'NEXT
                   *smb2 *zp 5 'NEXT
                   *tay *imp 2 'NEXT
                   *lda *imm 2 'NEXT
                   *tax *imp 2 'NEXT
                   *nop *imp 1 'NEXT
                   *ldy *ab 4 'NEXT
                   *lda *ab 4 'NEXT
                   *ldx *ab 4 'NEXT
                   *bbs2 *zp 5 'NEXT
                   *bcs *rel 2 'EXIT
                   *lda *yip 5 'NEXT
                   *lda *zpi 5 'NEXT
                   *nop *imp 1 'NEXT
                   *ldy *zpx 4 'NEXT
                   *lda *zpx 4 'NEXT
                   *ldx *zpy 4 'NEXT
                   *smb3 *zp 5 'NEXT
                   *clv *imp 2 'NEXT
                   *lda *ayp 4 'NEXT
                   *tsx *imp 2 'NEXT
                   *nop *imp 1 'NEXT
                   *ldy *axp 4 'NEXT
                   *lda *axp 4 'NEXT
                   *ldx *ayp 4 'NEXT
                   *bbs3 *zp 5 'NEXT
                   *cpy *imm 2 'NEXT
                   *cmp *xin 6 'NEXT
                   *ldd *imm 2 'NEXT
                   *nop *imp 1 'NEXT
                   *cpy *zp 3 'NEXT
                   *cmp *zp 3 'NEXT
                   *dec *zp 5 'NEXT
                   *smb4 *zp 5 'NEXT
                   *iny *imp 2 'NEXT
                   *cmp *imm 2 'NEXT
                   *dex *imp 2 'NEXT
                   *wai *imp 3 'NEXT
                   *cpy *ab 4 'NEXT
                   *cmp *ab 4 'NEXT
                   *dec *ab 6 'NEXT
                   *bbs4 *zp 5 'NEXT
                   *bne *rel 2 'EXIT
                   *cmp *yip 5 'NEXT
                   *cmp *zpi 5 'NEXT
                   *nop *imp 1 'NEXT
                   *ldd *zpx 4 'NEXT
                   *cmp *zpx 4 'NEXT
                   *dec *zpx 6 'NEXT
                   *smb5 *zp 5 'NEXT
                   *cld *imp 2 'NEXT
                   *cmp *ayp 4 'NEXT
                   *phx *imp 3 'NEXT
                   *stp *imp 3 'NEXT
                   *ldd *ab 4 'NEXT
                   *cmp *axp 4 'NEXT
                   *dec *abx 7 'NEXT
                   *bbs5 *zp 5 'NEXT
                   *cpx *imm 2 'NEXT
                   *sbc *xin 6 'NEXT
                   *ldd *imm 2 'NEXT
                   *nop *imp 1 'NEXT
                   *cpx *zp 3 'NEXT
                   *sbc *zp 3 'NEXT
                   *inc *zp 5 'NEXT
                   *smb6 *zp 5 'NEXT
                   *inx *imp 2 'NEXT
                   *sbc *imm 2 'NEXT
                   *nop *imp 2 'NEXT
                   *nop *imp 1 'NEXT
                   *cpx *ab 4 'NEXT
                   *sbc *ab 4 'NEXT
                   *inc *ab 6 'NEXT
                   *bbs6 *zp 5 'NEXT
                   *beq *rel 2 'EXIT
                   *sbc *yip 5 'NEXT
                   *sbc *zpi 5 'NEXT
                   *nop *imp 1 'NEXT
                   *ldd *zpx 4 'NEXT
                   *sbc *zpx 4 'NEXT
                   *inc *zpx 6 'NEXT
                   *smb7 *zp 5 'NEXT
                   *sed *imp 2 'NEXT
                   *sbc *ayp 4 'NEXT
                   *plx *imp 4 'NEXT
                   *nop *imp 1 'NEXT
                   *ldd *ab 4 'NEXT
                   *sbc *axp 4 'NEXT
                   *inc *abx 7 'NEXT
                   *bbs7 *zp 5 'NEXT)))

    `(begin
       (pre-include "stdint.h")
       (declare s6502_t (type (struct
                               (pc uint16_t)
                               (ac uint8_t)
                               (ix uint8_t)
                               (iy uint8_t)
                               (sp uint8_t)
                               (status uint8_t))))

       (define (s6502_exec u cycles) (uint32_t s6502_t* uint32_t)
         (define _table
           (array (static void*) 0x100)
           (array-literal
            ,@(map (lambda (x) (string->symbol (format #f "&&_~2,'0x" x)))
                   (iota 256))))
         (pre-let*
          ,macros
          (let* ((executed uint32_t 0)
                 (dt uint8_t  0)
                 (et uint16_t 0)
                 (ea uint16_t 0)
                 (pc uint16_t u:pc)
                 (ac uint8_t u:ac)
                 (ix uint8_t u:ix)
                 (iy uint8_t u:iy)
                 (sp uint8_t u:sp)
                 (status uint8_t u:status))
            (label _exit
                   (if (or (>= executed cycles) (sys_halt_p))
                       (begin
                         (set u:pc pc
                              u:ac ac
                              u:ix ix
                              u:iy iy
                              u:sp sp
                              u:status status)
                         (return executed))
                       NEXT))
            (label _next (sc-insert "goto *_table[READX8(pc++)];"))
            ,@(list-tabulate
               256
               (lambda (i)
                 `(begin
                    (label
                     ,(string->symbol
                       (format #f "_~2,'0x" i)))
                    ,(list-ref opcodes (+ (* i 4) 1))
                    ,(list-ref opcodes (+ (* i 4) 0))
                    (CYCLES ,(list-ref opcodes (+ (* i 4) 2)))
                    ,(list-ref opcodes (+ (* i 4) 3)))))))))))


(with-output-to-file "s6502.c"
  (lambda ()
    (display (sc->c code.sc))))
