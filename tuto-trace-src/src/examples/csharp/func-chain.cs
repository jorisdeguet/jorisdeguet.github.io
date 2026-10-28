int Doubler(int x)
{
    return x * 2;
}

int Quadruple(int x)
{
    int d = Doubler(x);
    return Doubler(d);
}

Console.WriteLine(Quadruple(5));
