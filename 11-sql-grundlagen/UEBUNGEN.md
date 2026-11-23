# SQL-Übungen zum Mini-Webshop

Alle Übungen laufen gegen die Shop-Datenbank aus der [Readme](./Readme.md). Vorher:

```bash
cd 11-sql-grundlagen/beispiel
docker compose up -d
docker compose run --rm seed          # frische Beispieldaten
docker compose exec db psql -U app -d shop
```

**So gehst du vor:**

1. Lies die Aufgabe und überlege zuerst: **Welche Tabellen** brauche ich? **Welche Spalten**? Muss ich **filtern**, **gruppieren** oder **verknüpfen**?
2. Schreibe die Abfrage selbst. Fang klein an (`SELECT * FROM …`) und baue sie Schritt für Schritt aus.
3. Vergleiche mit dem **erwarteten Ergebnis**. Erst wenn du nicht weiterkommst, klappe die Lösung auf.

Es gibt oft **mehrere richtige Lösungen**. Wenn dein Ergebnis stimmt, ist deine Lösung richtig.

> Hast du in Teil E Daten verändert, setzt `docker compose run --rm seed` alles zurück. Die erwarteten Ergebnisse gelten für die **frischen** Beispieldaten.

---

## Teil A: SELECT, WHERE, ORDER BY

### A1 – Alles über Produkte

Zeige alle Spalten aller Produkte, sortiert nach Name.

> Erwartet: 12 Zeilen, beginnend mit „27 Zoll Monitor“.

<details><summary>Lösung</summary>

```sql
SELECT * FROM produkte ORDER BY name;
```

</details>

### A2 – Nachnamen mit S

Welche Kunden haben einen Nachnamen, der mit **S** beginnt? Zeige Vor- und Nachname.

> Erwartet: 2 Zeilen – Schmidt, Schulz.

<details><summary>Lösung</summary>

```sql
SELECT vorname, nachname FROM kunden WHERE nachname LIKE 'S%';
```

</details>

### A3 – Kunden aus dem Norden und Westen

Alle Kunden aus **Hamburg** oder **Köln**, sortiert nach Stadt und dann Nachname.

> Erwartet: 4 Zeilen – Felix Becker, Ben Müller (Hamburg), Lena Richter, Emma Wagner (Köln).

<details><summary>Lösung</summary>

```sql
SELECT vorname, nachname, stadt
FROM kunden
WHERE stadt IN ('Hamburg', 'Köln')
ORDER BY stadt, nachname;
```

Gleichwertig: `WHERE stadt = 'Hamburg' OR stadt = 'Köln'`.

</details>

### A4 – Nachbestellen!

Welche Produkte haben **weniger als 10 Stück** auf Lager? Das knappste zuerst.

> Erwartet: 5 Zeilen – Wasserkocher (0), Kubernetes in Action (3), 27 Zoll Monitor (5), Docker kompakt (8), Webcam HD (9).

<details><summary>Lösung</summary>

```sql
SELECT name, lagerbestand
FROM produkte
WHERE lagerbestand < 10
ORDER BY lagerbestand;
```

</details>

### A5 – Erstes Halbjahr

Wie sehen alle Bestellungen aus dem **ersten Halbjahr 2026** (Januar bis Juni) aus?

> Erwartet: 8 Zeilen (Bestellungen 1 bis 8).

<details><summary>Lösung</summary>

```sql
SELECT * FROM bestellungen
WHERE bestellt_am BETWEEN '2026-01-01' AND '2026-06-30'
ORDER BY bestellt_am;
```

</details>

### A6 – Adressbuch

Gib eine Liste aus mit einer Spalte `kunde` im Format **„Nachname, Vorname“** und der E-Mail. Kunden ohne Stadt sollen als Stadt `-` anzeigen. Sortiert nach Nachname.

> Erwartet: 10 Zeilen, beginnend mit „Becker, Felix“. Bei Greta Hoffmann steht `-`.

<details><summary>Lösung</summary>

```sql
SELECT nachname || ', ' || vorname AS kunde,
       email,
       COALESCE(stadt, '-') AS stadt
FROM kunden
ORDER BY nachname;
```

</details>

### A7 – Wo steckt das Geld?

Berechne für jedes Produkt den **Lagerwert** (Preis × Bestand) und zeige die **drei** Produkte mit dem höchsten Lagerwert.

> Erwartet: 27 Zoll Monitor (1245.00), USB-C Kabel (1198.80), Mechanische Tastatur (1068.00).

<details><summary>Lösung</summary>

```sql
SELECT name, preis * lagerbestand AS lagerwert
FROM produkte
ORDER BY lagerwert DESC
LIMIT 3;
```

</details>

### A8 – Noch nicht verschickt

Welche Bestellungen sind **noch nicht versendet** und **nicht storniert**?

> Erwartet: 4 Zeilen – Bestellungen 8, 10 (bezahlt), 11, 12 (offen).

<details><summary>Lösung</summary>

```sql
SELECT * FROM bestellungen
WHERE status IN ('offen', 'bezahlt')
ORDER BY id;
```

Oder: `WHERE status NOT IN ('versendet', 'storniert')`.

</details>

---

## Teil B: Aggregieren und Gruppieren

### B1 – Gesamter Lagerwert

Wie viel ist das **gesamte Lager** wert?

> Erwartet: 7862.95

<details><summary>Lösung</summary>

```sql
SELECT SUM(preis * lagerbestand) AS lagerwert_gesamt FROM produkte;
```

</details>

### B2 – Bestellungen je Status

Wie viele Bestellungen gibt es je Status? Die häufigste zuerst.

> Erwartet: versendet 7, bezahlt 2, offen 2, storniert 1.

<details><summary>Lösung</summary>

```sql
SELECT status, COUNT(*) AS anzahl
FROM bestellungen
GROUP BY status
ORDER BY anzahl DESC, status;
```

</details>

### B3 – Registrierungen pro Jahr

Wie viele Kunden haben sich in welchem **Jahr** registriert?

**Tipp:** `EXTRACT(YEAR FROM datum)` liefert das Jahr eines Datums.

> Erwartet: 2025 → 5, 2026 → 5.

<details><summary>Lösung</summary>

```sql
SELECT EXTRACT(YEAR FROM registriert_am) AS jahr, COUNT(*) AS anzahl
FROM kunden
GROUP BY jahr
ORDER BY jahr;
```

In PostgreSQL darfst du im `GROUP BY` den Alias `jahr` aus dem `SELECT` verwenden. Das ist nicht in jeder Datenbank erlaubt – dort schreibst du den Ausdruck noch einmal hin.

</details>

### B4 – Bestellungen pro Monat

Wie viele Bestellungen gab es in jedem **Monat**?

**Tipp:** `date_trunc('month', datum)` schneidet ein Datum auf den Monatsersten ab.

> Erwartet: 10 Zeilen. Januar und Februar je 2, die anderen Monate je 1. Im Juli gab es keine Bestellung – der Monat fehlt deshalb ganz.

<details><summary>Lösung</summary>

```sql
SELECT date_trunc('month', bestellt_am)::date AS monat, COUNT(*) AS anzahl
FROM bestellungen
GROUP BY monat
ORDER BY monat;
```

`::date` wandelt das Ergebnis (einen Zeitstempel) wieder in ein Datum um – nur für eine hübschere Anzeige.

</details>

### B5 – Große Kategorien

Welche `kategorie_id` hat **mehr als 3** Produkte?

> Erwartet: 1 Zeile – Kategorie 2 mit 5 Produkten.

<details><summary>Lösung</summary>

```sql
SELECT kategorie_id, COUNT(*) AS anzahl
FROM produkte
GROUP BY kategorie_id
HAVING COUNT(*) > 3;
```

</details>

### B6 – Wie viel Stück insgesamt?

Wie viele Positionen hat jede Bestellung? Zeige nur Bestellungen mit **mindestens 3 Positionen**.

> Erwartet: 1 Zeile – Bestellung 12 mit 3 Positionen.

<details><summary>Lösung</summary>

```sql
SELECT bestellung_id, COUNT(*) AS positionen
FROM bestellpositionen
GROUP BY bestellung_id
HAVING COUNT(*) >= 3;
```

</details>

---

## Teil C: JOINs

### C1 – Wer hat wann bestellt?

Alle Bestellungen mit Datum, Status und **vollem Namen** des Kunden, nach Datum sortiert.

> Erwartet: 12 Zeilen, die erste: 2026-01-08, Anna Schmidt, versendet.

<details><summary>Lösung</summary>

```sql
SELECT b.id, b.bestellt_am, k.vorname || ' ' || k.nachname AS kunde, b.status
FROM bestellungen b
JOIN kunden k ON b.kunde_id = k.id
ORDER BY b.bestellt_am;
```

</details>

### C2 – Bestellungen je Kunde (alle Kunden!)

Wie viele Bestellungen hat **jeder** Kunde? Auch Kunden ohne Bestellung sollen mit `0` erscheinen.

> Erwartet: 10 Zeilen. Anna 3, Clara 2, Lena 0, alle anderen 1.

<details><summary>Lösung</summary>

```sql
SELECT k.vorname, k.nachname, COUNT(b.id) AS anzahl
FROM kunden k
LEFT JOIN bestellungen b ON b.kunde_id = k.id
GROUP BY k.id, k.vorname, k.nachname
ORDER BY anzahl DESC, k.nachname;
```

`LEFT JOIN`, damit Lena nicht herausfällt, und `COUNT(b.id)`, damit sie `0` statt `1` bekommt.

</details>

### C3 – Ladenhüter

Welche Produkte wurden **noch nie** bestellt?

> Erwartet: 1 Zeile – Webcam HD.

<details><summary>Lösung</summary>

```sql
SELECT p.name
FROM produkte p
LEFT JOIN bestellpositionen bp ON bp.produkt_id = p.id
WHERE bp.produkt_id IS NULL;
```

</details>

### C4 – Annas Einkäufe

Welche Produkte hat **Anna Schmidt** schon gekauft? Jedes Produkt nur einmal, alphabetisch.

> Erwartet: 6 Zeilen – Docker kompakt, Funkmaus, Kaffeetasse, Kubernetes in Action, SQL für Einsteiger, USB-C Kabel.

<details><summary>Lösung</summary>

```sql
SELECT DISTINCT p.name
FROM kunden k
JOIN bestellungen b       ON b.kunde_id = k.id
JOIN bestellpositionen bp ON bp.bestellung_id = b.id
JOIN produkte p           ON bp.produkt_id = p.id
WHERE k.email = 'anna.schmidt@example.com'
ORDER BY p.name;
```

</details>

### C5 – Gesamtumsatz

Wie hoch ist der **Gesamtumsatz** des Shops? Stornierte Bestellungen zählen nicht.

> Erwartet: 888.17

<details><summary>Lösung</summary>

```sql
SELECT SUM(bp.menge * bp.einzelpreis) AS umsatz
FROM bestellungen b
JOIN bestellpositionen bp ON bp.bestellung_id = b.id
WHERE b.status <> 'storniert';
```

</details>

### C6 – Umsatz je Kategorie

Wie viel Umsatz macht jede **Kategorie** (mit Namen)? Produkte ohne Kategorie sollen als `(ohne Kategorie)` erscheinen. Stornierte Bestellungen zählen nicht.

> Erwartet: Elektronik 526.92, Bücher 184.40, Haushalt 127.35, (ohne Kategorie) 49.50. Zusammen wieder 888.17.

<details><summary>Lösung</summary>

```sql
SELECT COALESCE(k.name, '(ohne Kategorie)') AS kategorie,
       SUM(bp.menge * bp.einzelpreis)       AS umsatz
FROM bestellpositionen bp
JOIN bestellungen b     ON b.id = bp.bestellung_id
JOIN produkte p         ON p.id = bp.produkt_id
LEFT JOIN kategorien k  ON k.id = p.kategorie_id
WHERE b.status <> 'storniert'
GROUP BY k.name
ORDER BY umsatz DESC;
```

Beim letzten JOIN braucht es `LEFT JOIN`, sonst fehlt das Notizbuch und damit 49,50 €.

</details>

### C7 – Bestellungen je Stadt

Aus welcher **Stadt** kommen die meisten Bestellungen?

> Erwartet: Berlin 5, München 3, Hamburg 2, Köln 1 und eine Zeile ohne Stadt mit 1.

<details><summary>Lösung</summary>

```sql
SELECT k.stadt, COUNT(b.id) AS bestellungen
FROM kunden k
JOIN bestellungen b ON b.kunde_id = k.id
GROUP BY k.stadt
ORDER BY bestellungen DESC;
```

</details>

### C8 – Gute Kunden

Welche Kunden haben (ohne Stornos) **mehr als 100 €** Umsatz gemacht?

> Erwartet: 4 Zeilen – Clara 258.99, Anna 159.67, Jonas 111.35, Ben 108.99.

<details><summary>Lösung</summary>

```sql
SELECT k.vorname, k.nachname, SUM(bp.menge * bp.einzelpreis) AS umsatz
FROM kunden k
JOIN bestellungen b       ON b.kunde_id = k.id
JOIN bestellpositionen bp ON bp.bestellung_id = b.id
WHERE b.status <> 'storniert'
GROUP BY k.id, k.vorname, k.nachname
HAVING SUM(bp.menge * bp.einzelpreis) > 100
ORDER BY umsatz DESC;
```

</details>

### C9 – Letzte Bestellung

Wann hat jeder Kunde **zuletzt** bestellt? Kunden ohne Bestellung ganz unten.

> Erwartet: 10 Zeilen, oben Jonas (2026-11-02), unten Lena (leer).

<details><summary>Lösung</summary>

```sql
SELECT k.vorname, k.nachname, MAX(b.bestellt_am) AS letzte_bestellung
FROM kunden k
LEFT JOIN bestellungen b ON b.kunde_id = k.id
GROUP BY k.id, k.vorname, k.nachname
ORDER BY letzte_bestellung DESC NULLS LAST;
```

`NULLS LAST` sortiert die `NULL`-Werte ans Ende. Ohne diese Angabe stehen sie bei `DESC` in PostgreSQL ganz **oben**.

</details>

---

## Teil D: Knobelaufgaben (Unterabfragen)

Eine **Unterabfrage** ist ein `SELECT` in Klammern innerhalb eines anderen `SELECT`. Die innere Abfrage wird zuerst ausgewertet, ihr Ergebnis von der äußeren verwendet.

### D1 – Überdurchschnittlich teuer

Welche Produkte sind **teurer als der Durchschnittspreis** aller Produkte?

> Erwartet: 3 Zeilen – 27 Zoll Monitor, Mechanische Tastatur, Webcam HD.

<details><summary>Lösung</summary>

```sql
SELECT name, preis
FROM produkte
WHERE preis > (SELECT AVG(preis) FROM produkte)
ORDER BY preis DESC;
```

`WHERE preis > AVG(preis)` geht **nicht**: Aggregatfunktionen sind im `WHERE` verboten, weil `WHERE` **vor** dem Aggregieren ausgewertet wird.

</details>

### D2 – Durchschnittlicher Bestellwert

Wie viel ist eine Bestellung **im Durchschnitt** wert (ohne Stornos)?

**Tipp:** Berechne zuerst in einer Unterabfrage den Wert **jeder** Bestellung, dann davon den Durchschnitt.

> Erwartet: 80.74

<details><summary>Lösung</summary>

```sql
SELECT ROUND(AVG(gesamt), 2) AS durchschnittlicher_bestellwert
FROM (
    SELECT b.id, SUM(bp.menge * bp.einzelpreis) AS gesamt
    FROM bestellungen b
    JOIN bestellpositionen bp ON bp.bestellung_id = b.id
    WHERE b.status <> 'storniert'
    GROUP BY b.id
) AS bestellwerte;
```

Eine Unterabfrage im `FROM` braucht in PostgreSQL immer einen Namen (`AS bestellwerte`).

</details>

### D3 – Umsatz pro Monat

Wie viel Umsatz (ohne Stornos) hat der Shop in jedem Monat gemacht?

> Erwartet: 10 Zeilen. Stärkster Monat ist Mai 2026 mit 258.99.

<details><summary>Lösung</summary>

```sql
SELECT date_trunc('month', b.bestellt_am)::date AS monat,
       SUM(bp.menge * bp.einzelpreis)           AS umsatz
FROM bestellungen b
JOIN bestellpositionen bp ON bp.bestellung_id = b.id
WHERE b.status <> 'storniert'
GROUP BY monat
ORDER BY monat;
```

</details>

### D4 – Annas Nachbarn

Zeige alle Kunden, die in **derselben Stadt** wohnen wie **Anna Schmidt** – aber ohne Anna selbst. Die Stadt darf **nicht** fest im SQL stehen.

> Erwartet: 2 Zeilen – David Weber, Hannah Schulz.

<details><summary>Lösung</summary>

```sql
SELECT vorname, nachname
FROM kunden
WHERE stadt = (SELECT stadt FROM kunden WHERE email = 'anna.schmidt@example.com')
  AND email <> 'anna.schmidt@example.com';
```

</details>

---

## Teil E: Daten ändern

Ab hier veränderst du Daten. Am Ende: `docker compose run --rm seed`.

### E1 – Endlich Spielzeug

Lege ein neues Produkt **„Holz-Bauklötze“** für **19,90 €** mit **25 Stück** Lagerbestand in der Kategorie **Spielzeug** an. Die ID der Kategorie sollst du **nicht** von Hand nachschlagen.

<details><summary>Lösung</summary>

```sql
INSERT INTO produkte (name, preis, lagerbestand, kategorie_id)
VALUES ('Holz-Bauklötze', 19.90, 25,
        (SELECT id FROM kategorien WHERE name = 'Spielzeug'))
RETURNING *;
```

Kontrolle: Die Abfrage „Kategorien ohne Produkte“ aus Aufgabe 7 liefert jetzt **keine** Zeile mehr.

</details>

### E2 – Preiserhöhung mit Sicherheitsnetz

Alle **Bücher** sollen **10 % teurer** werden (auf 2 Nachkommastellen gerundet). Mach das in einer **Transaktion**, prüfe das Ergebnis und entscheide dann zwischen `COMMIT` und `ROLLBACK`.

> Erwartet (vor dem COMMIT): SQL für Einsteiger 27.39, Docker kompakt 32.89, Kubernetes in Action 54.89.

<details><summary>Lösung</summary>

```sql
BEGIN;

UPDATE produkte
SET preis = ROUND(preis * 1.10, 2)
WHERE kategorie_id = (SELECT id FROM kategorien WHERE name = 'Bücher')
RETURNING name, preis;

-- passt alles?
COMMIT;      -- oder ROLLBACK;
```

Prüfe danach Bestellung 1: Der `einzelpreis` für „SQL für Einsteiger“ steht dort **immer noch** auf 24.90. Genau deshalb speichern wir den Preis in der Position.

</details>

### E3 – Storno

Hannah Schulz storniert ihre offene Bestellung. Setze den Status auf `storniert`, ohne die Bestellnummer zu kennen.

<details><summary>Lösung</summary>

```sql
-- zuerst prüfen, welche Zeile getroffen wird:
SELECT * FROM bestellungen
WHERE status = 'offen'
  AND kunde_id = (SELECT id FROM kunden WHERE email = 'hannah.schulz@example.com');

-- dann ändern:
UPDATE bestellungen
SET status = 'storniert'
WHERE status = 'offen'
  AND kunde_id = (SELECT id FROM kunden WHERE email = 'hannah.schulz@example.com');
```

Erwartet: `UPDATE 1`. Der Gesamtumsatz aus C5 sinkt danach um 29,90 €.

</details>

### E4 – Wareneingang

Es wurden **20 Wasserkocher** geliefert. Erhöhe den Lagerbestand – **relativ** zum aktuellen Wert, nicht fest auf 20.

<details><summary>Lösung</summary>

```sql
UPDATE produkte
SET lagerbestand = lagerbestand + 20
WHERE name = 'Wasserkocher'
RETURNING name, lagerbestand;
```

`lagerbestand + 20` ist sicherer als `= 20`: Hat in der Zwischenzeit jemand anderes etwas verändert, rechnet die Datenbank mit dem **aktuellen** Wert weiter.

</details>

### E5 – Sortiment bereinigen

Versuche, die Produkte **Webcam HD** und **Funkmaus** zu löschen. Was passiert jeweils, und warum?

<details><summary>Lösung</summary>

```sql
DELETE FROM produkte WHERE name = 'Webcam HD';   -- DELETE 1
DELETE FROM produkte WHERE name = 'Funkmaus';    -- ERROR
```

Die Webcam wurde nie bestellt und kann gelöscht werden. Die Funkmaus steckt in Bestellpositionen, und der Fremdschlüssel `bestellpositionen.produkt_id` steht auf `ON DELETE RESTRICT` – sonst würden Rechnungen plötzlich auf ein Produkt zeigen, das es nicht mehr gibt.

In echten Shops löscht man Produkte deshalb selten, sondern **versteckt** sie, z. B. mit einer Spalte `aktiv BOOLEAN NOT NULL DEFAULT true`.

</details>

---

## Teil F: Tabellen entwerfen und das Seed-Skript erweitern

### F1 – Lieferadressen

Bisher haben Kunden nur eine Stadt. Der Shop braucht richtige **Lieferadressen**:

- Ein Kunde kann **mehrere** Adressen haben (Zuhause, Büro, Eltern).
- Eine Adresse besteht aus Straße, Hausnummer, PLZ, Ort und Land (Standard: `DE`).
- Jede Bestellung wird an **genau eine** Adresse des Kunden geliefert.
- Eine Adresse, an die schon geliefert wurde, darf nicht gelöscht werden.

Zeichne zuerst (auf Papier) die Tabellen und Beziehungen. Welche Beziehungsart liegt jeweils vor? Schreibe dann das SQL: die neue Tabelle und die Änderung an `bestellungen`.

<details><summary>Lösung</summary>

- Kunde → Adressen: **1:n** (Fremdschlüssel `kunde_id` in `adressen`)
- Adresse → Bestellungen: **1:n** (Fremdschlüssel `adresse_id` in `bestellungen`)

```sql
CREATE TABLE adressen (
    id          INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    kunde_id    INTEGER      NOT NULL REFERENCES kunden (id) ON DELETE CASCADE,
    bezeichnung VARCHAR(30),                       -- "Zuhause", "Büro" …
    strasse     VARCHAR(100) NOT NULL,
    hausnummer  VARCHAR(10)  NOT NULL,             -- Text! "12a" ist auch eine Hausnummer
    plz         VARCHAR(10)  NOT NULL,             -- Text! "01067" verliert als Zahl die führende 0
    ort         VARCHAR(100) NOT NULL,
    land        CHAR(2)      NOT NULL DEFAULT 'DE'
);

ALTER TABLE bestellungen
    ADD COLUMN adresse_id INTEGER REFERENCES adressen (id) ON DELETE RESTRICT;
```

Die neue Spalte darf hier (noch) `NULL` sein, weil es schon Bestellungen **ohne** Adresse gibt. Würdest du `NOT NULL` verlangen, schlägt das `ALTER TABLE` fehl. In der Praxis befüllt man erst alle alten Zeilen und setzt danach `ALTER TABLE bestellungen ALTER COLUMN adresse_id SET NOT NULL;`.

**Gut zu wissen:** Postleitzahlen, Telefonnummern und Hausnummern sind **keine** Zahlen, auch wenn sie so aussehen. Faustregel: Wenn man damit nicht rechnet, ist es Text.

**Für Fortgeschrittene:** Dieses Schema verhindert nicht, dass eine Bestellung an die Adresse eines **anderen** Kunden geht. Das ließe sich mit einem zusammengesetzten Fremdschlüssel `(kunde_id, adresse_id)` absichern.

</details>

### F2 – Das Seed-Skript um Bewertungen erweitern

In Aufgabe 9 der Readme hast du die Tabelle `bewertungen` entworfen. Bisher verschwindet sie bei jedem Seeden wieder. Baue sie dauerhaft ein:

1. Ergänze in `beispiel/sql/schema.sql` ganz unten das `CREATE TABLE bewertungen …` (das `DROP TABLE IF EXISTS bewertungen` steht schon oben).
2. Ergänze in `beispiel/seed/daten.js` eine Liste `bewertungen` mit mindestens 5 Einträgen. Wie bei den Bestellungen verweist du auf **E-Mail** und **Produktname**, nicht auf IDs. Vergiss den `module.exports` nicht.
3. Ergänze in `beispiel/seed/seed.js` eine Schleife, die die Bewertungen einfügt – **nach** Kunden und Produkten, aber **vor** dem `COMMIT`.
4. Nimm `bewertungen` in die Liste der gezählten Tabellen am Ende auf.
5. `docker compose run --rm seed` – erscheinen die Bewertungen in der Statistik?
6. Teste: Was passiert, wenn du in `daten.js` versehentlich **dieselbe** Kombination aus Kunde und Produkt zweimal einträgst? Wie viele Bewertungen sind danach in der Datenbank – und warum?

<details><summary>Lösung</summary>

**`sql/schema.sql`** (ans Ende):

```sql
CREATE TABLE bewertungen (
    id           INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    kunde_id     INTEGER  NOT NULL REFERENCES kunden (id)   ON DELETE CASCADE,
    produkt_id   INTEGER  NOT NULL REFERENCES produkte (id) ON DELETE RESTRICT,
    sterne       SMALLINT NOT NULL CHECK (sterne BETWEEN 1 AND 5),
    text         TEXT,
    erstellt_am  TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (kunde_id, produkt_id)
);
```

**`seed/daten.js`**:

```js
const bewertungen = [
  { kunde: "anna.schmidt@example.com", produkt: "SQL für Einsteiger", sterne: 5, text: "Endlich verstehe ich JOINs!" },
  { kunde: "anna.schmidt@example.com", produkt: "Kaffeetasse", sterne: 4, text: null },
  { kunde: "ben.mueller@example.com", produkt: "Mechanische Tastatur", sterne: 5, text: "Laut, aber herrlich." },
  { kunde: "clara.fischer@example.com", produkt: "27 Zoll Monitor", sterne: 3, text: "Ein Pixelfehler oben links." },
  { kunde: "david.weber@example.com", produkt: "USB-C Kabel", sterne: 2, text: "Nach zwei Wochen kaputt." },
  { kunde: "emma.wagner@example.com", produkt: "Kaffeetasse", sterne: 5, text: null },
];

module.exports = { kategorien, produkte, kunden, bestellungen, bewertungen };
```

**`seed/seed.js`** (nach der Schleife über die Bestellungen):

```js
    // Bewertungen: E-Mail und Produktname in IDs übersetzen
    for (const bw of daten.bewertungen) {
      await client.query(
        `INSERT INTO bewertungen (kunde_id, produkt_id, sterne, text)
         VALUES ($1, $2, $3, $4)`,
        [kundenIds[bw.kunde], produkte[bw.produkt].id, bw.sterne, bw.text]
      );
    }
```

und unten:

```js
    const tabellen = ["kategorien", "produkte", "kunden", "bestellungen", "bestellpositionen", "bewertungen"];
```

**Zu Frage 6:** Das Skript bricht mit `duplicate key value violates unique constraint "bewertungen_kunde_id_produkt_id_key"` ab – und in der Datenbank sind danach **gar keine** Daten, auch keine Kunden oder Produkte. Das Seed-Skript läuft in **einer Transaktion**; der Fehler löst den `ROLLBACK` aus. Nur die Tabellen selbst existieren (leer), weil das Schema **vor** dem `BEGIN` ausgeführt wurde. Fehler im Eintrag korrigieren, nochmal seeden – fertig.

</details>

### F3 – Eigenes Projekt

Entwirf das Datenbankschema für eine Anwendung deiner Wahl, z. B.:

- eine **Bibliothek** (Bücher, Autor:innen, Mitglieder, Ausleihen – ein Buch kann mehrere Autor:innen haben!)
- eine **Kursverwaltung** (Kurse, Teilnehmende, Dozierende, Anmeldungen, Noten)
- eine **Rezeptsammlung** (Rezepte, Zutaten mit Menge und Einheit, Kategorien, Bewertungen)

Vorgehen:

1. Entitäten und Attribute sammeln
2. Beziehungen bestimmen (1:n oder n:m?) und als Diagramm skizzieren
3. `schema.sql` mit allen `CREATE TABLE`-Befehlen, Schlüsseln und Constraints schreiben
4. Mit `\i` in psql laden (Datei vorher in den Ordner `beispiel/sql/` legen, dann ist sie im Container unter `/sql/` erreichbar):

   ```
   \i /sql/mein-schema.sql
   ```

5. Ein paar `INSERT`s schreiben und drei Fragen formulieren, die deine Datenbank mit `JOIN`s beantworten kann

> **Achtung:** Wähle Tabellennamen, die nicht mit dem Shop kollidieren – oder lege dir mit `CREATE DATABASE bibliothek;` und `\c bibliothek` eine eigene Datenbank an.

**Bonus:** Schreibe ein eigenes Seed-Skript nach dem Vorbild von `seed/seed.js`.
