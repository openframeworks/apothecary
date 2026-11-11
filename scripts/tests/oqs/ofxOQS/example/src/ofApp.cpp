#include "ofApp.h"

void ofApp::setup() {
	if (!ofxOQS::runSmokeTests()) {
		ofLogError("ofxOQS") << "ML-KEM / ML-DSA smoke tests failed";
		ofExit(1);
		return;
	}
	auto kems = ofxOQS::enabledKems();
	ofLogNotice("ofxOQS") << "enabled KEMs: " << kems.size();
	ofLogNotice("ofxOQS") << "ML-KEM-768 and ML-DSA-44 passed";
	ofExit(0);
}

void ofApp::update() {
}

void ofApp::draw() {
}
