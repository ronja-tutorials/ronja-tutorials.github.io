---
layout: page
title: Noise Functions
tagline: This is where to start learning.
---

A great way to generate images without textures is to use noise functions. In this series I go through the most common ones and how to use them. To write noise functions I recommend you to first {know the basics of shaders in unity](/basics.html). The tutorials also use [surface shaders]({{ site.baseurl }}{% post_url 2018-03-30-simple-surface %}), so if you have problems understanding that part I recommend looking into [it]({{ site.baseurl }}{% post_url 2018-03-30-simple-surface %}) first.

I also recommend reading the noise tutorials in order since some of them build on each other and they become more complex for the most part.

1. [White noise]({{ site.baseurl }}{% post_url 2018-09-02-white-noise %}):
    * This tutorial explains the basics of generating random numbers and vectors in shaders.
2. [Value Noise]({{ site.baseurl }}{% post_url 2018-09-08-value-noise %}):
    * For value noise we interpolate between cells with random values.
3. [Perlin Noise]({{ site.baseurl }}{% post_url 2018-09-15-perlin-noise %}):
    * Perlin noise is another kind of noise generation which often delivers more interresting results.
4. [Layered Noise]({{ site.baseurl }}{% post_url 2018-09-22-layered-noise %}):
    * This tutorial explains how to sample noise several times and layer it over itself to give the result more texture.
5. [Voronoi Noise]({{ site.baseurl }}{% post_url 2018-09-29-voronoi-noise %}):
    * Voronoi noise is another kind of noise which generates cells. We can use random values in the cells or the distance to the border between the cells.
5. [Bake shader output into texture]():
    * coming soon™