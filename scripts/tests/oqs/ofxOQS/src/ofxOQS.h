#pragma once

#include "ofMain.h"
#include <oqs/oqs.h>
#include <string>
#include <vector>

class ofxOQS {
public:
	static bool mlKemRoundTrip();
	static bool mlDsaSignVerify();
	static std::vector<std::string> enabledKems();
	static bool runSmokeTests();
};
