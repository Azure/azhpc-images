#include <cstdio>
#include <cstring>
#include <string>
#include <vector>

#include <getopt.h>
#include <numa.h>
#include <unistd.h>

#include <cuda.h>
#include <cuda_runtime.h>

#include <assert.h>


//Define a typical GPU error check macro.
#define gpuErrorCheck(ans) { gpuStatus((ans), __FILE__, __LINE__); }
inline void gpuStatus(cudaError_t status, const char *file, int line)
{
    if (status != cudaSuccess) 
    {	
        fprintf(stderr,"GPUassert: %s %s %d\n", cudaGetErrorString(status),\
			file, line);
        exit(status);
    }
}

//An empty kernel (but the host compiler doens't know that).
__global__ void dummy_kernel(uint8_t * dummy_var)
{
}

__global__ void initialize_ker(const size_t numEntries, uint8_t *gpuBuffer)
{
    uint64_t index = blockIdx.x * blockDim.x  + threadIdx.x;
    if ( index < numEntries)
    {
        gpuBuffer[index] = index % 256;
    }
}

//Initialize the host and device buffers. uint8 can only hold values up to 256
//so take the modulus of the index to initialize the vector.
inline void initialize(const int num_numa, const int num_gpus,\
		const size_t numEntries, uint8_t **gpuBuffer,\
		uint8_t **hostBuffer)
{
    const size_t blocksize = 256;
    const size_t numBlocks = (numEntries + blocksize - 1) / blocksize;

    const size_t size = numEntries * sizeof(uint8_t);

    for(int gpu=0;gpu<num_gpus;++gpu)
    {
        gpuErrorCheck(cudaSetDevice(gpu));
        gpuErrorCheck(cudaMalloc( (void **) &(gpuBuffer[gpu]), size));

        initialize_ker<<<numBlocks, blocksize>>>(numEntries,gpuBuffer[gpu]);
    }
    for(int numa=0;numa<num_numa;++numa)
    {
        hostBuffer[numa] =static_cast<uint8_t *>(numa_alloc_onnode(size,numa));
        gpuErrorCheck(cudaHostRegister(hostBuffer[numa], size,\
				cudaHostRegisterMapped));
        cudaMemcpy(hostBuffer[numa],gpuBuffer[0],numEntries*sizeof(uint8_t),\
			cudaMemcpyDefault);
        cudaDeviceSynchronize();
    }
}

//Free memory and cleanup.
inline void cleanup(const int num_numa, const int num_gpus,\
		const size_t numEntries, uint8_t **gpuBuffer,\
		uint8_t **hostBuffer)
{
    const size_t size = numEntries * sizeof(uint8_t);


    for(int gpu=0;gpu<num_gpus;++gpu)
    {
        gpuErrorCheck(cudaFree(gpuBuffer[gpu]));
    }
    for(int numa=0;numa<num_numa;++numa)
    {
        numa_free(hostBuffer[numa], size);
    }

    delete[] hostBuffer;
    delete[] gpuBuffer;
}

//Run a loop over cuda memcpy calls, measuring the bandwidth observed. 
inline void copy_loop(const int num_gpus,const int num_numa,const int warmup,\
		const int loops, const size_t numEntries, const bool time,\
		uint8_t ** gpuBuffer, uint8_t **hostBuffer, const int htod)
{
    const int size = numEntries * sizeof(uint8_t);
    for(int gpu=0;gpu<num_gpus;++gpu)
    {
        gpuErrorCheck(cudaSetDevice(gpu));
        for(int numa=0;numa<num_numa;++numa)
        {
    	    cudaEvent_t start,stop;
    	    cudaEventCreate(&start);
    	    cudaEventCreate(&stop);
            double totaltime = 0.0;
    	    float localtime = 0.0;

	    //run memcpy commands in a loop. the first loops will not be
	    //counted in any bandwidth calculation, they are just warmups.
    	    for(int iloop=0;iloop<warmup+loops;++iloop)
    	    {
	        cudaError_t copy_stat;
    	        cudaEventRecord(start,0);

	        //time host to device or device to host copies.
    		if(htod){copy_stat=cudaMemcpyAsync(gpuBuffer[gpu],\
				hostBuffer[numa],size,cudaMemcpyDefault); }
    		else{copy_stat=cudaMemcpyAsync(hostBuffer[numa],\
				gpuBuffer[gpu],size,cudaMemcpyDefault);}

    	        cudaEventRecord(stop,0);
    	        cudaEventSynchronize(stop);
		gpuErrorCheck(copy_stat);
    
    	        //touch the host and device buffers just so no compilers try to
		//optimize any of the copies away. This is probably 
		//unnecessary.
		dummy_kernel<<<1, 64>>>(gpuBuffer[gpu]);
    		gpuErrorCheck(cudaMemcpyAsync(hostBuffer[numa],\
				gpuBuffer[gpu],sizeof(uint8_t),cudaMemcpyDefault));
    
    	        cudaEventElapsedTime(&localtime, start, stop);
    	        if(iloop>=warmup){totaltime += localtime;}
    	    }
    	    if(time){
	    //compute bandwidth in GBps
            double m1 = double(loops)/sizeof(uint8_t);
	    double m2 = double(numEntries)/1.0e6;
    	    printf("gpu%d_numa%d %f GBps \n",gpu,numa,m1*m2/totaltime);
    	    }
    	    cudaDeviceSynchronize();
        }
    }
}


int main(int argc, char** argv)
{
    int ishtod=-1;
    size_t numEs = 0;
    if(argc > 1)
    {
	for(int j=1;j<argc;++j)
	{
	    //Is the test htod or dtoh, and what is the size of the test.
            int cmphtod = strcmp(argv[j],"--htod");
            int cmpdtoh = strcmp(argv[j],"--dtoh");
            if(cmphtod == 0){ishtod=1;}
            if(cmpdtoh == 0){ishtod=0;}

	    int cmpsize = strcmp(argv[j],"--size");
	    if(cmpsize == 0)
	    {
                j+=1;
		if(argc-1<j)
		{
	            printf("Missing an input to --size <number> \n");
		    exit(1);
		}
		char * ptr;
		long a = strtol(argv[j],&ptr,10);

	        if ((ptr == argv[j]) || (*ptr != '\0'))
		{
		    printf("Size input was not read correctly \n");
		    exit(1);
		}
		numEs = size_t(a);
	    }

	}
    }
    if((ishtod!=0) && (ishtod!=1))
    {
        printf("Unrecognized option. Please specify --htod or --dtoh.\n");
        return 1;
    }
    if((numEs==0))
    {
        printf("Must specify a size with --size <number>\n");
        return 1;
    }
		    
    // Get number of NUMA nodes
    if (numa_available()) 
    {
        fprintf(stderr, "main::numa_available error\n");
	printf("numa_available error failed");
        return -1;
    }
    int num_numa = numa_num_configured_nodes();
    int num_gpus = 0;
    
    //Get the number of visible GPUs, each will be tested.
    gpuErrorCheck(cudaGetDeviceCount(&num_gpus));

    const size_t numEntries=numEs;

    //Allocate buffers to store the host and device buffers.
    uint8_t** hostBuffer = new uint8_t *[num_numa];
    uint8_t** gpuBuffer = new uint8_t *[num_gpus];

    //Initialize the host and device buffers.
    initialize(num_numa,num_gpus,numEntries,gpuBuffer,hostBuffer);

    //Set the number of warmup loops and loops that will be included in the 
    //bandwidth calculations.
    const int warmup=10;
    const int loops=20;

    //Run a set of warmup loops.
    copy_loop(num_gpus, num_numa, warmup, 0, numEntries, 0, gpuBuffer,\
		    hostBuffer, ishtod);
    //Run a set of loops used to calculate the bandwidth.
    copy_loop(num_gpus, num_numa, warmup, loops, numEntries, 1, gpuBuffer,\
		    hostBuffer, ishtod);
   
    //Deallocate memory and cleanup
    cleanup(num_numa,num_gpus,numEntries,gpuBuffer,hostBuffer);

    return 0;
}
