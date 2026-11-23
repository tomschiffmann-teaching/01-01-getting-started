// Die Beispieldaten für den Mini-Webshop.
//
// Wichtig: Hier stehen KEINE IDs! Die vergibt die Datenbank selbst (IDENTITY).
// Beziehungen werden stattdessen über eindeutige Werte beschrieben:
//   - Produkte verweisen auf den NAMEN ihrer Kategorie
//   - Bestellungen verweisen auf die E-MAIL des Kunden und die NAMEN der Produkte
// Das Seed-Skript sucht sich daraus beim Einfügen die passenden IDs zusammen.

const kategorien = ["Bücher", "Elektronik", "Haushalt", "Spielzeug"];

const produkte = [
  { name: "SQL für Einsteiger", preis: 24.9, lagerbestand: 15, kategorie: "Bücher" },
  { name: "Docker kompakt", preis: 29.9, lagerbestand: 8, kategorie: "Bücher" },
  { name: "Kubernetes in Action", preis: 49.9, lagerbestand: 3, kategorie: "Bücher" },
  { name: "USB-C Kabel", preis: 9.99, lagerbestand: 120, kategorie: "Elektronik" },
  { name: "Funkmaus", preis: 19.99, lagerbestand: 45, kategorie: "Elektronik" },
  { name: "Mechanische Tastatur", preis: 89.0, lagerbestand: 12, kategorie: "Elektronik" },
  { name: "27 Zoll Monitor", preis: 249.0, lagerbestand: 5, kategorie: "Elektronik" },
  { name: "Webcam HD", preis: 59.0, lagerbestand: 9, kategorie: "Elektronik" },
  { name: "Kaffeetasse", preis: 7.5, lagerbestand: 60, kategorie: "Haushalt" },
  { name: "Wasserkocher", preis: 34.95, lagerbestand: 0, kategorie: "Haushalt" },
  { name: "Schreibtischlampe", preis: 39.9, lagerbestand: 18, kategorie: "Haushalt" },
  { name: "Notizbuch A5", preis: 4.95, lagerbestand: 200, kategorie: null }, // ohne Kategorie!
];

const kunden = [
  { vorname: "Anna", nachname: "Schmidt", email: "anna.schmidt@example.com", stadt: "Berlin", registriert_am: "2025-03-14" },
  { vorname: "Ben", nachname: "Müller", email: "ben.mueller@example.com", stadt: "Hamburg", registriert_am: "2025-05-02" },
  { vorname: "Clara", nachname: "Fischer", email: "clara.fischer@example.com", stadt: "München", registriert_am: "2025-07-21" },
  { vorname: "David", nachname: "Weber", email: "david.weber@example.com", stadt: "Berlin", registriert_am: "2025-09-09" },
  { vorname: "Emma", nachname: "Wagner", email: "emma.wagner@example.com", stadt: "Köln", registriert_am: "2025-11-30" },
  { vorname: "Felix", nachname: "Becker", email: "felix.becker@example.com", stadt: "Hamburg", registriert_am: "2026-01-18" },
  { vorname: "Greta", nachname: "Hoffmann", email: "greta.hoffmann@example.com", stadt: null, registriert_am: "2026-02-07" },
  { vorname: "Hannah", nachname: "Schulz", email: "hannah.schulz@example.com", stadt: "Berlin", registriert_am: "2026-04-12" },
  { vorname: "Jonas", nachname: "Koch", email: "jonas.koch@example.com", stadt: "München", registriert_am: "2026-06-25" },
  { vorname: "Lena", nachname: "Richter", email: "lena.richter@example.com", stadt: "Köln", registriert_am: "2026-09-03" }, // hat noch nie bestellt
];

const bestellungen = [
  {
    kunde: "anna.schmidt@example.com", bestellt_am: "2026-01-08", status: "versendet",
    positionen: [{ produkt: "SQL für Einsteiger", menge: 1 }, { produkt: "Kaffeetasse", menge: 2 }],
  },
  {
    kunde: "ben.mueller@example.com", bestellt_am: "2026-01-15", status: "versendet",
    positionen: [{ produkt: "Mechanische Tastatur", menge: 1 }, { produkt: "Funkmaus", menge: 1 }],
  },
  {
    kunde: "anna.schmidt@example.com", bestellt_am: "2026-02-03", status: "versendet",
    positionen: [{ produkt: "Docker kompakt", menge: 1 }, { produkt: "Kubernetes in Action", menge: 1 }],
  },
  {
    kunde: "clara.fischer@example.com", bestellt_am: "2026-02-20", status: "storniert",
    positionen: [{ produkt: "27 Zoll Monitor", menge: 1 }],
  },
  {
    kunde: "david.weber@example.com", bestellt_am: "2026-03-11", status: "versendet",
    positionen: [{ produkt: "USB-C Kabel", menge: 3 }, { produkt: "Notizbuch A5", menge: 5 }],
  },
  {
    kunde: "emma.wagner@example.com", bestellt_am: "2026-04-02", status: "versendet",
    positionen: [{ produkt: "Wasserkocher", menge: 1 }, { produkt: "Kaffeetasse", menge: 4 }],
  },
  {
    kunde: "clara.fischer@example.com", bestellt_am: "2026-05-17", status: "versendet",
    positionen: [{ produkt: "27 Zoll Monitor", menge: 1 }, { produkt: "USB-C Kabel", menge: 1 }],
  },
  {
    kunde: "felix.becker@example.com", bestellt_am: "2026-06-30", status: "bezahlt",
    positionen: [{ produkt: "SQL für Einsteiger", menge: 2 }, { produkt: "Notizbuch A5", menge: 2 }],
  },
  {
    kunde: "greta.hoffmann@example.com", bestellt_am: "2026-08-14", status: "versendet",
    positionen: [{ produkt: "Schreibtischlampe", menge: 1 }],
  },
  {
    kunde: "anna.schmidt@example.com", bestellt_am: "2026-09-22", status: "bezahlt",
    positionen: [{ produkt: "Funkmaus", menge: 1 }, { produkt: "USB-C Kabel", menge: 2 }],
  },
  {
    kunde: "hannah.schulz@example.com", bestellt_am: "2026-10-05", status: "offen",
    positionen: [{ produkt: "Docker kompakt", menge: 1 }],
  },
  {
    kunde: "jonas.koch@example.com", bestellt_am: "2026-11-02", status: "offen",
    positionen: [
      { produkt: "Mechanische Tastatur", menge: 1 },
      { produkt: "Kaffeetasse", menge: 1 },
      { produkt: "Notizbuch A5", menge: 3 },
    ],
  },
];

module.exports = { kategorien, produkte, kunden, bestellungen };
