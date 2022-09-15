#include <cuda_runtime.h>
#include <device_launch_parameters.h>
#include <cuda.h>
#include <device_functions.h>
#include <cuda_runtime_api.h>
#include <stdio.h>
#include <map>
#include <string>
#include <random>
#include <iostream>
#include <chrono>
__global__ void gpufreq(const char* text, int* res, int count)
{
    int threadid = blockIdx.x * blockDim.x + threadIdx.x;
    if (threadid < count)
    {
        int id = text[threadid];
        atomicAdd(&res[id], 1);
    }
}
void cpufreq(const std::vector<char> h_input, std::vector <int> &hh_ascii)
{
    for (auto v : h_input)
        hh_ascii[(int)v]++;
}
void generateString(std::vector<char> &input, size_t count)
{
    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_int_distribution<> rg(65, 122);
    for (int i = 0; i < count; i++)
        input[i] = rg(gen);
}
bool checkOk(std::vector<int> vec1, std::vector<int> vec2)
{
    bool check = 1;
    for (int i = 65; i < 122; i++)
    {
        if (vec1[i] != vec2[i])
            check = 0;
    }
    return check;
}
int main()
{
    int len;
    std::cout << "enter count of letters:\n";
    std::cin >> len;
    std::vector<char> h_input(len);
    generateString(h_input, len);
    //for (auto v : h_input)
    //    std::cout << v;
    std::vector<int> h_ascii(256,0);
    std::vector<int> hh_ascii(256, 0);
    char* d_input;
    int *d_ascii;

    int BLOCK_SIZE = 32;
    dim3 dimGrid(ceil(double(len)/ double(BLOCK_SIZE)));
    dim3 dimBlock(BLOCK_SIZE);
    cudaEvent_t start, stop;
    cudaEventCreate(&start);
    cudaEventCreate(&stop);

    //MEM ALLOC
    cudaMalloc(&d_input, sizeof(char) * len);
    cudaMalloc(&d_ascii, sizeof(int) * 256);
    cudaEventRecord(start);
    cudaMemcpy(d_input, h_input.data(), len*sizeof(char), cudaMemcpyHostToDevice);
    cudaMemcpy(d_ascii, h_ascii.data(), 256*sizeof(int), cudaMemcpyHostToDevice);

    //GPU CALL
    
    gpufreq <<< dimGrid, dimBlock >>> (d_input, d_ascii, len);
    cudaThreadSynchronize();
    

    cudaMemcpy(h_ascii.data(), d_ascii, 256 * sizeof(int), cudaMemcpyDeviceToHost);


    cudaEventRecord(stop);


    cudaEventSynchronize(stop);

    float milliseconds = 0;
    cudaEventElapsedTime(&milliseconds, start, stop);
    std::cout << "\ngpu milliseconds elapsed: " << milliseconds;
    std::cout << '\n';

    cudaEventDestroy(start);
    cudaEventDestroy(stop);

    for (int i = 65; i < 122; i++)
        std::cout <<char(i)<<": " << h_ascii[i]<< "\n";
    int control_sum = 0;
    for (auto v : h_ascii)
        control_sum += v;
    std::cout << "\ncontrol sum: " << control_sum;

    //CPU CALL
    auto begin = std::chrono::steady_clock::now();
    cpufreq(h_input, hh_ascii);
    auto end = std::chrono::steady_clock::now();
    auto elapsed_ms = std::chrono::duration_cast<std::chrono::milliseconds>(end - begin);
    std::cout << "\ncpu milliseconds elapsed: " << elapsed_ms.count();
    control_sum = 0;
    for (auto v : hh_ascii)
        control_sum += v;
    std::cout << '\n';
    for (int i = 65; i < 122; i++)
        std::cout << char(i) << ": " << hh_ascii[i] << "\n";
    std::cout << "\ncontrol sum: " << control_sum;

    if (checkOk(h_ascii, hh_ascii))
        std::cout << "\nall ok";
    else std::cout << "\nnot ok";
}
