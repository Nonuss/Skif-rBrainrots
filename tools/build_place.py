#!/usr/bin/env python3
"""Baut aus den Skripten in src/ eine Roblox-Platzdatei (SkiEggHeist.rbxlx).

Aufruf im Projektordner:  python3 tools/build_place.py
Die Datei laesst sich in Roblox Studio ueber "Datei > Aus Datei oeffnen" laden.
"""
import pathlib
import xml.dom.minidom

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "SkiEggHeist.rbxlx"

counter = 0


def item(class_name, name, children="", source=None):
    global counter
    counter += 1
    props = f'<string name="Name">{name}</string>'
    if source is not None:
        assert "]]>" not in source, f"{name}: Zeichenfolge ]]> im Skript nicht erlaubt"
        props += f'<ProtectedString name="Source"><![CDATA[{source}]]></ProtectedString>'
    return (
        f'<Item class="{class_name}" referent="RBX{counter}">'
        f"<Properties>{props}</Properties>{children}</Item>"
    )


def script(class_name, name, path):
    return item(class_name, name, source=(ROOT / path).read_text(encoding="utf-8"))


server_modules = "".join(
    script("ModuleScript", n, f"src/server/{n}.luau")
    for n in ["World", "Lift", "Bases", "Data", "Eggs"]
)

body = "".join(
    [
        item("Workspace", "Workspace"),
        item("Lighting", "Lighting"),
        item(
            "ReplicatedStorage",
            "ReplicatedStorage",
            item("Folder", "Shared", script("ModuleScript", "Config", "src/shared/Config.luau")),
        ),
        item(
            "ServerScriptService",
            "ServerScriptService",
            item(
                "Folder",
                "Server",
                script("Script", "Main", "src/server/Main.server.luau") + server_modules,
            ),
        ),
        item(
            "StarterPlayer",
            "StarterPlayer",
            item(
                "StarterPlayerScripts",
                "StarterPlayerScripts",
                item("Folder", "Client", script("LocalScript", "Hud", "src/client/Hud.client.luau")),
            ),
        ),
    ]
)

document = (
    '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
    'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
    'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">'
    f"{body}</roblox>"
)

xml.dom.minidom.parseString(document)  # bricht ab, falls die Datei ungueltig waere
OUT.write_text(document, encoding="utf-8")
print(f"{OUT.name} geschrieben ({len(document) // 1024} KB, {counter} Eintraege)")
