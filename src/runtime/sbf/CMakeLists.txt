set(LEAN_SBF_OUT_DIR "${CMAKE_BINARY_DIR}/lib/lean/sbf")
file(MAKE_DIRECTORY "${LEAN_SBF_OUT_DIR}")

set(LEAN_SBF_SOURCES entrypoint.c stubs.c runtime.c sbf.ld README.md)
foreach(_src IN LISTS LEAN_SBF_SOURCES)
  configure_file("${_src}" "${LEAN_SBF_OUT_DIR}/${_src}" COPYONLY)
endforeach()
