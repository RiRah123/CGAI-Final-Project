# Neural Network Enhanced Vicsek Snowflake

## Team Members

Our project was done by Rian Rahman and Ajay Krishnaswamy

## Image Overview

For this project, Ajay and I recreated a [Vicsek Snowflake fractal](https://en.wikipedia.org/wiki/Vicsek_fractal) by using modern graphic techniques. First, we generated a 3D real-time rendering of it using signed distance functions, which provided the snowflake with some iterative geometric transformations. It was then enhanced with a two-layer neural network influencing the fractal's geometry and color evolution. Also, we used Gaussian splats as they allowed for the particle movements to be organic but simultaneously subtle. Doing this allowed the fractal's mathematical structure to remain rigid with a fluid and natural motion. With our neural network and Gaussian spots implemented, we added a custom radiance field system with a 64-step volumetric sampling and a two-layer neural network. This added more atmospheric depth and volumetric effects for our Vicsek Snowflake. Finally, we incorporated some dynamic lighting with real-time shadows and reflections into the image to give the image a sense of realism. While the image is dynamically lighted, the neural network components continuously modulate the fractal's appearance. This allows for a repeated evolving matter where the original Vicsek Snowflake has more modern, organic elements added to its presentation.
