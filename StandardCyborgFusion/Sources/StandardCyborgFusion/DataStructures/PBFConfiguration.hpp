//
//  PBFConfiguration.hpp
//  StandardCyborgFusion
//
//  Created by Ricky Reusser on 12/17/18.
//

#pragma once

#import <ostream>
#import <cmath>

struct PBFConfiguration {
    float maxCameraVelocity = 0.6;
    float maxCameraAngularVelocity = 2.5;

    // For frames seeded by a predicted pose: how far ICP may correct the prediction (radians, meters)
    // before it's deemed wrong and the frame rejected. Replaces the velocity check for such frames,
    // whose motion since the previous one may legitimately be large.
    float maxPredictionCorrectionAngle = 10.0 * M_PI / 180.0;
    float maxPredictionCorrection = 0.03;
    // A prediction only seeds ICP when it moved at least this much since the last tracked frame (radians,
    // meters): smaller motions are within the prediction's own noise, so the last tracked pose is the
    // better starting point and the velocity check applies as for unpredicted frames.
    float minPredictedMotionAngle = 1.5 * M_PI / 180.0;
    float minPredictedMotion = 0.005;
    
    float icpDownsampleFraction = 0.05;
    
    int kdTreeRebuildInterval = 6;
};

std::ostream& operator<<(std::ostream& os, PBFConfiguration const& config);
