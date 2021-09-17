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

function(find_and_configure_blazingsql_io VERSION BUILD_STATIC ENABLE_S3 ENABLE_GCS ENABLE_ORC ENABLE_PYTHON)

    if(TARGET blazingdb::blazingsql-io)
        return()
    endif()

    if(${VERSION} MATCHES [=[([0-9]+)\.([0-9]+)\.([0-9]+)]=])
        set(MAJOR_AND_MINOR "${CMAKE_MATCH_1}.${CMAKE_MATCH_2}")
    else()
        set(MAJOR_AND_MINOR "${VERSION}")
    endif()

    rapids_cpm_find(blazingsql-io ${VERSION}
        GLOBAL_TARGETS         blazingdb::blazingsql-io
        BUILD_EXPORT_SET       blazingsql-engine-exports
        INSTALL_EXPORT_SET     blazingsql-engine-exports
        CPM_ARGS
            GIT_REPOSITORY         https://github.com/BlazingDB/blazingsql.git
            GIT_TAG                branch-${MAJOR_AND_MINOR}
            GIT_SHALLOW            TRUE
            SOURCE_SUBDIR          io
            OPTIONS                "BUILD_TESTS OFF"
                                   "BUILD_BENCHMARKS OFF"
                                   "S3_SUPPORT ${ENABLE_S3}"
                                   "GCS_SUPPORT ${ENABLE_GCS}"
                                   "BLAZINGSQL_IO_USE_ARROW_STATIC ${BUILD_STATIC}"
                                   "BLAZINGSQL_IO_BUILD_ARROW_ORC ${ENABLE_ORC}"
                                   "BLAZINGSQL_IO_BUILD_ARROW_PYTHON ${ENABLE_PYTHON}"
    )
endfunction()

set(BLAZINGSQL_ENGINE_MIN_VERSION_blazingsql_io "${BLAZINGSQL_ENGINE_VERSION_MAJOR}.${BLAZINGSQL_ENGINE_VERSION_MINOR}.00")

find_and_configure_blazingsql_io(
    ${BLAZINGSQL_ENGINE_MIN_VERSION_blazingsql_io}
    ${BLAZINGSQL_ENGINE_USE_ARROW_STATIC}
    ${S3_SUPPORT}
    ${GCS_SUPPORT}
    ${BLAZINGSQL_ENGINE_BUILD_ARROW_ORC}
    ${BLAZINGSQL_ENGINE_BUILD_ARROW_PYTHON}
)
