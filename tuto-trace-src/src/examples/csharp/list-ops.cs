List<int> notes = new List<int> { 70, 85 };
notes.Add(90);
notes[0] = 75;
int total = 0;
foreach (int n in notes)
{
    total = total + n;
}
Console.WriteLine(total / notes.Count);
