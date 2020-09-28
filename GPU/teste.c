
#include<stdio.h>
#include "in.h"


int main(int argc, char** argv)
{
   char*a = readTextFromFile(argv[1])->content;
   char*b = readTextFromFile(argv[2])->content;

   printf("\n%s", a);
   printf("\n%s", b);

   return 0;
}
