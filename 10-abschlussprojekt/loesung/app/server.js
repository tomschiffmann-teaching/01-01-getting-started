// Eine sehr einfache Web-App – ganz ohne zusätzliche Pakete (nur Node.js-Bordmittel)
const http = require("node:http");
const os = require("node:os");

// Einstellungen kommen aus Umgebungsvariablen (mit Standardwerten für lokal)
const PORT = Number(process.env.PORT) || 3000;
const VERSION = process.env.APP_VERSION || "dev"; // wird beim docker build gesetzt
const PLATTFORM = process.env.PLATTFORM || "lokal"; // wird beim docker run gesetzt

function startseite() {
  return `<!doctype html>
<html lang="de">
  <head>
    <meta charset="UTF-8" />
    <title>Abschlussprojekt</title>
    <style>
      body { font-family: sans-serif; max-width: 40rem; margin: 4rem auto; padding: 0 1rem; }
      td { padding: 0.25rem 1rem 0.25rem 0; }
    </style>
  </head>
  <body>
    <h1>Hallo aus dem Abschlussprojekt! 🚀</h1>
    <p>Gebaut von GitHub Actions, gespeichert in ECR, ausgerollt mit Terraform.</p>
    <table>
      <tr><td>Version (Commit)</td><td><code>${VERSION}</code></td></tr>
      <tr><td>Plattform</td><td><code>${PLATTFORM}</code></td></tr>
      <tr><td>Container (Hostname)</td><td><code>${os.hostname()}</code></td></tr>
    </table>
  </body>
</html>`;
}

// Der "Handler" entscheidet anhand der URL, was zurückgeschickt wird
function handler(req, res) {
  if (req.url === "/") {
    res.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });
    res.end(startseite());
    return;
  }

  // Für Health Checks (Pipeline, Docker, AWS): kurze, maschinenlesbare Antwort
  if (req.url === "/health") {
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ status: "ok", version: VERSION }));
    return;
  }

  res.writeHead(404, { "Content-Type": "text/plain; charset=utf-8" });
  res.end("Nicht gefunden");
}

module.exports = { handler };

// Nur starten, wenn die Datei direkt ausgeführt wird (nicht in den Tests)
if (require.main === module) {
  const server = http.createServer(handler);
  server.listen(PORT, () => {
    console.log(`Web-App läuft auf Port ${PORT} (Version ${VERSION}, Plattform ${PLATTFORM})`);
  });

  // "docker stop" schickt SIGTERM – sauber beenden statt 10 Sekunden zu warten
  process.on("SIGTERM", () => server.close(() => process.exit(0)));
}
