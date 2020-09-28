
#include <stdio.h>
#include <unistd.h>
#include "in.h"


int main(int argc, char** argv)
{
	short int c;
	char* a;
	char* b;

	while ((c = getopt (argc, argv, "b:a:")) != -1)
	{
		switch(c)
		{
			case 'b':
	            b = readTextFromFile(optarg)->content;
				break;
			case 'a':
				a = readTextFromFile(optarg)->content;
				break;
		}
	}


	printf("\nb = %s", b);
	printf("\na = %s", a);

   

   return 0;
}
