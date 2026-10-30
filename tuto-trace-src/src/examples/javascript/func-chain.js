function doubler(x) {
  return x * 2;
}

function quadruple(x) {
  let d = doubler(x);
  return doubler(d);
}

console.log(quadruple(5));
