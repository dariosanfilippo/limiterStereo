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
* apart from the primary peak can still be detected. The secondary peaks
* that are closer to the primary peaks can be taken care of by the release
* section.
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
declare version "0.2";
declare limiterStereo license "MIT-style STK-4.3 license";
peakHold(t, x) = loop ~ _
    with {
        loop(fb) = ba.sAndH(cond1 | cond2, abs(x))
            with {
                cond1 = abs(x) >= fb;
                cond2 = loop ~ _ <: _ < _'
                    with {
                        loop(fb) = 
                            ((1 - cond1) * fb + (1 - cond1)) % (t * ma.SR + 1);
                    };
            };
    };
peakHoldCascade(N, holdTime, x) = x : seq(i, N, peakHold(holdTime / N));
smoother(N, att, rel, x) = loop ~ _
    with {
        loop(fb) = ba.if(abs(x) >= fb, attSection, relSection)
            with {
                attSection = attCoeff * fb + (1.0 - attCoeff) * abs(x);
                relSection = relCoeff * fb + (1.0 - relCoeff) * abs(x);
                attCoeff = 
                    exp((((-2.0 * ma.PI) / att) * cutoffCorrection) * ma.T);
                relCoeff = 
                    exp((((-2.0 * ma.PI) / rel) * cutoffCorrection) * ma.T);
                cutoffCorrection = 1.0 / sqrt(pow(2.0, 1.0 / N) - 1.0);
            };
    };
smootherCascade(N, att, rel, x) = x : seq(i, N, smoother(N, att, rel));
gainAttenuation(th, att, hold, rel, x) =  
    th / (max(1.0, peakHoldCascade(8, att + hold, x)) : 
        smootherCascade(4, att, rel));
limiterStereo(xL_, xR_) =   
    (xL_ * (bypass) + (1 - bypass) * xLDelayed * stereoAttenuationGain : 
        peakDisplayL),
    (xR_ * (bypass) + (1 - bypass) * xRDelayed * stereoAttenuationGain : 
        peakDisplayR)
    with {
        xL = xL_ * preGain;
        xR = xR_ * preGain;
        xLDelayed = de.sdelay(.1 * ma.SR, .02 * ma.SR, attack * ma.SR, xL);
        xRDelayed = de.sdelay(.1 * ma.SR, .02 * ma.SR, attack * ma.SR, xR);
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
            displayGroup(peakGroup(attach(peak, (max(peak, abs) ~ *(reset) : 
                ba.linear2db : 
                    vbargraph(  "[06]Left Peak (dB)[style:numerical]", 
                                -60, 
                                60)))));
        peakDisplayR(peak) = 
            displayGroup(peakGroup(attach(peak, (max(peak, abs) ~ *(reset) : 
                ba.linear2db : 
                    vbargraph(  "[07]Right Peak (dB)[style:numerical]", 
                                -60, 
                                60)))));
        attenuationDisplay(attenuation) = 
            displayGroup(attach(attenuation, attenuation : 
                ba.linear2db : vbargraph("[09]Attenuation (dB)", -120, 0)));
        reset = 1 - button("[08]Reset Peak");
        bypass = controlGroup(checkbox("[00]Bypass"));
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
