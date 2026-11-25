import fs from "node:fs";
import path from "node:path";

import { Client } from "pg";

const DATABASE_URL =
  process.env.DATABASE_URL ||
  "postgres://postgres:geheim123@localhost:5436/shop";
const client = new Client({ connectionString: DATABASE_URL });

const schemaDatei = "../sql/schema.sql";
const schema = fs.readFileSync(schemaDatei, "utf8");
async function test() {
  await client.query(schema);
}

test();
