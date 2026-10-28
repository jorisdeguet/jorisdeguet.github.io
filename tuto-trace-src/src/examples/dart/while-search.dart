void main() {
  List<int> nombres = [3, 8, 12, 5];
  int i = 0;
  while (i < nombres.length && nombres[i] != 12) {
    i++;
  }
  print("Trouvé à l'indice $i");
}
