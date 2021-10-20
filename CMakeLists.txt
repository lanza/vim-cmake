cmake_minimum_required(VERSION 3.21)

if(TRUE)
  # maybe read the "special" llvm dir from an env var?
  if(EXISTS $ENV{HOME}/.llvm)
    set(CLANG_ROOT $ENV{HOME}/.llvm)
  elseif(EXISTS $ENV{HOME}/llvm-project/build/Release)
    set(CLANG_ROOT $ENV{PROJECTS}/llvm-project/build/Release)
  else()
    set(CLANG_ROOT /usr)
  endif()
  set(CMAKE_CXX_COMPILER ${CLANG_ROOT}/bin/clang++)
  set(CMAKE_C_COMPILER ${CLANG_ROOT}/bin/clang)
else()
  # make this more generic
  set(CMAKE_CXX_COMPILER /usr/local/bin/x86_64-apple-darwin20-g++-11)
  set(CMAKE_CXX_COMPILER /usr/local/bin/x86_64-apple-darwin20-gcc-11)
endif()

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_C_STANDARD 11)

project(test C CXX)

include($ENV{HOME}/.dotfiles/cmake/Utilities.cmake)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)

if(CMAKE_CXX_COMPILER_ID MATCHES Clang)
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fcolor-diagnostics")
  set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -fcolor-diagnostics")
elseif(CMAKE_CXX_COMPILER_ID MATCHES GNU)
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fdiagnostics-color=always")
  set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -fdiagnostics-color=always")
endif()

set(LLVM_DIR ~/.llvm/lib/cmake/llvm)
find_package(LLVM REQUIRED)
find_package(ZLIB REQUIRED)
find_package(Boost REQUIRED ALL)
find_package(Folly REQUIRED)
find_package(fmt REQUIRED)
find_package(GTest REQUIRED)
include_directories(${LLVM_INCLUDE_DIRS})

file(GLOB cpp_srcs *.cpp)
file(GLOB c_srcs *.c)
add_executable(main ${cpp_srcs} ${c_srcs})
target_link_libraries(
  main PUBLIC
  ${UtilLib}
  # LLVMSupport
  # LLVMCore
  # Folly::folly
  Boost::headers
  fmt::fmt
)
# target_compile_options(${name} PUBLIC -fno-rtti)
