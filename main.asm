; ms_sim - compact SimCity-like prototype for Sega Master System
; target assembler: WLA-DX 10.6

.MEMORYMAP
  DEFAULTSLOT 0
  SLOT 0 $0000 $4000
  SLOT 1 $4000 $4000
.ENDME

.ROMBANKSIZE $4000
.ROMBANKS 2

.BANK 0 SLOT 0
.ORG $0000
  di
  jp Start

.ORG $0038
  jp VBlankISR

.define VDP_DATA      $BE
.define VDP_CTRL      $BF
.define PSG_PORT      $7F
.define JOY_PORT_A    $DC

.define NT_BASE       $3800
.define SAT_BASE      $3F00

.define MAP_W         16
.define MAP_H         12
.define MAP_SIZE      (MAP_W*MAP_H)

.define TILE_EMPTY    0
.define TILE_ROAD     1
.define TILE_RES      2
.define TILE_COM      3
.define TILE_IND      4
.define TILE_BORDER   5
.define TILE_CURSOR   6

.define BUILD_ROAD    1
.define BUILD_RES     2
.define BUILD_COM     3
.define BUILD_IND     4

Start:
  im 1
  ld sp, $DFF0

  call InitVDP
  call LoadPalette
  call LoadTiles
  call ClearNameTable
  call InitGame

  call RenderHUD
  call RenderMap
  call UpdateCursorSprite

  ei

MainLoop:
  call WaitVBlank
  call ReadInput
  call UpdateGame
  call UpdateSound
  call RenderIfDirty
  call UpdateCursorSprite
  jp MainLoop

VBlankISR:
  push af
  ld a, 1
  ld (vblank_flag), a
  in a, (VDP_CTRL) ; ack VDP interrupt
  pop af
  reti

WaitVBlank:
.wait:
  ld a, (vblank_flag)
  or a
  jr z, .wait
  xor a
  ld (vblank_flag), a
  ret

InitVDP:
  ld hl, VDPRegs
  ld b, 0
.loop:
  ld a, (hl)
  call WriteVDPReg
  inc hl
  inc b
  ld a, b
  cp 11
  jr nz, .loop
  ret

WriteVDPReg:
  out (VDP_CTRL), a
  ld a, b
  or $80
  out (VDP_CTRL), a
  ret

LoadPalette:
  xor a
  out (VDP_CTRL), a
  ld a, $C0
  out (VDP_CTRL), a

  ld hl, PaletteData
  ld b, 16
.loop:
  ld a, (hl)
  out (VDP_DATA), a
  inc hl
  djnz .loop
  ret

SetVRAMWrite:
  ; HL = VRAM address
  ld a, l
  out (VDP_CTRL), a
  ld a, h
  or $40
  out (VDP_CTRL), a
  ret

LoadTiles:
  ld hl, $0000
  call SetVRAMWrite

  ld hl, TileData
  ld bc, TileDataEnd - TileData
.copy:
  ld a, (hl)
  out (VDP_DATA), a
  inc hl
  dec bc
  ld a, b
  or c
  jr nz, .copy
  ret

ClearNameTable:
  ld hl, NT_BASE
  call SetVRAMWrite

  ld bc, 32*24
  xor a
.loop:
  out (VDP_DATA), a
  out (VDP_DATA), a
  dec bc
  ld a, b
  or c
  jr nz, .loop
  ret

InitGame:
  xor a
  ld hl, city_map
  ld bc, MAP_SIZE
.clr:
  ld (hl), a
  inc hl
  dec bc
  ld a, b
  or c
  jr nz, .clr

  xor a
  ld (cursor_x), a
  ld (cursor_y), a

  ld a, BUILD_RES
  ld (build_mode), a

  ld hl, 40
  ld (money), hl

  ld a, 1
  ld (map_dirty), a
  ld (hud_dirty), a
  ret

ReadInput:
  in a, (JOY_PORT_A)
  cpl
  and %00111111
  ld b, a

  ld a, (joy_curr)
  ld (joy_prev), a
  ld a, b
  ld (joy_curr), a

  ld a, (joy_prev)
  cpl
  and b
  ld (joy_press), a
  ret

UpdateGame:
  call HandleMovement
  call HandleBuildMode
  call HandlePlace
  call SimTick
  ret

HandleMovement:
  ld a, (joy_press)
  bit 0, a
  call nz, MoveUp
  bit 1, a
  call nz, MoveDown
  bit 2, a
  call nz, MoveLeft
  bit 3, a
  call nz, MoveRight
  ret

MoveUp:
  ld a, (cursor_y)
  or a
  ret z
  dec a
  ld (cursor_y), a
  ret
MoveDown:
  ld a, (cursor_y)
  cp MAP_H-1
  ret z
  inc a
  ld (cursor_y), a
  ret
MoveLeft:
  ld a, (cursor_x)
  or a
  ret z
  dec a
  ld (cursor_x), a
  ret
MoveRight:
  ld a, (cursor_x)
  cp MAP_W-1
  ret z
  inc a
  ld (cursor_x), a
  ret

HandleBuildMode:
  ld a, (joy_press)
  bit 4, a
  ret z

  ld a, (build_mode)
  inc a
  cp 5
  jr nz, .store
  ld a, BUILD_ROAD
.store:
  ld (build_mode), a
  ld a, 1
  ld (hud_dirty), a
  call PlayClickSFX
  ret

HandlePlace:
  ld a, (joy_press)
  bit 5, a
  ret z

  call GetBuildCost
  ld d, h
  ld e, l

  ld hl, (money)
  xor a
  sbc hl, de
  ret c
  ld (money), hl

  call MapIndexToHL
  ld a, (build_mode)
  ld (hl), a

  ld a, 1
  ld (map_dirty), a
  ld (hud_dirty), a
  call PlayPlaceSFX
  ret

GetBuildCost:
  ld a, (build_mode)
  cp BUILD_ROAD
  jr nz, .zone
  ld hl, 1
  ret
.zone:
  ld hl, 3
  ret

MapIndexToHL:
  ld a, (cursor_y)
  ld h, 0
  ld l, a
  add hl, hl
  add hl, hl
  add hl, hl
  add hl, hl
  ld a, (cursor_x)
  ld e, a
  ld d, 0
  add hl, de
  ld de, city_map
  add hl, de
  ret

SimTick:
  ld a, (frame_counter)
  inc a
  ld (frame_counter), a
  cp 60
  ret nz

  xor a
  ld (frame_counter), a

  ld hl, city_map
  ld b, MAP_SIZE
.loop:
  ld a, (hl)
  cp BUILD_RES
  jr nz, .chkCom
  call AddMoney2
  jr .next
.chkCom:
  cp BUILD_COM
  jr nz, .chkInd
  call AddMoney3
  jr .next
.chkInd:
  cp BUILD_IND
  jr nz, .next
  call AddMoney4
.next:
  inc hl
  djnz .loop

  ld a, 1
  ld (hud_dirty), a
  ret

AddMoney2:
  ld hl, (money)
  ld de, 2
  add hl, de
  ld (money), hl
  ret
AddMoney3:
  ld hl, (money)
  ld de, 3
  add hl, de
  ld (money), hl
  ret
AddMoney4:
  ld hl, (money)
  ld de, 4
  add hl, de
  ld (money), hl
  ret

RenderIfDirty:
  ld a, (hud_dirty)
  or a
  call nz, RenderHUD
  ld a, (map_dirty)
  or a
  call nz, RenderMap

  xor a
  ld (hud_dirty), a
  ld (map_dirty), a
  ret

RenderMap:
  call DrawFrame

  ld iy, city_map
  ld b, MAP_H
  ld d, 0
.y:
  ld c, MAP_W
  ld e, 0
.x:
  push bc
  push de
  push iy

  ld a, (iy+0)
  call TileFromMapValue

  ld a, d
  add a, 4
  ld d, a
  ld a, e
  add a, 8
  ld e, a
  call WriteTileAt

  pop iy
  pop de
  pop bc
  inc iy
  inc e
  dec c
  jr nz, .x

  inc d
  djnz .y
  ret

DrawFrame:
  ; top
  ld b, MAP_W+2
  ld e, 7
.t:
  ld d, 3
  ld a, TILE_BORDER
  call WriteTileAt
  inc e
  djnz .t

  ; bottom
  ld b, MAP_W+2
  ld e, 7
.b:
  ld d, MAP_H+4
  ld a, TILE_BORDER
  call WriteTileAt
  inc e
  djnz .b

  ; sides
  ld b, MAP_H
  ld d, 4
.s:
  ld e, 7
  ld a, TILE_BORDER
  call WriteTileAt
  ld e, MAP_W+8
  call WriteTileAt
  inc d
  djnz .s
  ret

TileFromMapValue:
  or a
  ret z
  cp BUILD_ROAD
  jr nz, .res
  ld a, TILE_ROAD
  ret
.res:
  cp BUILD_RES
  jr nz, .com
  ld a, TILE_RES
  ret
.com:
  cp BUILD_COM
  jr nz, .ind
  ld a, TILE_COM
  ret
.ind:
  ld a, TILE_IND
  ret

; in: A tile, D row(0..23), E col(0..31)
WriteTileAt:
  push af
  push bc
  push de
  push hl

  ld h, 0
  ld l, d
  add hl, hl
  add hl, hl
  add hl, hl
  add hl, hl
  add hl, hl ; *32

  ld d, 0
  add hl, de
  add hl, hl ; *2 bytes

  ld de, NT_BASE
  add hl, de
  call SetVRAMWrite

  pop hl
  pop de
  pop bc
  pop af

  out (VDP_DATA), a
  xor a
  out (VDP_DATA), a
  ret

RenderHUD:
  ; left marker
  ld d, 0
  ld e, 0
  ld a, TILE_BORDER
  call WriteTileAt

  ; money as 3 digits at (0,2..4)
  ld hl, (money)
  call DrawMoney3Digits

  ; build mode tile at (0,20)
  ld a, (build_mode)
  add a, TILE_ROAD-1
  ld d, 0
  ld e, 20
  call WriteTileAt
  ret

DrawMoney3Digits:
  ; clamp to 999
  ld de, 999
  or a
  sbc hl, de
  jr c, .restore
  ld hl, 999
  jr .conv
.restore:
  add hl, de
.conv:
  ld bc, 100
  call DivHLByBC
  add a, TILE_EMPTY
  ld d, 0
  ld e, 2
  call WriteTileAt

  ld bc, 10
  call DivHLByBC
  add a, TILE_EMPTY
  ld d, 0
  ld e, 3
  call WriteTileAt

  ld a, l
  add a, TILE_EMPTY
  ld d, 0
  ld e, 4
  call WriteTileAt
  ret

; HL / BC -> A quotient, HL remainder
DivHLByBC:
  ld a, 0
.loop:
  or a
  sbc hl, bc
  jr c, .done
  inc a
  jr .loop
.done:
  add hl, bc
  ret

UpdateCursorSprite:
  ; Y table at SAT_BASE: first sprite + end marker
  ld hl, SAT_BASE
  call SetVRAMWrite
  ld a, (cursor_y)
  add a, 4
  add a, a
  add a, a
  add a, a
  out (VDP_DATA), a
  ld a, 208
  out (VDP_DATA), a

  ; X/tile table at SAT_BASE+128
  ld hl, SAT_BASE+128
  call SetVRAMWrite
  ld a, (cursor_x)
  add a, 8
  add a, a
  add a, a
  add a, a
  out (VDP_DATA), a
  ld a, TILE_CURSOR
  out (VDP_DATA), a
  ret

PlayClickSFX:
  ld a, $CE
  out (PSG_PORT), a
  ld a, $05
  out (PSG_PORT), a
  ld a, $F4
  out (PSG_PORT), a
  ld a, 6
  ld (sfx_timer), a
  ret

PlayPlaceSFX:
  ld a, $C7
  out (PSG_PORT), a
  ld a, $03
  out (PSG_PORT), a
  ld a, $F2
  out (PSG_PORT), a
  ld a, 12
  ld (sfx_timer), a
  ret

UpdateSound:
  ld a, (sfx_timer)
  or a
  ret z
  dec a
  ld (sfx_timer), a
  srl a
  and $0F
  or $F0
  out (PSG_PORT), a
  ret

VDPRegs:
  .db $04  ; R0: mode 4
  .db $E0  ; R1: display on + VBlank IRQ
  .db $0E  ; R2: nametable @ $3800
  .db $FF  ; R3
  .db $FF  ; R4
  .db $7E  ; R5: SAT @ $3F00
  .db $00  ; R6
  .db $00  ; R7 backdrop
  .db $00  ; R8 hscroll
  .db $00  ; R9 vscroll
  .db $FF  ; R10 line counter

PaletteData:
  .db $00,$15,$30,$0C,$03,$3F,$2A,$12
  .db $00,$00,$00,$00,$00,$00,$00,$00

TileData:
  ; tile 0 empty
  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  ; tile 1 road
  .db $00,$00,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF,$00,$00,$00,$00,$00,$00
  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  ; tile 2 res
  .db $AA,$55,$AA,$55,$AA,$55,$AA,$55,$AA,$55,$AA,$55,$AA,$55,$AA,$55
  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  ; tile 3 com
  .db $33,$33,$33,$33,$33,$33,$33,$33,$33,$33,$33,$33,$33,$33,$33,$33
  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  ; tile 4 ind
  .db $80,$40,$20,$10,$08,$04,$02,$01,$80,$40,$20,$10,$08,$04,$02,$01
  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  ; tile 5 border
  .db $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
  ; tile 6 cursor
  .db $FF,$81,$81,$81,$81,$81,$81,$FF,$00,$00,$00,$00,$00,$00,$00,$00
  .db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
TileDataEnd:

; WRAM map ($C000-$DFFF)
.define vblank_flag   $C000
.define joy_prev      $C001
.define joy_curr      $C002
.define joy_press     $C003
.define cursor_x      $C004
.define cursor_y      $C005
.define build_mode    $C006
.define map_dirty     $C007
.define hud_dirty     $C008
.define frame_counter $C009
.define sfx_timer     $C00A
.define money         $C00B
.define city_map      $C00D

.BANK 1 SLOT 1
.ORG $7FF0
  .db "TMR SEGA"
  .db 0,0
  .db 0,0,0,0,0,0
  .db $00,$00
  .db $00,$00
  .db $40
