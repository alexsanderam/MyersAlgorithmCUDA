/*
Authors: Alexsander Melo and Ygor Canalli
Date: November of 2014
Topicos Especiais em Programacao de Computadores = TEPC
Universidade Federal Rural do Rio de Janeiro - UFRRJ
*/

#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <unistd.h>
#include <string.h>
#include <limits.h>
#include <cuda_runtime.h>
#include "App.h"


extern "C" {
	#include "in.h"
}

typedef unsigned char boolean;
//typedef unsigned char bitvector_64;
//typedef unsigned short bitvector_64;
typedef unsigned int bitvector_64;
//typedef unsigned long bitvector_64;

//#define BITVECTOR_64_MAX UCHAR_MAX
//#define BITVECTOR_64_MAX USHRT_MAX
#define BITVECTOR_64_MAX UINT_MAX
//#define BITVECTOR_64_MAX ULONG_MAX

#define WORD_SIZE ((int) sizeof(bitvector_64) * 8)
#define ASCII pow(2, sizeof(char) * 8) /*max length of ASCII*/
//#define UTF8 (unsigned int) pow(2, sizeof(char) * 8) /*max length of UTF8*/

#define MASK(z) (bitvector_64) 1 << (z - 1)


#define GPU 0
#define MAX_THREADS 1024


#define CHECK_ERROR(call) do {\
   if( cudaSuccess != call) {\
      fprintf(stderr,"\nCUDA ERROR:%s in file: %s in line: %d", cudaGetErrorString(call),  __FILE__, __LINE__);\
         exit(0);\
} } while (0)



/*Functions Header*/
__device__ __host__ void printInfo(bitvector_64, bitvector_64, bitvector_64, bitvector_64, bitvector_64, bitvector_64, bitvector_64, long score);

__device__ __host__ char* strBin(bitvector_64);

void printoccurrences(boolean*, unsigned int);

boolean* myers(const char*, unsigned int, const char*, unsigned int, unsigned int, const unsigned int, const unsigned int, const unsigned int);

__global__ void myers_kernel(bitvector_64*, const unsigned int, const unsigned int, const bitvector_64, const bitvector_64, const unsigned int, const unsigned int, boolean*, const char*, const unsigned int, const unsigned int, const unsigned int);

void* preprocessingPEq(bitvector_64**, const char*, const unsigned int, const unsigned int);

__device__ long advancedBlock(bitvector_64*, const bitvector_64, const bitvector_64, unsigned int, bitvector_64*, bitvector_64*, bitvector_64*,	bitvector_64*, bitvector_64*, bitvector_64*, unsigned int);



int main(int argc, char** argv)
{

	string* strp; 
	string* strt;

	char *t = NULL, /*text*/
	     *p = NULL; /*pattern*/

	boolean* occurrence_array;


	unsigned int alphabet_lenght = ASCII;

	unsigned int m = 0;  /*length of pattern*/
	unsigned int n = 0; /*length of text*/

	unsigned int k = 0;
   unsigned int device = GPU;
   unsigned int threads_per_block = MAX_THREADS;
	
	short int c;
	
	while ((c = getopt (argc, argv, "P:T:p:t:a:k:d:b:")) != -1)
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
			case 'd':
				device = atoi(optarg);
				break;
			case 'b':
				threads_per_block = atoi(optarg);
				break;
			case '?':
				if ((optopt == 'P') || (optopt == 'T') || (optopt == 'p') || (optopt == 't') || (optopt == 'a') || (optopt == 'k') || (optopt == 'd') || (optopt == 'b'))
		       			fprintf(stderr, "Option -%c requires an argument.\n", optopt);
				else
		       			fprintf(stderr, "Unknown option `-%c'.\n", optopt);
				return 1;
		}
	}

	/*Aproximate string matching*/
	if(k > m)
		k = 0;

	Stopwatch sw;
	FREQUENCY(sw);
  	START_STOPWATCH(sw);

	occurrence_array = myers(t, n, p, m, k, alphabet_lenght, device, threads_per_block);

  	STOP_STOPWATCH(sw);

  	//printoccurrences(occurrence_array, n);
	printf("\nTotal time %lf (ms)\n", sw.mElapsedTime);

  
   free(occurrence_array);
   free(p);
   free(t);
   free(strt);
   free(strp);

	return 0;
}



boolean* myers(const char *t, unsigned int n, const char *p, unsigned int m, unsigned int k, const unsigned int alphabet_lenght, const unsigned int device, const unsigned int threads_per_block)
{
	unsigned int n_slices = floor((float) n / m);
	unsigned int slice_mask = 1;

	// find slice_base_mask = 2^k and greater than slice_base
	while (n_slices > slice_mask)
		slice_mask <<= 1;

    /*n_slices is the greather power of 2 less or equal to slice_base*/
	if ((n_slices > 1) && (n_slices < slice_mask))
		n_slices = (slice_mask >> 1);

	/*========================================================================================*/
	CHECK_ERROR(cudaSetDevice(device));
	CHECK_ERROR(cudaDeviceReset());
	/*========================================================================================*/


	/*========================================================================================*/
	bitvector_64 HMASK;
	bitvector_64 MMASK;

	bitvector_64 bits = m;

	MMASK = (bits == WORD_SIZE) ? BITVECTOR_64_MAX : pow(2, bits) - 1;
	HMASK = (bits == WORD_SIZE) ? MASK(WORD_SIZE) : MASK(bits);
	/*========================================================================================*/


	/*========================================================================================*/
	bitvector_64 *PEq;
	bitvector_64 *d_PEq;

	PEq = (bitvector_64*) malloc (sizeof(bitvector_64) * alphabet_lenght);
	preprocessingPEq(&PEq, p, m, alphabet_lenght);

	CHECK_ERROR(cudaMalloc(&d_PEq, alphabet_lenght * sizeof(bitvector_64)));

	/*Copy to device*/
	CHECK_ERROR(cudaMemcpy(d_PEq, PEq, alphabet_lenght * sizeof(bitvector_64), cudaMemcpyHostToDevice));	
	
	free(PEq);
	/*========================================================================================*/


	/*========================================================================================*/
	boolean *occurrence_array;
	boolean *d_occurrence_array;

	occurrence_array = (boolean*) malloc (sizeof(boolean) * n);
	CHECK_ERROR(cudaMalloc((void**) &d_occurrence_array, n * sizeof(boolean)));
	CHECK_ERROR(cudaMemset(d_occurrence_array, 0,  n * sizeof(boolean)));
	/*========================================================================================*/



	/*========================================================================================*/
	char* d_t;
	CHECK_ERROR(cudaMalloc((void**) &d_t, (n * sizeof(char)) + 1));
	/*Copy to device*/
	CHECK_ERROR(cudaMemcpy(d_t, t, (n * sizeof(char)), cudaMemcpyHostToDevice));
	/*========================================================================================*/


	/*========================================================================================*/
	/*size_t _free = 0,
            total = 0;*/

   /*CHECK_ERROR(cudaMemGetInfo(&_free, &total));
   printf("Memoria livre: %f MB", ((float)_free / 1024 / 1024));
   printf("Memoria total: %f MB", ((float)total / 1024 / 1024));*/
	/*========================================================================================*/


	/*========================================================================================*/
	unsigned int N_CUDA_THREADS = (n_slices > threads_per_block) ? threads_per_block : n_slices;
	unsigned int N_CUDA_BLOCKS = ceil((float) n_slices / threads_per_block);

	printf("\nSlices: %d, Threads: %d - Blocks: %d", n_slices, N_CUDA_THREADS, N_CUDA_BLOCKS);
	dim3 threadsPerBlock(N_CUDA_THREADS, 1);
  	dim3 numBlocks(N_CUDA_BLOCKS, 1);

	unsigned int slice_base = floor((float) n / n_slices);
	unsigned int remaining = n % n_slices;

   printf("\nLenght of text: %d - Slice base: %d - Remaining: %d", n, slice_base, remaining);

	Stopwatch sw;
	FREQUENCY(sw);
  	START_STOPWATCH(sw);

  	/*call myers kernel CUDA*/
	myers_kernel<<<numBlocks, threadsPerBlock>>>(d_PEq, slice_base, remaining, MMASK, HMASK, m, k, d_occurrence_array, d_t, n, n_slices, alphabet_lenght);
	CHECK_ERROR(cudaDeviceSynchronize());

  	STOP_STOPWATCH(sw);
	printf("\nKernel time %lf (ms)", sw.mElapsedTime);
	/*========================================================================================*/

	

	/*========================================================================================*/
	/*Copy device to host*/
	CHECK_ERROR(cudaMemcpy(occurrence_array, d_occurrence_array, n * sizeof(boolean), cudaMemcpyDeviceToHost));
	/*========================================================================================*/

	

	/*========================================================================================*/
	/*free GPU memory*/
	CHECK_ERROR(cudaFree(d_PEq));
	CHECK_ERROR(cudaFree(d_occurrence_array));
	CHECK_ERROR(cudaFree(d_t));
	/*========================================================================================*/


	return occurrence_array;
}



__global__ void myers_kernel(bitvector_64* PEq,
                      const unsigned int slice_base,
                      const unsigned int remaining,
							 const bitvector_64 MMASK,
							 const bitvector_64 HMASK,
							 const unsigned int m,
							 const unsigned int k,
							 boolean* occurrence_array,
							 const char* t,
							 const unsigned int n,
							 const unsigned int n_slices,
							 const unsigned int alphabet_lenght)
{

	unsigned int thread_reference = blockIdx.x * blockDim.x + threadIdx.x;
    unsigned int cooperation_remaining = (thread_reference < remaining);
   	unsigned int offset = (thread_reference * (slice_base + (remaining > 0))) - ((thread_reference - remaining)*(1-cooperation_remaining));
   	unsigned int overlapping_length = (thread_reference < (n_slices - 1))*(m - 1);
   	unsigned int length = slice_base + overlapping_length + cooperation_remaining;

	unsigned int position = 0;

    boolean signal = 0;
	unsigned int i = 0;

    bitvector_64 VP, VN, VX, HX, HP, HN;
	long score = m;

	/*set initial values*/
	VP = MMASK;
	VN = 0;

	for(i = 0; i < length; i++)
	{
		position = offset + i;
		
		score += advancedBlock(PEq, MMASK, HMASK, (unsigned int) t[position], &VP, &VN, &VX, &HX, &HP, &HN, alphabet_lenght);
		
		signal = score <= k;

		// We not found a better solution.
		// The time is not worst, but making more store operations we
		// spend a little bit more time than divergent memory acess
		signal && (occurrence_array[position] = signal);
	}	
}



void* preprocessingPEq(bitvector_64** PEq, const char* p, const unsigned int m, const unsigned int alphabet_lenght)
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


__device__ long advancedBlock(bitvector_64* PEq,
	 						const bitvector_64 MMASK,
	 						const bitvector_64 HMASK,
							unsigned int character_offset,
							bitvector_64* VP,
							bitvector_64* VN,
							bitvector_64* VX,
							bitvector_64* HX,   
							bitvector_64* HP,
							bitvector_64* HN,
							unsigned int alphabet_lenght)
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



void printoccurrences(boolean* occurrence_array, unsigned int n)
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



__device__ __host__ char* strBin(bitvector_64 n)
{
    //unsigned short int n_bits = 0;
    char* str;
    int i = 0;

    /*Suppose n_bits <= WORD_SIZE*/
    //n_bits = (n > 1) ? floor(log(n) / log(2) + 0.5) : (n == 1);
    str = (char*) malloc (WORD_SIZE * sizeof(char) + 1);

    bitvector_64 numerator = n;

    for(i = WORD_SIZE - 1; i >= 0; i--)
    {    
        str[i] = 48 + (numerator % 2);        
        numerator >>= 1;
    }

    str[WORD_SIZE] = 0;

    return str;
}


__device__ __host__ void printInfo(bitvector_64 EQ, bitvector_64 VX, bitvector_64 HX, bitvector_64 HP, bitvector_64 HN, bitvector_64 VP, bitvector_64 VN, long score)
{
	printf("\nScore: %ld", score);
	printf("\nEQ: %s  ::  %u", strBin(EQ), EQ);
	printf("\nVX: %s  ::  %u", strBin(VX), VX);
	printf("\nHX: %s  ::  %u", strBin(HX), HX);
	printf("\nHP: %s  ::  %u", strBin(HP), HP);
	printf("\nVP: %s  ::  %u", strBin(VP), VP);
	printf("\nVN: %s  ::  %u", strBin(VN), VN);
	printf("\nHN: %s  ::  %u\n", strBin(HN), HN);
}
