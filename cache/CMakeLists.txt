include_directories(../include)

add_library(elliptics_cache STATIC cache.cpp)
if(UNIX OR MINGW)
    set_target_properties(elliptics_cache PROPERTIES COMPILE_FLAGS "-fPIC")
endif()
target_link_libraries(elliptics_cache "")
