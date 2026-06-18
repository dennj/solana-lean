set(LEAN_WEB_OUT_DIR "${CMAKE_BINARY_DIR}/lib/lean/web")
file(MAKE_DIRECTORY "${LEAN_WEB_OUT_DIR}")

set(LEAN_WEB_SOURCES README.md runtime.c stubs.c)
foreach(_src IN LISTS LEAN_WEB_SOURCES)
  configure_file("${_src}" "${LEAN_WEB_OUT_DIR}/${_src}" COPYONLY)
endforeach()
