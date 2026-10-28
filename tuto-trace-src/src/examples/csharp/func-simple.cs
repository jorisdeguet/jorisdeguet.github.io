class Program
{
    static int Carre(int x)
    {
        int resultat = x * x;
        return resultat;
    }

    static void Main()
    {
        int a = Carre(3);
        Console.WriteLine(a);
    }
}
