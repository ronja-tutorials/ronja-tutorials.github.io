---
layout: post
title: "Spheretracing Basics"
image: /assets/images/posts/043/Result.png
hidden: false
---

Raytracing is a huge topic and one that seems scary and unapproachable for many. One specific kind of raytracing we can do with signed distance fields which I have explored in the 2d space in previous tutorials is called spheretracing. In this first tutorial we'll just trace the silouette of a sphere, but in future tutorials I'll give examples how to make more complex shapes and do lighting.

As the base of the shader we'll use the result of the [properties]({{ site.baseurl }}{% post_url 2018-03-22-properties %}) tutorial, so you can do this tutorial when you're fairly new to shaders. If you do struggle with some of the concepts of signed distance fields though, have a look into [my tutorial about 2d signed distance fields]({{ site.baseurl }}{% post_url 2018-11-10-2d-sdf-basics %}).

## The theory

The central concept of raytracing is the ray. To construct a ray we need a origin and a direction. If we only do the raytracing inside of a mesh we can use the surface point of that mesh as the origin of the ray. The direction of the view ray is the vector from the camera to that surface point.

With this data we can take steps through our SDF scene. We'll advance the distance of our distance field in the direction of our ray. We can do that because the definition of a distance field is that the closest surface is as far away as the return value of the distance function. As soon as we are close enough to a surface that we consider it a hit we know that the ray does hit the silouette. If the ray travelled too far or a maximum number of steps was reached that can be interpeted as a fail state and we can assume the ray never hits a scene object.

## Preparing the data

As mentioned previously what we need to define a ray for each pixel is the origin and the direction of the ray. We can do the raytracing in any "space" we want to. If we do it in world space we can move around the object and it moves like a window into the traced world. If we do it in object space the raytraced objects will be moved, scaled and rotated with the object that's moved. For this tutorial I'll do the spheretracing in object space because it's more intuitive and it's a bit harder to do so you might be able to figure out how to do it in worldspace yourself if you want that.

As the origin of the ray we'll use the local coordinates which is the data that's given to the shader via the appdata struct. The object space view direction is a bit trickier - we get it by transforming the camera world position into object space and then subtracting it from the local position. To transform the camera position into local space we have to multiply the world to object matrix with it, but before this multiplication we have to transform it from a float3 into a float4 with a "1" as the w component. If we don't do that the w component would be filled with a 0 and the movement would be ignored, only rotation and scale would be applied.

```glsl
//input data
struct appdata{
    float4 vertex : POSITION;
};

//data that goes from vertex to fragment shader
struct v2f{
    float4 position : SV_POSITION; //position in clip space
    float4 localPosition : TEXCOORD0; //position in local space
    float4 viewDirection : TEXCOORD1; //view direction in local space (not normalized!)
};

v2f vert(appdata v){
    v2f o;
    //position for rendering
    o.position = UnityObjectToClipPos(v.vertex);
    //save local position for origin
    o.localPosition = v.vertex;
    //get camera position in local space
    float4 objectSpaceCameraPos = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1));
    //get local view vector
    o.viewDirection = v.vertex - objectSpaceCameraPos;
    return o;
}
```

## 3d signed distance functions

Signed distance functions work similarly in 3d as they do in 2d. In this tutorial I'll only use a sphere, but if you're curious about other shapes and how to combine them you can use those two sites: <https://www.iquilezles.org/www/articles/distfunctions/distfunctions.htm>, <http://mercury.sexy/hg_sdf/>

The sphere is very similar to the circle in 2d. We first subtract the center of the sphere from the position we want to sample it at, then we calculate the length of the resulting vector and subtract the radius of the sphere to increase it's size. Because this is a very simple example I'm going to place the sphere at the origin of the scene which means I don't have to do the subtraction of the sphere center and give it a hardcoded size of `0.5`.

```glsl
float scene(float3 pos){
    return length(pos) - 0.5;
}
```

## Fixed step ray marching

Before we take full advantage of our signed distance field, I want to show a more simplistic way of raytracing which just going fixed steps forwards through the space until it hits something. The advantage of this is that we can use it with any function that tells us wether a given point is inside or outside of a shape.

To do the raytracing we first have to set up three variables. The point where the ray starts, the direction of the ray and the progress we've already made on our ray. The starting point is the local position in our case which we passed via the v2f struct. The direction was also already calculated in the vertex shader, but we have to normalize it so it's easier to work with before using it. We normalize this vector in the fragment and not the vertex shader because it would loose it wouldn't have a length of 1 anymore after being interpolated between vertices. This is especially visible when the camera is close to low poly objects. Third we define the progress variable which starts at `0`.

```glsl
//ray information
float3 pos = i.localPosition;
float3 dir = normalize(i.viewDirection.xyz);
float progress = 0;
```

For the tracing itself we also have to decide on two more factors, how many steps we iterate through at maximum and how big the steps we will do will be. Because those are fixed, I'm going to use define statements, but if you're more comfortable with variables or just writing in the numbers that's also fine. Because we know the size and complexity of our shape fairly well we can make a pretty good guess what would be appropriate values. I decided to define 10 steps with a distance of 0.1 each. Note that you can use the define statements anywhere, but I decided that they're best with the global variables that can also be manipulated by properties.

```glsl
//how big steps to take when usign fixed steps
#define STEP_SIZE 0.1
//maximum amount of steps
#define MAX_STEPS 10
```

And with all of this set up we can then finally write the loop that does the actual work. I used a for loop with a iterator that counts up and aborts when the iterator reaches the maximum amount of steps we defined. Inside the loop we first calculate the current point on the ray we're on. We get this by solving the line equation of `point = origin + direction * progress`. Putting this result into the scene function then gives us the distance to the closest shape. Right now we're only interrested in whether our current location is inside the shape or not so we check whether the distance smaller than `0` which would mean that it's inside of a shape. If that check is successful we directly return the color we set via our property. If it isn't inside the shape we increase our progress by the step size and the code goes into the next iteration of the loop. If the loop terminates without ever hitting a shape we assume it missed completely and return `0` for a completely black pixel.

```glsl
fixed4 frag(v2f i) : SV_TARGET{
    //ray information
    float3 pos = i.localPosition;
    float3 dir = normalize(i.viewDirection.xyz);
    float progress = 0;
    
    //tracing loop
    for (uint iter = 0; iter < MAX_STEPS; iter++) {
        //get current location on ray
        float3 samplePoint = pos + dir * progress;
        //get distance to closest shape
        float distance = scene(samplePoint);
        //return color if inside shape
        if(distance < 0){
            return _Color;
        }
        //go forwards
        progress = progress + STEP_SIZE;
    }
    
    //return black pixel if no shape was hit
    return 0;
}
```

![](/assets/images/posts/043/TracedSphere.png)

The main disadvantage of fixed step raymarching is that it's often hard to choose a step size. With a step size that's too short you do a lot of samples in areas where theres no shape anywhere close and loose a lot of calculation time doing that. If you choose a step size that's too big it's possible to jump through walls and shapes that should be visible are simply missing because they are between two samples.

## Spheretracing

With signed distance fields we have more information than just is it inside a shape or not. We can also determine how close the closest shape is. If we go the distance to the closest shape forwards we cannot skip any shapes. So instead of using a fixed step spheretracing walks forward the current distance of the SDF.

The changes we make to our existing code are just that we completely get rid of the step size and instead add the distance we have anyways to the progress. Because we only go the distance to the closest shape further it's impossible now to follow the ray inside of the surface. Instead we define a small thickness and accept it as a hit if the distance is smaller than that.

```glsl
//maximum amount of steps
#define MAX_STEPS 10
//furthest distance that's accepted as inside surface
#define THICKNESS 0.01
```

```glsl
fixed4 frag(v2f i) : SV_TARGET{
    //ray information
    float3 pos = i.localPosition;
    float3 dir = normalize(i.viewDirection.xyz);
    float progress = 0;
    
    //tracing loop
    for (uint iter = 0; iter < MAX_STEPS; iter++) {
        //get current location on ray
        float3 samplePoint = pos + dir * progress;
        //get distance to closest shape
        float distance = scene(samplePoint);
        //return color if inside shape
        if(distance < THICKNESS){
            return _Color;
        }
        //go forwards
        progress = progress + distance;
    }
    
    //return black pixel if no shape was hit
    return 0;
}
```

Your result shouldn't look too different from the previous iteration, but I promise you it works way better with huge spaces as well as more delicate shapes.

One minor tweak I'll also mention in this tutorial is how to make the object have the silouette of the traced shape instead of the mesh. For that you can discard the pixels with missed rays before returning black by calling the clip function with a negative argument.

```glsl
//discard pixel if no shape was hit
clip(-1);
return 0;
```

![](/assets/images/posts/043/ClippedSphere.png)

## Source

- <https://github.com/ronja-tutorials/ShaderTutorials/blob/master/Assets/043_SphereTracingBasics/SphereTracingBasics.shader>

```glsl
Shader "Tutorial/042_SphereTracingBasics"{
    //show values to edit in inspector
    Properties{
        _Color ("Color", Color) = (0, 0, 0, 1)
    }

    SubShader{
        //the material is completely non-transparent and is rendered at the same time as the other opaque geometry
        //also disable batching so local coordinates are always valid
        Tags{ "RenderType"="Opaque" "Queue"="Geometry" "DisableBatching"="True"}

        Pass{
            ZWrite Off

            CGPROGRAM
            #include "UnityCG.cginc"

            #pragma vertex vert
            #pragma fragment frag

            //silouette color
            fixed4 _Color;

            //maximum amount of steps
            #define MAX_STEPS 10
            //furthest distance that's accepted as inside surface
            #define THICKNESS 0.01

            //input data
            struct appdata{
                float4 vertex : POSITION;
            };

            //data that goes from vertex to fragment shader
            struct v2f{
                float4 position : SV_POSITION; //position in clip space
                float4 localPosition : TEXCOORD0; //position in local space
                float4 viewDirection : TEXCOORD1; //view direction in local space (not normalized!)
            };

            v2f vert(appdata v){
                v2f o;
                //position for rendering
                o.position = UnityObjectToClipPos(v.vertex);
                //save local position for origin
                o.localPosition = v.vertex;
                //get camera position in local space
                float4 objectSpaceCameraPos = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1));
                //get local view vector
                o.viewDirection = v.vertex - objectSpaceCameraPos;
                return o;
            }


            float scene(float3 pos){
                return length(pos) - 0.5;
            }

            fixed4 frag(v2f i) : SV_TARGET{
                //ray information
                float3 pos = i.localPosition;
                float3 dir = normalize(i.viewDirection.xyz);
                float progress = 0;
                
                //tracing loop
                for (uint iter = 0; iter < MAX_STEPS; iter++) {
                    //get current location on ray
                    float3 samplePoint = pos + dir * progress;
                    //get distance to closest shape
                    float distance = scene(samplePoint);
                    //return color if inside shape
                    if(distance < THICKNESS){
                        return _Color;
                    }
                    //go forwards
                    progress = progress + distance;
                }
                //discard pixel if no shape was hit
                clip(-1);
                return 0;
            }

            ENDCG
        }
    }
}
```