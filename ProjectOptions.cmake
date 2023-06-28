include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(insteonlib_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)
    set(SUPPORTS_UBSAN ON)
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(insteonlib_setup_options)
  option(insteonlib_ENABLE_HARDENING "Enable hardening" ON)
  option(insteonlib_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    insteonlib_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    insteonlib_ENABLE_HARDENING
    OFF)

  insteonlib_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR insteonlib_PACKAGING_MAINTAINER_MODE)
    option(insteonlib_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(insteonlib_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(insteonlib_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(insteonlib_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(insteonlib_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(insteonlib_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(insteonlib_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(insteonlib_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(insteonlib_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(insteonlib_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(insteonlib_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(insteonlib_ENABLE_PCH "Enable precompiled headers" OFF)
    option(insteonlib_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(insteonlib_ENABLE_IPO "Enable IPO/LTO" ON)
    option(insteonlib_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(insteonlib_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(insteonlib_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(insteonlib_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(insteonlib_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(insteonlib_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(insteonlib_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(insteonlib_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(insteonlib_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(insteonlib_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(insteonlib_ENABLE_PCH "Enable precompiled headers" OFF)
    option(insteonlib_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      insteonlib_ENABLE_IPO
      insteonlib_WARNINGS_AS_ERRORS
      insteonlib_ENABLE_USER_LINKER
      insteonlib_ENABLE_SANITIZER_ADDRESS
      insteonlib_ENABLE_SANITIZER_LEAK
      insteonlib_ENABLE_SANITIZER_UNDEFINED
      insteonlib_ENABLE_SANITIZER_THREAD
      insteonlib_ENABLE_SANITIZER_MEMORY
      insteonlib_ENABLE_UNITY_BUILD
      insteonlib_ENABLE_CLANG_TIDY
      insteonlib_ENABLE_CPPCHECK
      insteonlib_ENABLE_COVERAGE
      insteonlib_ENABLE_PCH
      insteonlib_ENABLE_CACHE)
  endif()

  insteonlib_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (insteonlib_ENABLE_SANITIZER_ADDRESS OR insteonlib_ENABLE_SANITIZER_THREAD OR insteonlib_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(insteonlib_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(insteonlib_global_options)
  if(insteonlib_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    insteonlib_enable_ipo()
  endif()

  insteonlib_supports_sanitizers()

  if(insteonlib_ENABLE_HARDENING AND insteonlib_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR insteonlib_ENABLE_SANITIZER_UNDEFINED
       OR insteonlib_ENABLE_SANITIZER_ADDRESS
       OR insteonlib_ENABLE_SANITIZER_THREAD
       OR insteonlib_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${insteonlib_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${insteonlib_ENABLE_SANITIZER_UNDEFINED}")
    insteonlib_enable_hardening(insteonlib_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(insteonlib_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(insteonlib_warnings INTERFACE)
  add_library(insteonlib_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  insteonlib_set_project_warnings(
    insteonlib_warnings
    ${insteonlib_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(insteonlib_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    configure_linker(insteonlib_options)
  endif()

  include(cmake/Sanitizers.cmake)
  insteonlib_enable_sanitizers(
    insteonlib_options
    ${insteonlib_ENABLE_SANITIZER_ADDRESS}
    ${insteonlib_ENABLE_SANITIZER_LEAK}
    ${insteonlib_ENABLE_SANITIZER_UNDEFINED}
    ${insteonlib_ENABLE_SANITIZER_THREAD}
    ${insteonlib_ENABLE_SANITIZER_MEMORY})

  set_target_properties(insteonlib_options PROPERTIES UNITY_BUILD ${insteonlib_ENABLE_UNITY_BUILD})

  if(insteonlib_ENABLE_PCH)
    target_precompile_headers(
      insteonlib_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(insteonlib_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    insteonlib_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(insteonlib_ENABLE_CLANG_TIDY)
    insteonlib_enable_clang_tidy(insteonlib_options ${insteonlib_WARNINGS_AS_ERRORS})
  endif()

  if(insteonlib_ENABLE_CPPCHECK)
    insteonlib_enable_cppcheck(${insteonlib_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(insteonlib_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    insteonlib_enable_coverage(insteonlib_options)
  endif()

  if(insteonlib_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(insteonlib_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(insteonlib_ENABLE_HARDENING AND NOT insteonlib_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR insteonlib_ENABLE_SANITIZER_UNDEFINED
       OR insteonlib_ENABLE_SANITIZER_ADDRESS
       OR insteonlib_ENABLE_SANITIZER_THREAD
       OR insteonlib_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    insteonlib_enable_hardening(insteonlib_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
