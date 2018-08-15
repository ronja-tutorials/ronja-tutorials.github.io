---
layout: post
title: "Clipping a Model with a Plane"
---

Another cool effect is to make the surface disappear when it’s beyond a certain plane.

To follow this tutorial, it’s best to know how surface shaders work - you can find a tutorial how they work here: https://ronja-tutorials.tumblr.com/post/172421924392/surface-shader-basics

image
We start by creating a new C# script which will define the plane we use later and pass it to the shader. It has a material as a public variable which we will pass the plane to.

In the Update Method we create a new variable of the type Plane which unity already has. We pass it the the normal of the plane and a point on the plane. We will use the up vector of the transform the script is on as the normal and the position of the transform as the point on the plane.

Then we create a new 4d vector and put the normal of the new plane in the first three components and the distance from the origin in the 4th component. I’ll explain later how we’ll use those values.

Then we pass this new vector to the shader so we can use it there.

image
To set up this script we add it to a empty gameobject and apply our material to the corresponding variable.

image
Then we’ll write the shader. As a base for it we use the basic surface shader from this tutorial: https://ronja-tutorials.tumblr.com/post/172421924392/surface-shader-basics.

First we add the plane variable we just passed into the material. Because we won’t write to it from the inspector, we don’t need a property for it.

image
In the surface shader we can then calculate the distance of the surface point to the plane if it was in the origin of the world. We do this by calculating the dot product between the surface point and the plane normal. For all points on that plane the dot product will return 0 because the position vector is orthogonal to the normal. For points that are above the plane the values will be positive because the vectors point in the same direction and for the surface points below the plane the dot product will be negative because they point away from the normal.

To do this comparison we need the world position, so we add it to our input struct. Then we get the dot product and just write it to the emission for now.

image
image
image
When we now rotate our plane object we can see the distance being calculated correctly, but it completely ignores the position of the plane object because we act like it’s positioned in the center so far. This is where the distance we saved in the 4th component of the vector earlier comes in. Because it’s the distance from the center we can simply add it to the plane we constructed around the center and we get the plane at the correct position.

image
image
You might notice that even though we call it the distance, the two sides of the plane don’t actually look the same, one has increasing values like we expect it from a distance, while the other side stays black. That’s because we actually have a signed distance, meaning the values on the dark side that are 1 unit far away from the plane have the value of -1.

We can use this fact by simply cutting off all values above one, that means everything above the plane will not be rendered while the parts that are currently black will be.

We can cut off pixels in hlsl by feeding a variable to the clip function, if the variable is less than zero it will be discarded, otherwise it will be rendered like usual. So in this case we invert our distance and feed it to the clip function, that way the surface in front of the plane has negative values and the surface behind the plane positive ones.

image
image
Now we can simply see through the upper part of the model. With this done, we don’t need the visualisation anymore and can use colors we use usually again.

image
image
With those changes we can now cut off the model based on a plane, but looking in the hole we created looks weird. Especially concave bodies look like they have small parts of them flying around sometimes. This is because by default we don’t draw the backfaces of models. It’s a optimisation we can make because we assume we won’t see inside the model anyways, but we can simply disable it.

To draw all faces, no matter if they’re pointing towards the camera or away from it, we set the Cull parameter to off at the top of our subshader, outside of the hlsl code.

image
image
Now we can see inside the head, but the normals still point to the outside and we might not want to see the inside of the head. But can detect the difference between the inside surface and outside surface pretty easily so let’s do that.

To get wether we’re rendering a inside or a outside surface we make a new parameter in our input struct and give it the vface attribute. This variable will have a value of 1 one the outside and a value of -1 on the inside.

To use the value for things like linear interpolation I prefer to have it in a 0 to 1 range so I halved it and added 0.5 to it to convert it.

image
image
image
Now that we know the difference between the inside and outside faces, we can make the inside it’s own specific color. We lerp to the new color we expose via a property on the emissive channel because the emission is not affected by the wrong normals. We also multiply all other channels with the facing variable to make them black/matte/non-metallic to make the color we can see in the opening as neutral as possible.

image
image
image
image
There are still a few artefacts because of golbal illumination, but we can’t fix them without rewriting/removing global illumination and we won’t do that in this tutorial.

image
This technique is great to make things disappear into nothing or make simple dynamic water in a vessel. I hope it’ll help you archieve cool effects yourself.

You can find the code for the tutorial here:
https://github.com/axoila/ShaderTutorials/blob/master/Assets/20_Clipping_Plane/ClippingPlane.cs
https://github.com/axoila/ShaderTutorials/blob/master/Assets/20_Clipping_Plane/ClippingPlane.shader