set(LEAN_FREESTANDING_OUT_DIR "${CMAKE_BINARY_DIR}/lib/lean/freestanding")
file(MAKE_DIRECTORY "${LEAN_FREESTANDING_OUT_DIR}")

set(LEAN_FREESTANDING_SOURCES runtime.c lean_freestanding.h)
foreach(_src IN LISTS LEAN_FREESTANDING_SOURCES)
  configure_file("${_src}" "${LEAN_FREESTANDING_OUT_DIR}/${_src}" COPYONLY)
endforeach()
