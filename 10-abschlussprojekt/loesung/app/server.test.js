// Unit-Tests mit dem eingebauten Test-Runner von Node.js ("node --test")
const { test, before, after } = require("node:test");
const assert = require("node:assert");
const http = require("node:http");
const { handler } = require("./server");

let server;
let basis;

// Vor allen Tests: Server auf einem zufälligen freien Port starten (Port 0)
before(async () => {
  server = http.createServer(handler);
  await new Promise((resolve) => server.listen(0, resolve));
  basis = `http://localhost:${server.address().port}`;
});

after(() => server.close());

test("Startseite liefert HTML mit Überschrift", async () => {
  const res = await fetch(`${basis}/`);
  assert.strictEqual(res.status, 200);
  const text = await res.text();
  assert.match(text, /<h1>/);
});

test("/health meldet status ok", async () => {
  const res = await fetch(`${basis}/health`);
  assert.strictEqual(res.status, 200);
  const daten = await res.json();
  assert.strictEqual(daten.status, "ok");
});

test("Unbekannte Seite liefert 404", async () => {
  const res = await fetch(`${basis}/gibt-es-nicht`);
  assert.strictEqual(res.status, 404);
});
