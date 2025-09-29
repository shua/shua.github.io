<pmeta id="created">2019-11-24T12:00:00-05:00</pmeta>
<pmeta id="title">colour and light</pmeta>

Colour and light are different things.
Light is the physical properties of photons, while colour is the human perception of light.
While light can have potentially infinite dimensions of variation, your eyes only have three variables.
This requires your brain to make some simplifying assumptions about the light it sees.

I described light as the physical properties of photons.
Specifically a photon can be described as having a wavelength, and there can be (often are) multiple photons in a single light that have different wavelengths.
Colour is the perception of light, and here I'll be specifically referring to the human perception of light.
This perception generally encompasses two things: the neurophysical aspect which can be described by certain pigments in your eyes generating an electrical signal when photons hit them,
and the nonphysical experience of colour, which I have less to say about in this article.
How often these pigments "activate" is based not only on how many photons hit them, but the distance each photon's wavelength is to the wavelength that a particular pigment is "tuned to".

Pigments in the human eye are generally grouped into two large categories of "rods" and "cones" based on how we use them; I'll be focusing on the "cones" for now.
The cones can themselves be separated into three groups based on what wavelength of light they are the most sensitive to.
These three groups are [often named](https://en.wikipedia.org/wiki/CIE_1931_color_space#Tristimulus_values): short wavelength (S), medium wavelength (M), long wavelength (L)

 
	.----,,   
	       \ 
	     ,--,  ....... S short ("blue")
	    <  <>  ~~~~~~~ M medium ("green")
	/\   '--'  \/\/\/\ L  l o n g  ("red")
	|      ', 
	\        \ 
	        _/ 
	       \   
	      ._|
	       \  ...I see
	    /""'

You've likely also heard them grouped as "red", "green" and "blue", but those are colour words, and actually get kind of confusing when you're talking about the distinction of colour and light.
Many different combinations of light can produce the same colour, and the pigments in the eye are actually able to "see" all colours, it's how "well" each pigment "sees" a light that determines how your brain maps that light to a colour.
A close analog is how binaural (or double-hearing) hearing allows us to locate sounds to the left or right of our heads.
Your left ear can hear noises on the right side of your body, but if a noise is louder in your right ear than your left, your brain says "there's something making noise to the right of you".

	   🔈10                 🔈10
	 👂9     👂1      👂1     👂9
	 L       R        L       R

This is because your brain is assuming there is a single source of the sound in question, and stereo speakers take advantage of this to trick your silly brain into thinking the "sound thing" is a single thing moving around, when really, it is _two_ speakers which are stationary.

	 🔈9     🔈1       (🔈10) <-- your brain thinks it's here
	 👂9     👂1      👂9     👂1
	 L       R        L       R

Your eyes generally assume there's a single source of light, and if there _is_ in fact a single stream of photons hitting your eyes at a singular wavelength, we call that "monochromatic light".
If you only had two types of cones in your eyes, you would only have two points of reference to triangulate a particular monochromatic light.
If you only had two types of cones, you could also simulate the experience of seeing a singular monochromatic light at any wavelength by using a dichromatic light and varying the strength of the two wavelengths.

	mono-light      ☀️10                ☀️10
	pigments     Ⓢ9      Ⓛ1    Ⓢ1      Ⓛ9
	wavelength  ...~~~~\/\/\    ...~~~~\/\/\ 

Again this is like how you can simulate the experience of hearing a single source of sound at any position relative to your body, by having two speakers on either side and varying the volume of each.

	di-light     ☀️9       ☀️1       (☀️10) <-- your brain thinks the wavelength is here
	pigments     Ⓢ9      Ⓛ1    Ⓢ9      Ⓛ1
	wavelength  ...~~~~\/\/\    ...~~~~\/\/\ 

While it's easier to reason about monochromatic light, in reality we experience a lot more polychromatic light (or many wavelengths).
It's kind of tricky to generate monochromatic light for any given wavelength, but we know certain things that will generate monochromatic light.
If we take a bunch of those things, we can build up a palette of monochromatic light sources, and we're pretty good at increasing or decreasing the power of the light sources then we can build a sort of stereo light system to simulate the experience of any monochromatic light.
[A pair of researchers did just that](https://en.wikipedia.org/wiki/CIE_1931_color_space), and used it to map out a sort of "colour space" that human perception of colour lies in.
They took a bunch of participants and let them look at two sources of light, one monochromatic at a know frequency, and the other trichromatic with the three wavelengths chosen to match the ones that the S/M/L cones in human eyes are tuned to.
They then asked the participants to vary the strength of the three components of the trichromatic light until the mono- and trichromatic lights looked the same.


	goal            ☀️10 
	                      (☀️10)
	variable     ☀️1        ☀️10    ☀️1 
	pigments     Ⓢ         Ⓜ     Ⓛ  
	wavelength  ......~~~~~~~/\/\/\/\/\ 


> increase the short one `Ⓢ`?

	goal            ☀️10 
	                 (☀️10)
	variable     ☀️10       ☀️10    ☀️1 
	pigments     Ⓢ         Ⓜ     Ⓛ  
	wavelength  ......~~~~~~~/\/\/\/\/\ 

> still not quite there, we can _decrease_ the medium one `Ⓜ`

	goal            ☀️10 
	               (☀️10)
	variable     ☀️10       ☀️8     ☀️1 
	pigments     Ⓢ         Ⓜ     Ⓛ  
	wavelength  ......~~~~~~~/\/\/\/\/\ 

With three monochromatic lights of variable intensity, we can unambiguously simulate the experience of arbitrary wavelengths of monochromatic light at arbitrary intensity.
This is because for every combination of wavelength and intensity, we have a unique mapping into the 3-dimensional space of `(S) activation, (M) activation, (L) activation`.

I think that's all I'll write for now, but I'll definitely be coming back to this, because I haven't even gotten to the the thing that started this interest in colours: the combinations of S/M/L intensity which *do not* map to monochromatic light.

Stay tuned for next time,


