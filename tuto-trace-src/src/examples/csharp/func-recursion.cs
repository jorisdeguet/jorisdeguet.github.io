int Factorielle(int n)
{
    if (n <= 1)
    {
        return 1;
    }
    return n * Factorielle(n - 1);
}

Console.WriteLine(Factorielle(4));
