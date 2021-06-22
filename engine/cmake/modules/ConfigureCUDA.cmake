#=============================================================================
# Copyright (c) 2021, NVIDIA CORPORATION.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#=============================================================================

if(CMAKE_COMPILER_IS_GNUCXX)
    list(APPEND ${PROJECT_NAME}_CXX_FLAGS -Wall -Wextra -Wno-unknown-pragmas)
    # -Werror is too strict for blazingsql
    # list(APPEND ${PROJECT_NAME}_CXX_FLAGS -Wall -Wextra -Wno-unknown-pragmas -Werror -Wno-error=deprecated-declarations)
    if(${PROJECT_NAME}_BUILD_TESTS OR ${PROJECT_NAME}_BUILD_BENCHMARKS)
        # Suppress parentheses warning which causes gmock to fail
        list(APPEND ${PROJECT_NAME}_CUDA_FLAGS -Xcompiler=-Wno-parentheses)
    endif()
endif()

list(APPEND ${PROJECT_NAME}_CUDA_FLAGS --expt-extended-lambda --expt-relaxed-constexpr)

# set warnings as errors
list(APPEND ${PROJECT_NAME}_CUDA_FLAGS -Werror=cross-execution-space-call)
list(APPEND ${PROJECT_NAME}_CUDA_FLAGS -Xcompiler=-Wall,-Wextra,-Wno-error=deprecated-declarations)
# -Werror is too strict for blazingsql
# list(APPEND ${PROJECT_NAME}_CUDA_FLAGS -Xcompiler=-Wall,-Wextra,-Wno-error=deprecated-declarations,-Werror)

if(DISABLE_DEPRECATION_WARNING)
    list(APPEND ${PROJECT_NAME}_CXX_FLAGS -Wno-deprecated-declarations)
    list(APPEND ${PROJECT_NAME}_CUDA_FLAGS -Xcompiler=-Wno-deprecated-declarations)
endif()

# Option to enable line info in CUDA device compilation to allow introspection when profiling / memchecking
if(CUDA_ENABLE_LINE_INFO)
  list(APPEND ${PROJECT_NAME}_CUDA_FLAGS -lineinfo)
endif()

if(CUDA_ENABLE_KERNEL_INFO)
  list(APPEND ${PROJECT_NAME}_CUDA_FLAGS -Xptxas=-v)
endif()

# Debug options
if(CMAKE_BUILD_TYPE MATCHES Debug)
    message(VERBOSE "${PROJECT_NAME}: Building with debugging flags")
    list(APPEND ${PROJECT_NAME}_CUDA_FLAGS -G -Xcompiler=-rdynamic)
endif()
