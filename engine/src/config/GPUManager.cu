#include "GPUManager.cuh"
#include <cuda.h>
#include <cuda_runtime.h>
#include <cudf/utilities/error.hpp>

namespace ral {
namespace config {

size_t gpuFreeMemory() {
	int currentDeviceId = 0;
	struct cudaDeviceProp props;
	// CUDF_CUDA_TRY( cudaSetDevice(currentDeviceId) );
	cudaGetDeviceProperties(&props, currentDeviceId);
	size_t free, total;
	cudaMemGetInfo(&free, &total);

	return free;
}

size_t gpuTotalMemory() {
	int currentDeviceId = 0;
	struct cudaDeviceProp props;
	// CUDF_CUDA_TRY( cudaSetDevice(currentDeviceId) );
	cudaGetDeviceProperties(&props, currentDeviceId);
	size_t free, total;
	cudaMemGetInfo(&free, &total);

	return total;
}

size_t gpuUsedMemory() {
	int currentDeviceId = 0;
	struct cudaDeviceProp props;
	// CUDF_CUDA_TRY( cudaSetDevice(currentDeviceId) );
	cudaGetDeviceProperties(&props, currentDeviceId);
	size_t free, total;
	cudaMemGetInfo(&free, &total);

	return total - free;
}

}  // namespace config
}  // namespace ral
