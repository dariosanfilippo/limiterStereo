Yet another look-ahead limiter. 

The novel aspect of this limiter is that it
uses N cascaded one-pole filters for amplitude profiling, which improves
smoothness in the first to N-1 order derivatives and reduces total 
harmonic distortion. This design uses four cascaded one-pole lowpass filters, 
following the cut-off correction formula (8.9) found in [Zavalishin 2012].

IIR filters produce exponential curves, which are perceptually more natural.
However, an IIR system, unlike a FIR moving average, for example, will never
completely reach the target value and is thus not suitable for perfect 
brick-wall limiting. With reasonable settings, though, the limiter
produces an overshooting of only .002 dB with signals boosted by 120 dBs,
which I find negligible for most musical applications.

The limiter introduces a delay that is equal to the attack time times 
the samplerate samples.

For better peak detection, N peak-hold sections with 1/N hold time can be 
cascaded, so that secondary peaks that are at least 1/N of the hold time
plus one sample apart from the primary peak can still be detected. 
The secondary peaks that are closer to the primary peaks can be taken care 
of by the release section. Thanks to Geraint "Signalsmith" Luff and our 
discussions on the topic, which inspired this solution.

The other parameters are the hold time and the release time, for the
amplitude profiling characteristics, as well as a bypass button, a pre-gain,
and a ceiling threshold.

The limiter is stereo-linked, hence the relative left-right amplitude
difference is preserved.

Future developements on this work may include an adaptive mechanism for
self-adjusting release times to reduce the 'pumping' effect, and a deployment
in multi-band processing for loudness maximisation.

Note on loudness: while I am aware of the loudness war in the pop music
context, which is today a rather nostalgic thought, loudness itself has been
explored as a creative means beautifully, for example, in the work of
Phil Niblock, which is a reason why I am interested in exploring these
techniques.

 ![Figure_0](https://user-images.githubusercontent.com/30258280/153643622-e3e698c0-cd32-4c5a-96f5-74e3ef4928ca.png)
 
 ![Figure_1](https://user-images.githubusercontent.com/30258280/153643639-85be6520-9a9b-4788-b1be-6ee7819313fd.png)

 ![desmos-graph](https://user-images.githubusercontent.com/30258280/154347305-ec464f50-65b3-44f4-976f-823baba92054.png)
 
 ![peakdetectionedgecase0](https://user-images.githubusercontent.com/30258280/153750561-a6b7ce92-aaf1-4927-86d5-9d130abbacbe.png)

 ![peakdetectionedgecase1](https://user-images.githubusercontent.com/30258280/153750565-11f07762-309d-4ea3-9593-a1a2fd97ec58.png)
 
 <img width="800" alt="image" src="https://user-images.githubusercontent.com/30258280/153645236-b0ab2bcd-e3f0-4a3a-adfe-a73ed52a737b.png">



