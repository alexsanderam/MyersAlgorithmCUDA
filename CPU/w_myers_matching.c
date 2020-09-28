#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <unistd.h>
#include <string.h>
#include <limits.h>
#include "App.h"

#include "in.h"

typedef unsigned char boolean;
//typedef unsigned int bitvector_64;
typedef unsigned long bitvector_64;

#//define BITVECTOR_64_MAX UINT_MAX
#define BITVECTOR_64_MAX ULONG_MAX

#define WORD_SIZE ((int) sizeof(bitvector_64) * 8)
#define ASCII pow(2, sizeof(char) * 8) /*max length of ASCII*/
//#define UTF8 pow(2, sizeof(char) * 8) /*max length of UTF8*/

#define MASK(z) (bitvector_64) 1 << (z - 1)


/*global variable*/
bitvector_64 HMASK = 0;
bitvector_64 MMASK = 0;


void printOccurrences(boolean*, unsigned int);
void myers(char*, unsigned int, char*, unsigned int, unsigned int, unsigned int, boolean*);
long advancedBlock(bitvector_64*, unsigned int, unsigned int, bitvector_64*, bitvector_64*, bitvector_64*, bitvector_64*, bitvector_64*, bitvector_64*);
void* preprocessingPEq(bitvector_64**, char*, unsigned int, unsigned int);
void printInfo(bitvector_64, bitvector_64, bitvector_64, bitvector_64, bitvector_64, bitvector_64, bitvector_64, long);
char* strBin(bitvector_64);

int main(int argc, char** argv)
{
   string* strp; 
	string* strt;

	char *t = NULL, /*text*/
	     *p = NULL; /*pattern*/


	unsigned int alphabet_lenght = ASCII;
	
	short int c;

	unsigned int m = 0; /*length of pattern <= 64*/
	unsigned int n = 0; /*length of text*/

	unsigned int k = 0;
	
	while ((c = getopt (argc, argv, "P:T:p:t:a:k:")) != -1)
	{
		switch(c)
		{
			case 'P':
				strp = readTextFromFile(optarg);
         	p = strp->content;
				m = strp->len;
            break;
			case 'T':
            strt = readTextFromFile(optarg);
            t = strt->content;
			   n = strt->len;
			   break;
			case 'p':
				p = optarg;
				m = strlen(p);
				break;
			case 't':
				t = optarg;
				n = strlen(t);
				break;
			case 'a':
				alphabet_lenght = atoi(optarg);
				break;
			case 'k':
				k = atoi(optarg);
				break;
			case '?':
				if ((optopt == 'P') || (optopt == 'T') || (optopt == 'p') || (optopt == 't') || (optopt == 'a') || (optopt == 'k'))
		       			fprintf(stderr, "Option -%c requires an argument.\n", optopt);
				else
		       			fprintf(stderr, "Unknown option `-%c'.\n", optopt);
				return 1;
		}
	}


	if(k > m)
		k = 0;

  	boolean *occurrence_array;
  	occurrence_array = (boolean*) malloc (sizeof(boolean) * n);
    
    int i = 0;
    for(i = 0; i < n; i++)
        occurrence_array[i] = 0;

	Stopwatch sw;
	FREQUENCY(sw);
  	START_STOPWATCH(sw);

	myers(t, n, p, m, k, alphabet_lenght, occurrence_array);

	STOP_STOPWATCH(sw);

	//printOccurrences(occurrence_array, n);
	printf("\nTotal time %lf (ms)\n", sw.mElapsedTime);

   free(occurrence_array);
   free(p);
   free(t);
   free(strt);
   free(strp);


	return 0;
}


void myers(char *t, unsigned int n, char *p, unsigned int m, unsigned int k, unsigned int alphabet_lenght, boolean* occurrence_array)
{

	unsigned int i = 0;

	bitvector_64 bits = m;
	MMASK = (bits == WORD_SIZE) ? BITVECTOR_64_MAX : pow(2, bits) - 1;
	HMASK = (bits == WORD_SIZE) ? MASK(WORD_SIZE) : MASK(bits);


	bitvector_64 *PEq;

	bitvector_64 VP, /*vertical positive vector*/
		     	    VN; /*vertical negative vector*/

	bitvector_64 HP, /*horizontal positive vector*/
		     	    HN, /*horizontal negative vector*/
		     	    VX, /*vertical vector*/
   		     	 HX; /*vertical vector*/

	long score = m;

	PEq = (bitvector_64*) malloc (sizeof(bitvector_64) * alphabet_lenght);


	//Stopwatch sw;
	//FREQUENCY(sw);
  	//START_STOPWATCH(sw);

	preprocessingPEq(&PEq, p, m, alphabet_lenght);

	//STOP_STOPWATCH(sw);
	//printf("\nPreprocessing time %lf (ms)\n", sw.mElapsedTime);
	

	VP = MMASK;
	VN = 0;


	for(i = 0; i < n; i++)
	{
		score += advancedBlock(PEq, alphabet_lenght, (unsigned int) t[i], &VP, &VN, &VX, &HX, &HP, &HN);
	
		if (score <= k)
		{
			occurrence_array[i] = 1;
		}
	}

	free(PEq);
}


long advancedBlock(bitvector_64* PEq,
							unsigned int alphabet_lenght,
							unsigned int character_offset,
							bitvector_64* VP,
							bitvector_64* VN,
							bitvector_64* VX,
							bitvector_64* HX,
							bitvector_64* HP,
							bitvector_64* HN)
{

	long score = 0;
	bitvector_64 EQ = 0;

	EQ = PEq[character_offset];

	(*VX) = EQ | *VN;
	(*VX) &= MMASK;

	(*HX) = (((EQ & *VP) + *VP) ^ *VP) | EQ;
	(*HX) &= MMASK;
	
	(*HP) = *VN | ~(*VP | *HX);
	(*HP) &= MMASK;

	(*HN) = *VP & *HX;
	(*HN) &= MMASK;

	score = ((*HP & HMASK) != 0) - ((*HN & HMASK) != 0);
		
	(*HP) = (*HP << 1);
	(*HP) &= MMASK;

	(*HN) <<= 1;
	(*HN) &= MMASK;

	(*VP) = *HN | ~(*HP | *VX);
	(*VP) &= MMASK;

	(*VN) = *HP & *VX;
	(*VN) &= MMASK;

	return score;
}

void* preprocessingPEq(bitvector_64** PEq, char* p, unsigned int m, unsigned int alphabet_lenght)
{
	unsigned int i = 0;

	for (i = 0; i < alphabet_lenght; i++)
		(*PEq)[i] = 0;
	

	for (i = 0; i < m; i++)
	{
		(*PEq)[((unsigned int) p[i])] |= MASK(i+1);
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


void printOccurrences(boolean* occurrence_array, unsigned int n)
{

	unsigned int i = 0;
	unsigned int total = 0;

	for (i = 0; i < n; i++)
	{
        if (occurrence_array[i])
		{
			printf("Occurrence at position: %d of text\n", i + 1);
			total++;
		}
	}

	printf("\nTotal of occurrences: %d\n", total);
}

