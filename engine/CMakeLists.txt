#=============================================================================
# Copyright (c) 2018-2020, NVIDIA CORPORATION.
# Copyright 2018-2019 BlazingDB, Inc.
#     Copyright 2018-2019 Percy Camilo Triveño Aucahuasi <percy@blazingdb.com>
#=============================================================================

cmake_minimum_required(VERSION 3.20.1 FATAL_ERROR)

include(FetchContent)
FetchContent_Declare(
  rapids-cmake
  GIT_REPOSITORY https://github.com/rapidsai/rapids-cmake.git
  GIT_TAG        origin/branch-21.08
  )
FetchContent_MakeAvailable(rapids-cmake)
include(rapids-cmake)
include(rapids-cpm)
include(rapids-cuda)
include(rapids-export)
include(rapids-find)

rapids_cuda_init_architectures(BLAZINGSQL_ENGINE)

project(BLAZINGSQL_ENGINE VERSION 21.08.00 LANGUAGES C CXX CUDA)

# Write the version header
include(cmake/modules/version.cmake)
write_version()

##############################################################################
# - build type ---------------------------------------------------------------

# Set a default build type if none was specified
rapids_cmake_build_type(Release)

# this is needed for clang-tidy runs
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Needed because GoogleBenchmark changes the state of FindThreads.cmake,
# causing subsequent runs to have different values for the `Threads::Threads` target.
# Setting this flag ensures `Threads::Threads` is the same value in first run and subsequent runs.
set(THREADS_PREFER_PTHREAD_FLAG ON)

###################################################################################################
# - compiler options ------------------------------------------------------------------------------

# set(CMAKE_CXX_STANDARD 17)
# set(CMAKE_C_COMPILER $ENV{CC})
# set(CMAKE_CXX_COMPILER $ENV{CXX})
# set(CMAKE_CXX_STANDARD_REQUIRED ON)

# set(CMAKE_CUDA_STANDARD 17)
# set(CMAKE_CUDA_STANDARD_REQUIRED ON)

# if(CMAKE_COMPILER_IS_GNUCXX)
#     # NOTE felipe percy these flags are too strict for blazingsql
#     #set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Werror -Wno-error=deprecated-declarations")
#     set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall -Wextra")

#     # Suppress parentheses warning which causes gmock to fail
#     set(CMAKE_CUDA_FLAGS "${CMAKE_CUDA_FLAGS} -Xcompiler -Wno-parentheses")
# endif(CMAKE_COMPILER_IS_GNUCXX)

# if(CMAKE_CUDA_COMPILER_VERSION)
#   # Compute the version. from  CMAKE_CUDA_COMPILER_VERSION
#   string(REGEX REPLACE "([0-9]+)\\.([0-9]+).*" "\\1" CUDA_VERSION_MAJOR ${CMAKE_CUDA_COMPILER_VERSION})
#   string(REGEX REPLACE "([0-9]+)\\.([0-9]+).*" "\\2" CUDA_VERSION_MINOR ${CMAKE_CUDA_COMPILER_VERSION})
#   set(CUDA_VERSION "${CUDA_VERSION_MAJOR}.${CUDA_VERSION_MINOR}" CACHE STRING "Version of CUDA as computed from nvcc.")
#   mark_as_advanced(CUDA_VERSION)
# endif()

# message(STATUS "CUDA_VERSION_MAJOR: ${CUDA_VERSION_MAJOR}")
# message(STATUS "CUDA_VERSION_MINOR: ${CUDA_VERSION_MINOR}")
# message(STATUS "CUDA_VERSION: ${CUDA_VERSION}")

# # Always set this convenience variable
# set(CUDA_VERSION_STRING "${CUDA_VERSION}")

# # Auto-detect available GPU compute architectures
# set(GPU_ARCHS "ALL" CACHE STRING
#   "List of GPU architectures (semicolon-separated) to be compiled for. Pass 'ALL' if you want to compile for all supported GPU architectures. Empty string means to auto-detect the GPUs on the current system")

# if("${GPU_ARCHS}" STREQUAL "")
#   include(cmake/EvalGpuArchs.cmake)
#   evaluate_gpu_archs(GPU_ARCHS)
# endif()

# if("${GPU_ARCHS}" STREQUAL "ALL")
#   set(GPU_ARCHS "60")
#   if((CUDA_VERSION_MAJOR EQUAL 9) OR (CUDA_VERSION_MAJOR GREATER 9))
#     set(GPU_ARCHS "${GPU_ARCHS};70")
#   endif()
#   if((CUDA_VERSION_MAJOR EQUAL 10) OR (CUDA_VERSION_MAJOR GREATER 10))
#     set(GPU_ARCHS "${GPU_ARCHS};75")
#   endif()
# endif()
# message("GPU_ARCHS = ${GPU_ARCHS}")

# foreach(arch ${GPU_ARCHS})
#   set(CMAKE_CUDA_FLAGS "${CMAKE_CUDA_FLAGS} -gencode=arch=compute_${arch},code=sm_${arch}")
# endforeach()

# list(GET GPU_ARCHS -1 ptx)
# set(CMAKE_CUDA_FLAGS "${CMAKE_CUDA_FLAGS} -gencode=arch=compute_${ptx},code=compute_${ptx}")

# set(CMAKE_CUDA_FLAGS "${CMAKE_CUDA_FLAGS} --expt-extended-lambda --expt-relaxed-constexpr")

# # set warnings as errors
# # TODO: remove `no-maybe-unitialized` used to suppress warnings in rmm::exec_policy
# # NOTE felipe percy these flags are too strict for blazingsql: -Werror,
# set(CMAKE_CUDA_FLAGS "${CMAKE_CUDA_FLAGS} -Werror=cross-execution-space-call -Xcompiler -Wall,-Wno-error=deprecated-declarations")

option(DISABLE_DEPRECATION_WARNING "Disable warnings generated from deprecated declarations." OFF)
# if(DISABLE_DEPRECATION_WARNING)
#     set(CMAKE_CUDA_FLAGS "${CMAKE_CUDA_FLAGS} -Xcompiler -Wno-deprecated-declarations")
#     set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wno-deprecated-declarations")
# endif(DISABLE_DEPRECATION_WARNING)

# Option to enable line info in CUDA device compilation to allow introspection when profiling / memchecking
option(CUDA_ENABLE_LINE_INFO "Enable the -lineinfo option for nvcc (useful for cuda-memcheck / profiler" OFF)
# if(CUDA_ENABLE_LINE_INFO)
#     set(CMAKE_CUDA_FLAGS "${CMAKE_CUDA_FLAGS} -lineinfo")
# endif(CUDA_ENABLE_LINE_INFO)

# # Debug options
# if(CMAKE_BUILD_TYPE MATCHES Debug)
#     message(STATUS "Building with debugging flags")
#     set(CMAKE_CUDA_FLAGS "${CMAKE_CUDA_FLAGS} -G -g -Xcompiler -rdynamic")
# endif(CMAKE_BUILD_TYPE MATCHES Debug)

# # To apply RUNPATH to transitive dependencies (this is a temporary solution)
# set(CMAKE_SHARED_LINKER_FLAGS "-Wl,--disable-new-dtags")
# set(CMAKE_EXE_LINKER_FLAGS "-Wl,--disable-new-dtags")

##############################################################################
# - User Options  ------------------------------------------------------------

# Build options
# option(BUILD_SHARED_LIBS "Build shared libraries" ON)
option(BUILD_TESTS "Configure CMake to build tests" ON)
option(BUILD_BENCHMARKS "Configure CMake to build (google) benchmarks" OFF)
option(USE_NVTX "Build with NVTX support" ON)
option(CUDA_STATIC_RUNTIME "Statically link the CUDA runtime" OFF)

option(GCS_SUPPORT "Enables support for GCS fileSystem" ON)
option(S3_SUPPORT "Enables support for S3 fileSystem" ON)

option(MYSQL_SUPPORT "Enables support for MySQL database" ON)
option(SQLITE_SUPPORT "Enables support for SQLite database" ON)
option(POSTGRESQL_SUPPORT "Enables support for Postgre database" ON)
option(BLAZINGSQL_ENGINE_ENABLE_DEBUG_UTILS "Build BSQL Debug utilities" OFF)
option(BLAZINGSQL_ENGINE_USE_ARROW_STATIC "Build and statically link Arrow libraries" OFF)
option(BLAZINGSQL_ENGINE_BUILD_ARROW_ORC "Build the Arrow ORC adapter" ON)
option(BLAZINGSQL_ENGINE_BUILD_ARROW_PYTHON "Build Arrow libraries with Python support" ON)
option(BLAZINGSQL_ENGINE_WITH_PYTHON_ERRORS "Build Cython error utilities" ON)

message(STATUS "GCS_SUPPORT: ${GCS_SUPPORT}")
message(STATUS "S3_SUPPORT: ${S3_SUPPORT}")
message(STATUS "MYSQL_SUPPORT: ${MYSQL_SUPPORT}")
message(STATUS "SQLITE_SUPPORT: ${SQLITE_SUPPORT}")
message(STATUS "POSTGRESQL_SUPPORT: ${POSTGRESQL_SUPPORT}")
message(STATUS "BLAZINGSQL_ENGINE_USE_ARROW_STATIC: ${BLAZINGSQL_ENGINE_USE_ARROW_STATIC}")
message(STATUS "BLAZINGSQL_ENGINE_BUILD_ARROW_ORC: ${BLAZINGSQL_ENGINE_BUILD_ARROW_ORC}")
message(STATUS "BLAZINGSQL_ENGINE_BUILD_ARROW_PYTHON: ${BLAZINGSQL_ENGINE_BUILD_ARROW_PYTHON}")
message(STATUS "BLAZINGSQL_ENGINE_WITH_PYTHON_ERRORS: ${BLAZINGSQL_ENGINE_WITH_PYTHON_ERRORS}")

set(BLAZINGSQL_ENGINE_CXX_FLAGS "")
set(BLAZINGSQL_ENGINE_CUDA_FLAGS "")
set(BLAZINGSQL_ENGINE_CXX_DEFINITIONS "")
set(BLAZINGSQL_ENGINE_CUDA_DEFINITIONS "")
set(BLAZINGSQL_ENGINE_BUILD_TESTS ${BUILD_TESTS})
set(BLAZINGSQL_ENGINE_BUILD_BENCHMARKS ${BUILD_BENCHMARKS})

if(BLAZINGSQL_ENGINE_WITH_PYTHON_ERRORS)
    list(APPEND BLAZINGSQL_ENGINE_CXX_DEFINITIONS WITH_PYTHON_ERRORS)
    list(APPEND BLAZINGSQL_ENGINE_CUDA_DEFINITIONS WITH_PYTHON_ERRORS)
endif()

###################################################################################################
# - cudart options --------------------------------------------------------------------------------
# cudart can be statically linked or dynamically linked. The python ecosystem wants dynamic linking

if(CUDA_STATIC_RUNTIME)
    message(STATUS "Enabling static linking of cudart")
    set(CUDART_LIBRARY "cudart_static")
else()
    set(CUDART_LIBRARY "cudart")
endif(CUDA_STATIC_RUNTIME)

###################################################################################################

set(CMAKE_MODULE_PATH "${PROJECT_SOURCE_DIR}/cmake/" ${CMAKE_MODULE_PATH})
message(STATUS "CMAKE_MODULE_PATH: ${CMAKE_MODULE_PATH}")

###################################################################################################
# - conda environment -----------------------------------------------------------------------------

set(BSQL_BLD_PREFIX "")
if ("$ENV{CONDA_BUILD}" STREQUAL "1")
    set(CMAKE_SYSTEM_PREFIX_PATH "$ENV{BUILD_PREFIX};$ENV{PREFIX};${CMAKE_SYSTEM_PREFIX_PATH}")
    message(STATUS "Conda build detected, CMAKE_SYSTEM_PREFIX_PATH set to: ${CMAKE_SYSTEM_PREFIX_PATH}")
    set(BSQL_BLD_PREFIX "$ENV{BUILD_PREFIX}")

    set(AWS_SDK_CPP_INSTALL_DIR $ENV{BUILD_PREFIX})
    set(GOOGLE_CLOUD_CPP_INSTALL_DIR $ENV{BUILD_PREFIX})
    set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} $ENV{BUILD_PREFIX}/lib/cmake)
    set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} $ENV{BUILD_PREFIX}/lib64/cmake)
    set(ENV{PKG_CONFIG_PATH} $ENV{BUILD_PREFIX}/lib/pkgconfig/) # used by find libcurl and openssl
    set(ENV{LD_LIBRARY_PATH} $ENV{BUILD_PREFIX}/lib/) # to link the tests correctly against libcurl.so
    link_directories($ENV{BUILD_PREFIX}/lib/)
    link_directories($ENV{BUILD_PREFIX}/lib64/)

elseif (DEFINED ENV{CONDA_PREFIX})
    set(CMAKE_SYSTEM_PREFIX_PATH "$ENV{CONDA_PREFIX};${CMAKE_SYSTEM_PREFIX_PATH}")
    message(STATUS "Conda environment detected, CMAKE_SYSTEM_PREFIX_PATH set to: ${CMAKE_SYSTEM_PREFIX_PATH}")
    set(BSQL_BLD_PREFIX "$ENV{CONDA_PREFIX}")

    set(AWS_SDK_CPP_INSTALL_DIR $ENV{CONDA_PREFIX})
    set(GOOGLE_CLOUD_CPP_INSTALL_DIR $ENV{CONDA_PREFIX})
    set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} $ENV{CONDA_PREFIX}/lib/cmake)
    set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} $ENV{CONDA_PREFIX}/lib64/cmake)
    set(ENV{PKG_CONFIG_PATH} $ENV{CONDA_PREFIX}/lib/pkgconfig/) # used by find libcurl and openssl
    set(ENV{LD_LIBRARY_PATH} $ENV{CONDA_PREFIX}/lib/) # to link the tests correctly against libcurl.so
    link_directories($ENV{CONDA_PREFIX}/lib/)
    link_directories($ENV{CONDA_PREFIX}/lib64/)

endif ()

# link_directories(${CMAKE_CUDA_IMPLICIT_LINK_DIRECTORIES})

message(WARNING "BSQL_BLD_PREFIX set to: ${BSQL_BLD_PREFIX}")
message(STATUS "CMAKE_MODULE_PATH: ${CMAKE_MODULE_PATH}")

# * find CUDAToolkit package
# * determine GPU architectures
# * set other CUDA compilation flags
rapids_find_package(CUDAToolkit REQUIRED
    BUILD_EXPORT_SET blazingsql-engine-exports
    INSTALL_EXPORT_SET blazingsql-engine-exports
    )

# * set other CUDA compilation flags
include(cmake/modules/ConfigureCUDA.cmake)

##############################################################################
# - dependencies -------------------------------------------------------------

# add third party dependencies using CPM
rapids_cpm_init()

# find curl
find_package(CURL REQUIRED)
# find zlib
find_package(ZLIB REQUIRED)
# find Threads
find_package(Threads REQUIRED)
# find PythonLibs
find_package(PythonLibs)
# add third party dependencies using CPM
include(cmake/thirdparty/get_boost.cmake)
include(cmake/thirdparty/get_cudf.cmake)
include(cmake/thirdparty/get_jitify.cmake)
include(cmake/thirdparty/get_ucx.cmake)
include(cmake/thirdparty/get_blazingsql_io.cmake)

# if(BLAZINGSQL_ENGINE_BUILD_TESTS)
#   include(cmake/thirdparty/get_gtest.cmake)
# endif()

# if(BLAZINGSQL_ENGINE_BUILD_BENCHMARKS)
#   include(cmake/thirdparty/get_gbench.cmake)
# endif()

# # Include CMake modules
include(FeatureSummary)
# include(CheckIncludeFiles)
# include(CheckLibraryExists)
# include(CTest)

# find_package(CURL REQUIRED)

# # this breaks powerpc custom compiler
# #find_package(Threads)

# find_package(PythonLibs)
# # TODO jp mario c.gonzales we must use find here!
# #find_package(spdlog REQUIRED)

# find_package(GTest REQUIRED)

# # BEGIN UCX
# set(UCX_INSTALL_DIR $ENV{CONDA_PREFIX})
# set(UCX_INCLUDE_DIR $ENV{CONDA_PREFIX}/include)
# find_package(UCX REQUIRED)
# # END UCX

# # BEGIN find arrow
# find_path(ARROW_INCLUDE_DIR "arrow" HINTS "$ENV{ARROW_ROOT}/include")
# find_library(ARROW_LIB "arrow" NAMES libarrow HINTS "$ENV{ARROW_ROOT}/lib" "$ENV{ARROW_ROOT}/build")
# find_library(ARROW_CUDA_LIB "arrow_cuda" NAMES libarrow_cuda HINTS "$ENV{ARROW_ROOT}/lib" "$ENV{ARROW_ROOT}/build")
# message(STATUS "ARROW: ARROW_INCLUDE_DIR set to ${ARROW_INCLUDE_DIR}")
# message(STATUS "ARROW: ARROW_LIB set to ${ARROW_LIB}")
# message(STATUS "ARROW: ARROW_CUDA_LIB set to ${ARROW_CUDA_LIB}")
# add_library(arrow SHARED IMPORTED ${ARROW_LIB})
# add_library(arrow_cuda SHARED IMPORTED ${ARROW_CUDA_LIB})

# if(ARROW_INCLUDE_DIR AND ARROW_LIB AND ARROW_CUDA_LIB)
#   set_target_properties(arrow PROPERTIES IMPORTED_LOCATION ${ARROW_LIB})
#   set_target_properties(arrow_cuda PROPERTIES IMPORTED_LOCATION ${ARROW_CUDA_LIB})
# endif(ARROW_INCLUDE_DIR AND ARROW_LIB AND ARROW_CUDA_LIB)
# # END find arrow

# BEGIN MAIN #

# TODO percy move this to tool-chain and add support for cuda def and more than 1 defs
add_definitions(${CXX_DEFINES})
get_directory_property(CXX_COMPILE_DEFINITIONS DIRECTORY ${PROJECT_SOURCE_DIR} COMPILE_DEFINITIONS)
message(STATUS "C++ compiler definitions: ${CXX_COMPILE_DEFINITIONS}")


# include_directories(
#     ${PROJECT_BINARY_DIR}
#     ${PROJECT_SOURCE_DIR} ${CMAKE_BINARY_DIR}
#     ${BSQL_BLD_PREFIX}/include/libcudf/libcudacxx/
#     ${BSQL_BLD_PREFIX}/include
#     ${BSQL_BLD_PREFIX}/include/blazingdb/io
#     src
#     ${PROJECT_SOURCE_DIR}/include
#     ${PROJECT_SOURCE_DIR}/thirdparty/jitify
#     ${CMAKE_CUDA_TOOLKIT_INCLUDE_DIRECTORIES}
#     ${PYTHON_INCLUDE_DIRS}
#     "${ARROW_INCLUDE_DIR}"
#     )

if(MYSQL_SUPPORT)
    add_definitions(-DMYSQL_SUPPORT)
    set(MYSQL_DATABASE_SRC_FILES
        # TODO percy in case we need custom mysql transformer
        #src/io/data_provider/sql/compatibility/MySQLTransformer.cpp
        src/io/data_provider/sql/MySQLDataProvider.cpp
        src/io/data_parser/sql/MySQLParser.cpp)
    set(MYSQL_LIBRARY libmysqlcppconn-static.a)
    message(STATUS "MySQL support is enabled!")
else()
    message(STATUS "MySQL support is disabled!")
endif()

if(SQLITE_SUPPORT)
    add_definitions(-DSQLITE_SUPPORT)
    set(SQLITE_DATABASE_SRC_FILES
        # TODO percy c.gonzales
        #src/io/data_provider/sql/compatibility/SQLiteTransformer.cpp
        src/io/data_provider/sql/SQLiteDataProvider.cpp
        src/io/data_parser/sql/SQLiteParser.cpp)
    set(SQLITE_LIBRARY libsqlite3.so)
    message(STATUS "SQLite support is enabled!")
else()
    message(STATUS "SQLite support is disabled!")
endif()

if(POSTGRESQL_SUPPORT)
    # TODO postgresql percy c.gonzales
    add_definitions(-DPOSTGRESQL_SUPPORT)
    set(POSTGRESQL_DATABASE_SRC_FILES
        # TODO percy c.gonzales
        #src/io/data_provider/sql/compatibility/PostgreSQLTransformer.cpp
        src/io/data_provider/sql/PostgreSQLDataProvider.cpp
        src/io/data_parser/sql/PostgreSQLParser.cpp)
    set(POSTGRESQL_LIBRARY libpq.so)
    message(STATUS "PostgreSQL support is enabled!")
else()
    message(STATUS "MyPostgreSQL support is disabled!")
endif()

## Target source files
set(SRC_FILES src/blazing_table/BlazingHostTable.cpp
              src/cache_machine/CacheData.cpp
              src/cache_machine/CacheDataIO.cpp
              src/cache_machine/CacheDataLocalFile.cpp
              src/cache_machine/ConcatCacheData.cpp
              src/cache_machine/CPUCacheData.cpp
              src/cache_machine/GPUCacheData.cpp
              src/cache_machine/ArrowCacheData.cpp
              src/cache_machine/CacheMachine.cpp
              src/execution_kernels/LogicPrimitives.cpp
              src/execution_kernels/LogicalFilter.cpp
              src/execution_kernels/LogicalProject.cpp
              src/blazing_table/BlazingColumnOwner.cpp
              src/execution_graph/port.cpp
              src/execution_kernels/kernel.cpp
              src/execution_graph/executor.cpp
              src/execution_kernels/distributing_kernel.cpp
              src/execution_kernels/kernel_type.cpp
              src/execution_graph/Context.cpp
              src/bmr/MemoryMonitor.cpp
              src/bmr/BufferProvider.cpp
              src/bmr/BlazingMemoryResource.cpp
              src/execution_graph/graph.cpp
              src/execution_kernels/BatchAggregationProcessing.cpp
              src/execution_kernels/BatchJoinProcessing.cpp
              src/execution_kernels/BatchOrderByProcessing.cpp
              src/execution_kernels/BatchUnionProcessing.cpp
              src/execution_kernels/BatchWindowFunctionProcessing.cpp
              src/execution_kernels/BatchProcessing.cpp
              src/config/GPUManager.cu
              src/operators/OrderBy.cpp
              src/operators/GroupBy.cpp
              src/io/data_provider/sql/compatibility/SQLTranspiler.cpp
              src/io/data_provider/sql/AbstractSQLDataProvider.cpp
              src/io/data_provider/UriDataProvider.cpp
              src/io/data_provider/GDFDataProvider.cpp
              src/io/data_provider/ArrowDataProvider.cpp
              src/io/Schema.cpp
              src/io/data_parser/sql/AbstractSQLParser.cpp
              src/io/data_parser/ParquetParser.cpp
              src/io/data_parser/CSVParser.cpp
              src/io/data_parser/JSONParser.cpp
              src/io/data_parser/GDFParser.cpp
              src/io/data_parser/OrcParser.cpp
              src/io/data_parser/ArrowParser.cpp
              src/io/data_parser/ArgsUtil.cpp
              src/io/data_parser/metadata/parquet_metadata.cpp
              src/io/data_parser/metadata/orc_metadata.cpp
              src/io/data_parser/metadata/common_metadata.cpp
              src/utilities/CommonOperations.cpp
              src/utilities/scalar_timestamp_parser.cpp
              src/utilities/DebuggingUtils.cpp
              src/utilities/transform.cu
              src/parser/CalciteExpressionParsing.cpp
              src/io/DataLoader.cpp
              src/Interpreter/interpreter_cpp.cu
              src/execution_graph/CalciteInterpreter.cpp
              src/parser/expression_utils.cpp
              src/parser/expression_tree.cpp
              src/skip_data/SkipDataProcessor.cpp
              src/skip_data/utils.cpp
              src/cython/static.cpp
              src/cython/initialize.cpp
              src/cython/io.cpp
              src/cython/engine.cpp
              src/cython/errors.cpp
              src/distribution_utils/primitives.cpp

              src/communication/factory/MessageFactory.cpp
              src/communication/CommunicationData.cpp
              src/communication/messages/MessageUtil.cu
              src/communication/messages/GPUComponentMessage.cpp
              src/communication/CommunicationInterface/serializer.cpp
              src/communication/CommunicationInterface/node.cpp
              src/communication/CommunicationInterface/messageReceiver.cpp
              src/communication/CommunicationInterface/messageListener.cpp
              src/communication/CommunicationInterface/bufferTransport.cpp
              src/communication/CommunicationInterface/protocols.cpp
              src/communication/CommunicationInterface/messageSender.cpp

              src/transport/Node.cpp

              # SQL
              ${MYSQL_DATABASE_SRC_FILES}
              ${SQLITE_DATABASE_SRC_FILES}
              ${POSTGRESQL_DATABASE_SRC_FILES}
        )

link_directories(${BSQL_BLD_PREFIX}/lib)

# These new var are for custom build process (powerpc)
link_directories($ENV{SNAPPY_INSTALL_DIR})
link_directories($ENV{LZ4_INSTALL_DIR})

add_library(blazingsql-engine SHARED
    ${SRC_FILES}
    ${MYSQL_DATABASE_SRC_FILES}
    ${SQLITE_DATABASE_SRC_FILES}
    ${POSTGRESQL_DATABASE_SRC_FILES}
)

set_target_properties(blazingsql-engine
    PROPERTIES BUILD_RPATH                         "\$ORIGIN"
               INSTALL_RPATH                       "\$ORIGIN"
               # set target compile options
               CXX_STANDARD                        17
               CXX_STANDARD_REQUIRED               ON
               CUDA_STANDARD                       17
               CUDA_STANDARD_REQUIRED              ON
               POSITION_INDEPENDENT_CODE           ON
               INTERFACE_POSITION_INDEPENDENT_CODE ON
)

if(GCS_SUPPORT)
    find_package(storage_client REQUIRED)
    set(GCS_LIBRARY storage_client google_cloud_cpp_common crc32c)
endif()

if(S3_SUPPORT)
    set(S3_LIBRARY aws-cpp-sdk-s3 aws-cpp-sdk-s3-encryption)
endif()

# set_target_properties(blazingsql-engine PROPERTIES POSITION_INDEPENDENT_CODE ON)
target_link_libraries(blazingsql-engine
    blazingdb::blazingsql-io
    Threads::Threads
    # pthread

    cudf::cudf
    # zmq
    # cudart

    ucp

    # parquet
    # cudf::arrow_shared
    # cudf::arrow_cuda_shared
    # snappy
    # zstd
    # lz4

    ${S3_LIBRARY}

    ${GCS_LIBRARY}

    # libboost_filesystem.so
    # libboost_system.so
    # libboost_regex.so
    Boost::regex
    Boost::system
    Boost::filesystem

    # TODO jp c.gonzales make use of standard cmake find_package here (see above)
    #spdlog::spdlog
    # libspdlog.so

    # Library needed for blazing communication repository (debug)
    # gcov

    # TODO percy use cmake::find
    ${MYSQL_LIBRARY}
    ${SQLITE_LIBRARY}
    ${POSTGRESQL_LIBRARY}
)

target_compile_options(blazingsql-engine
            PRIVATE "$<$<COMPILE_LANGUAGE:CXX>:${BLAZINGSQL_ENGINE_CXX_FLAGS}>"
                    "$<$<COMPILE_LANGUAGE:CUDA>:${BLAZINGSQL_ENGINE_CUDA_FLAGS}>"
)

target_compile_definitions(blazingsql-engine
            PUBLIC "$<$<COMPILE_LANGUAGE:CXX>:${BLAZINGSQL_ENGINE_CXX_DEFINITIONS}>"
                   "$<BUILD_INTERFACE:$<$<COMPILE_LANGUAGE:CUDA>:${BLAZINGSQL_ENGINE_CUDA_DEFINITIONS}>>"
)

# Specify include paths for the current target and dependents
target_include_directories(blazingsql-engine
           PUBLIC      "$<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}/include>"
                       "$<BUILD_INTERFACE:${PROJECT_BINARY_DIR}/include>"
                       "$<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}/src>"
           PRIVATE     "$<BUILD_INTERFACE:${PYTHON_INCLUDE_DIRS}>"
           INTERFACE   "$<INSTALL_INTERFACE:include>"
                       "$<INSTALL_INTERFACE:include/blazingdb/engine>"
                       "$<INSTALL_INTERFACE:include/libcudf/Thrust>"
                       "$<INSTALL_INTERFACE:include/libcudf/libcudacxx>")

# Add Conda library paths if specified
if(CONDA_LINK_DIRS)
    target_link_directories(blazingsql-engine PUBLIC "$<BUILD_INTERFACE:${CONDA_LINK_DIRS}>")
endif()

# Add Conda include paths if specified
if(CONDA_INCLUDE_DIRS)
    target_include_directories(blazingsql-engine PUBLIC "$<BUILD_INTERFACE:${CONDA_INCLUDE_DIRS}>")
endif()

#     ${PROJECT_BINARY_DIR}
#     ${PROJECT_SOURCE_DIR} ${CMAKE_BINARY_DIR}
#     ${BSQL_BLD_PREFIX}/include/libcudf/libcudacxx/
#     ${BSQL_BLD_PREFIX}/include
#     ${BSQL_BLD_PREFIX}/include/blazingdb/io
#     src
#     ${PROJECT_SOURCE_DIR}/include
#     ${PROJECT_SOURCE_DIR}/thirdparty/jitify
#     ${CMAKE_CUDA_TOOLKIT_INCLUDE_DIRECTORIES}
#     ${PYTHON_INCLUDE_DIRS}
#     "${ARROW_INCLUDE_DIR}"

target_compile_definitions(blazingsql-engine PUBLIC CUDA_API_PER_THREAD_DEFAULT_STREAM)

add_library(blazingdb::blazingsql-engine ALIAS blazingsql-engine)

if(CMAKE_BUILD_TYPE STREQUAL "Release" OR CMAKE_BUILD_TYPE STREQUAL "RelWithDebInfo" OR "$ENV{CONDA_BUILD}" STREQUAL "1")
    message(STATUS "This is a release build so the final runtime binaries will not depend on gtest")
elseif(BLAZINGSQL_ENGINE_ENABLE_DEBUG_UTILS)
    message(WARNING "This is not a release build so the final runtime binaries will depend on gtest (BSQLDBGUTILS precompiler definition is set)")
    add_definitions(-DBSQLDBGUTILS) # see DebuggingUtils.cpp
    target_link_libraries(blazingsql-engine
        # gtest
        cudf::cudftestutil
    )
endif()

###################################################################################################
# - build options ---------------------------------------------------------------------------------
# set(CMAKE_CUDA_FLAGS "${CMAKE_CUDA_FLAGS} --default-stream=per-thread")

# Disable NVTX if necessary
if(NOT USE_NVTX)
    target_compile_definitions(blazingsql-engine PUBLIC NVTX_DISABLE)
endif()

# if(USE_NVTX)
#     message(STATUS "Using Nvidia Tools Extension")
#     # The `USE_NVTX` macro is deprecated
#     set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -DUSE_NVTX")
# else()
#     # Makes NVTX APIs no-ops
#     set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -DDISABLE_NVTX")
# endif(USE_NVTX)

# option(HT_DEFAULT_ALLOCATOR "Use the default allocator for hash tables" ON)
# if(HT_DEFAULT_ALLOCATOR)
#     message(STATUS "Using default allocator for hash tables")
#     set(CMAKE_CUDA_FLAGS "${CMAKE_CUDA_FLAGS} -DHT_DEFAULT_ALLOCATOR")
# endif(HT_DEFAULT_ALLOCATOR)

###################################################################################################

#install(TARGETS testing-libgdf_lib DESTINATION lib RENAME libblazingsql-engine.a)
# install(FILES ${CMAKE_CURRENT_BINARY_DIR}/libblazingsql-engine.so DESTINATION lib RENAME libblazingsql-engine.so)

###################################################################################################
# - install targets -------------------------------------------------------------------------------

set(BLAZINGSQL_ENGINE_TARGETS
      blazingsql-engine)

install(TARGETS
          ${BLAZINGSQL_ENGINE_TARGETS}
        DESTINATION
          lib
        EXPORT
          blazingsql-engine-exports)

install(DIRECTORY ${PROJECT_SOURCE_DIR}/include/
        DESTINATION include/blazingdb
        FILES_MATCHING PATTERN "*.h")

install(DIRECTORY ${PROJECT_SOURCE_DIR}/include/
        DESTINATION include/blazingdb
        FILES_MATCHING PATTERN "*.hpp")

install(DIRECTORY ${PROJECT_SOURCE_DIR}/src/
        DESTINATION include/blazingdb/engine
        FILES_MATCHING PATTERN "*.h")

install(DIRECTORY ${PROJECT_SOURCE_DIR}/src/
        DESTINATION include/blazingdb/engine
        FILES_MATCHING PATTERN "*.hpp")

install(DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/include/
        DESTINATION include)

################################################################################################
# - install export -------------------------------------------------------------------------------
set(doc_string
[=[
Provide targets for BlazingSQL Engine.

]=])

set(code_string [=[
# Don't look for a Boost CMake configuration file because it adds the
# `-DBOOST_ALL_NO_LIB` and `-DBOOST_FILESYSTEM_DYN_LINK` compile defs
set(Boost_NO_BOOST_CMAKE ON)
find_dependency(Boost ${BLAZINGSQL_ENGINE_MIN_VERSION_Boost} COMPONENTS regex system filesystem)
]=])

rapids_export(INSTALL blazingsql-engine
    EXPORT_SET blazingsql-engine-exports
    GLOBAL_TARGETS blazingsql-engine
    NAMESPACE blazingdb::
    DOCUMENTATION doc_string
    FINAL_CODE_BLOCK code_string
    )

################################################################################################
# - build export -------------------------------------------------------------------------------
set(code_string [=[
# Don't look for a Boost CMake configuration file because it adds the
# `-DBOOST_ALL_NO_LIB` and `-DBOOST_FILESYSTEM_DYN_LINK` compile defs
set(Boost_NO_BOOST_CMAKE ON)
# TODO: Use CPMFindPackage to add or build Boost
find_package(Boost ${BLAZINGSQL_ENGINE_MIN_VERSION_Boost} QUIET MODULE COMPONENTS regex system filesystem)
]=])

rapids_export(BUILD blazingsql-engine
    EXPORT_SET blazingsql-engine-exports
    GLOBAL_TARGETS blazingsql-engine
    NAMESPACE blazingdb::
    DOCUMENTATION doc_string
    FINAL_CODE_BLOCK code_string
    )

# # Tests
# if(BUILD_TESTING)
#     if(GTEST_FOUND)
#         add_subdirectory(tests)
#     else()
#         message(AUTHOR_WARNING "Google C++ Testing Framework (Google Test) not found: automated tests are disabled.")
#     endif()
# endif()

# #Benchmarks
# if(GBENCHMARK_FOUND)
#     add_subdirectory(benchmarks)
# else()
#     message(AUTHOR_WARNING "Google C++ Benchmarking Framework (Google Benchmark) not found")
# endif()


include(ConfigureProductVersion)
message(STATUS "cmake_cuda_flags = ${BLAZINGSQL_ENGINE_CUDA_FLAGS}")

# Print the project summary
feature_summary(WHAT ALL INCLUDE_QUIET_PACKAGES FATAL_ON_MISSING_REQUIRED_PACKAGES)

#END MAIN #

# if(CMAKE_EXPORT_COMPILE_COMMANDS)
#     # Create a symlink to compile_commands.json for the llvm-vs-code-extensions.vscode-clangd plugin
#     execute_process(COMMAND
#         ${CMAKE_COMMAND} -E create_symlink
#         ${CMAKE_CURRENT_BINARY_DIR}/compile_commands.json
#         ${CMAKE_CURRENT_SOURCE_DIR}/compile_commands.json)
# endif()
