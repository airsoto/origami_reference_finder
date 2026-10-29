#include "MobileEngine.hpp"
#include <iostream>
int main(int argc, char** argv) {
 mobile::Request r;
 if(argc > 1) r.x = argv[1];
 if(argc > 2) r.y = argv[2];
 if(argc > 3) r.rank = std::stoi(argv[3]);
 if(argc > 4) { r.line = true; r.x2 = argv[4]; r.y2 = argv[5]; }
 std::cout << mobile::solve(r) << std::endl;
}
