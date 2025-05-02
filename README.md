# Neural Network Enhanced Vicsek Snowflake

## Team Members

Our project was done by Rian Rahman and Ajay Krishnaswamy

## Image Overview

For this project, Ajay and I recreated a [Vicsek Snowflake fractal](https://en.wikipedia.org/wiki/Vicsek_fractal) by using modern graphic techniques. First, we generated a 3D real-time rendering of it using signed distance functions, which provided the snowflake with some iterative geometric transformations. It was then enhanced with a two-layer neural network influencing the fractal's geometry and color evolution. Also, we used Gaussian splats as they allowed for the particle movements to be organic but simultaneously subtle. Doing this allowed the fractal's mathematical structure to remain rigid with a fluid and natural motion. With our neural network and Gaussian spots implemented, we added a custom radiance field system with a 64-step volumetric sampling and a two-layer neural network. This added more atmospheric depth and volumetric effects for our Vicsek Snowflake. Finally, we incorporated some dynamic lighting with real-time shadows and reflections into the image to give the image a sense of realism. While the image is dynamically lighted, the neural network components continuously modulate the fractal's appearance. This allows for a repeated evolving matter where the original Vicsek Snowflake has more modern, organic elements added to its presentation.

## Implementation

The project's core part involves many interconnected graphics techniques that we learned throughout CGAI. First, we started with ray marching and signed distance functions to create the base of the Vicsek Snowflake pattern. This provides for real-time rendering of the fractal structure. To build upon this, we implemented a neural radiance field system. As mentioned in the previous section, this radiance field system uses 64-step volumetric sampling and a two-layer neural network. These components are used to process position and direction data, which allow for dynamic volumetric effects that improve the scene's depth and atmosphere. To add more organic movement, we incoporated Gaussian splats into our implementation. We did this by creating a system of 8 animated elements with different intensities and positions that create fluid, particle-like effects. This constrasts against the fractal's rigid structure. In addition, we added an advanced lighting system for our implementation. This implementation allows for dynamic dual lights and some real time reflections to be present within our image. Specefically, we used some physics with [Fresnel equations](https://en.wikipedia.org/wiki/Fresnel_equations) in our implementation to allow for realistic light interaction and ambient occlusion. We also tried to calculate the shadow
customly with ray marching techniques. All of this works together to create a cohesive striking result.

## Contributions

## Video Demo

Visit the Link Here: [https://youtu.be/UV2tDr79eIg](https://youtu.be/UV2tDr79eIg)
