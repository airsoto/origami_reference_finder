// Modern iOS adapter, 2026. Distributed under GPL-2.0 with ReferenceFinder.
#include "MobileEngine.hpp"
#include "ReferenceFinder.h"
#include "parser.h"
#include <atomic>
#include <mutex>
#include <sstream>
#include <iomanip>
#include <stdexcept>
#include <algorithm>

namespace mobile {
namespace {
std::mutex engineMutex;
std::atomic<bool> cancelled{false};
bool ready = false;
int cachedRank = -1;
double cachedWidth = 0, cachedHeight = 0;

std::string json(const std::string& s) {
  std::ostringstream o; o << '"';
  for (unsigned char c : s) {
    switch (c) {
      case '"': o << "\\\""; break;
      case '\\': o << "\\\\"; break;
      case '\n': o << "\\n"; break;
      case '\r': o << "\\r"; break;
      case '\t': o << "\\t"; break;
      default: if (c < 32) o << "\\u" << std::hex << std::setw(4) << std::setfill('0') << int(c) << std::dec;
               else o << c;
    }
  }
  o << '"'; return o.str();
}
std::string xml(const std::string& s) {
  std::string o;
  for (char c : s) {
    if(c == '&') o += "&amp;";
    else if(c == '<') o += "&lt;";
    else if(c == '>') o += "&gt;";
    else if(c == '"') o += "&quot;";
    else o += c;
  }
  return o;
}
double evaluate(std::string value) {
  if(value.size() > 120 || value.find("set") != std::string::npos ||
     value.find('"') != std::string::npos) throw std::runtime_error("Unsupported expression.");
  std::replace(value.begin(), value.end(), ',', '.');
  Parser parser; double result = 0;
  const auto status = parser.evaluate(value, result);
  auto check = status;
  if(!check.isOK() || !std::isfinite(result))
    throw std::runtime_error("Invalid expression: " + value + ". Try 1/3 or sqrt(2)/2.");
  return result;
}
void databaseProgress(ReferenceFinder::DatabaseInfo, void*, bool& stop) {
  stop = cancelled.load();
}

// SVG is generated entirely on device from the original diagram primitives.
// Coordinates are flipped explicitly so that labels remain upright.
class SVG : public RefDgmr {
  std::ostringstream out;
  double height;
  double unit;
  static const char* color(int s) { return s == 0 ? "#64748b" : s == 1 ? "#007c91" : "#e14b32"; }
  std::string stroke(LineStyle s) {
    std::ostringstream o;
    o << " fill=\"none\" stroke=\"" << (s == LINESTYLE_HILITE ? "#007c91" :
       (s == LINESTYLE_VALLEY || s == LINESTYLE_MOUNTAIN ? "#e14b32" : "#334155"))
      << "\" stroke-width=\"" << (s == LINESTYLE_CREASE ? .0025*unit : .006*unit) << "\"";
    if(s == LINESTYLE_CREASE) o << " stroke-opacity=\"0.55\"";
    if(s == LINESTYLE_VALLEY) o << " stroke-dasharray=\".02 .012\"";
    if(s == LINESTYLE_MOUNTAIN) o << " stroke-dasharray=\".025 .008 .006 .008\"";
    return o.str();
  }
public:
  SVG(double width, double h) : height(h), unit(std::min(width, h)) {
    out << std::setprecision(9) << "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"-.12 -.12 "
        << width+.24 << ' ' << h+.24 << "\" width=\"100%\" height=\"100%\">";
  }
  void DrawPt(const XYPt& p, PointStyle s) override {
    out << "<circle cx=\"" << p.x << "\" cy=\"" << height-p.y
        << "\" r=\"" << (s == POINTSTYLE_NORMAL ? .008 : .014)*unit << "\" stroke=\"white\" stroke-width=\"" << .003*unit << "\" fill=\"" << color(s) << "\"/>";
  }
  void DrawLine(const XYPt& a, const XYPt& b, LineStyle s) override {
    out << "<path d=\"M " << a.x << ' ' << height-a.y << " L " << b.x << ' ' << height-b.y << '"' << stroke(s) << "/>";
  }
  void DrawArc(const XYPt& c, double r, double a, double b, bool ccw, LineStyle s) override {
    // Sample arcs to avoid SVG arc direction ambiguities after flipping Y.
    const double tau = 2 * std::acos(-1.0);
    double delta = b-a;
    if(ccw) { while(delta < 0) delta += tau; }
    else { while(delta > 0) delta -= tau; }
    out << "<path d=\"";
    for(int i=0; i<=48; ++i) {
      double t = a + delta*i/48;
      out << (i ? " L " : "M ") << c.x+r*std::cos(t) << ' ' << height-c.y-r*std::sin(t);
    }
    out << '"' << stroke(s) << "/>";
  }
  void DrawPoly(const std::vector<XYPt>& p, PolyStyle s) override {
    out << "<polygon points=\"";
    for(const auto& v : p) out << v.x << ',' << height-v.y << ' ';
    out << "\" fill=\"" << (s == POLYSTYLE_WHITE ? "#fff" : s == POLYSTYLE_ARROW ? "#334155" : "#e8eef9")
        << "\" stroke=\"#334155\" stroke-width=\".002\"/>";
  }
  void DrawLabel(const XYPt& p, const std::string& label, LabelStyle s) override {
    const double x = p.x + .014*unit, y = height-p.y-.014*unit;
    out << "<rect x=\"" << x-.007*unit << "\" y=\"" << y-.040*unit
        << "\" width=\"" << (.030*label.size()+.014)*unit << "\" height=\"" << .052*unit
        << "\" rx=\"" << .006*unit << "\" fill=\"white\" fill-opacity=\"0.94\"/>";
    out << "<text x=\"" << x << "\" y=\"" << y
        << "\" font-family=\"Helvetica,Arial,sans-serif\" font-weight=\"700\" font-size=\"" << .044*unit
        << "\" fill=\"" << color(s) << "\">" << xml(label) << "</text>";
  }
  std::string finish() { return out.str() + "</svg>"; }
};

template<class R, class Target>
std::string solutions(std::vector<R*>& refs, const Target& target, double width, double height) {
  std::ostringstream o; o << std::setprecision(12) << '[';
  bool first = true;
  for(auto* ref : refs) {
    if(cancelled) throw std::runtime_error("Search cancelled.");
    if(!first) o << ','; first = false;
    std::ostringstream instructions;
    ref->PutHowtoSequence(instructions);
    ref->BuildDiagrams();
    o << "{\"rank\":" << ref->mRank << ",\"error\":" << ref->DistanceTo(target)
      << ",\"instructions\":" << json(instructions.str()) << ",\"steps\":[";
    bool firstStep = true;
    for(const auto& step : RefBase::sDgms) {
      if(!firstStep) o << ','; firstStep = false;
      SVG svg(width, height); RefBase::DrawDiagram(svg, step);
      std::ostringstream caption; RefBase::PutDiagramCaption(caption, step);
      o << "{\"caption\":" << json(caption.str()) << ",\"svg\":" << json(svg.finish()) << '}';
    }
    o << "]}";
  }
  o << ']'; return o.str();
}
}
void cancel() { cancelled = true; }
std::string solve(const Request& r) {
  std::lock_guard<std::mutex> lock(engineMutex);
  cancelled = false;
  try {
    const double width = evaluate(r.width), height = evaluate(r.height);
    if(width < .25 || width > 2 || height < .25 || height > 2 ||
       std::max(width,height)/std::min(width,height) > 4)
      throw std::runtime_error("Use paper dimensions from 0.25 to 2 and a maximum aspect ratio of 4:1.");
    if(r.rank < 2 || r.rank > 4) throw std::runtime_error("Search rank must be between 2 and 4.");
    const XYPt p(evaluate(r.x), evaluate(r.y));
    XYPt p2;
    auto inside = [&](const XYPt& q) { return q.x >= 0 && q.y >= 0 && q.x <= width && q.y <= height; };
    if(!inside(p)) throw std::runtime_error("The point must be inside the paper.");
    if(r.line) {
      p2 = XYPt(evaluate(r.x2), evaluate(r.y2));
      if(!inside(p2) || (p-p2).Mag() < 1e-7)
        throw std::runtime_error("A line needs two different points inside the paper.");
    }
    if(!ready || r.rank != cachedRank || width != cachedWidth || height != cachedHeight) {
      ready = false;
      ReferenceFinder::sPaper.SetSize(width,height);
      ReferenceFinder::sMaxRank = r.rank;
      ReferenceFinder::sMaxLines = 100000;
      ReferenceFinder::sMaxMarks = 100000;
      ReferenceFinder::sDatabaseStatusSkip = 1000;
      ReferenceFinder::SetDatabaseFn(databaseProgress);
      ReferenceFinder::MakeAllMarksAndLines();
      if(cancelled) throw std::runtime_error("Search cancelled.");
      cachedRank = r.rank; cachedWidth = width; cachedHeight = height; ready = true;
    }
    std::string found;
    if(r.line) {
      XYLine line(p,p2); std::vector<RefLine*> refs;
      ReferenceFinder::FindBestLines(line, refs, 5);
      found = solutions(refs,line,width,height);
    } else {
      std::vector<RefMark*> refs; ReferenceFinder::FindBestMarks(p,refs,5);
      found = solutions(refs,p,width,height);
    }
    std::ostringstream o;
    o << "{\"marks\":" << ReferenceFinder::GetNumMarks() << ",\"lines\":" << ReferenceFinder::GetNumLines()
      << ",\"solutions\":" << found << '}';
    return o.str();
  } catch(const std::exception& e) { return "{\"error\":" + json(e.what()) + '}'; }
}
}
