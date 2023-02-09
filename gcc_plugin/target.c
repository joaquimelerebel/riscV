#include <stdio.h>


int f2()
{
    return 7;
}

void f1()
{
    int a = 5;
    a = a + 5 + f2();
    return;
}

__attribute((profiled)) int main()
{
    volatile (*ptr)(void) = &f1+5;
    f1();
    (*ptr)();
    return 1;
}