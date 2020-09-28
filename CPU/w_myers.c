#include<stdio.h>
#include<stdlib.h>
#include<math.h>
#include <unistd.h>
#include<string.h>

typedef unsigned char boolean;
typedef unsigned long bitvector_64;


#define WORD_SIZE sizeof(bitvector_64) * 8
#define ALPHABET_LENGHT pow(2, sizeof(char) * 8) /*max length of ASCII*/
#define MASK(z) (bitvector_64) 1 << (z - 1)


/*global variable*/
bitvector_64 HMASK = 0;
bitvector_64 MMASK = 0;

size_t PATTERN_SIZE = 0;

unsigned long myers(char*, char*, unsigned short int);
unsigned long advancedBlock(bitvector_64*, bitvector_64*, bitvector_64*, bitvector_64*, bitvector_64*, bitvector_64*, bitvector_64*);
void* preprocessingPEq(bitvector_64**, char*, size_t, unsigned short int);

void printInfo(bitvector_64, bitvector_64, bitvector_64, bitvector_64, bitvector_64, bitvector_64, bitvector_64, long);
char* strBin(bitvector_64);

int main(int argc, char** argv)
{
	long score;

	char *t, /*text*/
	     *p; /*pattern*/

	unsigned short int alphabet_lenght = ALPHABET_LENGHT; /*The alphabet_lenght, default value is ASCII size*/
	
	short int c;
	
	while ((c = getopt (argc, argv, "s:t:a:")) != -1)
	{
		switch(c)
		{
			case 's':
				p = optarg;
				break;
			case 't':
				t = optarg;
				break;
			case 'a':
				alphabet_lenght = atoi(optarg);
				break;
			case '?':
				if ((optopt == 's') || (optopt == 't') || (optopt == 'a'))
		       			fprintf(stderr, "Option -%c requires an argument.\n", optopt);
				else
		       			fprintf(stderr, "Unknown option `-%c'.\n", optopt);
				return 1;
		}
	}


	score = myers(t, p, alphabet_lenght);

	printf("The edit distance is: %ld\n", score); 

	return 0;
}


unsigned long myers(char *t, char *p, unsigned short int alphabet_lenght)
{
	bitvector_64 *PEq;
	bitvector_64 EQ = 0;

	bitvector_64 VP, /*vertical positive vector*/
		     VN; /*vertical negative vector*/

	bitvector_64 HP, /*horizontal positive vector*/
		     HN, /*horizontal negative vector*/
		     VX, /*vertical vector*/
		     HX; /*vertical vector*/

	size_t m = PATTERN_SIZE = strlen(p); /*length of pattern <= 64*/
	unsigned long n = strlen(t); /*length of text*/

	HMASK = MASK(m); /*HMASK(m) = 100...0 (0's m-1 times)*/
	MMASK = (m == WORD_SIZE) ? 0xFFFFFFFFFFFFFFFF : pow(2, m) - 1; /*00...0 (w-m times) 11...1 (m times)*/

	long score = m;

	unsigned int j = 0;

	PEq = (bitvector_64*) malloc (sizeof(bitvector_64) * alphabet_lenght);

	preprocessingPEq(&PEq, p, m, alphabet_lenght);

	/*set initial values*/
	VP = MMASK;
	VN = 0;	

	printf("\nscore: %ld", score);
	
	for(j = 0; j < n; j++)
	{
		EQ = PEq[(unsigned int) t[j]];
		//printf("\ncharacter: %c", t[j]);
		//EQ &= MMASK;

		score += advancedBlock(&EQ, &VP, &VN, &VX, &HX, &HP, &HN);
		//printf("\nscore[%d]: %ld", j, score);
	}

	return score;
}


unsigned long advancedBlock(bitvector_64* EQ, bitvector_64* VP, bitvector_64* VN, bitvector_64* VX, bitvector_64* HX, bitvector_64* HP, bitvector_64* HN)
{
	long score = 0; 
	
	*VX = (*EQ) | (*VN);
	*VX &= MMASK;

	*HX = ((((*EQ) & (*VP)) + (*VP)) ^ (*VP)) | (*EQ);
	*HX &= MMASK;
	
	*HP = (*VN) | ~((*VP) | (*HX));
	*HP &= MMASK;

	*HN = (*VP) & (*HX);
	*HN &= MMASK;

	
	score = (((*HP) & HMASK) != 0) - (((*HN) & HMASK) != 0);
	//printInfo(*EQ, *VX, *HX, *HP, *HN, *VP, *VN, score);
	//getchar();
	

	(*HP) = ((*HP) << 1) | 1; /* | 1 is a modification for calculate edit distance*/
	*HP &= MMASK;

	(*HN) <<= 1;
	*HN &= MMASK;

	*VP = (*HN) | ~((*HP) | (*VX));
	*VP &= MMASK;

	*VN = (*HP) & (*VX);
	*VN &= MMASK;

	return score;
}


void* preprocessingPEq(bitvector_64** PEq, char* p, size_t m, unsigned short int alphabet_lenght)
{
	unsigned int j = 0;

	for (j = 0; j < alphabet_lenght; j++)
		(*PEq)[j] = 0;
	
	for (j = 0; j < m; j++)
	{
		//printf("\n%c:", p[j]);
		//printf("\n%s", strBin((*PEq)[((unsigned int) p[j])]));
		//printf("\n%s", strBin(MASK(j+1)));

		(*PEq)[((unsigned int) p[j])] |= MASK(j+1);

		//printf("\n%s\n", strBin((*PEq)[((unsigned int) p[j])]));
	}

	return 0;	
}



void printInfo(bitvector_64 EQ, bitvector_64 VX, bitvector_64 HX, bitvector_64 HP, bitvector_64 HN, bitvector_64 VP, bitvector_64 VN, long score)
{
	printf("\nScore: %ld", score);
	printf("\nEQ: %s  ::  %lu", strBin(EQ), EQ);
	printf("\nVX: %s  ::  %lu", strBin(VX), VX);
	printf("\nHX: %s  ::  %lu", strBin(HX), HX);
	printf("\nHP: %s  ::  %lu", strBin(HP), HP);
	printf("\nVP: %s  ::  %lu", strBin(VP), VP);
	printf("\nVN: %s  ::  %lu", strBin(VN), VN);
	printf("\nHN: %s  ::  %lu\n", strBin(HN), HN);
}


char* strBin(bitvector_64 n)
{
	//unsigned short int n_bits = 0;
	char* str;
	int i = 0;

	/*Suppose n_bits <= WORD_SIZE*/
	//n_bits = (n > 1) ? floor(log(n) / log(2) + 0.5) : (n == 1);
	str = (char*) malloc (WORD_SIZE * sizeof(char));

	bitvector_64 numerator = n;

	for(i = WORD_SIZE - 1; i >= 0; i--)
	{	
		str[i] = 48 + (numerator % 2);		
		numerator >>= 1;
	}

	return str;
}
