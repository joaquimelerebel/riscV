#include <stdio.h>
#include <stdarg.h>

void printk(const char*, ...);
void f1(int);

int f(int x) {
    return -x;
}

void printk(const char* fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    printf(fmt, ap);
    va_end(ap);
}

void f1(int x)
{
    int a = 5;
    extern int f3(int, int);
    a = a + 5 + f3(0, 5);
    return;
}

__attribute((profiled)) int main()
{
    printk("%s\n", "Hello world");
    volatile (*ptr)(void) = &f1+4;
    f1(5);
    (*ptr)();
    return 1;
}

int f3(int x, int y)
{
    return x + f(1);
}