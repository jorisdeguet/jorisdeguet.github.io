notes = [70, 85]
notes.append(90)
notes[0] = 75
total = 0
for n in notes:
    total = total + n
print(total / len(notes))
