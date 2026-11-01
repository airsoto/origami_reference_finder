// Regression cases for Mu-Tsun Tsai's two fixes merged by Robert J. Lang in 2024.
#include "ReferenceFinder.h"
#include <iostream>
#include <stdexcept>
#include <vector>

static void require(bool condition, const char* message) {
    if (!condition) throw std::runtime_error(message);
}

int main() {
    try {
        ReferenceFinder::sPaper.SetSize(1, 1);
        // Before PR #2, the top-left boundary point incorrectly shared a key
        // with the adjacent bottom-edge bucket, dropping a distinct reference.
        RefMark topLeft(XYPt(0, 1), 0);
        RefMark nextBottom(XYPt(1.0 / (ReferenceFinder::sNumX - 1), 0), 0);
        RefMark topRight(XYPt(1, 1), 0);
        topLeft.FinishConstructor();
        nextBottom.FinishConstructor();
        topRight.FinishConstructor();
        require(topLeft.mKey != nextBottom.mKey, "Boundary reference keys collide (upstream PR #2)");
        require(topRight.mKey <= ReferenceFinder::sNumX * ReferenceFinder::sNumY,
                "Boundary reference key is outside the allocated grid (upstream PR #2)");
        std::cout << "PASS upstream_boundary_keys\n";

        ReferenceFinder::sMaxRank = 3;
        ReferenceFinder::sMaxLines = 100000;
        ReferenceFinder::sMaxMarks = 100000;
        ReferenceFinder::sGoodEnoughError = 1e-10;
        ReferenceFinder::MakeAllMarksAndLines();

        // Rank-3 O5: bring bottom midpoint to the right edge through top
        // midpoint. The second root was omitted by PR #1's original typo.
        RefMark_Original bottomMidpoint(XYPt(0.5, 0), 1, "bottom midpoint");
        RefMark_Original topMidpoint(XYPt(0.5, 1), 1, "top midpoint");
        RefLine_Original rightEdge(ReferenceFinder::sPaper.mRightEdge, 0, "right edge");
        RefLine_P2L_C2P secondRoot(&bottomMidpoint, &rightEdge, &topMidpoint, 1);
        require(secondRoot.mKey != 0, "Expected a valid second O5 root");
        std::vector<RefLine*> found;
        ReferenceFinder::FindBestLines(secondRoot.l, found, 1);
        require(!found.empty() && found[0] && found[0]->DistanceTo(secondRoot.l) < 1e-10,
                "Second O5 root is missing from generated references (upstream PR #1)");
        require(found[0]->mRank <= 3, "O5 second-root construction exceeds rank 3");
        std::cout << "PASS upstream_axiom5_second_root\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "FAIL " << error.what() << '\n';
        return 1;
    }
}
