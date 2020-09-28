#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <unistd.h>
#include <string.h>
#include <limits.h>
#include "App.h"

#include "in.h"

typedef unsigned char boolean;
typedef unsigned long bitvector_64;

#define BITVECTOR_64_MAX ULONG_MAX

#define WORD_SIZE ((int) sizeof(bitvector_64) * 8)
#define ASCII pow(2, sizeof(char) * 8) /*max length of ASCII*/

#define MASK(z) (bitvector_64) 1 << (z - 1)


/*global variable*/
bitvector_64* HMASK = NULL;
bitvector_64* MMASK = NULL;


void printOccurrences(boolean*, unsigned int);

void myers(const char*, const unsigned int, const char*, const unsigned int, const unsigned int, const unsigned int, boolean*);
long advancedBlock(const bitvector_64*, const unsigned int, const unsigned int, bitvector_64*, bitvector_64*, bitvector_64*, bitvector_64*, bitvector_64*, bitvector_64*, const unsigned short int);
void* preprocessingPEq(bitvector_64**, const char*, const unsigned int, const unsigned int, const unsigned short int);
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

	int i = 0;

	
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

	for(i = 0; i < n; i++)
		occurrence_array[i] = 0;

	Stopwatch sw;
	FREQUENCY(sw);
  	START_STOPWATCH(sw);

	myers(t, n, p, m, k, alphabet_lenght, occurrence_array);

	STOP_STOPWATCH(sw);

	//printOccurrences(occurrence_array, n);
	printf("\nTotal time %lf (ms)\n", sw.mElapsedTime);

	return 0;
}


void myers(const char *t, const unsigned int n, const char *p, const unsigned int m, const unsigned int k, const unsigned int alphabet_lenght, boolean* occurrence_array)
{

	unsigned short int n_blocks = ceil((float) m / WORD_SIZE); /*quantity of blocks*/

	unsigned int j = 0,
				 i = 0;

	//HMASK = MASK(block_size) ; /*100...0 (0's block_size-1 times)*/
	HMASK = (bitvector_64*) malloc (sizeof(bitvector_64) * n_blocks);
	MMASK = (bitvector_64*) malloc (sizeof(bitvector_64) * n_blocks);
	bitvector_64 remaining_bits = m;

	for (i = 0; i < n_blocks; i++)
	{
		MMASK[i] = (remaining_bits > WORD_SIZE) ? BITVECTOR_64_MAX : pow(2, remaining_bits) - 1;
		HMASK[i] = (remaining_bits > WORD_SIZE) ? MASK(WORD_SIZE) : MASK(remaining_bits);
		remaining_bits = (remaining_bits > WORD_SIZE) ? remaining_bits - WORD_SIZE : 0;
	}


	bitvector_64 *PEq;

	bitvector_64 *VP, /*vertical positive vector*/
		     	 *VN; /*vertical negative vector*/

	bitvector_64 *HP, /*horizontal positive vector*/
		     	 *HN, /*horizontal negative vector*/
		     	 *VX, /*vertical vector*/
		     	 *HX; /*vertical vector*/

	VP = (bitvector_64*) malloc (sizeof(bitvector_64) * n_blocks);
	VN = (bitvector_64*) malloc (sizeof(bitvector_64) * n_blocks);
	HP = (bitvector_64*) malloc (sizeof(bitvector_64) * n_blocks);
	HN = (bitvector_64*) malloc (sizeof(bitvector_64) * n_blocks);
	VX = (bitvector_64*) malloc (sizeof(bitvector_64) * n_blocks);
	HX = (bitvector_64*) malloc (sizeof(bitvector_64) * n_blocks);

	long score = m;

	PEq = (bitvector_64*) malloc (sizeof(bitvector_64) * alphabet_lenght * n_blocks);

	preprocessingPEq(&PEq, p, m, alphabet_lenght, n_blocks);

	/*set initial values*/
	for (i = 0; i < n_blocks; i++)
	{
		VP[i] = MMASK[i];
		VN[i] = 0;
	}

	for(j = 0; j < n; j++)
	{
		score += advancedBlock(PEq, alphabet_lenght, (unsigned int) t[j], VP, VN, VX, HX, HP, HN, n_blocks);
		//printf("\n(%c) score[%d]: %ld", t[j], j, score);
		//getchar();
		
		if (score <= k)
		{
            occurrence_array[j] = 1;
		}

	}

	free(HMASK);
	free(MMASK);
	free(VP);
	free(VN);
	free(HP);
	free(HN);
	free(VX);
	free(HX);
	free(PEq);
}


long advancedBlock(const bitvector_64* PEq,
							const unsigned int alphabet_lenght,
							const unsigned int character_offset,
							bitvector_64* VP,
							bitvector_64* VN,
							bitvector_64* VX,
							bitvector_64* HX,
							bitvector_64* HP,
							bitvector_64* HN,
							const unsigned short int n_blocks)
{
	long score = 0;

	bitvector_64 add_carry = 0;
	bitvector_64 has_carry = 0;
	bitvector_64 shift_carry_HN = 0;
	bitvector_64 shift_carry_HP = 0;
	bitvector_64 EQ = 0;
	bitvector_64 X = 0;

	unsigned int i = 0;

	for(i = 0; i < n_blocks; i++)
	{

		EQ = PEq[(i * alphabet_lenght) + character_offset];

		VX[i] = EQ | VN[i];
		VX[i] &= MMASK[i];

		has_carry = add_carry;		
		X = EQ | has_carry;

		add_carry = ((X & VP[i]) > (MMASK[i] - VP[i]));
		HX[i] = (((X & VP[i]) + VP[i]) ^ VP[i]) | X | VN[i];
		HX[i] &= MMASK[i];
		
		HP[i] = VN[i] | ~(VP[i] | HX[i]);
		HP[i] &= MMASK[i];

		HN[i] = VP[i] & HX[i];
		HN[i] &= MMASK[i];

		score = ((HP[i] & HMASK[i]) != 0) - ((HN[i] & HMASK[i]) != 0);
		
		//printf("\n(%d) character: %c", i, (char) character_offset);
		//printInfo(EQ, VX[i], HX[i], HP[i], HN[i], VP[i], VN[i], score);
		//getchar();
		
		has_carry = shift_carry_HP;
		shift_carry_HP = (HP[i] & HMASK[i]) != 0;

		HP[i] = (HP[i] << 1);
		HP[i] |= has_carry;
		HP[i] &= MMASK[i];

		has_carry = shift_carry_HN;
		shift_carry_HN = (HN[i] & HMASK[i]) != 0;

		HN[i] <<= 1;
		HN[i] |= has_carry;
		HN[i] &= MMASK[i];

		VP[i] = HN[i] | ~(HP[i] | VX[i]);
		VP[i] &= MMASK[i];

		VN[i] = HP[i] & VX[i];
		VN[i] &= MMASK[i];
	}

	return score;
}


void* preprocessingPEq(bitvector_64** PEq, const char* p, const unsigned int m, const unsigned int alphabet_lenght, const unsigned short int n_blocks)
{
	unsigned int i = 0,
		         j = 0,
		         k = 0;

	for (i = 0; i < n_blocks; i++)
		for (j = 0; j < alphabet_lenght; j++)
			(*PEq)[i * alphabet_lenght + j] = 0;
	

	for (j = 0; j < m; j++) /*j is pattern id*/ /*p[j] is alphabet id, collumn*/
	{
		i = floor(j / WORD_SIZE); /*Block id, line*/
		k = j % WORD_SIZE;
		(*PEq)[i * alphabet_lenght + ((unsigned int) p[j])] |= MASK(k+1);
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
			printf("occurrence at position: %d of text\n", i + 1);
			total++;
		}
	}

	printf("Total of occurrences: %d\n", total);
}


