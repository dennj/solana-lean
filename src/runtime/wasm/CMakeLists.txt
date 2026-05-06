set(LEAN_WASM_OUT_DIR "${CMAKE_BINARY_DIR}/lib/lean/wasm")
file(MAKE_DIRECTORY "${LEAN_WASM_OUT_DIR}")

set(LEAN_WASM_SOURCES entrypoint.c stubs.c runtime.c)
foreach(_src IN LISTS LEAN_WASM_SOURCES)
  configure_file("${_src}" "${LEAN_WASM_OUT_DIR}/${_src}" COPYONLY)
endforeach()
