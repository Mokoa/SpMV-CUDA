#include "spmv.h"
#include <stdio.h>
#include <stdlib.h>

int main()
{
        // PARAMETERS
        double p_diag = 0.8;
        double p_nondiag = 0.05;
        float *A_cpu, *A_gpu, *x_cpu, *x_gpu, *y_cpu, *y_gpu;//, *y_correct;
        int *IA_cpu, *IA_gpu, *JA_cpu, *JA_gpu;
        int NNZ;

        const int NUM_ITERS = 1;

        // Define cuda events
        float milliseconds;
        cudaEvent_t start, stop;
        cudaEventCreate(&start);
        cudaEventCreate(&stop);
        
        int N, iter;
        for (N = 2; N < (1 << 15)+1; N=N*2)
        {
                for (iter = 0; iter < NUM_ITERS; ++iter)
                {
                        // Create sparse matrix
                        SpMatrix S = generateSquareSpMatrix(N, p_diag, p_nondiag); // allocates!
                        IA_cpu = S.IA; A_cpu = S.A; JA_cpu = S.JA; NNZ = S.NNZ;

                        // Generate dense vector x
                        x_cpu = (float *)malloc(sizeof(float)*N);
                        fillDenseVector(x_cpu, N);
                        
                        // Define output vector y
                        y_cpu = (float *)malloc(sizeof(float)*N);

                        // Setup memory on the GPU
                        cudaMalloc((void**) &A_gpu, NNZ*sizeof(float));
                        cudaMalloc((void**) &IA_gpu, (N+1)*sizeof(int)); // N = M
                        cudaMalloc((void**) &JA_gpu, NNZ*sizeof(int));
                        cudaMalloc((void**) &x_gpu, N*sizeof(float));
                        cudaMalloc((void**) &y_gpu, N*sizeof(float)); // N = M
        
                        // Transfer to device
                        cudaMemcpy(A_gpu, A_cpu, NNZ*sizeof(float), cudaMemcpyHostToDevice);
                        cudaMemcpy(IA_gpu, IA_cpu, (N+1)*sizeof(int), cudaMemcpyHostToDevice);
                        cudaMemcpy(JA_gpu, JA_cpu, NNZ*sizeof(int), cudaMemcpyHostToDevice);
                        cudaMemcpy(x_gpu, x_cpu, N*sizeof(float), cudaMemcpyHostToDevice);
                        
                        // CUDA kernel parameters
                        int threadsPerBlock, blocksPerGrid;
                        if (N < 1024)
                        {
                                threadsPerBlock = N;
                                blocksPerGrid = 1;
                        }
                        else
                        {
                                threadsPerBlock = 1024;
                                blocksPerGrid = N / 1024;
                        }

                        // Start cudaEvent timing
                        cudaEventRecord(start);
                        
                        // CUDA Kernel - compute spmv multiplication
                        spmvSimple<<<blocksPerGrid, threadsPerBlock>>>(y_gpu, A_gpu, IA_gpu, JA_gpu, x_gpu); // supports well over 2^20
                        
                        cudaEventRecord(stop);
                        cudaEventSynchronize(stop);

                        // Print result
                        milliseconds = 0;
                        cudaEventElapsedTime(&milliseconds, start, stop);
                        printf("N = %i, time taken = %f\n", N, milliseconds);

                        // Transfer to host
                        //cudaMemcpy(y_cpu, y_gpu, N*sizeof(float), cudaMemcpyDeviceToHost);

                        // Verify correctness of CUDA kernel
                        //y_correct = (float *)malloc(sizeof(float)*N);
                        //cpuSpMV(y_correct, S, x_cpu);
                        //printf("Correct output vector y_correct: "); printArray(y_correct, N);
                        //if (areEqual(y_correct, y_cpu, N))
                        //        printf("They are equal!\n");
                        //else
                        //        printf("They are NOT equal!\n");
                        
                        // Free memory
                        free(A_cpu);
                        free(IA_cpu);
                        free(JA_cpu);
                        free(x_cpu);
                        free(y_cpu);
                        //free(y_correct);
                        cudaFree(A_gpu);
                        cudaFree(IA_gpu);
                        cudaFree(JA_gpu);
                        cudaFree(x_gpu);
                        cudaFree(y_gpu);

                        // Set dangling pointers to NULL
                        S.A = NULL;
                        S.IA = NULL;
                        S.JA = NULL;
                }

        }
        
        cudaDeviceReset();
	return 0;
}
