#=============================================================================
# Copyright 2018 BlazingDB, Inc.
#     Copyright 2018 Percy Camilo Triveño Aucahuasi <percy@blazingdb.com>
#=============================================================================

#pass the dependency libraries as optional arguments using ${ARGN}
#NOTE the order of libraries matter, so try to link first with the most high level lib
function(configure_test TEST_NAME Tests_SRCS)
    add_executable(${TEST_NAME} ${Tests_SRCS})

    target_link_directories(${TEST_NAME} PRIVATE $ENV{CONDA_PREFIX}/lib)
    target_include_directories(${TEST_NAME} PRIVATE $ENV{CONDA_PREFIX}/include)
    target_link_libraries(${TEST_NAME} PRIVATE
        GTest::gtest_main
        GTest::gmock_main
        blazingdb::blazingsql-io
        ${S3_LIBRARY}
        ${GCS_LIBRARY}
        # arrow

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

    set_target_properties(${TEST_NAME} PROPERTIES
        RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/gtests/")

    #register the target as CMake test so we can use ctest for this executable
    add_test(NAME ${TEST_NAME} COMMAND ${TEST_NAME})
endfunction()

## Main ##

enable_testing()

set(GTEST_BOTH_LIBRARIES GTest::gtest_main GTest::gtest)
set(GMOCK_BOTH_LIBRARIES GTest::gmock_main GTest::gmock)

# Configure unit tests with Google Test
# -------------------
message(STATUS "******** Configuring tests ********")

# TODO percy fix tests
add_subdirectory(ExceptionHandling)
add_subdirectory(FileSystem)
#add_subdirectory(Library)
add_subdirectory(Util)

message(STATUS "******** Tests are ready ********")
