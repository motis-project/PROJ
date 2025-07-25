################################################################################
#
# This file is part of CMake configuration for PROJ library (inspired from SOCI
# CMake,  Copyright (C) 2009-2010 Mateusz Loskot <mateusz@loskot.net> )
#
# Copyright (C) 2011 Nicolas David <nicolas.david@ign.fr>
# Distributed under the MIT license
#
################################################################################
# General settings
################################################################################
cmake_minimum_required(VERSION 3.16)

project(PROJ
  DESCRIPTION "PROJ coordinate transformation software library"
  LANGUAGES C CXX
)

# Only interpret if() arguments as variables or keywords when unquoted
cmake_policy(SET CMP0054 NEW)

# Set C++ version
# Make CMAKE_CXX_STANDARD available as cache option overridable by user
set(CMAKE_CXX_STANDARD 17
  CACHE STRING "C++ standard version to use (default is 17)")
message(STATUS "Requiring C++${CMAKE_CXX_STANDARD}")
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
message(STATUS "Requiring C++${CMAKE_CXX_STANDARD} - done")

# Set C99 version
# Make CMAKE_C_STANDARD available as cache option overridable by user
set(CMAKE_C_STANDARD 99
  CACHE STRING "C standard version to use (default is 99)")
message(STATUS "Requiring C${CMAKE_C_STANDARD}")
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS OFF)
message(STATUS "Requiring C${CMAKE_C_STANDARD} - done")

# Set global -fvisibility=hidden
set(CMAKE_C_VISIBILITY_PRESET hidden)
set(CMAKE_CXX_VISIBILITY_PRESET hidden)

# Set warnings as variables, then store as cache options
set(PROJ_common_WARN_FLAGS  # common only to GNU/Clang C/C++
  -Wall
  -Wdate-time
  -Werror=format-security
  -Werror=vla
  -Wextra
  -Wformat
  -Wmissing-declarations
  -Wshadow
  -Wswitch
  -Wunused-parameter
)
if("${CMAKE_C_COMPILER_ID}" STREQUAL "GNU")
  set(PROJ_common_WARN_FLAGS ${PROJ_common_WARN_FLAGS}
    -Wduplicated-cond
    -Wduplicated-branches
    -Wlogical-op
    -Wimplicit-fallthrough
  )
  set(PROJ_C_WARN_FLAGS ${PROJ_common_WARN_FLAGS}
    -Wmissing-prototypes
  )
  if (CMAKE_CXX_COMPILER_VERSION VERSION_GREATER_EQUAL 8)
        set(PROJ_CXX_WARN_FLAGS ${PROJ_common_WARN_FLAGS} -Wextra-semi)
  endif()
  set(PROJ_CXX_WARN_FLAGS ${PROJ_common_WARN_FLAGS}
    -Weffc++
    # -Wold-style-cast
    -Woverloaded-virtual
    -Wzero-as-null-pointer-constant
    -Wdeprecated-copy-dtor
  )
elseif("${CMAKE_C_COMPILER_ID}" MATCHES "Clang")
  set(PROJ_common_WARN_FLAGS ${PROJ_common_WARN_FLAGS}
    -Wcomma
    -Wdeprecated
    -Wdocumentation -Wno-documentation-deprecated-sync
    -Wfloat-conversion
    -Wlogical-op-parentheses
    -Wimplicit-fallthrough
  )

  # Not sure about the minimum version, but clang 12 complains about \file, @cond Doxygen_Suppress, etc.
  if("${CMAKE_CXX_COMPILER_VERSION}" VERSION_GREATER_EQUAL 18.0.0)
      set(PROJ_common_WARN_FLAGS ${PROJ_common_WARN_FLAGS} -Wdocumentation-unknown-command)
  endif()

  set(PROJ_C_WARN_FLAGS ${PROJ_common_WARN_FLAGS}
    -Wmissing-prototypes
    -Wc11-extensions
  )
  set(PROJ_CXX_WARN_FLAGS ${PROJ_common_WARN_FLAGS}
    -Weffc++
    -Wextra-semi
    # -Wold-style-cast
    -Woverloaded-virtual
    -Wshorten-64-to-32
    -Wunused-private-field
    -Wzero-as-null-pointer-constant
    -Wdeprecated-copy-dtor
    -Wweak-vtables
  )
elseif("${CMAKE_C_COMPILER_ID}" STREQUAL "MSVC")
  add_definitions(/D_CRT_SECURE_NO_WARNINGS) # Eliminate deprecation warnings
  set(PROJ_C_WARN_FLAGS
    /W4
    /wd4706  # Suppress warning about assignment within conditional expression
    /wd4996  # Suppress warning about sprintf, etc., being unsafe
  )
  if("$ENV{VSCMD_ARG_TGT_ARCH}" STREQUAL "arm64")
    # Suppress an inaccurate warning when compiling for an MSVC/ARM64 platform
    # It incorrectly assumes a division by zero is possible despite a check
    set(PROJ_C_WARN_FLAGS ${PROJ_C_WARN_FLAGS} /wd4723)
  endif()
  set(PROJ_CXX_WARN_FLAGS /EHsc ${PROJ_C_WARN_FLAGS})
elseif("${CMAKE_C_COMPILER_ID}" STREQUAL "Intel")
  if(MSVC)
    set(PROJ_C_WARN_FLAGS /Wall)
    set(PROJ_CXX_WARN_FLAGS /Wall)
  else()
    set(PROJ_C_WARN_FLAGS -Wall)
    set(PROJ_CXX_WARN_FLAGS -Wall)
  endif()
endif()

if (CMAKE_CXX_COMPILER_ID STREQUAL "IntelLLVM")
  # Intel CXX compiler based on clang defaults to -ffast-math, which
  # breaks std::isinf(), std::isnan(), etc.
  set(CMAKE_C_FLAGS ${CMAKE_C_FLAGS} -fno-fast-math)
  set(CMAKE_CXX_FLAGS ${CMAKE_CXX_FLAGS} -fno-fast-math)
endif ()

set(PROJ_C_WARN_FLAGS "${PROJ_C_WARN_FLAGS}"
  CACHE STRING "C flags used to compile PROJ targets")
set(PROJ_CXX_WARN_FLAGS "${PROJ_CXX_WARN_FLAGS}"
  CACHE STRING "C++ flags used to compile PROJ targets")

################################################################################
# PROJ CMake modules
################################################################################
# Path to additional CMake modules
set(CMAKE_MODULE_PATH ${PROJ_SOURCE_DIR}/cmake ${CMAKE_MODULE_PATH})

include(ProjUtilities)

message(STATUS "Configuring PROJ:")

################################################################################
#PROJ version information
################################################################################
include(ProjVersion)
proj_version(MAJOR 9 MINOR 7 PATCH 0)
set(PROJ_SOVERSION 25)
set(PROJ_BUILD_VERSION "${PROJ_SOVERSION}.${PROJ_VERSION}")

################################################################################
# Build features and variants
################################################################################

#include(Ccache)
include(ProjConfig)
include(ProjMac)
include(policies)

##############################################
### SWITCH BETWEEN STATIC OR SHARED LIBRARY###
##############################################

# default config is shared
option(BUILD_SHARED_LIBS "Build PROJ library shared." OFF)

################################################################################
# pkg dependencies
################################################################################

include(cmake/pkg.cmake)

set(NLOHMANN_JSON "external")

################################################################################
# Check for sqlite3
################################################################################

# Would build and run with older versions, but with horrible performance
# See https://github.com/OSGeo/PROJ/issues/1718
if(SQLite3_VERSION VERSION_LESS "3.11")
  message(SEND_ERROR "SQLite3 >= 3.11 required!")
endif()

################################################################################
# Check for libtiff
################################################################################

option(ENABLE_TIFF "Enable TIFF support to read some grids" OFF)
mark_as_advanced(ENABLE_TIFF)
set(TIFF_ENABLED FALSE)
if(ENABLE_TIFF)
  find_package(TIFF REQUIRED)
  if(TIFF_FOUND)
    set(TIFF_ENABLED TRUE)
  else()
    message(SEND_ERROR
      "libtiff dependency not found! Use ENABLE_TIFF=OFF to force it off")
  endif()
else()
  message(WARNING
    "TIFF support is not enabled and will result in the inability to read "
    "some grids")
endif()

################################################################################
# Check for curl
################################################################################

option(ENABLE_CURL "Enable Curl support" OFF)
set(CURL_ENABLED FALSE)
if(ENABLE_CURL)
  find_package(CURL REQUIRED)
  if(CURL_FOUND)
    set(CURL_ENABLED TRUE)

    # Curl SSL options are described in
    #   https://curl.se/libcurl/c/CURLOPT_SSL_OPTIONS.html
    #set(CURLSSLOPT_NO_REVOKE 2)
    #set(SSL_OPTIONS ${CURLSSLOPT_NO_REVOKE})
    #add_compile_definitions(SSL_OPTIONS=${SSL_OPTIONS})

  else()
    message(SEND_ERROR "curl dependency not found!")
  endif()
endif()

################################################################################

option(EMBED_PROJ_DATA_PATH "Whether the PROJ_DATA_PATH should be embedded" ON)

if(DEFINED PROJ_LIB_ENV_VAR_TRIED_LAST)
  set(PROJ_DATA_ENV_VAR_TRIED_LAST ${PROJ_LIB_ENV_VAR_TRIED_LAST})
  message(WARNING "PROJ_LIB_ENV_VAR_TRIED_LAST option has been renamed to PROJ_DATA_ENV_VAR_TRIED_LAST. PROJ_LIB_ENV_VAR_TRIED_LAST is still working for now, but may be completely replaced by PROJ_DATA_ENV_VAR_TRIED_LAST in a future release")
else()
  option(PROJ_DATA_ENV_VAR_TRIED_LAST "Whether the PROJ_DATA environment variable should be tried after the hardcoded location" OFF)
endif()
if(PROJ_DATA_ENV_VAR_TRIED_LAST)
    add_definitions(-DPROJ_DATA_ENV_VAR_TRIED_LAST)
endif()

################################################################################
# threading configuration
################################################################################
set(CMAKE_THREAD_PREFER_PTHREAD TRUE)
find_package(Threads)
if(Threads_FOUND AND CMAKE_USE_PTHREADS_INIT)
  set(CMAKE_REQUIRED_LIBRARIES
    "${CMAKE_REQUIRED_LIBRARIES} ${CMAKE_THREAD_LIBS_INIT}")
endif()

# Set a default build type for single-configuration cmake generators if
# no build type is set.
if(NOT CMAKE_CONFIGURATION_TYPES AND NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release)
endif()

if(MSVC OR CMAKE_CONFIGURATION_TYPES)
  # For multi-config systems and for Visual Studio, the debug version of
  # the library has _d appended.
  set(CMAKE_DEBUG_POSTFIX _d)
endif()

# Put the libraries and binaries that get built into directories at the
# top of the build tree rather than in hard-to-find leaf
# directories. This simplifies manual testing and the use of the build
# tree rather than installed PROJ libraries.
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${PROJ_BINARY_DIR}/lib)
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${PROJ_BINARY_DIR}/lib)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${PROJ_BINARY_DIR}/bin)
link_directories(${CMAKE_LIBRARY_OUTPUT_DIRECTORY})

################################################################################
# Installation
################################################################################
include(ProjInstallPath)

# By default GNUInstallDirs will use the upper case project name
# for CMAKE_INSTALL_DOCDIR, resulting in something like share/doc/PROJ
# instead of share/doc/proj which historically have been the path used
# by the project.
# Here force the use of a lower case project name and reset after
# GNUInstallDirs has done its thing
set(PROJECT_NAME_ORIGINAL "${PROJECT_NAME}")
string(TOLOWER "${PROJECT_NAME}" PROJECT_NAME)

include(GNUInstallDirs)

set(PROJECT_NAME "${PROJECT_NAME_ORIGINAL}")

set(PROJ_DATA_PATH "${CMAKE_INSTALL_FULL_DATADIR}/proj")

################################################################################
# Tests
################################################################################

#option(BUILD_TESTING "Build the testing tree." OFF)
#if(BUILD_TESTING)
#  enable_testing()
#  include(ProjTest)
#else()
#  message(STATUS "Testing disabled")
#endif()

################################################################################
# Whether we should embed resources
################################################################################

function (is_sharp_embed_available res)
    if (CMAKE_VERSION VERSION_GREATER_EQUAL 3.21 AND
        ((CMAKE_C_COMPILER_ID STREQUAL "GNU" AND CMAKE_C_COMPILER_VERSION VERSION_GREATER_EQUAL 15.0) OR
         (CMAKE_C_COMPILER_ID STREQUAL "Clang" AND CMAKE_C_COMPILER_VERSION VERSION_GREATER_EQUAL 19.0)))
        # CMAKE_C_STANDARD=23 only supported since CMake 3.21
        set(TEST_SHARP_EMBED
          "static const unsigned char embedded[] = {\n#embed __FILE__\n};\nint main() { (void)embedded; return 0;}"
        )
        set(CMAKE_C_STANDARD_BACKUP "${CMAKE_C_STANDARD}")
        set(CMAKE_C_STANDARD "23")
        check_c_source_compiles("${TEST_SHARP_EMBED}" _TEST_SHARP_EMBED)
        set(CMAKE_C_STANDARD "${CMAKE_C_STANDARD_BACKUP}")
        if (_TEST_SHARP_EMBED)
            set(${res} ON PARENT_SCOPE)
        else()
            set(${res} OFF PARENT_SCOPE)
        endif()
    else()
        set(${res} OFF PARENT_SCOPE)
    endif()
endfunction()

is_sharp_embed_available(IS_SHARP_EMBED_AVAILABLE_RES)
if (NOT DEFINED BUILD_SHARED_LIBS)
    message(FATAL_ERROR "BUILD_SHARED_LIBS should be set")
endif()
if (NOT BUILD_SHARED_LIBS)
    set(DEFAULT_EMBED_RESOURCE_FILES ON)
else()
    set(DEFAULT_EMBED_RESOURCE_FILES OFF)
endif()
option(EMBED_RESOURCE_FILES "Whether resource files (limited to proj.db) should be embedded into the PROJ library" ${DEFAULT_EMBED_RESOURCE_FILES})

option(USE_ONLY_EMBEDDED_RESOURCE_FILES "Whether embedded resource files (limited to proj.db) should be used (should nominally be used together with EMBED_RESOURCE_FILES=ON, otherwise this will result in non-functional builds)" OFF)

if (USE_ONLY_EMBEDDED_RESOURCE_FILES AND NOT EMBED_RESOURCE_FILES)
  message(WARNING "USE_ONLY_EMBEDDED_RESOURCE_FILES=ON set but EMBED_RESOURCE_FILES=OFF: some drivers will lack required resource files")
endif()

################################################################################
# Build configured components
################################################################################

set(PROJ_DICTIONARY
  world
  other.extra
  nad27
  GL27
  nad83
  nad.lst
  CH
  ITRF2000
  ITRF2008
  ITRF2014
  ITRF2020
)

include_directories(${PROJ_SOURCE_DIR}/src)

add_subdirectory(data)
add_subdirectory(include)
add_subdirectory(src)
#add_subdirectory(man)
#add_subdirectory(cmake)
#if(BUILD_TESTING)
#  add_subdirectory(test)
#endif()

option(BUILD_EXAMPLES "Whether to build example programs" OFF)
if(BUILD_EXAMPLES)
  add_subdirectory(examples)
endif()

#add_subdirectory(scripts)

set(docfiles COPYING NEWS.md AUTHORS.md)
install(FILES ${docfiles}
        DESTINATION ${CMAKE_INSTALL_DOCDIR})

################################################################################
# Build debug symbols
################################################################################
option(EXPORT_PDB "Export PDB file" OFF)

if (WIN32 AND EXPORT_PDB)
  target_compile_options(proj PRIVATE /Zi /Zf)
  target_link_options(proj PRIVATE /DEBUG /OPT:REF /OPT:ICF)

  if(BUILD_SHARED_LIBS)
    set(pdbFile $<TARGET_PDB_FILE:proj>)
  else()
    set(pdbDirFullPath ${CMAKE_BINARY_DIR}/lib)
    set_target_properties(proj
        PROPERTIES
            COMPILE_PDB_OUTPUT_DIRECTORY ${pdbDirFullPath}
            COMPILE_PDB_NAME proj)
    set(pdbFile ${pdbDirFullPath}/proj.pdb)
  endif()

  install(FILES ${pdbFile} DESTINATION lib)
endif()

message(STATUS "EMBED_RESOURCE_FILES=${EMBED_RESOURCE_FILES}")
