# Copyright (c) 2021, NVIDIA CORPORATION.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except
# in compliance with the License. You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License
# is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express
# or implied. See the License for the specific language governing permissions and limitations under
# the License.

# Generate version_config.hpp from the version found in CMakeLists.txt
function(write_version)
  function(_exec_git OUT_VAR)
      execute_process(COMMAND git ${ARGN}
                      WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
                      OUTPUT_VARIABLE RET_VAL
                      OUTPUT_STRIP_TRAILING_WHITESPACE)
      set(${OUT_VAR} ${RET_VAL} PARENT_SCOPE)
  endfunction()

  _exec_git(BLAZINGSQL_GIT_BRANCH rev-parse --abbrev-ref HEAD)
  _exec_git(BLAZINGSQL_GIT_COMMIT_HASH log -1 --format=%H)
  _exec_git(BLAZINGSQL_GIT_DESCRIBE_TAG describe --abbrev=0 --tags)
  _exec_git(BLAZINGSQL_GIT_DESCRIBE_NUMBER rev-list ${BLAZINGSQL_GIT_DESCRIBE_TAG}..HEAD --count)

  message(STATUS "BLAZINGSQL_ENGINE VERSION: ${BLAZINGSQL_ENGINE_VERSION}")
  message(STATUS "BLAZINGSQL_GIT_BRANCH: ${BLAZINGSQL_GIT_BRANCH}")
  message(STATUS "BLAZINGSQL_GIT_COMMIT_HASH: ${BLAZINGSQL_GIT_COMMIT_HASH}")
  message(STATUS "BLAZINGSQL_GIT_DESCRIBE_TAG: ${BLAZINGSQL_GIT_DESCRIBE_TAG}")
  message(STATUS "BLAZINGSQL_GIT_DESCRIBE_NUMBER: ${BLAZINGSQL_GIT_DESCRIBE_NUMBER}")

  configure_file(${CMAKE_CURRENT_SOURCE_DIR}/cmake/version_config.hpp.in
                 ${CMAKE_CURRENT_BINARY_DIR}/include/blazingdb/engine/version_config.hpp @ONLY)
endfunction(write_version)
