# Unit Testing mit Node.js

Dieses Beispiel nutzt den **eingebauten Test Runner von Node.js** (`node:test`) und das Modul `node:assert`.
Es müssen keine Pakete installiert werden (Node.js 20 oder neuer).

## Struktur

```
nodejs-unit-testing/
├── package.json
├── src/
│   ├── calculator.js      # einfache Funktionen
│   ├── shoppingCart.js    # Klasse mit Zustand
│   └── userService.js     # asynchroner Code mit Abhängigkeit
└── test/
    ├── calculator.test.js     # Grundlagen: describe, it, assert, Fehler testen
    ├── shoppingCart.test.js   # beforeEach, Arrange-Act-Assert
    └── userService.test.js    # async Tests und Mocks
```

## Tests ausführen

```bash
npm test                # alle Tests einmal ausführen
npm run test:watch      # Tests bei jeder Änderung neu ausführen
npm run test:coverage   # Testabdeckung anzeigen
```

`node --test` findet automatisch alle Dateien, die auf `.test.js` enden.

## Wichtige Begriffe

| Begriff            | Bedeutung                                                          |
| ------------------ | ------------------------------------------------------------------ |
| `describe`         | Gruppiert zusammengehörige Tests                                   |
| `it` / `test`      | Ein einzelner Testfall                                             |
| `assert.equal`     | Vergleicht zwei Werte (`===`)                                      |
| `assert.deepEqual` | Vergleicht Objekte und Arrays inhaltlich                           |
| `assert.throws`    | Prüft, dass eine Funktion einen Fehler wirft                       |
| `assert.rejects`   | Wie `throws`, aber für async Funktionen / Promises                 |
| `beforeEach`       | Code, der vor jedem Test läuft (z.B. Objekte neu erzeugen)         |
| `mock.fn`          | Ersetzt eine echte Abhängigkeit (z.B. DB) durch eine Fake-Funktion |

## Übung

1. Lass einen Test absichtlich fehlschlagen (z.B. erwarte `add(2, 3)` = `6`) und schau dir die Ausgabe an.
2. Ergänze in `calculator.js` eine Funktion `multiply` und schreibe dazu Tests.
3. Was passiert bei `cart.applyDiscount(150)`? Passe den Code an und schreibe einen Test dafür.
