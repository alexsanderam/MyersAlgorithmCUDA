#ifndef IN_H
#define IN_H

#include <stdlib.h>
#include <stdio.h>
#include <sys/stat.h>

typedef struct
{
	char* content;
	int len;
} string;


extern string* readTextFromFile(char*);
off_t fsize(const char *);

#endif
