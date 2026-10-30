function doubler(x: number): number {
  return x * 2;
}

function quadruple(x: number): number {
  let d: number = doubler(x);
  return doubler(d);
}

console.log(quadruple(5));
