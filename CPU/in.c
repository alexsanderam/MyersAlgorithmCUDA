#include "in.h"

extern string* readTextFromFile(char* path)
{
	FILE* file;
	string* str;
	unsigned int i;

	str = (string*) malloc (sizeof(string));
	str->len = fsize(path);
	str->content = (char*) malloc (sizeof(char) * (str->len));
	
	file = fopen(path, "r");

	if(file == NULL)
	{
		fprintf(stderr, "Can't read file: '%s'", path);
		return NULL;
	}

   for(i = 0; !feof(file) && (str->content[i] = fgetc(file)) != '\0'; i++);
   str->len--;
   str->content[str->len] = '\0';

	fclose(file);
	
	return str;
}

off_t fsize(const char *filename)
{
	struct stat st; 

	if (stat(filename, &st) == 0)
		return st.st_size;

	return -1; 
}
