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

function(find_and_configure_cudf VERSION BUILD_STATIC ENABLE_S3 ENABLE_ORC ENABLE_PYTHON)

    if(TARGET cudf::cudf)
        return()
    endif()

    if(${VERSION} MATCHES [=[([0-9]+)\.([0-9]+)\.([0-9]+)]=])
        set(MAJOR_AND_MINOR "${CMAKE_MATCH_1}.${CMAKE_MATCH_2}")
    else()
        set(MAJOR_AND_MINOR "${VERSION}")
    endif()

    rapids_cpm_find(cudf ${VERSION}
        GLOBAL_TARGETS         "cudf::cudf;cudf::cudftestutil"
        BUILD_EXPORT_SET       blazingsql-engine-exports
        INSTALL_EXPORT_SET     blazingsql-engine-exports
        CPM_ARGS
            GIT_REPOSITORY         https://github.com/rapidsai/cudf.git
            GIT_TAG                branch-${MAJOR_AND_MINOR}
            GIT_SHALLOW            TRUE
            SOURCE_SUBDIR          cpp
            OPTIONS                "BUILD_TESTS OFF"
                                   "BUILD_BENCHMARKS OFF"
                                   "CUDF_USE_ARROW_STATIC ${BUILD_STATIC}"
                                   "CUDF_ENABLE_ARROW_S3 ${ENABLE_S3}"
                                   "CUDF_ENABLE_ARROW_ORC ${ENABLE_ORC}"
                                   "CUDF_ENABLE_ARROW_PYTHON ${ENABLE_PYTHON}"
                                   "CUDF_ENABLE_ARROW_PARQUET ON"
                                   "DISABLE_DEPRECATION_WARNING ${DISABLE_DEPRECATION_WARNING}"
            FIND_PACKAGE_ARGUMENTS "COMPONENTS testing"
    )
endfunction()

set(BLAZINGSQL_ENGINE_MIN_VERSION_cudf "${BLAZINGSQL_ENGINE_VERSION_MAJOR}.${BLAZINGSQL_ENGINE_VERSION_MINOR}.00")

find_and_configure_cudf(
    ${BLAZINGSQL_ENGINE_MIN_VERSION_cudf}
    ${BLAZINGSQL_ENGINE_USE_ARROW_STATIC}
    ${S3_SUPPORT}
    ${BLAZINGSQL_ENGINE_BUILD_ARROW_ORC}
    ${BLAZINGSQL_ENGINE_BUILD_ARROW_PYTHON}
)
