#include "MobileEngine.hpp"
#include <iostream>
int main() {
    mobile::Request r;
    auto run = [&](const char* name) { std::cout << name << '\t' << mobile::solve(r) << '\n'; };
    run("thirds");
    r.x = "0"; r.y = "1/3"; run("edge_third");
    r.x = "sqrt(2)/2"; r.y = "0,5"; run("expression");
    r.x = "0"; r.y = "0"; run("corner");
    r.x = "0"; r.y = "1/3"; r.x2 = "1"; r.y2 = "1/3"; r.line = true; run("line");
    r.x2 = "0"; run("same_point");
    r.line = false; r.x = "2"; run("outside");
    r.x = "1/0"; run("zero_divide");
    r.x = "sqrt(-1)"; run("sqrt_negative");
    r.x = "set(a,1)"; run("set_rejected");
    r.x = "unknown"; run("unknown");
    r.x = "1/3"; r.width = "sqrt(2)"; run("rectangle");
    r.width = "1"; r.rank = 2; run("rank2");
    r.rank = 3; run("rank3");
    r.rank = 4; run("rebuild4");
    r.rank = 7; run("invalid_rank");
    r.rank = 4; r.width = "0"; run("invalid_paper");
}
