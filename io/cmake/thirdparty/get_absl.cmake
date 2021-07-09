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

function(find_and_configure_abseil VERSION)

    if(TARGET absl::time)
        return()
    endif()

    rapids_cpm_find(absl   ${VERSION}
        GLOBAL_TARGETS     absl::time
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
        BUILD_EXPORT_SET   blazingsql-io-exports
        INSTALL_EXPORT_SET blazingsql-io-exports
        CPM_ARGS
            GIT_REPOSITORY https://github.com/abseil/abseil-cpp.git
            GIT_TAG        ${VERSION}
            GIT_SHALLOW    TRUE
            OPTIONS        "BUILD_TESTING OFF"
                           "ABSL_ENABLE_INSTALL ON"
    )

    rapids_export(BUILD absl EXPORT_SET abslTargets)

endfunction()

set(BLAZINGSQL_ENGINE_MIN_VERSION_abseil "20210324.2")

find_and_configure_abseil(${BLAZINGSQL_ENGINE_MIN_VERSION_abseil})
