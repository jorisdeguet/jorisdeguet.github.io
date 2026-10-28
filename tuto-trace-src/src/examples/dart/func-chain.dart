int doubler(int x) {
  return x * 2;
}

int quadruple(int x) {
  int d = doubler(x);
  return doubler(d);
}

void main() {
  print(quadruple(5));
}
