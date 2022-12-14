# Designed to be included from an IDF app's CMakeLists.txt file
#
cmake_minimum_required(VERSION 3.5)

include(${CMAKE_CURRENT_LIST_DIR}/idf_functions.cmake)

# Set the path of idf.py.
set(IDFTOOL ${PYTHON} "${IDF_PATH}/tools/idf.py")

# Trick to temporarily redefine project(). When functions are overriden in CMake, the originals can still be accessed
# using an underscore prefixed function of the same name. The following lines make sure that __project  calls
# the original project(). See https://cmake.org/pipermail/cmake/2015-October/061751.html.
function(project)
endfunction()

function(_project)
endfunction()

macro(project name)

    # Bridge existing documented variable names with library namespaced
    # variables in order for old projects to work.

    if(COMPONENT_DIRS)
        spaces2list(COMPONENT_DIRS)

        foreach(component_dir ${COMPONENT_DIRS})
            get_filename_component(component_dir ${component_dir} ABSOLUTE BASE_DIR ${CMAKE_SOURCE_DIR})
            list(APPEND IDF_COMPONENT_DIRS "${component_dir}")
        endforeach()
    endif()

    if(NOT MAIN_SRCS)
        list(APPEND IDF_EXTRA_COMPONENT_DIRS "${CMAKE_SOURCE_DIR}/main")
    endif()

    list(APPEND IDF_EXTRA_COMPONENT_DIRS "${CMAKE_SOURCE_DIR}/components")

    if(EXTRA_COMPONENT_DIRS)
        spaces2list(EXTRA_COMPONENT_DIRS)

        foreach(component_dir ${EXTRA_COMPONENT_DIRS})
            get_filename_component(component_dir ${component_dir} ABSOLUTE BASE_DIR ${CMAKE_SOURCE_DIR})
            list(APPEND IDF_EXTRA_COMPONENT_DIRS "${component_dir}")
        endforeach()
    endif()

    if(COMPONENTS)
        set(IDF_COMPONENTS "${COMPONENTS}")
    endif()

    if(COMPONENT_REQUIRES_COMMON)
        set(IDF_COMPONENT_REQUIRES_COMMON "${COMPONENT_REQUIRES_COMMON}")
    endif()

    if(EXCLUDE_COMPONENTS)
        set(IDF_EXCLUDE_COMPONENTS "${COMPONENT_EXCLUDES}")
    endif()

    if(TESTS_ALL EQUAL 1 OR TEST_COMPONENTS)
        set(IDF_BUILD_TESTS 1)
    endif()

    if(TEST_COMPONENTS)
        set(IDF_TEST_COMPONENTS "${TEST_COMPONENTS}")
    endif()

    if(TEST_EXCLUDE_COMPONENTS)
        set(IDF_TEST_EXCLUDE_COMPONENTS "${TEST_EXCLUDE_COMPONENTS}")
    endif()

    if(NOT SDKCONFIG_DEFAULTS)
        if(EXISTS ${CMAKE_SOURCE_DIR}/sdkconfig.defaults)
            set(IDF_SDKCONFIG_DEFAULTS ${CMAKE_SOURCE_DIR}/sdkconfig.defaults)
        endif()
    else()
        set(IDF_SDKCONFIG_DEFAULTS ${SDKCONFIG_DEFAULTS})
    endif()
    message(STATUS "SDKCONFIG_DEFAULTS:${SDKCONFIG_DEFAULTS}")
    # Set build variables
    idf_set_variables()

    # Now the configuration is loaded, set the toolchain appropriately
    idf_set_toolchain()

    # Enable ccache if it's on the path
    if(NOT CCACHE_DISABLE)
        find_program(CCACHE_FOUND ccache)
        if(CCACHE_FOUND)
            message(STATUS "ccache will be used for faster builds")
            set_property(GLOBAL PROPERTY RULE_LAUNCH_COMPILE ccache)
        endif()
    endif()

    __project(${name} C CXX ASM)

    set(IDF_BUILD_ARTIFACTS ON)
    set(IDF_PROJECT_EXECUTABLE ${CMAKE_PROJECT_NAME}.elf)
    set(IDF_BUILD_ARTIFACTS_DIR ${CMAKE_BINARY_DIR})

    if(MAIN_SRCS)
        spaces2list(MAIN_SRCS)
        add_executable(${IDF_PROJECT_EXECUTABLE} ${MAIN_SRCS})
    else()
        # Create a dummy file to work around CMake requirement of having a source
        # file while adding an executable
        add_executable(${IDF_PROJECT_EXECUTABLE} "${CMAKE_CURRENT_BINARY_DIR}/dummy_main_src.c")
        add_custom_command(OUTPUT dummy_main_src.c
            COMMAND ${CMAKE_COMMAND} -E touch dummy_main_src.c
            WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
            VERBATIM)

        add_custom_target(dummy_main_src DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/dummy_main_src.c)

        add_dependencies(${IDF_PROJECT_EXECUTABLE} dummy_main_src)
    endif()

    set(mapfile "${CMAKE_PROJECT_NAME}.map")

    target_link_libraries(${IDF_PROJECT_EXECUTABLE} "-Wl,--cref -Wl,--Map=${mapfile}")

    set_property(DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}" APPEND PROPERTY
        ADDITIONAL_MAKE_CLEAN_FILES
        "${CMAKE_CURRENT_BINARY_DIR}/${mapfile}")

    # Add size targets, depend on map file, run idf_size.py
    add_custom_target(size
        DEPENDS ${exe_target}
        COMMAND ${PYTHON} ${IDF_PATH}/tools/idf_size.py ${mapfile}
        )
    add_custom_target(size-files
        DEPENDS ${exe_target}
        COMMAND ${PYTHON} ${IDF_PATH}/tools/idf_size.py --files ${mapfile}
        )
    add_custom_target(size-components
        DEPENDS ${exe_target}
        COMMAND ${PYTHON} ${IDF_PATH}/tools/idf_size.py --archives ${mapfile}
        )

    # Since components can import third-party libraries, the original definition of project() should be restored
    # before the call to add components to the build.
    function(project)
        set(project_ARGV ARGV)
        __project(${${project_ARGV}})

        # Set the variables that project() normally sets, documented in the
        # command's docs.
        #
        # https://cmake.org/cmake/help/v3.5/command/project.html
        #
        # There is some nuance when it comes to setting version variables in terms of whether
        # CMP0048 is set to OLD or NEW. However, the proper behavior should have bee already handled by the original
        # project call, and we're just echoing the values those variables were set to.
        set(PROJECT_NAME "${PROJECT_NAME}" PARENT_SCOPE)
        set(PROJECT_BINARY_DIR "${PROJECT_BINARY_DIR}" PARENT_SCOPE)
        set(PROJECT_SOURCE_DIR "${PROJECT_SOURCE_DIR}" PARENT_SCOPE)
        set(PROJECT_VERSION "${PROJECT_VERSION}" PARENT_SCOPE)
        set(PROJECT_VERSION_MAJOR "${PROJECT_VERSION_MAJOR}" PARENT_SCOPE)
        set(PROJECT_VERSION_MINOR "${PROJECT_VERSION_MINOR}" PARENT_SCOPE)
        set(PROJECT_VERSION_PATCH "${PROJECT_VERSION_PATCH}" PARENT_SCOPE)
        set(PROJECT_VERSION_TWEAK "${PROJECT_VERSION_TWEAK}" PARENT_SCOPE)

        set(${PROJECT_NAME}_BINARY_DIR "${${PROJECT_NAME}_BINARY_DIR}" PARENT_SCOPE)
        set(${PROJECT_NAME}_SOURCE_DIR "${${PROJECT_NAME}_SOURCE_DIR}" PARENT_SCOPE)
        set(${PROJECT_NAME}_VERSION "${${PROJECT_NAME}_VERSION}" PARENT_SCOPE)
        set(${PROJECT_NAME}_VERSION_MAJOR "${${PROJECT_NAME}_VERSION_MAJOR}" PARENT_SCOPE)
        set(${PROJECT_NAME}_VERSION_MINOR "${${PROJECT_NAME}_VERSION_MINOR}" PARENT_SCOPE)
        set(${PROJECT_NAME}_VERSION_PATCH "${${PROJECT_NAME}_VERSION_PATCH}" PARENT_SCOPE)
        set(${PROJECT_NAME}_VERSION_TWEAK "${${PROJECT_NAME}_VERSION_TWEAK}" PARENT_SCOPE)
    endfunction()
    message(STATUS "IDF_PROJECT_EXECUTABLE:${IDF_PROJECT_EXECUTABLE}")
    # Finally, add the rest of the components to the build.
    idf_import_components(components $ENV{IDF_PATH} esp-idf)
    idf_link_components(${IDF_PROJECT_EXECUTABLE} "${components}")
endmacro()
