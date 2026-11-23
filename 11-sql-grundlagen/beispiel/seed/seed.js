// Seed-Skript für den Mini-Webshop
//
// Was passiert hier?
//   1. Verbindung zur Datenbank aufbauen
//   2. Das Schema aus ../sql/schema.sql ausführen (Tabellen löschen und neu anlegen)
//   3. Die Beispieldaten aus daten.js einfügen – alles in EINER Transaktion
//   4. Optional: viele zufällige Bestellungen erzeugen (node seed.js --zufall 5000)
//
// Aufruf:
//   docker compose run --rm seed          (im Ordner beispiel/, ohne lokales Node.js)
//   npm install && npm run seed           (im Ordner beispiel/seed/, mit lokalem Node.js)

const fs = require("node:fs");
const path = require("node:path");
const { Client } = require("pg");
const daten = require("./daten");

// Die Verbindungsdaten kommen aus einer Umgebungsvariable – mit Standardwert für lokal.
// Aufbau: postgres://<benutzer>:<passwort>@<host>:<port>/<datenbank>
const DATABASE_URL = process.env.DATABASE_URL || "postgres://app:geheim123@localhost:5432/shop";

// "--zufall 5000" aus den Kommandozeilen-Argumenten lesen
function anzahlZufallsBestellungen() {
  const index = process.argv.indexOf("--zufall");
  if (index === -1) return 0;
  return Number(process.argv[index + 1]) || 1000;
}

async function main() {
  const client = new Client({ connectionString: DATABASE_URL });

  try {
    await client.connect();
  } catch (fehler) {
    console.error("❌ Keine Verbindung zur Datenbank:", fehler.message);
    console.error("   Läuft der Container? -> docker compose ps");
    process.exit(1);
  }
  console.log("✅ Verbunden mit", DATABASE_URL.replace(/:[^:@]+@/, ":****@")); // Passwort nicht ausgeben

  try {
    // ---------------------------------------------------------------
    // Schritt 1: Schema anlegen
    // ---------------------------------------------------------------
    const schemaDatei = path.join(__dirname, "..", "sql", "schema.sql");
    const schema = fs.readFileSync(schemaDatei, "utf8");
    await client.query(schema);
    console.log("✅ Tabellen neu angelegt");

    // ---------------------------------------------------------------
    // Schritt 2: Daten einfügen – in einer Transaktion.
    // Geht unterwegs etwas schief, wird mit ROLLBACK ALLES rückgängig gemacht.
    // Es gibt also nie eine "halb befüllte" Datenbank.
    // ---------------------------------------------------------------
    await client.query("BEGIN");

    // Kategorien: Name -> ID merken, damit die Produkte darauf verweisen können
    const kategorieIds = {};
    for (const name of daten.kategorien) {
      // $1 ist ein PLATZHALTER. Der Wert wird getrennt von der SQL-Anweisung geschickt.
      // Niemals Werte per Template-String in SQL einbauen -> Gefahr von SQL-Injection!
      const ergebnis = await client.query(
        "INSERT INTO kategorien (name) VALUES ($1) RETURNING id",
        [name]
      );
      kategorieIds[name] = ergebnis.rows[0].id; // RETURNING liefert die neue ID zurück
    }

    // Produkte: Kategorie-Name in Kategorie-ID übersetzen (Fremdschlüssel!)
    const produkte = {}; // Name -> { id, preis }
    for (const p of daten.produkte) {
      const kategorieId = p.kategorie ? kategorieIds[p.kategorie] : null;
      const ergebnis = await client.query(
        `INSERT INTO produkte (name, preis, lagerbestand, kategorie_id)
         VALUES ($1, $2, $3, $4)
         RETURNING id`,
        [p.name, p.preis, p.lagerbestand, kategorieId]
      );
      produkte[p.name] = { id: ergebnis.rows[0].id, preis: p.preis };
    }

    // Kunden: E-Mail -> ID merken
    const kundenIds = {};
    for (const k of daten.kunden) {
      const ergebnis = await client.query(
        `INSERT INTO kunden (vorname, nachname, email, stadt, registriert_am)
         VALUES ($1, $2, $3, $4, $5)
         RETURNING id`,
        [k.vorname, k.nachname, k.email, k.stadt, k.registriert_am]
      );
      kundenIds[k.email] = ergebnis.rows[0].id;
    }

    // Bestellungen und ihre Positionen
    for (const b of daten.bestellungen) {
      await bestellungAnlegen(client, kundenIds[b.kunde], b.bestellt_am, b.status, b.positionen.map((pos) => ({
        produkt: produkte[pos.produkt],
        menge: pos.menge,
      })));
    }

    // ---------------------------------------------------------------
    // Schritt 3 (optional): viele Zufallsbestellungen für Performance-Tests
    // ---------------------------------------------------------------
    const anzahl = anzahlZufallsBestellungen();
    if (anzahl > 0) {
      console.log(`⏳ Erzeuge ${anzahl} zufällige Bestellungen ...`);
      const alleKunden = Object.values(kundenIds);
      const alleProdukte = Object.values(produkte);
      const stati = ["offen", "bezahlt", "versendet", "versendet", "versendet", "storniert"];

      for (let i = 0; i < anzahl; i++) {
        // Zufällige Auswahl von 1–4 verschiedenen Produkten
        const gemischt = [...alleProdukte].sort(() => Math.random() - 0.5);
        const positionen = gemischt.slice(0, zufallsZahl(1, 4)).map((produkt) => ({
          produkt,
          menge: zufallsZahl(1, 5),
        }));
        await bestellungAnlegen(client, zufallsElement(alleKunden), zufallsDatum(), zufallsElement(stati), positionen);
      }
    }

    await client.query("COMMIT");
    console.log("✅ Daten eingefügt");

    // ---------------------------------------------------------------
    // Schritt 4: Zur Kontrolle zählen, was jetzt in den Tabellen steht
    // ---------------------------------------------------------------
    const tabellen = ["kategorien", "produkte", "kunden", "bestellungen", "bestellpositionen"];
    console.log("\n📊 Inhalt der Datenbank:");
    for (const tabelle of tabellen) {
      // Tabellennamen kann man NICHT als $1-Platzhalter übergeben. Hier ist das ok,
      // weil die Namen fest im Code stehen und nicht von außen kommen.
      const { rows } = await client.query(`SELECT COUNT(*) AS anzahl FROM ${tabelle}`);
      console.log(`   ${tabelle.padEnd(18)} ${rows[0].anzahl} Zeilen`);
    }
  } catch (fehler) {
    await client.query("ROLLBACK");
    console.error("❌ Fehler beim Seeden – alles wurde zurückgerollt:", fehler.message);
    process.exitCode = 1;
  } finally {
    await client.end();
  }
}

// Legt eine Bestellung samt Positionen an.
// Der Einzelpreis wird aus dem aktuellen Produktpreis übernommen und in der Position gespeichert.
async function bestellungAnlegen(client, kundeId, bestelltAm, status, positionen) {
  const ergebnis = await client.query(
    `INSERT INTO bestellungen (kunde_id, bestellt_am, status)
     VALUES ($1, $2, $3)
     RETURNING id`,
    [kundeId, bestelltAm, status]
  );
  const bestellungId = ergebnis.rows[0].id;

  for (const pos of positionen) {
    await client.query(
      `INSERT INTO bestellpositionen (bestellung_id, produkt_id, menge, einzelpreis)
       VALUES ($1, $2, $3, $4)`,
      [bestellungId, pos.produkt.id, pos.menge, pos.produkt.preis]
    );
  }
}

// Kleine Hilfsfunktionen für Zufallsdaten
function zufallsZahl(min, max) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

function zufallsElement(liste) {
  return liste[Math.floor(Math.random() * liste.length)];
}

function zufallsDatum() {
  const start = new Date("2025-01-01").getTime();
  const ende = new Date("2026-11-30").getTime();
  return new Date(start + Math.random() * (ende - start)).toISOString().slice(0, 10); // "JJJJ-MM-TT"
}

main();
