# SQL-Grundlagen: Daten speichern und abfragen mit PostgreSQL

In der Bonusaufgabe von Kapitel 06 hast du schon einmal eine **PostgreSQL**-Datenbank mit Docker Compose gestartet und über Adminer eine Tabelle angelegt. Dabei hast du ein paar Zeilen **SQL** abgetippt, ohne genau zu wissen, was da eigentlich passiert.

In diesem Kapitel lernst du SQL von Grund auf. Du verstehst, wie eine **relationale Datenbank** aufgebaut ist, was **Primär- und Fremdschlüssel** sind und wie man **Tabellen sinnvoll entwirft**. Danach startest du eine Datenbank in Docker, befüllst sie mit einem **Seed-Skript in JavaScript** und übst Schritt für Schritt: Daten abfragen, filtern, sortieren, zählen, Tabellen verknüpfen und Daten ändern.

Als Beispiel dient ein **Mini-Webshop** mit Kunden, Produkten, Kategorien und Bestellungen.

## Inhalt

- [Grundbegriffe](#grundbegriffe)
- [Tabellen richtig entwerfen](#tabellen-richtig-entwerfen)
- [Unser Beispiel: Der Mini-Webshop](#unser-beispiel-der-mini-webshop)
- [Aufgabe 1: PostgreSQL mit Docker Compose starten](#aufgabe-1-postgresql-mit-docker-compose-starten)
- [Aufgabe 2: Mit der Datenbank verbinden](#aufgabe-2-mit-der-datenbank-verbinden)
- [Aufgabe 3: Deine erste eigene Tabelle](#aufgabe-3-deine-erste-eigene-tabelle)
- [Aufgabe 4: Die Shop-Datenbank mit dem Seed-Skript befüllen](#aufgabe-4-die-shop-datenbank-mit-dem-seed-skript-befüllen)
- [Aufgabe 5: Daten abfragen mit SELECT](#aufgabe-5-daten-abfragen-mit-select)
- [Aufgabe 6: Zählen, summieren, gruppieren](#aufgabe-6-zählen-summieren-gruppieren)
- [Aufgabe 7: Tabellen verknüpfen mit JOIN](#aufgabe-7-tabellen-verknüpfen-mit-join)
- [Aufgabe 8: Daten ändern und die Schlüssel auf die Probe stellen](#aufgabe-8-daten-ändern-und-die-schlüssel-auf-die-probe-stellen)
- [Aufgabe 9: Eine eigene Tabelle entwerfen](#aufgabe-9-eine-eigene-tabelle-entwerfen)
- [Bonusaufgabe: Indizes – warum manche Abfragen schnell sind](#bonusaufgabe-indizes--warum-manche-abfragen-schnell-sind)
- [Übungen](#übungen) · [Befehlsübersicht](#befehlsübersicht) · [Aufräumen](#aufräumen) · [Fehlerbehebung](#fehlerbehebung) · [Kontrollfragen](#kontrollfragen)

## Grundbegriffe

### Was ist eine Datenbank?

Eine **Datenbank** ist ein Programm, das Daten **dauerhaft, geordnet und sicher** speichert und sie auf Anfrage schnell wieder herausgibt. Fast jede Anwendung braucht eine: Der Webshop speichert Kunden und Bestellungen, die Bank Kontostände, Instagram Fotos und Likes.

Genau genommen ist die Software, die du startest, ein **Datenbankmanagementsystem** (**DBMS**), z. B. PostgreSQL, MySQL oder Microsoft SQL Server. Darin legst du dann eine oder mehrere **Datenbanken** an.

> **Warum nicht einfach eine Excel-Datei oder JSON?** Solange nur **eine** Person mit wenigen Daten arbeitet, geht das. Eine Datenbank kann aber mehr: Hunderte Programme dürfen **gleichzeitig** lesen und schreiben, ohne sich gegenseitig Daten zu zerstören. Sie **prüft Regeln** (z. B. „keine E-Mail doppelt“), findet in Millionen Zeilen in Millisekunden das Richtige und verliert auch bei einem Stromausfall keine bestätigten Daten.

### Relationale Datenbanken: Alles ist eine Tabelle

PostgreSQL ist eine **relationale** Datenbank. Die Daten liegen in **Tabellen**, die miteinander in **Beziehung** (_relation_) stehen.

```
 Tabelle: kunden                                                  ◀── Tabelle (Relation)
 ┌────┬─────────┬──────────┬──────────────────────────┬─────────┐
 │ id │ vorname │ nachname │ email                    │ stadt   │  ◀── Spalten (Attribute)
 ├────┼─────────┼──────────┼──────────────────────────┼─────────┤
 │  1 │ Anna    │ Schmidt  │ anna.schmidt@example.com │ Berlin  │  ◀── Zeile (Datensatz)
 │  2 │ Ben     │ Müller   │ ben.mueller@example.com  │ Hamburg │
 │  3 │ Clara   │ Fischer  │ clara.fischer@example.com│ München │
 └────┴─────────┴──────────┴──────────────────────────┴─────────┘
   ▲                                                       ▲
   Primärschlüssel                                         ein einzelner Wert (Feld)
```

| Begriff              | Bedeutung                                                                       | Vergleich mit Excel            |
| -------------------- | ------------------------------------------------------------------------------- | ------------------------------ |
| **Tabelle**          | Sammlung gleichartiger Dinge, z. B. alle Kunden                                 | Ein Tabellenblatt              |
| **Spalte**           | Eine Eigenschaft mit **festem Datentyp**, z. B. `email` ist immer Text          | Eine Spalte – aber mit Regeln  |
| **Zeile**            | Ein einzelnes Ding, z. B. **eine** Kundin                                       | Eine Zeile                     |
| **Schema**           | Der **Bauplan** aller Tabellen: welche Spalten, welche Typen, welche Regeln     | Die Spaltenüberschriften       |
| **Primärschlüssel**  | Spalte, die jede Zeile **eindeutig** identifiziert                              | Die Zeilennummer               |
| **Fremdschlüssel**   | Spalte, die auf den Primärschlüssel einer **anderen** Tabelle verweist          | Ein `SVERWEIS`, der kontrolliert wird |
| **Constraint**       | Eine **Regel**, die die Datenbank bei jedem Schreiben prüft                     | Datenüberprüfung               |
| **Abfrage (Query)**  | Eine Frage an die Datenbank, in SQL formuliert                                  | Filter + Formeln               |

Der große Unterschied zu Excel: In einer Datenbank-Spalte steht **immer** derselbe Datentyp, und die Datenbank **weigert sich**, Daten zu speichern, die gegen die Regeln verstoßen.

### Was ist SQL?

**SQL** (_Structured Query Language_, gesprochen „S-Q-L“ oder „Sequel“) ist die Sprache, mit der du mit relationalen Datenbanken sprichst. Sie ist über 50 Jahre alt, genormt und funktioniert – mit kleinen Unterschieden – in PostgreSQL, MySQL, SQLite, Oracle und SQL Server gleich.

SQL ist **deklarativ** – das Prinzip kennst du von Terraform und Kubernetes: Du beschreibst, **was** du haben willst, nicht **wie** die Datenbank es suchen soll.

```sql
SELECT vorname, nachname FROM kunden WHERE stadt = 'Berlin';
```

Auf Deutsch: „Gib mir Vor- und Nachname aller Kunden aus Berlin.“ Ob die Datenbank dafür die ganze Tabelle durchliest oder ein Inhaltsverzeichnis (Index) benutzt, entscheidet sie selbst.

SQL-Befehle lassen sich in Gruppen einteilen:

| Gruppe                                | Wofür?                         | Wichtigste Befehle                     |
| ------------------------------------- | ------------------------------ | -------------------------------------- |
| **DDL** – _Data Definition Language_  | Den **Bauplan** ändern         | `CREATE TABLE`, `ALTER TABLE`, `DROP TABLE` |
| **DML** – _Data Manipulation Language_ | **Daten** ändern              | `INSERT`, `UPDATE`, `DELETE`           |
| **DQL** – _Data Query Language_       | Daten **lesen**                | `SELECT`                               |
| **TCL** – _Transaction Control_       | Änderungen bündeln             | `BEGIN`, `COMMIT`, `ROLLBACK`          |
| **DCL** – _Data Control Language_     | **Rechte** vergeben            | `GRANT`, `REVOKE`                      |

> **Schreibweise:** SQL-Schlüsselwörter schreibt man üblicherweise **GROSS** (`SELECT`, `FROM`), Tabellen- und Spaltennamen **klein**. Nötig ist das nicht – `select * from kunden` funktioniert genauso. Jede Anweisung endet mit einem **Semikolon** `;`. **Texte** stehen in **einfachen** Anführungszeichen: `'Berlin'`. Doppelte Anführungszeichen `"..."` sind in PostgreSQL für Namen von Tabellen/Spalten reserviert. Kommentare beginnen mit `--`.

### Datentypen

Jede Spalte hat einen festen Datentyp. Die wichtigsten in PostgreSQL:

| Datentyp                | Inhalt                                          | Beispiel                     |
| ----------------------- | ----------------------------------------------- | ---------------------------- |
| `INTEGER`               | Ganze Zahl (bis ca. ± 2,1 Milliarden)           | `42`                         |
| `BIGINT`                | Sehr große ganze Zahl                           | `9000000000`                 |
| `NUMERIC(10,2)`         | **Exakte** Kommazahl: 10 Stellen, davon 2 nach dem Komma | `249.00`            |
| `REAL` / `DOUBLE PRECISION` | Gleitkommazahl – schnell, aber **ungenau**  | `3.14159`                    |
| `VARCHAR(n)`            | Text mit höchstens `n` Zeichen                  | `'Anna'`                     |
| `TEXT`                  | Text beliebiger Länge                           | `'Ein langer Beschreibungstext …'` |
| `BOOLEAN`               | Wahr oder falsch                                | `true`, `false`              |
| `DATE`                  | Datum                                           | `'2026-11-23'`               |
| `TIMESTAMPTZ`           | Datum + Uhrzeit mit Zeitzone                    | `'2026-11-23 14:30:00+01'`   |
| `UUID`                  | Weltweit eindeutige ID                          | `'a0eebc99-9c0b-4ef8-…'`     |
| `JSONB`                 | JSON-Dokument                                   | `'{"farbe": "rot"}'`         |

> **Merke:** Geldbeträge **nie** als `REAL` oder `DOUBLE` speichern! Gleitkommazahlen können `0.1` nicht exakt darstellen (in JavaScript ergibt `0.1 + 0.2` den Wert `0.30000000000000004`). Für Geld immer `NUMERIC`. Datumswerte immer im Format **`JJJJ-MM-TT`** schreiben.

### NULL – der „unbekannte“ Wert

`NULL` bedeutet **„kein Wert / unbekannt“**. Es ist **nicht** dasselbe wie `0` oder ein leerer Text `''`. Wenn bei einer Kundin die Stadt `NULL` ist, wissen wir die Stadt einfach nicht.

Die Tücke: Mit `NULL` kann man nicht rechnen oder vergleichen. `NULL = NULL` ist nicht wahr, sondern wieder `NULL`. Deshalb prüft man mit **`IS NULL`** bzw. **`IS NOT NULL`**, niemals mit `= NULL`. Das probierst du in Aufgabe 5 selbst aus.

### Constraints: Regeln für die Daten

**Constraints** (Einschränkungen) sind Regeln, die du beim Anlegen einer Tabelle festlegst. Die Datenbank prüft sie bei **jedem** `INSERT` und `UPDATE` und verweigert alles, was dagegen verstößt.

| Constraint     | Bedeutung                                                    | Beispiel                                  |
| -------------- | ------------------------------------------------------------ | ----------------------------------------- |
| `NOT NULL`     | Die Spalte muss **immer** einen Wert haben                   | `nachname VARCHAR(50) NOT NULL`           |
| `UNIQUE`       | Jeder Wert darf nur **einmal** vorkommen                     | `email VARCHAR(255) UNIQUE`               |
| `DEFAULT`      | Standardwert, wenn beim Einfügen nichts angegeben wird       | `status VARCHAR(20) DEFAULT 'offen'`      |
| `CHECK`        | Eine beliebige **Bedingung** muss erfüllt sein               | `preis NUMERIC CHECK (preis >= 0)`        |
| `PRIMARY KEY`  | Der **Primärschlüssel** (= `NOT NULL` + `UNIQUE`)            | `id INTEGER PRIMARY KEY`                  |
| `REFERENCES`   | Ein **Fremdschlüssel**: Wert muss in einer anderen Tabelle existieren | `kunde_id INTEGER REFERENCES kunden (id)` |

> **Warum Regeln in der Datenbank und nicht nur im Programm?** Weil irgendwann **mehrere** Programme (Web-App, Admin-Skript, Import-Job, ein Kollege mit psql) in dieselbe Datenbank schreiben. Die Datenbank ist die letzte Verteidigungslinie – was sie nicht durchlässt, kann auch kein fehlerhaftes Skript kaputtmachen.

### Der Primärschlüssel (Primary Key, PK)

Jede Tabelle braucht eine Spalte (oder Kombination von Spalten), die **jede Zeile eindeutig** identifiziert: den **Primärschlüssel**. Er ist

- **eindeutig** – kein Wert kommt zweimal vor,
- **nie leer** – niemals `NULL`,
- **unveränderlich** – er sollte sich nie ändern, denn andere Tabellen verweisen darauf.

> **Vergleich:** Der Primärschlüssel ist wie die **Personalausweisnummer**. Es gibt viele „Anna Schmidt“, aber nur eine mit dieser Nummer.

Es gibt zwei Arten von Schlüsseln:

| Art                                 | Beispiel                                   | Vorteil                       | Nachteil                                                          |
| ----------------------------------- | ------------------------------------------ | ----------------------------- | ----------------------------------------------------------------- |
| **Natürlicher Schlüssel**           | E-Mail-Adresse, ISBN, Kfz-Kennzeichen      | Hat eine Bedeutung            | Kann sich **ändern** (neue E-Mail!) oder ist doch nicht eindeutig |
| **Künstlicher Schlüssel** (Surrogat) | Fortlaufende Nummer `1, 2, 3 …` oder UUID | Ändert sich **nie**, ist kurz | Hat keine Bedeutung                                               |

**Faustregel:** Nimm einen **künstlichen** Schlüssel `id` und mache natürliche Kandidaten wie die E-Mail zusätzlich `UNIQUE`. In PostgreSQL lässt du die ID automatisch hochzählen:

```sql
id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY
```

`GENERATED ALWAYS AS IDENTITY` heißt: Die Datenbank vergibt die Nummer selbst, du gibst beim `INSERT` **keine** `id` an. In älteren Anleitungen findest du dafür oft `SERIAL` – das macht fast dasselbe, ist aber die veraltete Schreibweise.

Ein Primärschlüssel kann auch aus **mehreren Spalten** bestehen (**zusammengesetzter Schlüssel**). Das siehst du gleich bei der Tabelle `bestellpositionen`.

### Der Fremdschlüssel (Foreign Key, FK)

Ein **Fremdschlüssel** ist eine Spalte, die auf den **Primärschlüssel einer anderen Tabelle** zeigt. So entstehen die Beziehungen zwischen Tabellen.

```
   kunden                              bestellungen
 ┌────┬─────────┐                    ┌────┬──────────┬─────────────┬───────────┐
 │ id │ vorname │                    │ id │ kunde_id │ bestellt_am │ status    │
 ├────┼─────────┤                    ├────┼──────────┼─────────────┼───────────┤
 │  1 │ Anna    │◀───────────────────│  1 │    1     │ 2026-01-08  │ versendet │
 │  2 │ Ben     │◀──────────┐        │  2 │    2     │ 2026-01-15  │ versendet │
 │  3 │ Clara   │           │    ┌───│  3 │    1     │ 2026-02-03  │ versendet │
 └────┴─────────┘           └────┼───│ .. │   ...    │             │           │
   ▲  Primärschlüssel            │   └────┴──────────┴─────────────┴───────────┘
   └─────────────────────────────┘           ▲ Fremdschlüssel: "gehört zu Kunde Nr. …"
```

Statt Name, E-Mail und Stadt der Kundin in **jeder** Bestellung zu wiederholen, steht dort nur ihre Nummer. Die Datenbank sorgt dabei für **referenzielle Integrität**:

- Du kannst **keine** Bestellung für Kunde `999` anlegen, wenn es Kunde `999` nicht gibt.
- Du kannst eine Kundin **nicht löschen**, solange noch Bestellungen auf sie verweisen (außer du erlaubst es ausdrücklich).

Was beim Löschen passieren soll, legst du mit `ON DELETE` fest:

| Option                      | Was passiert, wenn der Kunde gelöscht wird?                         | Sinnvoll für                                  |
| --------------------------- | ------------------------------------------------------------------- | --------------------------------------------- |
| `ON DELETE RESTRICT` (Standard) | Löschen wird **verweigert**, solange Bestellungen existieren     | Bestellungen (Rechnungen darf man nicht verlieren) |
| `ON DELETE CASCADE`         | Die Bestellungen werden **mitgelöscht**                             | Bestellpositionen einer gelöschten Bestellung |
| `ON DELETE SET NULL`        | In den Bestellungen wird `kunde_id` auf `NULL` gesetzt              | Produkt einer gelöschten Kategorie            |

> **Vorsicht mit `CASCADE`:** Ein einziges `DELETE` kann dann über mehrere Tabellen hinweg tausende Zeilen löschen. Nur verwenden, wenn die abhängigen Daten ohne den „Elternteil“ wirklich sinnlos sind.

### Beziehungen zwischen Tabellen

Es gibt drei Arten von Beziehungen. Die Schreibweise „1:n“ liest man „eins zu n“ (n = beliebig viele).

**1:n (eins zu viele) – der häufigste Fall**

Eine Kundin hat **viele** Bestellungen, eine Bestellung gehört zu **genau einer** Kundin.

```
 ┌─────────┐ 1          n ┌──────────────┐
 │ kunden  │──────────────│ bestellungen │     Der Fremdschlüssel steht immer
 │ id (PK) │              │ kunde_id (FK)│     auf der "n"-Seite (bei den vielen).
 └─────────┘              └──────────────┘
```

**n:m (viele zu viele)**

Eine Bestellung enthält **viele** Produkte, ein Produkt kommt in **vielen** Bestellungen vor. Das lässt sich **nicht** mit einer einzigen Fremdschlüssel-Spalte abbilden – du bräuchtest ja eine Liste von IDs in einem Feld. Die Lösung ist eine **Zwischentabelle** (auch Verbindungstabelle), die aus der n:m-Beziehung **zwei 1:n-Beziehungen** macht:

```
 ┌──────────────┐ 1     n ┌────────────────────┐ n     1 ┌──────────┐
 │ bestellungen │─────────│ bestellpositionen  │─────────│ produkte │
 │ id (PK)      │         │ bestellung_id (FK) │         │ id (PK)  │
 └──────────────┘         │ produkt_id    (FK) │         └──────────┘
                          │ menge              │
                          │ einzelpreis        │
                          └────────────────────┘
```

Die Zwischentabelle kann außerdem **eigene** Informationen tragen, die zur Verbindung gehören: Hier die `menge` und den `einzelpreis` zum Zeitpunkt der Bestellung.

**1:1 (eins zu eins) – selten**

Eine Zeile gehört zu **genau einer** Zeile in einer anderen Tabelle, z. B. `kunden` ↔ `kunden_login` (Passwort-Hash, letzter Login). Technisch ist das ein Fremdschlüssel, der zusätzlich `UNIQUE` ist. Man nutzt es, um selten gebrauchte oder besonders schützenswerte Daten auszulagern. Meistens gehören die Spalten aber einfach in dieselbe Tabelle.

## Tabellen richtig entwerfen

Ein gutes Tabellendesign spart dir später viel Ärger. Ein schlechtes merkst du erst, wenn schon Millionen Zeilen darin liegen – dann ist der Umbau teuer.

### Das Problem: Alles in eine Tabelle

So würde man eine Bestellliste vielleicht in Excel führen:

```
 bestellungen_schlecht
 ┌────┬─────────────┬──────────────────────────┬────────┬────────────┬──────────────────────────────────┬──────────────┐
 │ nr │ kunde       │ kunde_email              │ stadt  │ datum      │ produkte                         │ preise       │
 ├────┼─────────────┼──────────────────────────┼────────┼────────────┼──────────────────────────────────┼──────────────┤
 │  1 │ Anna Schmidt│ anna.schmidt@example.com │ Berlin │ 08.01.2026 │ SQL für Einsteiger, Kaffeetasse  │ 24.90, 7.50  │
 │  3 │ Anna Schmidt│ anna.schmidt@example.com │ Berlin │ 03.02.2026 │ Docker kompakt, Kubernetes …     │ 29.90, 49.90 │
 │ 10 │ A. Schmidt  │ anna.schmidt@exmaple.com │ berlin │ 22.09.2026 │ Funkmaus, USB-C Kabel, USB-C …   │ 19.99, 9.99… │
 └────┴─────────────┴──────────────────────────┴────────┴────────────┴──────────────────────────────────┴──────────────┘
```

Was ist hier alles schief?

| Problem                                   | Folge                                                                                         |
| ----------------------------------------- | --------------------------------------------------------------------------------------------- |
| **Mehrere Werte in einem Feld** (`produkte`) | „Wie oft wurde die Kaffeetasse verkauft?“ lässt sich kaum beantworten                      |
| **Doppelte Daten** (Name, E-Mail, Stadt in jeder Bestellung) | Speicherverschwendung – und Anna zieht um: Wie viele Zeilen musst du ändern? |
| **Widersprüche** (`A. Schmidt`, `exmaple.com`, `berlin`) | Ist das dieselbe Person? Niemand weiß es mehr sicher                             |
| **Kein Primärschlüssel / keine Regeln**   | Doppelte Nummern, Tippfehler und Text im Datumsfeld sind möglich                              |
| **Datum als Text** (`08.01.2026`)         | Sortieren und Rechnen („alle Bestellungen im Januar“) klappt nicht zuverlässig               |

Man spricht von **Anomalien**: Beim Einfügen, Ändern oder Löschen entstehen Widersprüche oder es gehen Informationen verloren (lösche die letzte Bestellung eines Kunden – und der Kunde ist weg).

### Die Lösung: Normalisierung

**Normalisierung** bedeutet: Daten so auf Tabellen verteilen, dass **jede Information genau einmal** gespeichert ist. Dafür gibt es die **Normalformen**. Für den Alltag reichen die ersten drei:

| Normalform | Regel (vereinfacht)                                                                     | Im Beispiel                                                                              |
| ---------- | --------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| **1. NF**  | Jedes Feld enthält **genau einen** Wert. Keine Listen, keine Wiederholungsspalten (`produkt1`, `produkt2`, …) | Jedes Produkt einer Bestellung bekommt eine **eigene Zeile** → `bestellpositionen` |
| **2. NF**  | Jede Spalte hängt vom **ganzen** Primärschlüssel ab, nicht nur von einem Teil           | Der Produktname hängt nur von `produkt_id` ab, nicht von der Bestellung → gehört in `produkte` |
| **3. NF**  | Keine Spalte hängt von einer **anderen Nicht-Schlüssel-Spalte** ab                      | Stadt und E-Mail hängen vom Kunden ab, nicht von der Bestellung → gehören in `kunden`    |

> **Eselsbrücke:** Jede Spalte muss etwas aussagen über _„den Schlüssel, den ganzen Schlüssel und nichts als den Schlüssel“_.

> **Ausnahme mit Absicht:** In `bestellpositionen` speichern wir den `einzelpreis`, obwohl der Preis auch in `produkte` steht. Das ist **keine** Doppelung: Der Preis im Produkt ist der **aktuelle** Preis, der in der Position der Preis **zum Zeitpunkt der Bestellung**. Erhöhst du morgen den Preis der Tastatur, darf sich die Rechnung vom Januar nicht ändern.

### Schritt für Schritt zum eigenen Tabellendesign

1. **Dinge (Entitäten) finden:** Welche „Hauptwörter“ kommen in deiner Anwendung vor? → Kunde, Produkt, Kategorie, Bestellung. Jedes wird eine Tabelle.
2. **Eigenschaften (Attribute) sammeln:** Was willst du über jedes Ding wissen? → Kunde: Vorname, Nachname, E-Mail, Stadt …
3. **Datentypen wählen:** Text, Zahl, Datum? Geld → `NUMERIC`. Datum → `DATE`, nicht Text.
4. **Primärschlüssel festlegen:** In der Regel eine künstliche `id`.
5. **Beziehungen bestimmen:** Für jedes Paar von Tabellen fragen: „Wie viele A gehören zu einem B – und umgekehrt?“
   - **1:n** → Fremdschlüssel auf der n-Seite
   - **n:m** → Zwischentabelle mit zwei Fremdschlüsseln
6. **Regeln (Constraints) ergänzen:** Was ist Pflicht (`NOT NULL`)? Was muss eindeutig sein (`UNIQUE`)? Welche Werte sind erlaubt (`CHECK`)? Was passiert beim Löschen (`ON DELETE`)?
7. **Prüfen:** Steht irgendeine Information doppelt? Gibt es Felder mit Listen? → Nochmal aufteilen.

### Namenskonventionen

Es gibt keine feste Regel, aber **eine** Konvention pro Projekt durchhalten:

- Tabellen- und Spaltennamen **klein** und mit **Unterstrich**: `bestellt_am`, nicht `BestelltAm` (PostgreSQL wandelt Großbuchstaben sonst um, außer du setzt überall `"Anführungszeichen"`)
- **Keine Leerzeichen und Umlaute** in Namen: `groesse` statt `größe` (in den **Daten** sind Umlaute natürlich kein Problem)
- Tabellen im **Plural** (`kunden`, `produkte`) – oder überall im Singular, aber nicht gemischt
- Primärschlüssel heißt `id`, Fremdschlüssel `<tabelle_im_singular>_id`: `kunde_id`, `produkt_id`
- Keine reservierten Wörter als Namen: `user`, `order`, `group`, `table` → lieber `benutzer`, `bestellung`

## Unser Beispiel: Der Mini-Webshop

So sieht das Schema aus, mit dem du ab Aufgabe 4 arbeitest. Den vollständigen SQL-Code findest du in [`beispiel/sql/schema.sql`](./beispiel/sql/schema.sql) – lies ihn dir einmal in Ruhe durch, jede Zeile ist kommentiert.

```
 ┌───────────────────────┐                        ┌──────────────────────────┐
 │ kategorien            │                        │ kunden                   │
 ├───────────────────────┤                        ├──────────────────────────┤
 │ PK id                 │                        │ PK id                    │
 │    name   UNIQUE      │                        │    vorname     NOT NULL  │
 └───────────┬───────────┘                        │    nachname    NOT NULL  │
             │ 1                                  │    email       UNIQUE    │
             │                                    │    stadt       (NULL ok) │
             │ n                                  │    registriert_am        │
 ┌───────────┴───────────┐                        └────────────┬─────────────┘
 │ produkte              │                                     │ 1
 ├───────────────────────┤                                     │
 │ PK id                 │                                     │ n
 │    name               │                        ┌────────────┴─────────────┐
 │    preis   CHECK >= 0 │                        │ bestellungen             │
 │    lagerbestand       │                        ├──────────────────────────┤
 │ FK kategorie_id ──────┼─▶ kategorien.id        │ PK id                    │
 └───────────┬───────────┘   ON DELETE SET NULL   │ FK kunde_id  ────────────┼─▶ kunden.id
             │ 1                                  │    bestellt_am           │   ON DELETE RESTRICT
             │                                    │    status   CHECK IN (…) │
             │ n                                  └────────────┬─────────────┘
             │          ┌──────────────────────────────┐       │ 1
             │          │ bestellpositionen            │       │
             │          ├──────────────────────────────┤     n │
             └─────────▶│ PK,FK produkt_id             │◀──────┘
                        │ PK,FK bestellung_id          │  ON DELETE CASCADE
                        │       menge        CHECK > 0 │
                        │       einzelpreis            │
                        └──────────────────────────────┘
```

| Beziehung                                 | Art   | Umsetzung                                                      |
| ----------------------------------------- | ----- | -------------------------------------------------------------- |
| Kategorie → Produkte                      | 1:n   | `produkte.kategorie_id` (darf `NULL` sein: Produkt ohne Kategorie) |
| Kunde → Bestellungen                      | 1:n   | `bestellungen.kunde_id` (`NOT NULL`: keine Bestellung ohne Kunde) |
| Bestellungen ↔ Produkte                   | n:m   | Zwischentabelle `bestellpositionen` mit **zusammengesetztem** PK `(bestellung_id, produkt_id)` |

Der zusammengesetzte Primärschlüssel in `bestellpositionen` sorgt dafür, dass dasselbe Produkt in **einer** Bestellung nur **einmal** vorkommt. Wer drei USB-Kabel kauft, bekommt eine Zeile mit `menge = 3`, nicht drei Zeilen.

In den Beispieldaten sind ein paar **Sonderfälle** absichtlich eingebaut, damit die Übungen spannend werden: eine Kundin ohne Stadt, eine Kundin ohne Bestellung, ein Produkt ohne Kategorie, eine Kategorie ohne Produkte, ein Produkt, das nie bestellt wurde, und eine stornierte Bestellung.

## Voraussetzungen

- **WSL mit Ubuntu** (siehe Kapitel 01)
- **Docker** mit dem **Compose-Plugin** in der WSL (siehe Kapitel 06, Aufgabe 1)
- Dieses Repository in der WSL (`git clone` bzw. `git pull`, siehe Kapitel 02/03)
- **Optional:** Node.js in der WSL – nur für Variante B in Aufgabe 4. Ohne Node.js läuft alles über Docker.

Prüfen:

```bash
docker --version
docker compose version
```

---

## Aufgabe 1: PostgreSQL mit Docker Compose starten

### Schritt 1: In den Beispielordner wechseln

```bash
cd ~/<pfad-zum-repo>/11-sql-grundlagen/beispiel
ls
```

Du siehst:

```
compose.yaml   seed/   sql/
```

| Datei / Ordner        | Inhalt                                                           |
| --------------------- | ---------------------------------------------------------------- |
| `compose.yaml`        | Startet PostgreSQL, Adminer und (auf Wunsch) das Seed-Skript     |
| `sql/schema.sql`      | Der Bauplan der Shop-Tabellen (DDL)                              |
| `seed/seed.js`        | Das Seed-Skript in JavaScript                                    |
| `seed/daten.js`       | Die Beispieldaten                                                |
| `seed/package.json`   | Abhängigkeiten des Skripts (der PostgreSQL-Treiber `pg`)         |

### Schritt 2: Die Compose-Datei ansehen

```bash
cat compose.yaml
```

Das meiste kennst du aus Kapitel 06. Neu sind:

- `ports: "5432:5432"` – die Datenbank ist von **deinem Laptop** aus erreichbar (für Variante B in Aufgabe 4 und Programme wie DBeaver). Auf einem Server würdest du das **nicht** machen!
- `./sql:/sql:ro` – der Ordner `sql/` ist im Container unter `/sql` **lesbar** (`ro` = _read only_).
- `healthcheck` – Docker fragt alle 2 Sekunden mit `pg_isready`, ob die Datenbank schon Verbindungen annimmt. Erst dann gilt der Container als **healthy**.
- Der Service `seed` hat ein **Profil** (`profiles: ["seed"]`). Dadurch startet er **nicht** bei `docker compose up`, sondern nur, wenn du ihn ausdrücklich aufrufst (Aufgabe 4).

### Schritt 3: Starten

```bash
docker compose up -d
docker compose ps
```

Warte, bis bei `db` in der Spalte `STATUS` **`(healthy)`** steht (ein paar Sekunden). Wiederhole dafür `docker compose ps`.

```
NAME                 IMAGE                STATUS                   PORTS
beispiel-adminer-1   adminer              Up 10 seconds            0.0.0.0:8081->8080/tcp
beispiel-db-1        postgres:17-alpine   Up 10 seconds (healthy)  0.0.0.0:5432->5432/tcp
```

Die Datenbank `shop` ist jetzt da – aber noch **leer**.

## Aufgabe 2: Mit der Datenbank verbinden

Es gibt viele Wege, mit einer Datenbank zu sprechen. Wir nutzen zwei: das Kommandozeilen-Programm **psql** (wie ein Profi) und die Web-Oberfläche **Adminer** (zum Durchklicken).

### Schritt 1: psql im Container starten

`psql` ist das offizielle Kommandozeilen-Werkzeug von PostgreSQL. Es ist im Container schon installiert:

```bash
docker compose exec db psql -U app -d shop
```

| Teil                    | Bedeutung                                          |
| ----------------------- | -------------------------------------------------- |
| `docker compose exec db` | Führe im laufenden Container `db` einen Befehl aus |
| `psql`                  | Das Programm                                       |
| `-U app`                | Als Benutzer `app` anmelden                        |
| `-d shop`               | Mit der Datenbank `shop` verbinden                 |

Die Eingabezeile ändert sich:

```
psql (17.x)
Type "help" for help.

shop=#
```

`shop=#` heißt: Du bist mit der Datenbank `shop` verbunden und kannst SQL eintippen.

### Schritt 2: Die ersten psql-Befehle

Neben SQL kennt psql eigene **Meta-Befehle**. Sie beginnen mit einem **Backslash** `\` und brauchen **kein** Semikolon:

```
\l
```

Listet alle Datenbanken auf. Du siehst `shop` und ein paar Systemdatenbanken (`postgres`, `template0`, `template1`).

```
\dt
```

Listet die Tabellen der aktuellen Datenbank auf. Ergebnis: `Did not find any relations.` – stimmt, die Datenbank ist noch leer.

```
\conninfo
```

Zeigt, als wer und womit du verbunden bist.

Und jetzt der erste echte SQL-Befehl (mit Semikolon!):

```sql
SELECT version();
```

```sql
SELECT 1 + 1 AS ergebnis, CURRENT_DATE AS heute;
```

> **Wichtig:** Vergisst du das Semikolon, passiert scheinbar nichts und die Eingabe wechselt zu `shop-#`. psql wartet auf den Rest der Anweisung. Tippe einfach `;` und Enter. Mit `Strg + C` brichst du eine halbe Eingabe ab.

Die wichtigsten Meta-Befehle:

| Befehl          | Wirkung                                                |
| --------------- | ------------------------------------------------------ |
| `\l`            | Alle Datenbanken anzeigen                              |
| `\c <name>`     | Zu einer anderen Datenbank wechseln                    |
| `\dt`           | Alle Tabellen anzeigen                                 |
| `\d <tabelle>`  | Aufbau einer Tabelle anzeigen (Spalten, Typen, Schlüssel) |
| `\x`            | Erweiterte Anzeige ein/aus – praktisch bei breiten Tabellen |
| `\i <datei>`    | SQL-Datei ausführen                                    |
| `\?`            | Hilfe zu allen Meta-Befehlen                           |
| `\h SELECT`     | Hilfe zu einem SQL-Befehl                              |
| `\q`            | psql beenden                                           |

Lange Ergebnisse zeigt psql seitenweise an. **Leertaste** blättert weiter, **`q`** beendet die Anzeige.

### Schritt 3: Adminer im Browser

Öffne in Windows:

```
http://localhost:8081
```

| Feld         | Wert         |
| ------------ | ------------ |
| **System**   | `PostgreSQL` |
| **Server**   | `db`         |
| **Username** | `app`        |
| **Password** | `geheim123`  |
| **Database** | `shop`       |

Warum `db` und nicht `localhost`? Das weißt du aus Kapitel 06: Adminer läuft selbst in einem Container und erreicht die Datenbank über das Compose-Netzwerk unter dem **Service-Namen**.

Über **SQL command** (links) kannst du in Adminer genauso SQL ausführen wie in psql. Such dir aus, was dir lieber ist – alle folgenden Aufgaben funktionieren mit beidem. **psql** ist aber das Werkzeug, das du auf jedem Server findest.

## Aufgabe 3: Deine erste eigene Tabelle

Bevor du mit dem Shop arbeitest, legst du eine kleine Tabelle **von Hand** an und lernst dabei die vier Grundoperationen kennen, die man oft **CRUD** nennt:

| CRUD       | Bedeutung       | SQL      |
| ---------- | --------------- | -------- |
| **C**reate | Anlegen         | `INSERT` |
| **R**ead   | Lesen           | `SELECT` |
| **U**pdate | Ändern          | `UPDATE` |
| **D**elete | Löschen         | `DELETE` |

Alle Befehle tippst du in **psql** (`shop=#`) ein.

### Schritt 1: Tabelle anlegen (CREATE TABLE)

```sql
CREATE TABLE haustiere (
    id          INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name        VARCHAR(50) NOT NULL,
    tierart     VARCHAR(30) NOT NULL,
    geburtstag  DATE
);
```

Ein SQL-Befehl darf über **mehrere Zeilen** gehen – erst das `;` schickt ihn ab. psql antwortet mit `CREATE TABLE`.

Den Aufbau ansehen:

```
\d haustiere
```

```
                                 Table "public.haustiere"
   Column   |         Type          | Collation | Nullable |           Default
------------+-----------------------+-----------+----------+------------------------------
 id         | integer               |           | not null | generated always as identity
 name       | character varying(50) |           | not null |
 tierart    | character varying(30) |           | not null |
 geburtstag | date                  |           |          |
Indexes:
    "haustiere_pkey" PRIMARY KEY, btree (id)
```

Der Primärschlüssel hat automatisch einen **Index** bekommen (`haustiere_pkey`). Dazu mehr in der Bonusaufgabe.

### Schritt 2: Daten einfügen (INSERT)

```sql
INSERT INTO haustiere (name, tierart, geburtstag)
VALUES ('Bello', 'Hund', '2020-05-01');
```

Die `id` gibst du **nicht** an – die vergibt die Datenbank. Mehrere Zeilen auf einmal:

```sql
INSERT INTO haustiere (name, tierart, geburtstag)
VALUES ('Minka', 'Katze', '2019-11-11'),
       ('Hoppel', 'Kaninchen', NULL),
       ('Nemo', 'Fisch', '2024-02-29');
```

### Schritt 3: Daten lesen (SELECT)

```sql
SELECT * FROM haustiere;
```

```
 id |  name  |  tierart  | geburtstag
----+--------+-----------+------------
  1 | Bello  | Hund      | 2020-05-01
  2 | Minka  | Katze     | 2019-11-11
  3 | Hoppel | Kaninchen |
  4 | Nemo   | Fisch     | 2024-02-29
(4 rows)
```

`*` heißt „alle Spalten“. Nur bestimmte Spalten und nur bestimmte Zeilen:

```sql
SELECT name, tierart FROM haustiere WHERE tierart = 'Katze';
```

### Schritt 4: Daten ändern (UPDATE)

Hoppels Geburtstag ist jetzt bekannt:

```sql
UPDATE haustiere SET geburtstag = '2023-03-03' WHERE name = 'Hoppel';
```

psql antwortet `UPDATE 1` – eine Zeile wurde geändert.

> **⚠️ Achtung, die gefährlichste Zeile in SQL:** Ein `UPDATE` oder `DELETE` **ohne `WHERE`** betrifft **alle** Zeilen der Tabelle. `UPDATE haustiere SET name = 'Bello';` – und alle Tiere heißen Bello. Es gibt **kein** „Rückgängig“. Gewöhn dir an, vorher mit einem `SELECT … WHERE …` zu prüfen, welche Zeilen getroffen werden, und erst dann das `SELECT *` durch `UPDATE … SET …` bzw. `DELETE` zu ersetzen.

### Schritt 5: Daten löschen (DELETE)

```sql
DELETE FROM haustiere WHERE id = 4;
SELECT * FROM haustiere;
```

Nemo ist weg. Lege ein neues Tier an und schau dir seine `id` an:

```sql
INSERT INTO haustiere (name, tierart) VALUES ('Flocke', 'Hamster');
SELECT * FROM haustiere;
```

Flocke bekommt die `id` **5**, nicht 4! Eine vergebene ID wird **nie** wiederverwendet. So kann eine alte Referenz (z. B. in einer E-Mail „Ihr Tier Nr. 4“) niemals versehentlich auf ein neues Tier zeigen.

### Schritt 6: Die Regeln testen

Probiere bewusst Dinge, die **nicht** erlaubt sind, und lies die Fehlermeldungen genau:

```sql
INSERT INTO haustiere (tierart) VALUES ('Hund');
```

```
ERROR:  null value in column "name" of relation "haustiere" violates not-null constraint
```

Der Name ist Pflicht (`NOT NULL`).

```sql
INSERT INTO haustiere (id, name, tierart) VALUES (1, 'Rex', 'Hund');
```

```
ERROR:  cannot insert a non-DEFAULT value into column "id"
DETAIL:  Column "id" is an identity column defined as GENERATED ALWAYS.
```

Die `id` vergibt nur die Datenbank.

```sql
INSERT INTO haustiere (name, tierart, geburtstag) VALUES ('Rex', 'Hund', 'gestern');
```

```
ERROR:  invalid input syntax for type date: "gestern"
```

In eine `DATE`-Spalte kommt nur ein gültiges Datum.

### Schritt 7: Tabelle nachträglich ändern (ALTER TABLE)

Eine neue Spalte hinzufügen:

```sql
ALTER TABLE haustiere ADD COLUMN gewicht_kg NUMERIC(5,2);
SELECT * FROM haustiere;
```

Bestehende Zeilen haben in der neuen Spalte `NULL`. Eine Regel nachrüsten:

```sql
ALTER TABLE haustiere ADD CONSTRAINT gewicht_positiv CHECK (gewicht_kg > 0);
UPDATE haustiere SET gewicht_kg = -3 WHERE name = 'Bello';
```

Der `UPDATE` wird abgelehnt: `violates check constraint "gewicht_positiv"`.

### Schritt 8: Tabelle löschen (DROP TABLE)

```sql
DROP TABLE haustiere;
\dt
```

Tabelle samt Daten sind weg – wieder **ohne** Rückfrage.

> **Unterschied:** `DELETE FROM haustiere;` löscht alle **Zeilen**, die Tabelle (der Bauplan) bleibt. `DROP TABLE haustiere;` löscht die **ganze Tabelle**.

## Aufgabe 4: Die Shop-Datenbank mit dem Seed-Skript befüllen

### Was ist ein Seed-Skript?

**Seeden** (engl. _to seed_ = säen) heißt: eine Datenbank mit **Start- oder Testdaten** befüllen. Jedes größere Projekt hat so ein Skript, denn:

- Neue Entwickler:innen haben mit **einem Befehl** eine Datenbank mit sinnvollen Daten.
- Automatische Tests (Kapitel 09) brauchen **immer denselben** Ausgangszustand.
- Hast du beim Üben Daten kaputtgemacht, stellst du mit einem Befehl den Anfangszustand wieder her. 🎉

```
  seed/daten.js ──┐
                  ├──▶ seed/seed.js ──── SQL über das Netzwerk ────▶ PostgreSQL (shop)
  sql/schema.sql ─┘      (Node.js + Paket "pg")                       ┌────────────────┐
                                                                      │ kategorien     │
                         1. Schema ausführen (DROP + CREATE)          │ produkte       │
                         2. BEGIN                                     │ kunden         │
                         3. INSERT … RETURNING id  (viele Male)       │ bestellungen   │
                         4. COMMIT                                    │ bestellpos.    │
                                                                      └────────────────┘
```

### Schritt 1: Den Code verstehen

Öffne [`seed/daten.js`](./beispiel/seed/daten.js) und [`seed/seed.js`](./beispiel/seed/seed.js) im Editor (`code .` öffnet VS Code aus der WSL). Die wichtigsten Stellen:

**1. Verbindung aus einer Umgebungsvariable** – wie bei der App im Abschlussprojekt:

```js
const DATABASE_URL = process.env.DATABASE_URL || "postgres://app:geheim123@localhost:5432/shop";
```

Eine Verbindungs-URL ist so aufgebaut: `postgres://<benutzer>:<passwort>@<host>:<port>/<datenbank>`.

**2. Platzhalter statt zusammengebauter Strings:**

```js
await client.query(
  "INSERT INTO kategorien (name) VALUES ($1) RETURNING id",
  [name]
);
```

`$1`, `$2`, … sind **Platzhalter**. Die Werte werden **getrennt** vom SQL-Befehl an die Datenbank geschickt. Baue Werte **niemals** per Template-String in SQL ein:

```js
// ❌ NIEMALS SO!
await client.query(`SELECT * FROM kunden WHERE email = '${email}'`);
```

Gibt jemand als E-Mail `' OR '1'='1` ein, wird daraus `WHERE email = '' OR '1'='1'` – und er bekommt **alle** Kunden. Das nennt man **SQL-Injection**, und es ist seit Jahrzehnten eine der häufigsten Sicherheitslücken überhaupt.

**3. IDs zurückbekommen mit `RETURNING`:**

In `daten.js` stehen **keine** IDs. Produkte verweisen auf den **Namen** ihrer Kategorie, Bestellungen auf die **E-Mail** des Kunden. Das Skript fügt erst die Kategorien ein, merkt sich mit `RETURNING id` die neue ID und setzt diese dann beim Produkt als Fremdschlüssel ein:

```js
kategorieIds[name] = ergebnis.rows[0].id;          // z. B. kategorieIds["Bücher"] = 1
...
const kategorieId = p.kategorie ? kategorieIds[p.kategorie] : null;
```

Deshalb muss die **Reihenfolge** stimmen: erst die Tabellen, auf die verwiesen wird (`kategorien`, `kunden`), dann die, die verweisen (`produkte`, `bestellungen`, `bestellpositionen`). Andersherum würde der Fremdschlüssel einen Fehler werfen.

**4. Alles oder nichts mit einer Transaktion:**

```js
await client.query("BEGIN");
// ... viele INSERTs ...
await client.query("COMMIT");
// im Fehlerfall:
await client.query("ROLLBACK");
```

Eine **Transaktion** bündelt mehrere Befehle zu einer Einheit: Entweder werden **alle** gespeichert (`COMMIT`) oder **keiner** (`ROLLBACK`). Bricht das Skript in der Mitte ab, bleibt keine halb befüllte Datenbank zurück. Mehr dazu in Aufgabe 8.

### Schritt 2 (Variante A, empfohlen): Seed-Skript mit Docker ausführen

Du brauchst **kein** Node.js auf deinem Laptop – das Skript läuft in einem `node`-Container:

```bash
docker compose run --rm seed
```

| Teil       | Bedeutung                                                                     |
| ---------- | ----------------------------------------------------------------------------- |
| `run seed` | Startet den Service `seed` **einmalig** (er läuft durch und beendet sich)     |
| `--rm`     | Löscht den Container danach wieder                                            |

Compose wartet dank `depends_on: condition: service_healthy`, bis die Datenbank bereit ist, installiert die Pakete mit `npm install` und startet `node seed.js`. Ausgabe:

```
✅ Verbunden mit postgres://app:****@db:5432/shop
✅ Tabellen neu angelegt
✅ Daten eingefügt

📊 Inhalt der Datenbank:
   kategorien         4 Zeilen
   produkte           12 Zeilen
   kunden             10 Zeilen
   bestellungen       12 Zeilen
   bestellpositionen  22 Zeilen
```

Im Container lautet die Adresse der Datenbank `db` (Compose-Netzwerk), deshalb ist in der `compose.yaml` `DATABASE_URL` mit `@db:5432` gesetzt.

### Schritt 2 (Variante B): Seed-Skript mit lokalem Node.js

Hast du Node.js in der WSL installiert (`node --version`), geht es auch ohne Container:

```bash
cd seed
npm install
npm run seed
cd ..
```

Jetzt läuft das Skript **außerhalb** von Docker. Es nutzt die Standard-URL mit `localhost:5432` – das funktioniert, weil die `compose.yaml` den Port `5432` nach außen freigibt.

### Schritt 3: Ergebnis prüfen

```bash
docker compose exec db psql -U app -d shop
```

```
\dt
\d kunden
\d bestellpositionen
SELECT * FROM kunden;
```

Schau dir bei `\d bestellpositionen` die Abschnitte **Indexes** und **Foreign-key constraints** an: Dort stehen der zusammengesetzte Primärschlüssel und die beiden Fremdschlüssel mit ihrem `ON DELETE`-Verhalten.

> **Tipp – der Reset-Knopf:** Das Seed-Skript löscht vor dem Befüllen **alle** Shop-Tabellen und legt sie neu an. Egal was du in den nächsten Aufgaben kaputtmachst: `docker compose run --rm seed` (in einem **zweiten** Terminal oder nach `\q`) und alles ist wieder wie am Anfang.

## Aufgabe 5: Daten abfragen mit SELECT

Ab jetzt arbeitest du in psql mit den Shop-Daten. Tippe jede Abfrage ab (nicht kopieren – so lernst du die Syntax!) und schau dir das Ergebnis an. Nach jedem Abschnitt gibt es eine **Mini-Übung** mit Lösung zum Aufklappen.

Ein `SELECT` ist immer gleich aufgebaut. Nicht alle Teile sind Pflicht, aber die **Reihenfolge** ist fest:

```sql
SELECT    spalten            -- 5. welche Spalten?
FROM      tabelle            -- 1. aus welcher Tabelle?
WHERE     bedingung          -- 2. welche Zeilen?
GROUP BY  spalten            -- 3. wie gruppieren?        (Aufgabe 6)
HAVING    bedingung          -- 4. welche Gruppen?        (Aufgabe 6)
ORDER BY  spalten            -- 6. wie sortieren?
LIMIT     anzahl;            -- 7. wie viele?
```

Die Nummern im Kommentar zeigen die Reihenfolge, in der die Datenbank die Teile **intern** abarbeitet. Das erklärt später manche Fehlermeldung.

### Schritt 1: Spalten auswählen

```sql
SELECT * FROM produkte;
SELECT name, preis FROM produkte;
```

Spalten umbenennen mit `AS` und direkt **rechnen**:

```sql
SELECT name,
       preis,
       lagerbestand,
       preis * lagerbestand AS lagerwert
FROM produkte;
```

Texte zusammensetzen mit `||`:

```sql
SELECT vorname || ' ' || nachname AS kunde, email FROM kunden;
```

### Schritt 2: Sortieren mit ORDER BY und begrenzen mit LIMIT

```sql
SELECT name, preis FROM produkte ORDER BY preis;          -- aufsteigend (ASC, Standard)
SELECT name, preis FROM produkte ORDER BY preis DESC;     -- absteigend
SELECT name, preis FROM produkte ORDER BY preis DESC LIMIT 3;
```

Nach mehreren Spalten sortieren:

```sql
SELECT vorname, nachname, stadt FROM kunden ORDER BY stadt, nachname;
```

> **Merke:** Ohne `ORDER BY` ist die Reihenfolge der Zeilen **nicht garantiert**. Dass sie oft nach `id` sortiert aussieht, ist Zufall.

<details>
<summary><b>Mini-Übung:</b> Die drei Kunden, die sich zuletzt registriert haben – mit Datum.</summary>

```sql
SELECT vorname, nachname, registriert_am
FROM kunden
ORDER BY registriert_am DESC
LIMIT 3;
```

Ergebnis: Lena (2026-09-03), Jonas (2026-06-25), Hannah (2026-04-12).

</details>

### Schritt 3: Zeilen filtern mit WHERE

```sql
SELECT vorname, nachname FROM kunden WHERE stadt = 'Berlin';
SELECT name, preis FROM produkte WHERE preis < 20;
SELECT name, lagerbestand FROM produkte WHERE lagerbestand = 0;
```

Die Vergleichsoperatoren:

| Operator         | Bedeutung                           | Beispiel                                    |
| ---------------- | ----------------------------------- | ------------------------------------------- |
| `=`              | gleich (nur **ein** `=`!)           | `stadt = 'Berlin'`                          |
| `<>` oder `!=`   | ungleich                            | `status <> 'storniert'`                     |
| `<`, `>`, `<=`, `>=` | kleiner, größer …               | `preis >= 50`                               |
| `BETWEEN a AND b` | zwischen a und b (**inklusive**)   | `preis BETWEEN 20 AND 50`                   |
| `IN (…)`         | ist einer der Werte                 | `stadt IN ('Berlin', 'Hamburg')`            |
| `LIKE`           | Textmuster (Groß/Klein beachten)    | `name LIKE 'K%'`                            |
| `ILIKE`          | Textmuster (Groß/Klein **egal**, nur PostgreSQL) | `name ILIKE '%kabel%'`         |
| `IS NULL`        | hat keinen Wert                     | `stadt IS NULL`                             |
| `IS NOT NULL`    | hat einen Wert                      | `kategorie_id IS NOT NULL`                  |

Bei `LIKE` steht `%` für **beliebig viele** Zeichen und `_` für **genau ein** Zeichen.

```sql
SELECT name FROM produkte WHERE name LIKE 'K%';            -- beginnt mit K
SELECT name FROM produkte WHERE name ILIKE '%kabel%';      -- enthält "kabel"
SELECT name, preis FROM produkte WHERE preis BETWEEN 20 AND 50;
SELECT vorname, stadt FROM kunden WHERE stadt IN ('Köln', 'München');
SELECT * FROM bestellungen WHERE bestellt_am >= '2026-06-01';
```

Bedingungen verknüpfen mit `AND`, `OR` und `NOT`:

```sql
SELECT name, preis, lagerbestand
FROM produkte
WHERE preis < 50 AND lagerbestand > 10;
```

```sql
SELECT * FROM bestellungen
WHERE (status = 'offen' OR status = 'bezahlt')
  AND bestellt_am >= '2026-09-01';
```

> **Klammern setzen!** `AND` bindet stärker als `OR` (wie Punkt vor Strich). Ohne Klammern bedeutet die letzte Abfrage etwas ganz anderes.

### Schritt 4: Die NULL-Falle

Wer von den Kunden hat keine Stadt angegeben?

```sql
SELECT vorname, stadt FROM kunden WHERE stadt = NULL;
```

**0 Zeilen** – obwohl Greta keine Stadt hat! Denn `NULL = NULL` ist nicht wahr, sondern „unbekannt“. Richtig:

```sql
SELECT vorname, stadt FROM kunden WHERE stadt IS NULL;
```

Und noch eine Falle: Wie viele Kunden wohnen **nicht** in Berlin?

```sql
SELECT vorname, stadt FROM kunden WHERE stadt <> 'Berlin';
```

Das sind 6, nicht 7 – Greta fehlt schon wieder, weil `NULL <> 'Berlin'` ebenfalls „unbekannt“ ist. Wer sie mitzählen will, muss es ausdrücklich sagen: `WHERE stadt <> 'Berlin' OR stadt IS NULL`.

Mit `COALESCE` ersetzt du `NULL` bei der Ausgabe durch einen Ersatzwert:

```sql
SELECT vorname, COALESCE(stadt, '(unbekannt)') AS stadt FROM kunden;
```

### Schritt 5: Doppelte Werte entfernen mit DISTINCT

```sql
SELECT stadt FROM kunden;                       -- 10 Zeilen, viele doppelt
SELECT DISTINCT stadt FROM kunden ORDER BY stadt;   -- jede Stadt einmal
```

<details>
<summary><b>Mini-Übung:</b> Alle Produkte zwischen 5 und 30 Euro, die auf Lager sind, nach Preis sortiert.</summary>

```sql
SELECT name, preis, lagerbestand
FROM produkte
WHERE preis BETWEEN 5 AND 30
  AND lagerbestand > 0
ORDER BY preis;
```

Ergebnis: 5 Zeilen – Kaffeetasse, USB-C Kabel, Funkmaus, SQL für Einsteiger, Docker kompakt. Das Notizbuch kostet nur 4,95 € und fällt raus.

</details>

## Aufgabe 6: Zählen, summieren, gruppieren

### Schritt 1: Aggregatfunktionen

**Aggregatfunktionen** fassen viele Zeilen zu **einem** Wert zusammen:

| Funktion        | Ergebnis                                  |
| --------------- | ----------------------------------------- |
| `COUNT(*)`      | Anzahl Zeilen                             |
| `COUNT(spalte)` | Anzahl Zeilen, in denen `spalte` **nicht** `NULL` ist |
| `SUM(spalte)`   | Summe                                     |
| `AVG(spalte)`   | Durchschnitt                              |
| `MIN(spalte)`   | Kleinster Wert                            |
| `MAX(spalte)`   | Größter Wert                              |

```sql
SELECT COUNT(*) FROM kunden;

SELECT COUNT(*)              AS anzahl,
       MIN(preis)            AS billigstes,
       MAX(preis)            AS teuerstes,
       ROUND(AVG(preis), 2)  AS durchschnitt,
       SUM(lagerbestand)     AS stueck_auf_lager
FROM produkte;
```

Ergebnis: 12 Produkte, 4,95 € bis 249,00 €, Durchschnitt 51,58 €, 495 Stück auf Lager.

Siehst du den Unterschied zwischen den `COUNT`-Varianten?

```sql
SELECT COUNT(*), COUNT(stadt), COUNT(DISTINCT stadt) FROM kunden;
```

`10 | 9 | 4` – 10 Kunden, 9 davon mit Stadt, 4 verschiedene Städte.

### Schritt 2: Gruppieren mit GROUP BY

Wie viele Kunden wohnen in **jeder** Stadt?

```sql
SELECT stadt, COUNT(*) AS anzahl
FROM kunden
GROUP BY stadt
ORDER BY anzahl DESC;
```

```
  stadt  | anzahl
---------+--------
 Berlin  |      3
 Hamburg |      2
 Köln    |      2
 München |      2
         |      1
```

So funktioniert `GROUP BY`:

```
 kunden (vorher)              GROUP BY stadt                Ergebnis
 ┌───────┬─────────┐       ┌─────────┬──────────────┐     ┌─────────┬────────┐
 │ Anna  │ Berlin  │       │ Berlin  │ Anna, David, │     │ Berlin  │   3    │
 │ Ben   │ Hamburg │  ──▶  │         │ Hannah       │ ──▶ │ Hamburg │   2    │
 │ David │ Berlin  │       │ Hamburg │ Ben, Felix   │     │ …       │   …    │
 │ Felix │ Hamburg │       │ …       │ …            │     └─────────┴────────┘
 │ …     │ …       │       └─────────┴──────────────┘       COUNT(*) pro Gruppe
 └───────┴─────────┘        Zeilen in "Stapel" sortieren
```

> **Wichtige Regel:** Jede Spalte im `SELECT` muss entweder im `GROUP BY` stehen **oder** in einer Aggregatfunktion. `SELECT stadt, vorname, COUNT(*) … GROUP BY stadt` ergibt einen Fehler: Welcher der drei Vornamen aus Berlin sollte denn angezeigt werden?

Wie viele Bestellungen gibt es je Status?

```sql
SELECT status, COUNT(*) FROM bestellungen GROUP BY status ORDER BY status;
```

### Schritt 3: Gruppen filtern mit HAVING

`WHERE` filtert **Zeilen vor** dem Gruppieren, `HAVING` filtert **Gruppen nach** dem Gruppieren. Nur Städte mit mindestens zwei Kunden:

```sql
SELECT stadt, COUNT(*) AS anzahl
FROM kunden
GROUP BY stadt
HAVING COUNT(*) >= 2;
```

Beides kombiniert – Städte mit mindestens zwei Kunden, die sich **vor 2026** registriert haben:

```sql
SELECT stadt, COUNT(*) AS anzahl
FROM kunden
WHERE registriert_am < '2026-01-01'   -- erst Zeilen filtern
GROUP BY stadt
HAVING COUNT(*) >= 2;                 -- dann Gruppen filtern
```

Ergebnis: nur Berlin (Anna, David).

<details>
<summary><b>Mini-Übung:</b> Die Anzahl Produkte und der Durchschnittspreis je <code>kategorie_id</code>.</summary>

```sql
SELECT kategorie_id, COUNT(*) AS anzahl, ROUND(AVG(preis), 2) AS durchschnitt
FROM produkte
GROUP BY kategorie_id
ORDER BY kategorie_id;
```

Die Kategorien heißen hier nur `1`, `2`, `3` und eine Zeile ist leer (`NULL`, das Notizbuch). Den **Namen** der Kategorie bekommst du erst mit einem JOIN – nächste Aufgabe.

</details>

## Aufgabe 7: Tabellen verknüpfen mit JOIN

Bisher hast du immer nur **eine** Tabelle abgefragt. Aber in `bestellungen` steht nur `kunde_id = 3` – wer ist das? Mit einem **JOIN** holst du die Daten aus mehreren Tabellen zusammen, und zwar über die Fremdschlüssel.

### Schritt 1: INNER JOIN

```sql
SELECT bestellungen.id,
       bestellungen.bestellt_am,
       kunden.vorname,
       kunden.nachname
FROM bestellungen
JOIN kunden ON bestellungen.kunde_id = kunden.id;
```

`JOIN kunden ON …` heißt: „Hänge an jede Bestellung die Zeile aus `kunden`, bei der die Bedingung passt“ – hier: Fremdschlüssel = Primärschlüssel.

Mit **Aliasen** (Kurznamen) wird das kürzer und lesbarer:

```sql
SELECT b.id, b.bestellt_am, b.status, k.vorname, k.nachname
FROM bestellungen b
JOIN kunden k ON b.kunde_id = k.id
ORDER BY b.bestellt_am;
```

> **Wenn zwei Tabellen dieselbe Spalte haben** (beide haben `id`!), musst du immer angeben, welche du meinst: `b.id` oder `k.id`. Sonst kommt `ERROR: column reference "id" is ambiguous`.

Produkte mit dem Namen ihrer Kategorie:

```sql
SELECT p.name, p.preis, k.name AS kategorie
FROM produkte p
JOIN kategorien k ON p.kategorie_id = k.id
ORDER BY kategorie, p.name;
```

Zähl die Zeilen: Es sind **11**, nicht 12! Das **Notizbuch A5** fehlt. Es hat `kategorie_id = NULL` und findet deshalb keinen Partner. Ein normaler `JOIN` (= `INNER JOIN`) zeigt nur Zeilen, die **auf beiden Seiten** einen Partner haben.

### Schritt 2: LEFT JOIN

Ein `LEFT JOIN` behält **alle** Zeilen der **linken** Tabelle (die nach `FROM`). Fehlt rechts ein Partner, werden die Spalten mit `NULL` aufgefüllt:

```sql
SELECT p.name, k.name AS kategorie
FROM produkte p
LEFT JOIN kategorien k ON p.kategorie_id = k.id
ORDER BY kategorie, p.name;
```

Jetzt sind es 12 Zeilen, und beim Notizbuch ist die Kategorie leer.

```
         INNER JOIN                          LEFT JOIN
   produkte      kategorien           produkte      kategorien
  ┌────────┐    ┌────────┐           ┌────────┐    ┌────────┐
  │        │    │        │           │████████│    │        │
  │     ┌──┼────┼──┐     │           │████┌───┼────┼──┐     │
  │     │██│████│██│     │           │████│███│████│██│     │
  │     └──┼────┼──┘     │           │████└───┼────┼──┘     │
  │        │    │        │           │████████│    │        │
  └────────┘    └────────┘           └────────┘    └────────┘
   nur Paare, die zusammenpassen      alle Produkte + passende Kategorie
                                      (oder NULL, wenn keine passt)
```

Der Trick mit `LEFT JOIN` + `IS NULL` findet Zeilen **ohne** Partner. Welche Kategorie hat **keine** Produkte?

```sql
SELECT k.name
FROM kategorien k
LEFT JOIN produkte p ON p.kategorie_id = k.id
WHERE p.id IS NULL;
```

Ergebnis: **Spielzeug**.

Und welche Kunden haben **noch nie** bestellt?

```sql
SELECT k.vorname, k.nachname
FROM kunden k
LEFT JOIN bestellungen b ON b.kunde_id = k.id
WHERE b.id IS NULL;
```

Ergebnis: **Lena Richter** – eine Kandidatin für einen Gutschein-Newsletter.

> Es gibt auch `RIGHT JOIN` (alle Zeilen der **rechten** Tabelle) und `FULL JOIN` (alle Zeilen beider Seiten). In der Praxis kommst du fast immer mit `JOIN` und `LEFT JOIN` aus – einen `RIGHT JOIN` kann man durch Vertauschen der Tabellen immer als `LEFT JOIN` schreiben.

### Schritt 3: Mehrere Tabellen verbinden (n:m)

Was steckt in Bestellung 1? Dafür brauchst du die Zwischentabelle **und** die Produkte:

```sql
SELECT p.name, bp.menge, bp.einzelpreis, bp.menge * bp.einzelpreis AS summe
FROM bestellpositionen bp
JOIN produkte p ON bp.produkt_id = p.id
WHERE bp.bestellung_id = 1;
```

```
        name        | menge | einzelpreis | summe
--------------------+-------+-------------+-------
 SQL für Einsteiger |     1 |       24.90 | 24.90
 Kaffeetasse        |     2 |        7.50 | 15.00
```

Jetzt alles zusammen – vier Tabellen, eine Rechnung pro Bestellung:

```sql
SELECT b.id                           AS bestellung,
       b.bestellt_am,
       k.vorname || ' ' || k.nachname AS kunde,
       b.status,
       SUM(bp.menge * bp.einzelpreis) AS gesamt
FROM bestellungen b
JOIN kunden k             ON b.kunde_id = k.id
JOIN bestellpositionen bp ON bp.bestellung_id = b.id
GROUP BY b.id, k.vorname, k.nachname
ORDER BY b.bestellt_am;
```

Der Weg durch die Tabellen:

```
 kunden ◀──kunde_id── bestellungen ◀──bestellung_id── bestellpositionen ──produkt_id──▶ produkte
```

### Schritt 4: Echte Fragen beantworten

Damit kannst du schon richtige Geschäftsfragen beantworten. Wie viel **Umsatz** hat jeder Kunde gemacht (stornierte Bestellungen zählen nicht)?

```sql
SELECT k.vorname, k.nachname, SUM(bp.menge * bp.einzelpreis) AS umsatz
FROM kunden k
JOIN bestellungen b       ON b.kunde_id = k.id
JOIN bestellpositionen bp ON bp.bestellung_id = b.id
WHERE b.status <> 'storniert'
GROUP BY k.id, k.vorname, k.nachname
ORDER BY umsatz DESC;
```

Spitzenreiterin: **Clara Fischer** mit 258,99 €. Ihre stornierte Monitor-Bestellung (249 €) ist nicht mitgezählt.

Welche Produkte verkaufen sich am besten (nach Stückzahl)?

```sql
SELECT p.name, SUM(bp.menge) AS stueck
FROM produkte p
JOIN bestellpositionen bp ON bp.produkt_id = p.id
GROUP BY p.id, p.name
ORDER BY stueck DESC
LIMIT 5;
```

<details>
<summary><b>Mini-Übung:</b> Welche Kunden haben die <b>Kaffeetasse</b> gekauft?</summary>

```sql
SELECT DISTINCT k.vorname, k.nachname
FROM kunden k
JOIN bestellungen b       ON b.kunde_id = k.id
JOIN bestellpositionen bp ON bp.bestellung_id = b.id
JOIN produkte p           ON bp.produkt_id = p.id
WHERE p.name = 'Kaffeetasse'
ORDER BY k.nachname;
```

Ergebnis: Jonas Koch, Anna Schmidt, Emma Wagner. `DISTINCT` verhindert, dass jemand doppelt erscheint, der die Tasse mehrmals bestellt hat.

</details>

<details>
<summary><b>Mini-Übung:</b> Anzahl Produkte je Kategorie – mit Namen, und auch Kategorien mit 0 Produkten.</summary>

```sql
SELECT k.name, COUNT(p.id) AS anzahl
FROM kategorien k
LEFT JOIN produkte p ON p.kategorie_id = k.id
GROUP BY k.id, k.name
ORDER BY anzahl DESC;
```

Ergebnis: Elektronik 5, Bücher 3, Haushalt 3, Spielzeug 0. Wichtig ist `COUNT(p.id)` statt `COUNT(*)`: `COUNT(*)` würde bei Spielzeug die eine Zeile mit `NULL`-Werten mitzählen und `1` anzeigen.

</details>

## Aufgabe 8: Daten ändern und die Schlüssel auf die Probe stellen

Jetzt siehst du, wofür das ganze Tabellendesign gut ist: Die Datenbank **schützt** deine Daten. Keine Sorge, du kannst danach mit dem Seed-Skript alles zurücksetzen.

### Schritt 1: Neue Daten einfügen

Lege dich selbst als Kunde an. `RETURNING` zeigt dir direkt die neue ID:

```sql
INSERT INTO kunden (vorname, nachname, email, stadt)
VALUES ('Max', 'Mustermann', 'max@example.com', 'Hamburg')
RETURNING id, registriert_am;
```

`registriert_am` hat automatisch das heutige Datum bekommen (`DEFAULT CURRENT_DATE`).

### Schritt 2: Die Constraints testen

Führe die folgenden Befehle **einzeln** aus und lies jede Fehlermeldung:

**UNIQUE** – dieselbe E-Mail nochmal:

```sql
INSERT INTO kunden (vorname, nachname, email) VALUES ('Anna', 'Kopie', 'anna.schmidt@example.com');
```

```
ERROR:  duplicate key value violates unique constraint "kunden_email_key"
DETAIL:  Key (email)=(anna.schmidt@example.com) already exists.
```

**CHECK** – negativer Preis und ein Status, den es nicht gibt:

```sql
INSERT INTO produkte (name, preis) VALUES ('Geschenkt', -5);
INSERT INTO bestellungen (kunde_id, status) VALUES (1, 'verloren');
```

**FOREIGN KEY** – Bestellung für einen Kunden, den es nicht gibt:

```sql
INSERT INTO bestellungen (kunde_id) VALUES (999);
```

```
ERROR:  insert or update on table "bestellungen" violates foreign key constraint "bestellungen_kunde_id_fkey"
DETAIL:  Key (kunde_id)=(999) is not present in table "kunden".
```

### Schritt 3: Löschen und ON DELETE

**RESTRICT** – Anna hat Bestellungen, also darf sie nicht gelöscht werden:

```sql
DELETE FROM kunden WHERE id = 1;
```

```
ERROR:  update or delete on table "kunden" violates foreign key constraint "bestellungen_kunde_id_fkey" on table "bestellungen"
DETAIL:  Key (id)=(1) is still referenced from table "bestellungen".
```

Lena (ohne Bestellungen) darf dagegen gelöscht werden:

```sql
DELETE FROM kunden WHERE email = 'lena.richter@example.com';
```

**CASCADE** – Bestellung 12 hat drei Positionen. Was passiert beim Löschen der Bestellung?

```sql
SELECT COUNT(*) FROM bestellpositionen;                -- 22
DELETE FROM bestellungen WHERE id = 12;
SELECT COUNT(*) FROM bestellpositionen;                -- 19
```

Die drei Positionen wurden **automatisch mitgelöscht**.

**SET NULL** – Was passiert mit den Produkten, wenn die Kategorie „Haushalt“ verschwindet?

```sql
DELETE FROM kategorien WHERE name = 'Haushalt';
SELECT name, kategorie_id FROM produkte WHERE kategorie_id IS NULL;
```

Kaffeetasse, Wasserkocher und Schreibtischlampe existieren weiter, aber ohne Kategorie.

### Schritt 4: Transaktionen – alles oder nichts

Stell dir vor, Kunde Ben bestellt 2 Funkmäuse. Dafür sind **mehrere** Schritte nötig: Bestellung anlegen, Position anlegen, Lagerbestand verringern. Fällt nach Schritt 2 der Strom aus, ist die Bestellung da, aber der Lagerbestand falsch. Deshalb bündelt man solche Schritte in einer **Transaktion**:

```sql
BEGIN;

INSERT INTO bestellungen (kunde_id, status) VALUES (2, 'bezahlt') RETURNING id;
```

Merk dir die angezeigte `id` (z. B. `13`) und setze sie unten ein:

```sql
INSERT INTO bestellpositionen (bestellung_id, produkt_id, menge, einzelpreis)
VALUES (13, 5, 2, 19.99);

UPDATE produkte SET lagerbestand = lagerbestand - 2 WHERE id = 5;

SELECT name, lagerbestand FROM produkte WHERE id = 5;
```

Bis jetzt ist nichts endgültig gespeichert. Öffne ein **zweites Terminal**, verbinde dich ebenfalls mit psql und frage dort den Lagerbestand ab: Er steht noch auf dem **alten** Wert 45! Andere sehen deine Änderungen erst nach dem `COMMIT`.

Jetzt entscheidest du im ersten Terminal:

```sql
ROLLBACK;   -- alles verwerfen
```

oder

```sql
COMMIT;     -- alles speichern
```

Probiere zuerst `ROLLBACK` und prüfe, dass Bestellung, Position und Lagerbestand wieder wie vorher sind. Dann wiederhole alles mit `COMMIT`.

Was passiert, wenn **mitten** in einer Transaktion ein Fehler auftritt?

```sql
BEGIN;
UPDATE produkte SET lagerbestand = lagerbestand - 1 WHERE id = 4;
UPDATE produkte SET lagerbestand = lagerbestand - 1 WHERE id = 10;   -- Wasserkocher: Bestand 0!
```

Der zweite Befehl verletzt `CHECK (lagerbestand >= 0)`. Ab jetzt lehnt PostgreSQL **jeden** weiteren Befehl ab (`current transaction is aborted`), bis du `ROLLBACK;` eingibst. Auch die **erste** Änderung wird damit verworfen. Genau so verkauft ein Shop keinen Wasserkocher, den er nicht hat.

```sql
ROLLBACK;
```

> **Ohne `BEGIN`** ist in psql jeder einzelne Befehl seine eigene kleine Transaktion und wird sofort gespeichert (**Autocommit**).

### Schritt 5: Zurücksetzen

Verlasse psql (`\q`) und setze die Datenbank zurück:

```bash
docker compose run --rm seed
```

## Aufgabe 9: Eine eigene Tabelle entwerfen

Jetzt bist du dran. Der Shop soll **Produktbewertungen** bekommen:

- Ein Kunde kann ein Produkt mit **1 bis 5 Sternen** bewerten und optional einen **Text** schreiben.
- Jeder Kunde darf jedes Produkt nur **einmal** bewerten.
- Das **Datum** der Bewertung soll automatisch gespeichert werden.
- Wird ein Kunde gelöscht, sollen seine Bewertungen **mitgelöscht** werden.
- Ein Produkt mit Bewertungen soll **nicht** gelöscht werden können.

Gehe die Schritte aus [Schritt für Schritt zum eigenen Tabellendesign](#schritt-für-schritt-zum-eigenen-tabellendesign) durch:

1. Welche **Beziehung** besteht zwischen Kunden und Produkten über die Bewertungen?
2. Welche **Spalten** und **Datentypen** brauchst du?
3. Was ist der **Primärschlüssel**? Wie stellst du sicher, dass niemand doppelt bewertet?
4. Welche **Constraints** und welches **`ON DELETE`** brauchst du?

Schreibe das `CREATE TABLE`, führe es aus und teste es: eine gültige Bewertung, eine mit 6 Sternen, eine doppelte Bewertung, eine für ein Produkt, das es nicht gibt.

<details>
<summary><b>Musterlösung</b> (erst selbst probieren!)</summary>

Es ist eine **n:m-Beziehung** (ein Kunde bewertet viele Produkte, ein Produkt wird von vielen Kunden bewertet). Die Tabelle `bewertungen` ist also eine **Zwischentabelle mit eigenen Daten** – genau wie `bestellpositionen`.

```sql
CREATE TABLE bewertungen (
    id           INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    kunde_id     INTEGER  NOT NULL REFERENCES kunden (id)   ON DELETE CASCADE,
    produkt_id   INTEGER  NOT NULL REFERENCES produkte (id) ON DELETE RESTRICT,
    sterne       SMALLINT NOT NULL CHECK (sterne BETWEEN 1 AND 5),
    text         TEXT,
    erstellt_am  TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (kunde_id, produkt_id)          -- jeder Kunde bewertet jedes Produkt nur einmal
);
```

Hier wurde eine eigene `id` als Primärschlüssel gewählt und die Eindeutigkeit über `UNIQUE (kunde_id, produkt_id)` gesichert. Genauso richtig wäre – wie bei `bestellpositionen` – ein zusammengesetzter Primärschlüssel `PRIMARY KEY (kunde_id, produkt_id)`. Die eigene `id` ist praktisch, wenn man später auf eine Bewertung verweisen möchte (z. B. „Bewertung Nr. 17 hilfreich finden“).

Testen:

```sql
INSERT INTO bewertungen (kunde_id, produkt_id, sterne, text) VALUES (1, 1, 5, 'Super Buch!');   -- ok
INSERT INTO bewertungen (kunde_id, produkt_id, sterne) VALUES (2, 1, 6);                         -- CHECK
INSERT INTO bewertungen (kunde_id, produkt_id, sterne) VALUES (1, 1, 3);                         -- UNIQUE
INSERT INTO bewertungen (kunde_id, produkt_id, sterne) VALUES (1, 999, 4);                       -- FOREIGN KEY
```

Durchschnittliche Bewertung je Produkt:

```sql
SELECT p.name, ROUND(AVG(b.sterne), 1) AS sterne, COUNT(b.id) AS anzahl
FROM produkte p
LEFT JOIN bewertungen b ON b.produkt_id = p.id
GROUP BY p.id, p.name
ORDER BY sterne DESC NULLS LAST;
```

**Hinweis:** Beim nächsten `docker compose run --rm seed` wird die Tabelle `bewertungen` wieder gelöscht (siehe erste Zeilen von `sql/schema.sql`). Wie du sie dauerhaft ins Schema und ins Seed-Skript aufnimmst, übst du in [`UEBUNGEN.md`](./UEBUNGEN.md), Teil F.

</details>

## Bonusaufgabe: Indizes – warum manche Abfragen schnell sind

Mit 12 Bestellungen ist jede Abfrage blitzschnell. Interessant wird es bei vielen Daten. Das Seed-Skript kann zusätzlich Zufallsbestellungen erzeugen:

```bash
docker compose run --rm seed --zufall 5000
```

Jetzt hast du gut 5000 Bestellungen und über 12 000 Bestellpositionen. Verbinde dich mit psql und frage mit **`EXPLAIN ANALYZE`**, **wie** die Datenbank eine Abfrage ausführt:

```sql
EXPLAIN ANALYZE SELECT * FROM bestellungen WHERE bestellt_am = '2026-03-11';
```

```
 Seq Scan on bestellungen  (cost=0.00..65.20 rows=13 width=70) (actual time=0.011..0.324 rows=12 loops=1)
   Filter: (bestellt_am = '2026-03-11'::date)
   Rows Removed by Filter: 5000
```

**Seq Scan** (_sequential scan_) heißt: Die Datenbank liest **jede einzelne Zeile** und wirft 5000 davon weg. Lege einen **Index** an:

```sql
CREATE INDEX idx_bestellungen_datum ON bestellungen (bestellt_am);
EXPLAIN ANALYZE SELECT * FROM bestellungen WHERE bestellt_am = '2026-03-11';
```

```
 Bitmap Heap Scan on bestellungen  (cost=4.48..36.29 rows=25 width=70) (actual time=0.023..0.028 rows=12 loops=1)
   ->  Bitmap Index Scan on idx_bestellungen_datum  ...
```

Jetzt springt die Datenbank über den Index **direkt** zu den passenden Zeilen. Bei 5000 Zeilen ist das ein paar Zehntel Millisekunden schneller, bei 50 Millionen Zeilen der Unterschied zwischen „sofort“ und „Timeout“.

> **Vergleich:** Ein Index ist wie das **Stichwortverzeichnis** am Ende eines Buchs. Ohne Verzeichnis musst du das ganze Buch durchblättern, um „Fremdschlüssel“ zu finden. Mit Verzeichnis schlägst du direkt Seite 42 auf.

Warum dann nicht einfach **jede** Spalte indizieren? Jeder Index muss bei **jedem** `INSERT`, `UPDATE` und `DELETE` mit aktualisiert werden und braucht Speicherplatz. Indizes lohnen sich für Spalten, nach denen oft **gesucht, gefiltert, sortiert oder gejoint** wird.

| Bekommt automatisch einen Index        | Bekommt **keinen** automatischen Index            |
| -------------------------------------- | ------------------------------------------------- |
| `PRIMARY KEY`                          | Fremdschlüssel (`REFERENCES`) – in PostgreSQL!    |
| `UNIQUE`                               | Normale Spalten                                   |

Deshalb legt `schema.sql` am Ende Indizes auf die Fremdschlüssel an. Mit `\di` siehst du alle Indizes.

Zum Schluss wieder auf die kleinen Beispieldaten zurücksetzen (das entfernt auch deinen Index):

```bash
docker compose run --rm seed
```

## Übungen

Weitere Übungen von leicht bis knifflig – mit Lösungen und erwarteten Ergebnissen – findest du in [`UEBUNGEN.md`](./UEBUNGEN.md).

## Befehlsübersicht

### Docker / psql

| Befehl                                          | Wirkung                                           |
| ----------------------------------------------- | ------------------------------------------------- |
| `docker compose up -d`                          | Datenbank und Adminer starten                     |
| `docker compose ps`                             | Status anzeigen (auf `healthy` warten)            |
| `docker compose run --rm seed`                  | Schema neu anlegen und Beispieldaten einfügen     |
| `docker compose run --rm seed --zufall 5000`    | … plus 5000 Zufallsbestellungen                   |
| `docker compose exec db psql -U app -d shop`    | Mit psql verbinden                                |
| `docker compose logs db`                        | Logs der Datenbank                                |
| `docker compose down`                           | Container stoppen und löschen (Daten bleiben)     |
| `docker compose down -v`                        | … **und** das Volume mit allen Daten löschen      |

### SQL

| Befehl                                                    | Wirkung                                    |
| --------------------------------------------------------- | ------------------------------------------ |
| `CREATE TABLE t (spalte TYP regeln, …);`                  | Tabelle anlegen                            |
| `ALTER TABLE t ADD COLUMN spalte TYP;`                    | Spalte hinzufügen                          |
| `DROP TABLE t;`                                           | Tabelle löschen                            |
| `INSERT INTO t (a, b) VALUES (1, 'x') RETURNING id;`      | Zeile einfügen, neue ID zurückgeben        |
| `SELECT a, b FROM t WHERE … ORDER BY … LIMIT n;`          | Daten lesen                                |
| `SELECT a, COUNT(*) FROM t GROUP BY a HAVING COUNT(*) > 1;` | Gruppieren und Gruppen filtern           |
| `SELECT … FROM a JOIN b ON a.b_id = b.id;`                | Nur Zeilen mit Partner                     |
| `SELECT … FROM a LEFT JOIN b ON a.b_id = b.id;`           | Alle Zeilen aus `a`, Partner oder `NULL`   |
| `UPDATE t SET a = 1 WHERE …;`                             | Zeilen ändern (**WHERE nicht vergessen!**) |
| `DELETE FROM t WHERE …;`                                  | Zeilen löschen (**WHERE nicht vergessen!**) |
| `BEGIN;` … `COMMIT;` / `ROLLBACK;`                        | Transaktion                                |
| `CREATE INDEX name ON t (spalte);`                        | Index anlegen                              |
| `EXPLAIN ANALYZE SELECT …;`                               | Ausführungsplan anzeigen                   |

## Aufräumen

Container stoppen, Daten behalten (beim nächsten `docker compose up -d` ist alles wieder da):

```bash
docker compose down
```

Alles inklusive der Datenbank-Daten löschen:

```bash
docker compose down -v
```

Die heruntergeladenen Images (optional):

```bash
docker image rm postgres:17-alpine adminer node:24-alpine
```

## Fehlerbehebung

| Fehlermeldung / Problem                                              | Mögliche Ursache und Lösung                                                                                                         |
| -------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| psql zeigt `shop-#` und reagiert nicht                               | Das **Semikolon** fehlt → `;` eintippen und Enter. Abbrechen mit `Strg + C`                                                         |
| psql zeigt `shop'#` oder `shop(#`                                    | Ein **Anführungszeichen** oder eine **Klammer** ist nicht geschlossen → `Strg + C` und neu tippen                                   |
| `ERROR: syntax error at or near "…"`                                 | Tippfehler, fehlendes Komma zwischen Spalten oder Komma **nach** der letzten Spalte. Der Fehler steht meist **direkt vor** der genannten Stelle |
| `ERROR: column "Berlin" does not exist`                              | Text in **doppelten** statt einfachen Anführungszeichen → `'Berlin'`                                                                |
| `ERROR: relation "kunden" does not exist`                            | Seed-Skript noch nicht gelaufen (`docker compose run --rm seed`) oder mit falscher Datenbank verbunden (`\conninfo`)                 |
| `ERROR: column reference "id" is ambiguous`                          | Beim JOIN haben beide Tabellen eine Spalte `id` → mit Tabellenname oder Alias angeben: `k.id`                                       |
| `ERROR: column "…" must appear in the GROUP BY clause …`             | Spalte im `SELECT` steht weder im `GROUP BY` noch in einer Aggregatfunktion → Aufgabe 6, Schritt 2                                 |
| `ERROR: current transaction is aborted …`                            | In einer Transaktion ist ein Fehler passiert → `ROLLBACK;` eingeben                                                                 |
| Abfrage mit `= NULL` liefert keine Zeilen                            | `NULL` immer mit `IS NULL` / `IS NOT NULL` prüfen                                                                                   |
| JOIN liefert **mehr** Zeilen als erwartet                            | `ON`-Bedingung fehlt oder ist falsch (z. B. `b.id = k.id` statt `b.kunde_id = k.id`) → jede Zeile wird mit jeder kombiniert         |
| JOIN liefert **weniger** Zeilen als erwartet                         | `JOIN` statt `LEFT JOIN` – Zeilen ohne Partner fallen weg                                                                           |
| `Bind for 0.0.0.0:5432 failed: port is already allocated`            | Ein anderer Container (z. B. aus Kapitel 06) oder ein lokal installiertes PostgreSQL nutzt Port 5432 → stoppen, oder in `compose.yaml` z. B. `"5433:5432"` eintragen (dann Variante B mit `DATABASE_URL=postgres://app:geheim123@localhost:5433/shop npm run seed`) |
| Seed-Skript: `❌ Keine Verbindung zur Datenbank`                      | Container läuft nicht (`docker compose ps`) oder bei Variante B falscher Port                                                       |
| Seed-Skript: `password authentication failed for user "app"`        | Das Volume stammt von einem früheren Start mit anderem Passwort. Benutzer/Passwort werden nur beim **allerersten** Start gesetzt → `docker compose down -v`, dann `docker compose up -d` |
| Seed-Skript: `Cannot find module 'pg'` (Variante B)                  | `npm install` im Ordner `seed/` vergessen                                                                                           |
| Adminer: `Unable to connect to PostgreSQL server`                    | Als Server `db` eintragen, nicht `localhost`                                                                                        |
| Ergebnis rutscht aus dem Bildschirm / ist unlesbar                   | `\x` für die erweiterte Anzeige; mit `q` die Seitenansicht verlassen                                                                |

## Kontrollfragen

- Was ist der Unterschied zwischen einer **Datenbank** und einem **DBMS**?
- Nenne drei Gründe, warum man Daten in einer Datenbank statt in einer Excel- oder JSON-Datei speichert.
- Was bedeutet „SQL ist **deklarativ**“?
- Ordne zu: `CREATE TABLE`, `SELECT`, `UPDATE`, `COMMIT` – DDL, DML, DQL oder TCL?
- Warum speichert man Geldbeträge als `NUMERIC` und nicht als `REAL`?
- Was ist `NULL`, und warum findet `WHERE stadt = NULL` nichts?
- Welche drei Eigenschaften muss ein **Primärschlüssel** haben?
- Was ist der Unterschied zwischen einem **natürlichen** und einem **künstlichen** Schlüssel? Warum ist die E-Mail-Adresse kein guter Primärschlüssel?
- Was ist ein **Fremdschlüssel**, und was bedeutet **referenzielle Integrität**?
- Erkläre `ON DELETE RESTRICT`, `CASCADE` und `SET NULL` jeweils an einem Beispiel aus dem Shop.
- Auf welcher Seite einer **1:n**-Beziehung steht der Fremdschlüssel?
- Wie bildet man eine **n:m**-Beziehung ab? Nenne das Beispiel aus dem Shop.
- Warum speichert `bestellpositionen` den `einzelpreis`, obwohl der Preis schon in `produkte` steht?
- Was ist **Normalisierung**? Nenne zwei Probleme einer Tabelle, in der alles doppelt steht.
- Was ist der Unterschied zwischen `WHERE` und `HAVING`?
- Was ist der Unterschied zwischen `JOIN` und `LEFT JOIN`? Wie findest du mit `LEFT JOIN` Kunden ohne Bestellung?
- Warum ist ein `UPDATE` oder `DELETE` ohne `WHERE` so gefährlich?
- Was ist eine **Transaktion**, und wozu dienen `COMMIT` und `ROLLBACK`?
- Was ist ein **Seed-Skript**, und wofür braucht man es?
- Warum verwendet das Seed-Skript `$1`-Platzhalter statt Template-Strings? Was ist **SQL-Injection**?
- In welcher Reihenfolge muss das Seed-Skript die Tabellen befüllen, und warum?
- Was ist ein **Index**, und warum legt man nicht auf jede Spalte einen an?
