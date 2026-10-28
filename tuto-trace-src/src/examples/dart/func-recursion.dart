int factorielle(int n) {
  if (n <= 1) {
    return 1;
  }
  return n * factorielle(n - 1);
}

void main() {
  print(factorielle(4));
}
