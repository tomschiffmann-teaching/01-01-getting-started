-- =====================================================================
-- Schema für den Mini-Webshop
-- Wird vom Seed-Skript ausgeführt (seed/seed.js), kann aber auch
-- direkt in psql geladen werden:  \i /sql/schema.sql
--
-- ACHTUNG: Löscht zuerst alle Shop-Tabellen samt Daten!
-- =====================================================================

-- Aufräumen: in umgekehrter Reihenfolge der Abhängigkeiten.
-- CASCADE entfernt dabei auch Fremdschlüssel, die auf die Tabelle zeigen.
DROP TABLE IF EXISTS bewertungen CASCADE;          -- aus Aufgabe 9 / den Übungen
DROP TABLE IF EXISTS bestellpositionen CASCADE;
DROP TABLE IF EXISTS bestellungen CASCADE;
DROP TABLE IF EXISTS produkte CASCADE;
DROP TABLE IF EXISTS kategorien CASCADE;
DROP TABLE IF EXISTS kunden CASCADE;


-- ---------------------------------------------------------------------
-- kunden: Wer kauft bei uns ein?
-- ---------------------------------------------------------------------
CREATE TABLE kunden (
    id              INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,  -- künstlicher Schlüssel, zählt automatisch hoch
    vorname         VARCHAR(50)  NOT NULL,
    nachname        VARCHAR(50)  NOT NULL,
    email           VARCHAR(255) NOT NULL UNIQUE,                       -- keine E-Mail doppelt
    stadt           VARCHAR(100),                                       -- darf leer (NULL) sein
    registriert_am  DATE         NOT NULL DEFAULT CURRENT_DATE
);


-- ---------------------------------------------------------------------
-- kategorien: z. B. "Bücher", "Elektronik"
-- ---------------------------------------------------------------------
CREATE TABLE kategorien (
    id    INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name  VARCHAR(50) NOT NULL UNIQUE
);


-- ---------------------------------------------------------------------
-- produkte: gehören zu (höchstens) einer Kategorie  ->  1:n
-- ---------------------------------------------------------------------
CREATE TABLE produkte (
    id            INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name          VARCHAR(100)  NOT NULL,
    preis         NUMERIC(10,2) NOT NULL CHECK (preis >= 0),            -- NUMERIC statt FLOAT: exakt, wichtig bei Geld!
    lagerbestand  INTEGER       NOT NULL DEFAULT 0 CHECK (lagerbestand >= 0),
    kategorie_id  INTEGER       REFERENCES kategorien (id)              -- Fremdschlüssel, darf NULL sein
                                ON DELETE SET NULL                      -- Kategorie gelöscht -> Produkt bleibt, ohne Kategorie
);


-- ---------------------------------------------------------------------
-- bestellungen: eine Kundin hat viele Bestellungen  ->  1:n
-- ---------------------------------------------------------------------
CREATE TABLE bestellungen (
    id           INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    kunde_id     INTEGER     NOT NULL REFERENCES kunden (id)            -- jede Bestellung MUSS einen Kunden haben
                             ON DELETE RESTRICT,                        -- Kunde mit Bestellungen kann nicht gelöscht werden
    bestellt_am  DATE        NOT NULL DEFAULT CURRENT_DATE,
    status       VARCHAR(20) NOT NULL DEFAULT 'offen'
                             CHECK (status IN ('offen', 'bezahlt', 'versendet', 'storniert'))
);


-- ---------------------------------------------------------------------
-- bestellpositionen: Zwischentabelle für die n:m-Beziehung
--   eine Bestellung enthält viele Produkte,
--   ein Produkt kommt in vielen Bestellungen vor.
-- ---------------------------------------------------------------------
CREATE TABLE bestellpositionen (
    bestellung_id  INTEGER       NOT NULL REFERENCES bestellungen (id)
                                 ON DELETE CASCADE,                     -- Bestellung gelöscht -> Positionen auch weg
    produkt_id     INTEGER       NOT NULL REFERENCES produkte (id)
                                 ON DELETE RESTRICT,                    -- bestellte Produkte dürfen nicht verschwinden
    menge          INTEGER       NOT NULL CHECK (menge > 0),
    einzelpreis    NUMERIC(10,2) NOT NULL CHECK (einzelpreis >= 0),     -- Preis ZUM ZEITPUNKT der Bestellung
    PRIMARY KEY (bestellung_id, produkt_id)                             -- zusammengesetzter Primärschlüssel
);


-- Indizes auf Fremdschlüssel beschleunigen JOINs.
-- (PostgreSQL legt sie für Fremdschlüssel NICHT automatisch an, für PRIMARY KEY und UNIQUE schon.)
CREATE INDEX idx_produkte_kategorie   ON produkte (kategorie_id);
CREATE INDEX idx_bestellungen_kunde   ON bestellungen (kunde_id);
CREATE INDEX idx_positionen_produkt   ON bestellpositionen (produkt_id);
