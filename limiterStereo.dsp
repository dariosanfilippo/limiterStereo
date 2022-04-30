/*******************************************************************************
**********      Look-ahead IIR stereo limiter       ****************************
********************************************************************************
*
* Yet another look-ahead limiter. 
*
* The novel aspect of this limiter is that it
* uses N cascaded one-pole filters for amplitude profiling, which improves
* smoothness in the first to N-1 order derivatives and reduces total 
* harmonic distortion. This design uses four cascaded one-pole lowpass filters, 
* following the cut-off correction formula (8.9) found in [Zavalishin 2012].
*
* IIR filters produce exponential curves, which are perceptually more natural.
* However, an IIR system, unlike a FIR moving average, for example, will never
* completely reach the target value and is thus not suitable for perfect 
* brick-wall limiting. With reasonable settings, though, the limiter
* produces an overshooting of only .002 dB with signals boosted by 120 dBs,
* which I find negligible for most musical applications.
*
* The limiter introduces a delay that is equal to the attack time times 
* the samplerate samples.
*
* For better peak detection, N peak-hold sections with 1/N hold time can be 
* cascaded, so that secondary peaks that are at least 1/N of the hold time 
* plus one sample apart from the primary peak can still be detected. 
* The secondary peaks that are closer to the primary peaks can be taken care 
* of by the release section. Thanks to Geraint "Signalsmith" Luff and our 
* discussions on the topic, which inspired this solution.
*
* The other parameters are the hold time and the release time, for the 
* amplitude profiling characteristics, as well as a bypass button, a pre-gain, 
* and a ceiling threshold.
*
* The limiter is stereo-linked, hence the relative left-right amplitude 
* difference is preserved.
*
* Future developements on this work may include an adaptive mechanism for
* self-adjusting release times to reduce the 'pumping' effect, and a deployment
* in multi-band processing for loudness maximisation.
*
* Note on loudness: while I am aware of the loudness war in the pop music
* context, which is today a rather nostalgic thought, loudness itself has been 
* explored as a creative means beautifully, for example, in the work of 
* Phil Niblock, which is a reason why I am interested in exploring these
* techniques.
*
*******************************************************************************/

import("stdfaust.lib");
declare limiterStereo author "Dario Sanfilippo";
declare limiterStereo copyright
    "Copyright (C) 2022 Dario Sanfilippo <sanfilippo.dario@gmail.com>";
declare version "0.4.0";
declare limiterStereo license "MIT-style STK-4.3 license";
sdelay(maxDelay, interpolationLen, delayLen, x) = 
    loop ~ si.bus(4) : (! , ! , ! , ! , _)
    with {
        loop(lineState, incrState, lowerDelayState, upperDelayState) = 
            line , incr , lowerDelay , upperDelay , output
            with {
                lowerReach = lineState == 0;
                upperReach = lineState == 1;
                lowerDelayChange = delayLen != lowerDelayState;
                upperDelayChange = delayLen != upperDelayState;
                incr = ba.if(   upperReach & upperDelayChange,
                                -1.0 / interpolationLen,
                                ba.if(  lowerReach & lowerDelayChange),
                                        1.0 / interpolationLen,
                                        incrState);
                line = max(.0, min(1.0, lineState + incr));
                lowerDelay = ba.if(upperReach, delayLen, lowerDelayState);
                upperDelay = ba.if(lowerReach, delayLen, upperDelayState);
                lowerDelayline = de.delay(maxDelay, lowerDelay, x) * (1.0 - line);
                upperDelayline = de.delay(maxDelay, upperDelay, x) * line;
                output = lowerDelayline + upperDelayline;
            };
    };
peakHold(t, x) = loop ~ si.bus(2) : ! , _
    with {
        loop(timerState, outState) = timer , output
            with {
                isNewPeak = abs(x) >= outState;
                isTimeOut = timerState >= rint(t * ma.SR);
                bypass = isNewPeak | isTimeOut;
                timer = (1 - bypass) * (timerState + 1);
                output = bypass * (abs(x) - outState) + outState;
            };
    };
peakHoldCascade(N, holdTime, x) = x : seq(i, N, peakHold(holdTime / N));
smoother(N, att, rel, x) = loop ~ _
    with {
        loop(fb) = coeff * fb + (1.0 - coeff) * x
            with {
                coeff = ba.if(x > fb, attCoeff, relCoeff);
                twoPiCT = 2.0 * ma.PI * cutoffCorrection * ma.T;
                attCoeff = exp(-twoPiCT / att);
                relCoeff = exp(-twoPiCT / rel);
                cutoffCorrection = 1.0 / sqrt(pow(2.0, 1.0 / N) - 1.0);
            };
    };
smootherCascade(N, att, rel, x) = x : seq(i, N, smoother(N, att, rel));
gainAttenuation(th, att, hold, rel, x) =  
    th / (max(th, peakHoldCascade(8, att + hold, x)) : 
        smootherCascade(4, att, rel));
limiterStereo(xL_, xR_) =   
    (xL_ * (bypass) + (1 - bypass) * xLDelayed * stereoAttenuationGain : 
        peakDisplayL),
    (xR_ * (bypass) + (1 - bypass) * xRDelayed * stereoAttenuationGain : 
        peakDisplayR)
    with {
        xL = xL_ * preGain;
        xR = xR_ * preGain;
        delay = rint((attack / 8) * ma.SR) * 8;
        xLDelayed = sdelay(.1 * ma.SR, delay, delay, xL);
        xRDelayed = sdelay(.1 * ma.SR, delay, delay, xR);
        stereoAttenuationGain = 
            gainAttenuation(threshold, 
                            attack, 
                            hold, 
                            release, 
                            max(abs(xL), abs(xR))) : attenuationDisplay;
        horizontalGroup(group) = hgroup("Look-ahead IIR Stereo Limiter", group);
        peakGroup(group) = hgroup("Peaks", group);
        displayGroup(display) = horizontalGroup(vgroup("Display", display));
        controlGroup(param) = horizontalGroup(vgroup("Control", param));
        peakDisplayL(peak) = 
            displayGroup(peakGroup(attach(peak, (peakHold(3, peak) : 
                ba.linear2db : 
                    vbargraph(  "[06]Left Peak (dB)[style:numerical]", 
                                -60, 
                                60)))));
        peakDisplayR(peak) = 
            displayGroup(peakGroup(attach(peak, (peakHold(3, peak) : 
                ba.linear2db : 
                    vbargraph(  "[07]Right Peak (dB)[style:numerical]", 
                                -60, 
                                60)))));
        attenuationDisplay(attenuation) = 
            displayGroup(attach(attenuation, attenuation : 
                ba.linear2db : vbargraph("[09]Attenuation (dB)", -120, 0)));
        reset = 1 - button("[08]Reset Peak");
        bypass = controlGroup(checkbox("[00]Bypass")) : si.smoo;
        preGain = controlGroup(ba.db2linear(hslider("[01]Pre Gain (dB)", 
                                            0, 
                                            0, 
                                            120, 
                                            .001))) : si.smoo;
        threshold = controlGroup(ba.db2linear(  hslider("[02]Threshold (dB)", 
                                                0, 
                                                -60, 
                                                0, 
                                                .001))) : si.smoo;
        attack = controlGroup(hslider(  "[03]Attack (s)", 
                                        .01, 
                                        .001, 
                                        .05, 
                                        .001)) : si.smoo;
        hold = controlGroup(hslider("[04]Hold (s)", 
                                    .05, 
                                    .000, 
                                    1, 
                                    .001)) : si.smoo;
        release = controlGroup(hslider( "[05]Release (s)", 
                                        .15, 
                                        .05, 
                                        1, 
                                        .001)) : si.smoo;
    };
process = limiterStereo;
