#pragma once
#include <string>
namespace mobile {
struct Request {
  std::string x = "1/3", y = "1/3", x2 = "1", y2 = "1/3";
  std::string width = "1", height = "1";
  bool line = false;
  int rank = 4;
};
// Calls are serialized internally: the upstream engine has process-wide state.
std::string solve(const Request& request);
void cancel();
}
