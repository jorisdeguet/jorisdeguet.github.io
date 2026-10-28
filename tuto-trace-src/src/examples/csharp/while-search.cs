int[] nombres = { 3, 8, 12, 5 };
int i = 0;
while (i < nombres.Length && nombres[i] != 12)
{
    i++;
}
Console.WriteLine("Trouvé à l'indice " + i);
