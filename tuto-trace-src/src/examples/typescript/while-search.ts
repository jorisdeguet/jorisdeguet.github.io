const nombres: number[] = [3, 8, 12, 5];
let i: number = 0;
while (i < nombres.length && nombres[i] !== 12) {
  i = i + 1;
}
console.log("Trouvé à l'indice", i);
