# ms_sim (Sega Master System)

Ein kompakter **SimCity-ähnlicher Prototyp** in Z80-Assembler für das Sega Master System.
Der Code ist für **WLA-DX 10.6** ausgelegt.

## Features

- 16x12 Stadtkarte (Straße, Wohngebiet, Gewerbe, Industrie)
- Cursor-Steuerung per D-Pad
- B1: Bauart wechseln, B2: platzieren
- Einfaches Wirtschaftssystem (Einnahmen pro Sekunde)
- PSG-Soundeffekte für UI und Platzierung
- Mode-4 Tile-Rendering + Sprite-Cursor

## Build

```bash
wla-z80 -o main.o main.asm
wlalink -v linkfile citysim.sms
```

`linkfile`:

```txt
[objects]
main.o
```

## Emulator

Getestet werden sollte mit einem SMS-Emulator wie Emulicious, Ares oder Meka.

## Hardware-/VDP-/PSG-Notizen

- VDP ist auf **Mode 4** konfiguriert, Nametable auf `$3800`, Sprite-Attributtabelle auf `$3F00`.
- VBlank-IRQ wird über `R1` aktiviert und durch Status-Read am VDP-Control-Port quittiert.
- Rendering erfolgt pro Frame nach VBlank-Wait; für größere Projekte sollte man VRAM-Transfers strikter im VBlank-Budget halten.
- PSG ist SN76489-kompatibel:
  - Kanal 2 wird für kurze Effekte genutzt.
  - Lautstärke ist invers (0 = laut, 15 = stumm).

## Bekannte Vereinfachungen

- Grafik ist minimalistisch, aber klar lesbar.
- Keine Textengine/Font; HUD zeigt nur Symbol-/Digit-Tiles.
- Sega-Header-Felder (Checksumme/Product) sind Platzhalter für den Prototyp.
