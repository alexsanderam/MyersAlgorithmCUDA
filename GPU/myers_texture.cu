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
typedef unsigned int bitvector_64;

#define BITVECTOR_64_MAX UINT_MAX
#define WORD_SIZE ((int) sizeof(bitvector_64) * 8)
#define ASCII pow(2, sizeof(char) * 8) /*max length of ASCII*/

#define MASK(z) (bitvector_64) 1 << (z - 1)


#define GPU 0
#define MAX_THREADS 1024


#define CHECK_ERROR(call) do {\
   if( cudaSuccess != call) {\
      fprintf(stderr,"CUDA ERROR:%s in file: %s in line: %d", cudaGetErrorString(call),  __FILE__, __LINE__);\
         exit(0);\
} } while (0)



/*Functions Header*/
__device__ __host__ void printInfo(bitvector_64, bitvector_64, bitvector_64, bitvector_64, bitvector_64, bitvector_64, bitvector_64, long score);

__device__ __host__ char* strBin(bitvector_64);

void printoccurrences(boolean*, unsigned int);

__device__ long advancedBlock(const bitvector_64*, const bitvector_64*, unsigned int, bitvector_64*, bitvector_64*, bitvector_64*, bitvector_64*, bitvector_64*, bitvector_64*, const unsigned short int, const unsigned int);

void* preprocessingPEq(bitvector_64**, const char*, const unsigned int, const unsigned int, const unsigned short int);

__global__ void myers_kernel(const unsigned int, const unsigned int, bitvector_64*, bitvector_64*, bitvector_64*, bitvector_64* HX, bitvector_64*, bitvector_64*, const bitvector_64*, const bitvector_64*, const unsigned int, const unsigned int k, boolean*, const char*, const unsigned int, const unsigned int, const unsigned short int, const unsigned int);

boolean* myers(char*, unsigned int, char*, unsigned int, unsigned int, const unsigned int, const unsigned int, const unsigned int);


/*Global varibles*/
texture<bitvector_64, 2> UINTtexRef;


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

	return 0;
}



boolean* myers(char *t, unsigned int n, char *p, unsigned int m, unsigned int k, const unsigned int alphabet_lenght, const unsigned int device, const unsigned int threads_per_block)
{
	
	unsigned short int n_blocks = ceil((float) m / WORD_SIZE); /*quantity of blocks*/

	unsigned int n_slices = floor((float) n / m);
	unsigned int slice_mask = 1;

	unsigned int i = 0;

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
	bitvector_64* HMASK = NULL;
	bitvector_64* MMASK = NULL;
	bitvector_64* d_HMASK = NULL;
	bitvector_64* d_MMASK = NULL;


	HMASK = (bitvector_64*) malloc (sizeof(bitvector_64) * n_blocks);
	MMASK = (bitvector_64*) malloc (sizeof(bitvector_64) * n_blocks);

	bitvector_64 remaining_bits = m;

	for (i = 0; i < n_blocks; i++)
	{
		MMASK[i] = (remaining_bits > WORD_SIZE) ? BITVECTOR_64_MAX : pow(2, remaining_bits) - 1;
		HMASK[i] = (remaining_bits > WORD_SIZE) ? MASK(WORD_SIZE) : MASK(remaining_bits);
		remaining_bits = (remaining_bits > WORD_SIZE) ? remaining_bits - WORD_SIZE : 0;
	}

	CHECK_ERROR(cudaMalloc(&d_HMASK, n_blocks * sizeof(bitvector_64)));
	CHECK_ERROR(cudaMalloc(&d_MMASK, n_blocks * sizeof(bitvector_64)));


	/*Copy to device*/
	CHECK_ERROR(cudaMemcpy(d_MMASK, MMASK, n_blocks * sizeof(bitvector_64), cudaMemcpyHostToDevice));
	CHECK_ERROR(cudaMemcpy(d_HMASK, HMASK, n_blocks * sizeof(bitvector_64), cudaMemcpyHostToDevice));
	
	free(HMASK);
	free(MMASK);
	/*========================================================================================*/


	/*========================================================================================*/
	bitvector_64 *PEq;
    cudaArray* d_PEq;

	PEq = (bitvector_64*) malloc (sizeof(bitvector_64) * alphabet_lenght * n_blocks);
	preprocessingPEq(&PEq, p, m, alphabet_lenght, n_blocks);

    cudaChannelFormatDesc channelDesc = cudaCreateChannelDesc<bitvector_64>();
	CHECK_ERROR(cudaMallocArray(&d_PEq, &channelDesc, alphabet_lenght, n_blocks));
	/*Copy to device*/
	CHECK_ERROR(cudaMemcpyToArray(d_PEq, 0, 0, PEq, n_blocks*alphabet_lenght*sizeof(bitvector_64), cudaMemcpyHostToDevice));
    CHECK_ERROR(cudaBindTextureToArray(UINTtexRef, d_PEq));
	
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
	bitvector_64 *d_VP, /*vertical positive vector*/
		     	 *d_VN; /*vertical negative vector*/

	bitvector_64 *d_HP, /*horizontal positive vector*/
		     	 *d_HN, /*horizontal negative vector*/
		     	 *d_VX, /*vertical vector*/
		     	 *d_HX; /*vertical vector*/

	
	CHECK_ERROR(cudaMalloc((void**) &d_HX, (sizeof(bitvector_64) * n_blocks * n_slices)));
	CHECK_ERROR(cudaMalloc((void**) &d_VP, (sizeof(bitvector_64) * n_blocks * n_slices)));
	CHECK_ERROR(cudaMalloc((void**) &d_VN, (sizeof(bitvector_64) * n_blocks * n_slices)));
	CHECK_ERROR(cudaMalloc((void**) &d_HP, (sizeof(bitvector_64) * n_blocks * n_slices)));
	CHECK_ERROR(cudaMalloc((void**) &d_HN, (sizeof(bitvector_64) * n_blocks * n_slices)));
	CHECK_ERROR(cudaMalloc((void**) &d_VX, (sizeof(bitvector_64) * n_blocks * n_slices)));
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
	printf("\nThreads: %d - Blocks: %d", N_CUDA_THREADS, N_CUDA_BLOCKS);
	dim3 threadsPerBlock(N_CUDA_THREADS, 1);
  	dim3 numBlocks(N_CUDA_BLOCKS, 1);

	unsigned int slice_base = floor((float) n / n_slices);
	unsigned int remaining = n % n_slices;
    printf("\nLenght of text: %d - Slice base: %d - Remaining: %d", n, slice_base, remaining);

	Stopwatch sw;
	FREQUENCY(sw);
  	START_STOPWATCH(sw);

  	/*call myers kernel CUDA*/
	myers_kernel<<<numBlocks, threadsPerBlock>>>(slice_base, remaining, d_VP, d_VN, d_VX, d_HX,
                                                d_HP, d_HN, d_MMASK, d_HMASK, m, k, d_occurrence_array,
												d_t, n, n_slices, n_blocks, alphabet_lenght);
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
	CHECK_ERROR(cudaFree(d_MMASK));
	CHECK_ERROR(cudaFree(d_HMASK));
	CHECK_ERROR(cudaFreeArray(d_PEq));
	CHECK_ERROR(cudaFree(d_occurrence_array));
	CHECK_ERROR(cudaFree(d_t));
	/*========================================================================================*/


	return occurrence_array;
}



__global__ void myers_kernel(const unsigned int slice_base,
                             const unsigned int remaining,
						     bitvector_64* VP,
						     bitvector_64* VN,
						     bitvector_64* VX,
						     bitvector_64* HX,
						     bitvector_64* HP,
						     bitvector_64* HN,
							 const bitvector_64* MMASK,
							 const bitvector_64* HMASK,
							 const unsigned int m,
							 const unsigned int k,
							 boolean* occurrence_array,
							 const char* t,
							 const unsigned int n,
							 const unsigned int n_slices,
							 const unsigned short int n_blocks,
							 const unsigned int alphabet_lenght)
{

	unsigned int thread_reference = blockIdx.x * blockDim.x + threadIdx.x;
    unsigned int cooperation_remaining = (thread_reference < remaining);
   	unsigned int offset = (thread_reference * (slice_base + (remaining > 0))) - ((thread_reference - remaining)*(1-cooperation_remaining));
   	unsigned int overlapping_length = (thread_reference < (n_slices - 1))*(m - 1);
   	unsigned int length = slice_base + overlapping_length + cooperation_remaining;
   	unsigned int bitvector_start = thread_reference * n_blocks;
 
	unsigned int position = 0;

	long score = m;

    boolean signal = 0;

	unsigned int i = 0,
				 j = 0;

	/*set initial values*/
	for (i = 0; i < n_blocks; i++)
	{
		VP[bitvector_start + i] = MMASK[i];
		VN[bitvector_start + i] = 0;
	}


	for(j = 0; j < length; j++)
	{
		position = offset + j;
		
		score += advancedBlock(MMASK, HMASK, (unsigned int) t[position], VP + bitvector_start, VN + bitvector_start, VX + bitvector_start, HX + bitvector_start, HP + bitvector_start, HN + bitvector_start, n_blocks, alphabet_lenght);
		
		signal = score <= k;

		// We not found a better solution.
		// The time is not worst, but making more store operations we
		// spend a little bit more time than divergent memory acess
		signal && (occurrence_array[position] = signal);
	}	
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


__device__ long advancedBlock(const bitvector_64* MMASK,
	 						const bitvector_64* HMASK,
							const unsigned int character_offset,
							bitvector_64* VP,
							bitvector_64* VN,
							bitvector_64* VX,
							bitvector_64* HX,
							bitvector_64* HP,
							bitvector_64* HN,
							const unsigned short int n_blocks,
							const unsigned int alphabet_lenght)
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
		EQ = tex2D(UINTtexRef, character_offset, i);

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



void printoccurrences(boolean* occurrence_array, unsigned int n)
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
