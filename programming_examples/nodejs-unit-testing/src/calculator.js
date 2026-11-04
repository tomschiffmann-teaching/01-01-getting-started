// Einfache, "reine" Funktionen – ideal zum Einstieg ins Unit Testing

export function add(a, b) {
  console.log("add() aufgerufen mit:", a, b);
  return a + b;
}

export function subtract(a, b) {
  return a - b;
}

export function divide(a, b) {
  if (b === 0) {
    throw new Error("Division durch 0 ist nicht erlaubt");
  }
  return a / b;
}

export function isEven(n) {
  return n % 2 === 0;
}
