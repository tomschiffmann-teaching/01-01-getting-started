# WSL

Das Windows Subsystem für Linux (WSL) ist eine Funktion von Windows, mit der man eine vollwertige Linux-Umgebung inklusive Kommandozeilen-Tools und Anwendungen direkt unter Windows ausführen kann – ohne virtuelle Maschine oder Dual-Boot.

## WSL unter Windows installieren

1. PowerShell als Administrator öffnen
2. Ubuntu als Distribution installieren: `wsl.exe --install Ubuntu-26.04`
3. Den Anweisungen in der PowerShell folgen (Benutzername und Passwort für Linux festlegen)

Weitere Details findet ihr in der offiziellen [WSL-Installationsanleitung](https://learn.microsoft.com/de-de/windows/wsl/install).

## Visual Studio Code installieren (IDE)

- VS Code [herunterladen](https://code.visualstudio.com/download) und installieren

## VS Code mit WSL verbinden

1. In der PowerShell die WSL-Erweiterung installieren: `code --install-extension ms-vscode-remote.remote-wsl`
2. VS Code öffnen und unten links über das grüne Symbol (oder per `F1` → „WSL: Connect to WSL“) eine Verbindung zur WSL herstellen
3. Ihr arbeitet nun direkt in der WSL und könnt eure Linux-Ordner als Projektmappe öffnen
