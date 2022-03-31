#=============================================================================
# Copyright 2018-2020 BlazingDB, Inc.
#     Copyright 2018 Felipe Aramburu <felipe@blazingdb.com>
#     Copyright 2018-2020 Percy Camilo Triveño Aucahuasi <percy@blazingdb.com>
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

cmake_minimum_required(VERSION 3.20.1 FATAL_ERROR)

file(DOWNLOAD https://raw.githubusercontent.com/rapidsai/rapids-cmake/branch-22.06/RAPIDS.cmake
     ${CMAKE_BINARY_DIR}/RAPIDS.cmake)
include(${CMAKE_BINARY_DIR}/RAPIDS.cmake)
include(rapids-cmake)
include(rapids-cpm)
include(rapids-cuda)
include(rapids-export)
include(rapids-find)

rapids_cuda_init_architectures(BLAZINGSQL_IO)

project(BLAZINGSQL_IO VERSION 22.06.00 LANGUAGES CXX)

# Write the version header
include(cmake/modules/version.cmake)
write_version()

##############################################################################
# - build type ---------------------------------------------------------------

# Set a default build type if none was specified
rapids_cmake_build_type(Release)

# this is needed for clang-tidy runs
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

set(CMAKE_MODULE_PATH "${PROJECT_SOURCE_DIR}/cmake/" ${CMAKE_MODULE_PATH})
message(STATUS "CMAKE_MODULE_PATH: ${CMAKE_MODULE_PATH}")

##############################################################################
# - User Options  ------------------------------------------------------------

option(BUILD_SHARED_LIBS "Build shared libraries" ON)
option(GCS_SUPPORT "Enables support for GCS fileSystem" ON)
option(S3_SUPPORT "Enables support for S3 fileSystem" ON)
option(BLAZINGSQL_IO_USE_ARROW_STATIC "Build and statically link Arrow libraries" OFF)
option(BLAZINGSQL_IO_BUILD_ARROW_ORC "Build the Arrow ORC adapter" ON)
option(BLAZINGSQL_IO_BUILD_ARROW_PYTHON "Build Arrow libraries with Python support" ON)

message(STATUS "GCS_SUPPORT: ${GCS_SUPPORT}")
message(STATUS "S3_SUPPORT: ${S3_SUPPORT}")
message(STATUS "BLAZINGSQL_IO_USE_ARROW_STATIC: ${BLAZINGSQL_IO_USE_ARROW_STATIC}")
message(STATUS "BLAZINGSQL_IO_BUILD_ARROW_ORC: ${BLAZINGSQL_IO_BUILD_ARROW_ORC}")
message(STATUS "BLAZINGSQL_IO_BUILD_ARROW_PYTHON: ${BLAZINGSQL_IO_BUILD_ARROW_PYTHON}")

###################################################################################################
# - conda environment -----------------------------------------------------------------------------

if ("$ENV{CONDA_BUILD}" STREQUAL "1")
    set(CMAKE_PREFIX_PATH "$ENV{BUILD_PREFIX};$ENV{PREFIX};${CMAKE_PREFIX_PATH}")
    set(CONDA_INCLUDE_DIRS "$ENV{BUILD_PREFIX}/include" "$ENV{PREFIX}/include")
    set(CONDA_LINK_DIRS "$ENV{BUILD_PREFIX}/lib" "$ENV{PREFIX}/lib")
    message(STATUS "Conda build detected, CMAKE_PREFIX_PATH set to: ${CMAKE_PREFIX_PATH}")

    set(ENV{PKG_CONFIG_PATH} $ENV{BUILD_PREFIX}/lib/pkgconfig/) # used by find libcurl
    set(ENV{LD_LIBRARY_PATH} $ENV{BUILD_PREFIX}/lib/) # to link the tests correctly against libcurl.so
    find_library(CURL PATHS $ENV{BUILD_PREFIX}/lib/ NO_DEFAULT_PATH)
    set(GOOGLE_CLOUD_CPP_INSTALL_DIR $ENV{BUILD_PREFIX})
    set(AWS_SDK_CPP_INSTALL_DIR $ENV{BUILD_PREFIX})
    set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} $ENV{BUILD_PREFIX}/lib/cmake)

elseif (DEFINED ENV{CONDA_PREFIX})
    set(CMAKE_PREFIX_PATH "$ENV{CONDA_PREFIX};${CMAKE_PREFIX_PATH}")
    set(CONDA_INCLUDE_DIRS "$ENV{CONDA_PREFIX}/include")
    set(CONDA_LINK_DIRS "$ENV{CONDA_PREFIX}/lib")
    message(STATUS "Conda environment detected, CMAKE_PREFIX_PATH set to: ${CMAKE_PREFIX_PATH}")

    set(ENV{PKG_CONFIG_PATH} $ENV{CONDA_PREFIX}/lib/pkgconfig/) # used by find libcurl
    set(ENV{LD_LIBRARY_PATH} $ENV{CONDA_PREFIX}/lib/) # to link the tests correctly against libcurl.so
    find_library(CURL PATHS $ENV{CONDA_PREFIX}/lib/ NO_DEFAULT_PATH)
    set(GOOGLE_CLOUD_CPP_INSTALL_DIR $ENV{CONDA_PREFIX})
    set(AWS_SDK_CPP_INSTALL_DIR $ENV{CONDA_PREFIX})
    set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} $ENV{CONDA_PREFIX}/lib/cmake)

endif ()

#########################################################################3
# - compiler stuff ------------------

set(BLAZINGSQL_IO_CXX_FLAGS "")
set(BLAZINGSQL_IO_CUDA_FLAGS "")
set(BLAZINGSQL_IO_CXX_DEFINITIONS "")
set(BLAZINGSQL_IO_CUDA_DEFINITIONS "")

list(APPEND BLAZINGSQL_IO_CXX_FLAGS -Wall -Wextra -Wno-unknown-pragmas -w)
list(APPEND BLAZINGSQL_IO_CUDA_FLAGS -w -Xcompiler=-w)

# set(CMAKE_CXX_STANDARD 17)
# set(CMAKE_CXX_STANDARD_REQUIRED ON)

# set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall -Wextra")

##############################################################################
# - dependencies -------------------------------------------------------------

# add third party dependencies using CPM
rapids_cpm_init()

# find absl
include(cmake/thirdparty/get_absl.cmake)
# find arrow
include(cmake/thirdparty/get_arrow.cmake)

# Include CMake modules
include(FeatureSummary)
include(CheckIncludeFiles)
include(CheckLibraryExists)
# include(CTest)

# TODO percy jp mario we don't need curl unless we use the storages
find_package(CURL REQUIRED)
# add_definitions( -DCURL_STATICLIB )
list(APPEND BLAZINGSQL_IO_CXX_DEFINITIONS CURL_STATICLIB)

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

set(FILESYSTEM_SRC_FILES
    ${PROJECT_SOURCE_DIR}/src/FileSystem/FileSystemType.cpp
    ${PROJECT_SOURCE_DIR}/src/FileSystem/Path.cpp
    ${PROJECT_SOURCE_DIR}/src/FileSystem/Uri.cpp
    ${PROJECT_SOURCE_DIR}/src/FileSystem/FileStatus.cpp
    ${PROJECT_SOURCE_DIR}/src/FileSystem/FileFilter.cpp
    ${PROJECT_SOURCE_DIR}/src/FileSystem/FileSystemConnection.cpp
    ${PROJECT_SOURCE_DIR}/src/FileSystem/FileSystemException.cpp
    ${PROJECT_SOURCE_DIR}/src/FileSystem/LocalFileSystem.cpp
    ${PROJECT_SOURCE_DIR}/src/FileSystem/HadoopFileSystem.cpp
    ${PROJECT_SOURCE_DIR}/src/FileSystem/FileSystemManager.cpp
    ${PROJECT_SOURCE_DIR}/src/FileSystem/FileSystemEntity.cpp
    ${PROJECT_SOURCE_DIR}/src/FileSystem/FileSystemRepository.cpp
    ${PROJECT_SOURCE_DIR}/src/FileSystem/private/LocalFileSystem_p.cpp
    ${PROJECT_SOURCE_DIR}/src/FileSystem/private/HadoopFileSystem_p.cpp
    ${PROJECT_SOURCE_DIR}/src/FileSystem/private/FileSystemManager_p.cpp
    ${PROJECT_SOURCE_DIR}/src/FileSystem/private/FileSystemFactory.cpp
    ${PROJECT_SOURCE_DIR}/src/FileSystem/private/FileSystemRepository_p.cpp)

set(LOGGING_SRC_FILES
    ${PROJECT_SOURCE_DIR}/src/Library/Logging/BlazingLogger.cpp
    ${PROJECT_SOURCE_DIR}/src/Library/Logging/CoutOutput.cpp
    ${PROJECT_SOURCE_DIR}/src/Library/Logging/FileOutput.cpp
    ${PROJECT_SOURCE_DIR}/src/Library/Logging/Logger.cpp
    ${PROJECT_SOURCE_DIR}/src/Library/Logging/LoggingLevel.cpp
    ${PROJECT_SOURCE_DIR}/src/Library/Logging/ServiceLogging.cpp
    ${PROJECT_SOURCE_DIR}/src/Library/Logging/TcpOutput.cpp)

set(EXCEPTION_SRC_FILES
    ${PROJECT_SOURCE_DIR}/src/ExceptionHandling/BlazingThread.cpp
    ${PROJECT_SOURCE_DIR}/src/ExceptionHandling/BlazingException.cpp
    ${PROJECT_SOURCE_DIR}/src/ExceptionHandling/BlazingExceptionHolder.cpp)

set(UTIL_SRC_FILES
    ${PROJECT_SOURCE_DIR}/src/Util/StringUtil.cpp
    ${PROJECT_SOURCE_DIR}/src/Util/EncryptionUtil.cpp
    ${PROJECT_SOURCE_DIR}/src/Util/FileUtil.cpp
    ${PROJECT_SOURCE_DIR}/src/Config/BlazingContext.cpp)

if(GCS_SUPPORT)
    add_definitions(-DGCS_SUPPORT)
    find_package(storage_client REQUIRED)
    set(GCS_FILESYSTEM_SRC_FILES
        ${PROJECT_SOURCE_DIR}/src/FileSystem/GoogleCloudStorage.cpp
        ${PROJECT_SOURCE_DIR}/src/FileSystem/private/GoogleCloudStorageReadableFile.cpp
        ${PROJECT_SOURCE_DIR}/src/FileSystem/private/GoogleCloudStorageOutputStream.cpp
        ${PROJECT_SOURCE_DIR}/src/FileSystem/private/GoogleCloudStorage_p.cpp)
    set(GCS_LIBRARY storage_client)
endif()

if(S3_SUPPORT)
    add_definitions(-DS3_SUPPORT)
    set(S3_FILESYSTEM_SRC_FILES
        ${PROJECT_SOURCE_DIR}/src/FileSystem/S3FileSystem.cpp
        ${PROJECT_SOURCE_DIR}/src/FileSystem/private/S3ReadableFile.cpp
        ${PROJECT_SOURCE_DIR}/src/FileSystem/private/S3OutputStream.cpp
        ${PROJECT_SOURCE_DIR}/src/FileSystem/private/S3FileSystem_p.cpp)
    set(S3_LIBRARY aws-cpp-sdk-core aws-cpp-sdk-s3 aws-cpp-sdk-s3-encryption)
endif()
# link_directories($ENV{CONDA_PREFIX}/lib)

add_library(blazingsql-io
    ${FILESYSTEM_SRC_FILES}
    ${GCS_FILESYSTEM_SRC_FILES}
    ${S3_FILESYSTEM_SRC_FILES}
    ${UTIL_SRC_FILES}
    ${LOGGING_SRC_FILES}
    ${EXCEPTION_SRC_FILES}
)

set_target_properties(blazingsql-io
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

target_compile_options(blazingsql-io
            PRIVATE "$<$<COMPILE_LANGUAGE:CXX>:${BLAZINGSQL_IO_CXX_FLAGS}>"
                    "$<$<COMPILE_LANGUAGE:CUDA>:${BLAZINGSQL_IO_CUDA_FLAGS}>"
)

target_compile_definitions(blazingsql-io
            PUBLIC "$<$<COMPILE_LANGUAGE:CXX>:${BLAZINGSQL_IO_CXX_DEFINITIONS}>"
                   "$<BUILD_INTERFACE:$<$<COMPILE_LANGUAGE:CUDA>:${BLAZINGSQL_IO_CUDA_DEFINITIONS}>>"
)

target_link_libraries(blazingsql-io
     PUBLIC ${ARROW_LIBRARIES}
    PRIVATE ${CURL_LIBRARIES}
            ${GCS_LIBRARY}
            ${S3_LIBRARY}
            absl::time
            absl::str_format_internal
            absl::strings
            absl::strings_internal
            absl::time_zone
            absl::base
            absl::int128
            absl::raw_logging_internal
            absl::spinlock_wait
            absl::bad_variant_access
            absl::civil_time
)

# target_include_directories(blazingsql-io
#     ${PROJECT_SOURCE_DIR}/src
#     $ENV{CONDA_PREFIX}/include
#     "${ARROW_INCLUDE_DIR}")

# Specify include paths for the current target and dependents
target_include_directories(blazingsql-io
           PUBLIC      "$<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}/src>"
                       "$<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/include>"
           PRIVATE     "$<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}/src>"
           INTERFACE   "$<INSTALL_INTERFACE:include>"
                       "$<INSTALL_INTERFACE:include/blazingdb/io>")

# Add Conda library paths if specified
if(CONDA_LINK_DIRS)
    target_link_directories(blazingsql-io PUBLIC "$<BUILD_INTERFACE:${CONDA_LINK_DIRS}>")
endif()

# Add Conda include paths if specified
if(CONDA_INCLUDE_DIRS)
    target_include_directories(blazingsql-io PUBLIC "$<BUILD_INTERFACE:${CONDA_INCLUDE_DIRS}>")
endif()

add_library(blazingdb::blazingsql-io ALIAS blazingsql-io)

# # Install target and headers
# install(TARGETS blazingsql-io DESTINATION lib)
# install(DIRECTORY ${PROJECT_SOURCE_DIR}/src/ DESTINATION include/blazingdb/io FILES_MATCHING PATTERN "*.h")

# # Tests
# if(BUILD_TESTING)
#     add_subdirectory(tests)
# endif()

###################################################################################################
# - install targets -------------------------------------------------------------------------------

set(BLAZINGSQL_IO_TARGETS
      blazingsql-io)

install(TARGETS
          ${BLAZINGSQL_IO_TARGETS}
        DESTINATION
          lib
        EXPORT
          blazingsql-io-exports)

file(COPY ${PROJECT_SOURCE_DIR}/src/
     DESTINATION ${CMAKE_CURRENT_BINARY_DIR}/include/blazingdb/io
     FILES_MATCHING PATTERN "*.h")

file(COPY ${PROJECT_SOURCE_DIR}/src/
     DESTINATION ${CMAKE_CURRENT_BINARY_DIR}/include/blazingdb/io
     FILES_MATCHING PATTERN "*.hpp")

install(DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/include/
        DESTINATION include)

##################################################################################################
# - install export -------------------------------------------------------------------------------
set(doc_string
[=[
Provide targets for BlazingSQL IO.

]=])

rapids_export(INSTALL blazingsql-io
    EXPORT_SET blazingsql-io-exports
    GLOBAL_TARGETS blazingsql-io
    NAMESPACE blazingdb::
    DOCUMENTATION doc_string
    )

################################################################################################
# - build export -------------------------------------------------------------------------------
set(code_string [=[
]=])

rapids_export(BUILD blazingsql-io
    EXPORT_SET blazingsql-io-exports
    GLOBAL_TARGETS blazingsql-io
    NAMESPACE blazingdb::
    DOCUMENTATION doc_string
    FINAL_CODE_BLOCK code_string
    )

# Print the project summary
feature_summary(WHAT ALL INCLUDE_QUIET_PACKAGES FATAL_ON_MISSING_REQUIRED_PACKAGES)

# if(CMAKE_EXPORT_COMPILE_COMMANDS)
#     # Create a symlink to compile_commands.json for the llvm-vs-code-extensions.vscode-clangd plugin
#     execute_process(COMMAND
#         ${CMAKE_COMMAND} -E create_symlink
#         ${CMAKE_CURRENT_BINARY_DIR}/compile_commands.json
#         ${CMAKE_CURRENT_SOURCE_DIR}/compile_commands.json)
# endif()
