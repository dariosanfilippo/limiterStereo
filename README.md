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
* The limiter introduces a delay that is equal to the attack time. The other
* parameters are the hold time and the release time, for the amplitude
* profiling characteristics, as well as a bypass button, a pre-gain, and a
* ceiling threshold.
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
