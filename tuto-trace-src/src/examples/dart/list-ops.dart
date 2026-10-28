void main() {
  List<int> notes = [70, 85];
  notes.add(90);
  notes[0] = 75;
  int total = 0;
  for (int n in notes) {
    total = total + n;
  }
  print(total / notes.length);
}
