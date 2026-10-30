const notes = [70, 85];
notes.push(90);
notes[0] = 75;
let total = 0;
for (const n of notes) {
  total = total + n;
}
console.log(total / notes.length);
