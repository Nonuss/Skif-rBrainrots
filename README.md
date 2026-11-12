# Ski Egg Heist

Roblox-Spiel: Mit dem Schilift auf den Berg fahren, ein Ei aus einem Nest stehlen und auf Schi ins Tal fliehen, bevor die Mutter einen einholt. Eier in der eigenen Basis verdienen Geld, andere Spieler können sie stehlen.

## In Roblox Studio öffnen

1. `SkiEggHeist.rbxlx` herunterladen.
2. In Roblox Studio: Datei > Aus Datei öffnen.
3. Auf Spielen drücken. Die Karte wird beim Start von den Skripten gebaut, im Bearbeitungsmodus ist der Arbeitsbereich deshalb leer.
4. Zum Veröffentlichen: Datei > In Roblox veröffentlichen als ... und das bestehende leere Spiel auswählen.

Damit Spielstände gespeichert werden: Spieleinstellungen > Sicherheit > Studiozugriff auf API-Dienste aktivieren. Servergröße auf höchstens 8 Spieler stellen (es gibt 8 Basen).

## Aufbau

| Datei | Aufgabe |
|---|---|
| `src/shared/Config.luau` | Alle Stellschrauben: Zonen, Eier, Preise, Geschwindigkeiten |
| `src/server/World.luau` | Baut Lobby und Berg |
| `src/server/Lift.luau` | Schilift |
| `src/server/Bases.luau` | Basen, Sperre |
| `src/server/Eggs.luau` | Nester, Eier, Mutter-Verfolgung, Stehlen, Einkommen |
| `src/server/Data.luau` | Spielstand und Speichern |
| `src/server/Main.server.luau` | Startpunkt des Servers |
| `src/client/Hud.client.luau` | Anzeige und Schi-Tempo beim Spieler |

## Nach Änderungen

Platzdatei neu bauen:

```bash
python3 tools/build_place.py
```

Logik probelaufen lassen (benötigt Lua 5.1, läuft ohne Roblox):

```bash
lua5.1 tests/run.lua .
```

Wer Rojo nutzt, kann stattdessen `default.project.json` verwenden.
