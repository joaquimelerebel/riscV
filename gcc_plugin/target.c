#include <stdio.h>


int f2(int x)
{
    return 2 + x;
}

int f3(int x)
{
    return 3 + x;
}

void f1()
{
    int a = 5;
    a = a + 5 + (f2(1) == f3(0));
    return;
}

__attribute((profiled)) int main()
{
    volatile (*ptr)(void) = &f1+5;
    f1();
    (*ptr)();
    return 1;
}