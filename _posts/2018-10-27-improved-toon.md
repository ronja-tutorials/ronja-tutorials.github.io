---
layout: post
title: "Improved Toon Light"
image: /assets/images/posts/032/CompleteToon.png
hidden: false
---

[Last weeks tutorial]({{ site.baseurl }}{% post_url 2018-10-20-single-step-toon %}) was about making a simple toon shader, but I felt like there's still a lot to improve about it so this weeks tutorial is too. We'll fix a thing, and add multiple steps to the lighting as well as a specular highlight. I recommend you to read [the previous tutorial]({{ site.baseurl }}{% post_url 2018-10-20-single-step-toon %}) if you haven't because this one is heavily based on it and expands its code.

## Improved shadows for multiple lights.

If we have multiple lights in our scene we want them to all light up the light parts, but not have it change the areas where all of them have shadows. With the custom shadow color we have right now applied in the lighting function we also add the shadow color the more lights we have. This is also critical because point lights will add lighting in a weird square shape that we definitely don't want.

![](/assets/images/posts/032/BadLight.gif)

The easiest fix for this is to add the shadow color in a way that only adds it once everywhere on the model and then use black as the shadow color in the lighting function.

There are 2 ways to do that. Either we set the ambient color in the lighting settings to the color we want our shadows to be in, or we set the ambient color to black and add the shadow color to the emissive value. I'll do the second solution here because it allows us to set a custom shadow color per material, but feel free to use the ambient color solution if you want to change the color of all shadows at the same time.

We start by setting the ambient color to black in the lighting settings. Then we also disable environment reflections and global illumination. I recommend you do this in general if you want greater control over your lighting and you want a "clean" look.

![](/assets/images/posts/032/LightingSettings.png)

Then we move the shadow color to the emission of the material instead of the lighting function. We calculate it just like before by multiplying the albedo color of the object with the shadow color property. Then to use it we simply add it to the emissive color. Now that we implemented this we don't have to set the color in the lighting function anymore. In the line where we used it to interpolate from the shadow to the light color we can now remove the lerp function and simply multiply the light intensity by the albedo.

```glsl
//the surface shader function which sets parameters the lighting function then uses
void surf (Input i, inout SurfaceOutput o) {
    //sample and tint albedo texture
    fixed4 col = tex2D(_MainTex, i.uv_MainTex);
    col *= _Color;
    o.Albedo = col.rgb;

    float3 shadowColor = col.rgb * _ShadowTint;
    o.Emission = _Emission + shadowColor;
}
```

```glsl
float4 color;
color.rgb = s.Albedo * lightIntensity * _LightColor0.rgb;
color.a = s.Alpha;
return color;
```

![](/assets/images/posts/032/EmissiveShadowColor.png)

This technique works really well for dark shadow colors, but if we want the shadow color to be very strong we we always have the light tinted in the shadow color. There are ways to avoid that but they have their own disadvantages, so I won't get into them here (write me if you're curious).

## Multiple Steps

So far we only have a single hard cut for the lighting. Another option is to have several of those. Having more steps can give the model more plasticity while still looking clean, but it's important that you consider what fits your style best.

To make multiple steps we divide the `towardsLight` variable by the relative width of a single step. We'll make that a property to edit. By dividing it, the variable will become higher and span more whole numbers. If we pass 0.5 as the relative width, it'll go from 0 to 2 (in the area towards the light, we'll ignore the backside for now), for a width of 0.25 it's from 0 to 4 etc. We can then use this stretched variable to generate hard steps with the `ceil` function to force it to whole values. After we have whole values we divide it again, this time by another property which represents the amount of steps we want to show. The values will still be negative for the values on the shadow side and might go over 1 if we have a few narrow cuts, so we then clamp it between 0 and 1 by passing it though the `saturate` method. After those steps we can use it as the light intensity.

```glsl
Properties {
    [Header(Base Parameters)]
    _Color ("Tint", Color) = (1, 1, 1, 1)
    _MainTex ("Texture", 2D) = "white" {}
    [HDR] _Emission ("Emission", color) = (0 ,0 ,0 , 1)

    [Header(Lighting Parameters)]
    _ShadowTint ("Shadow Color", Color) = (0.5, 0.5, 0.5, 1)
    [IntRange]_StepAmount ("Shadow Steps", Range(1, 16)) = 2
    _StepWidth ("Step Size", Range(0.05, 1)) = 0.25
}
```

```glsl
//our lighting function. Will be called once per light
float4 LightingStepped(SurfaceOutput s, float3 lightDir, half3 viewDir, float shadowAttenuation){
    //how much does the normal point towards the light?
    float towardsLight = dot(s.Normal, lightDir);
    towardsLight = towardsLight / _StepWidth;
    float lightIntensity = ceil(towardsLight);
    lightIntensity = lightIntensity / _StepAmount;
    lightIntensity = saturate(lightIntensity);

    //shadow etc...
```

![](/assets/images/posts/032/SimpleSteps.gif)

This already works pretty well now, but we have lost our antialiasing with that conversion, so we have to implement that again. We do this by interpolating to the next lower step in the first pixels of each step. This addition has to happen between the line where we ceil the value to a whole number and the line where we divide it by the amount of steps. We first get the change of how much it points towards the light with the `fwidth` function, then we do a `smoothstep` again from 0 to the amount the change in one pixel. But instead of using the towards light variable as the value to check against, which would only smooth the first step towards the shadowed area, we use the fractional part. This way we'll get the smoothing for every single step. Once we have that smoothing variable which masks out the first few pixels, we add it to the intensity. Because this smoothing is 0 at the very beginning and 1 for most of the area of the step, this will make the material appear too bright. The easy way around that is to change the `ceil` method we used earlier to a `floor` which is basically the same, just one whole value lower.

```glsl
//how much does the normal point towards the light?
float towardsLight = dot(s.Normal, lightDir);

//stretch values so each whole value is one step
towardsLight = towardsLight / _StepWidth;
//make steps harder
float lightIntensity = floor(towardsLight);

// calculate smoothing in first pixels of the steps and add smoothing to step, raising it by one step
// (that's fine because we used floor previously and we want everything to be the value above the floor value, 
// for example 0 to 1 should be 1, 1 to 2 should be 2 etc...)
float change = fwidth(towardsLight);
float smoothing = smoothstep(0, change, frac(towardsLight));
lightIntensity = lightIntensity + smoothing;

// bring the light intensity back into a range where we can use it for color
// and clamp it so it doesn't do weird stuff below 0 / above one
lightIntensity = lightIntensity / _StepAmount;
lightIntensity = saturate(lightIntensity);
```

![](/assets/images/posts/032/AntialiasedSteps.png)

## Specular Highlights

For objects to look wet, shiny or metallic we can implement specular highlights. Because they depend on how the light would be reflected towards the camera they change based on the view direction.

First we calculate in which direction the light would be reflected, for this hlsl has the handy `reflect` method which takes a direction and a normal. Then we compare it to the view direction with a dot product, but only after we invert it because the reflection goes out of the surface and the view direction towards the surface.

```glsl
float3 reflectionDirection = reflect(lightDir, s.Normal);
float towardsReflection = dot(viewDir, -reflectionDirection);
return towardsReflection;
```

![](/assets/images/posts/032/ReflectionDirection.png)

With this we get a nice soft gradient towards the direction of the light reflection. Just like the shadowing, we can then cut it off so we get a nice hard highlight. We first get the change in the variable, then we do a smoothstep. We subtract our specular size property from 1 because the towards light variable will be one where it points towards the reflection so when we cut off at 1, the specular highlight will be invisible, and the lower the cutoff points gets, the bigger the highlight grows.

```glsl
//property
_SpecularSize ("Specular Size", Range(0, 1)) = 0.1
```

```glsl
//global shader variable
float _SpecularSize;
```

```glsl
float3 reflectionDirection = reflect(lightDir, s.Normal);
float towardsReflection = dot(viewDir, -reflectionDirection);
float specularChange = fwidth(towardsReflection);
float specularIntensity = smoothstep(1 - _SpecularSize, 1 - _SpecularSize + specularChange, towardsReflection);
return specularIntensity;
```

![](/assets/images/posts/032/SpecularIntensity.png)

One thing that can look weird with this is that if we go behind out object and look in the direction of the light, the highlight can become huge and span around the outside of the object.

![](/assets/images/posts/032/BigSpecular.png)

To counteract this, we can simply multiply the towardsLight variable with a inverse fresnel before doing the cutoff. We get the inverse fresnel by simply taking the dot product between the normal and the view direction. To make it adjustable by a property, we take the dot product by the power of the property. Then we multiply the new falloff variable by the towards light direction.

```glsl
//property
_SpecularFalloff ("Specular Falloff", Range(0, 2)) = 1
```

```glsl
//global shader variable
float _SpecularFalloff;
```

```glsl
float3 reflectionDirection = reflect(lightDir, s.Normal);
float towardsReflection = dot(viewDir, -reflectionDirection);
float specularFalloff = dot(viewDir, s.Normal);
specularFalloff = pow(specularFalloff, _SpecularFalloff);
towardsReflection = towardsReflection * specularFalloff;
float specularChange = fwidth(towardsReflection);
float specularIntensity = smoothstep(1 - _SpecularSize, 1 - _SpecularSize + specularChange, towardsReflection);
return specularIntensity;
```

![](/assets/images/posts/032/FalloffAdjustment.gif)

And as a last point we also multiply the shadow intensity by our shadow variable so we don't see the specular highlights where the surface should be shadowed.

```glsl
specularIntensity = specularIntensity * shadow;
```

Then to implement it with the correct colors and with the existing lighting we simply do a linear interpolation from the color we calculated with lighting and the specular color based on the specular intensity and the color of the light. We set the specular color property as the specular parameter of the surfaceoutput struct. At this moment it doesn't matter wether we write the property to the surfaceoutput and read that in the lighting function or we simply read the property in the lighting function, but doing it this way makes it easier to expand in the future and for example read the specular color from a texture.

```glsl
//property
_Specular ("Specular Color", Color) = 1
```

```glsl
//global shader variable
fixed3 _Specular;
```

```glsl
//in the surface function
o.Specular = _Specular;
```

```glsl
//in the lighting function

//calculate how much the surface points points towards the reflection direction
float3 reflectionDirection = reflect(lightDir, s.Normal);
float towardsReflection = dot(viewDir, -reflectionDirection);

//make specular highlight all off towards outside of model
float specularFalloff = dot(viewDir, s.Normal);
specularFalloff = pow(specularFalloff, _SpecularFalloff);
towardsReflection = towardsReflection * specularFalloff;

//make specular intensity with a hard corner
float specularChange = fwidth(towardsReflection);
float specularIntensity = smoothstep(1 - _SpecularSize, 1 - _SpecularSize + specularChange, towardsReflection);
//factor inshadows
specularIntensity = specularIntensity * shadow;

float4 color;
//calculate final color
color.rgb = s.Albedo * lightIntensity * _LightColor0.rgb;
color.rgb = lerp(color.rgb, s.Specular * _LightColor0.rgb, saturate(specularIntensity));

color.a = s.Alpha;
return color;
```

Sadly the surface variable only supports 1-dimensional variables, so we'll write our own struct for passing variables. It needs an albedo, emission, specular, alpha, and normal property. We'll then replace all occurances of SurfaceOutput with our new struct.

```glsl
struct ToonSurfaceOutput{
    fixed3 Albedo;
    half3 Emission;
    fixed3 Specular;
    fixed Alpha;
    fixed3 Normal;
};
```

```glsl
float4 LightingStepped(ToonSurfaceOutput s, float3 lightDir, half3 viewDir, float shadowAttenuation){
```

```glsl
void surf (Input i, inout ToonSurfaceOutput o) {
```

![](/assets/images/posts/032/CompleteToon.png)

## Source

- <https://github.com/ronja-tutorials/ShaderTutorials/blob/master/Assets/032_ImprovedToon/ImprovedToonLighting.shader>

```glsl
Shader "Tutorial/032_ImprovedToon" {
    //show values to edit in inspector
    Properties {
        [Header(Base Parameters)]
        _Color ("Tint", Color) = (1, 1, 1, 1)
        _MainTex ("Texture", 2D) = "white" {}
        _Specular ("Specular Color", Color) = (1,1,1,1)
        [HDR] _Emission ("Emission", color) = (0 ,0 ,0 , 1)

        [Header(Lighting Parameters)]
        _ShadowTint ("Shadow Color", Color) = (0.5, 0.5, 0.5, 1)
        [IntRange]_StepAmount ("Shadow Steps", Range(1, 16)) = 2
        _StepWidth ("Step Size", Range(0, 1)) = 0.25
        _SpecularSize ("Specular Size", Range(0, 1)) = 0.1
        _SpecularFalloff ("Specular Falloff", Range(0, 2)) = 1
    }
    SubShader {
        //the material is completely non-transparent and is rendered at the same time as the other opaque geometry
        Tags{ "RenderType"="Opaque" "Queue"="Geometry"}

        CGPROGRAM

        //the shader is a surface shader, meaning that it will be extended by unity in the background to have fancy lighting and other features
        //our surface shader function is called surf and we use our custom lighting model
        //fullforwardshadows makes sure unity adds the shadow passes the shader might need
        #pragma surface surf Stepped fullforwardshadows
        #pragma target 3.0

        sampler2D _MainTex;
        fixed4 _Color;
        half3 _Emission;
        fixed4 _Specular;

        float3 _ShadowTint;
        float _StepWidth;
        float _StepAmount;
        float _SpecularSize;
        float _SpecularFalloff;

        struct ToonSurfaceOutput{
            fixed3 Albedo;
            half3 Emission;
            fixed3 Specular;
            fixed Alpha;
            fixed3 Normal;
        };

        //our lighting function. Will be called once per light
        float4 LightingStepped(ToonSurfaceOutput s, float3 lightDir, half3 viewDir, float shadowAttenuation){
            //how much does the normal point towards the light?
            float towardsLight = dot(s.Normal, lightDir);

            //stretch values so each whole value is one step
            towardsLight = towardsLight / _StepWidth;
            //make steps harder
            float lightIntensity = floor(towardsLight);

            // calculate smoothing in first pixels of the steps and add smoothing to step, raising it by one step
            // (that's fine because we used floor previously and we want everything to be the value above the floor value, 
            // for example 0 to 1 should be 1, 1 to 2 should be 2 etc...)
            float change = fwidth(towardsLight);
            float smoothing = smoothstep(0, change, frac(towardsLight));
            lightIntensity = lightIntensity + smoothing;

            // bring the light intensity back into a range where we can use it for color
            // and clamp it so it doesn't do weird stuff below 0 / above one
            lightIntensity = lightIntensity / _StepAmount;
            lightIntensity = saturate(lightIntensity);

        #ifdef USING_DIRECTIONAL_LIGHT
            //for directional lights, get a hard vut in the middle of the shadow attenuation
            float attenuationChange = fwidth(shadowAttenuation) * 0.5;
            float shadow = smoothstep(0.5 - attenuationChange, 0.5 + attenuationChange, shadowAttenuation);
        #else
            //for other light types (point, spot), put the cutoff near black, so the falloff doesn't affect the range
            float attenuationChange = fwidth(shadowAttenuation);
            float shadow = smoothstep(0, attenuationChange, shadowAttenuation);
        #endif
            lightIntensity = lightIntensity * shadow;

            //calculate how much the surface points points towards the reflection direction
            float3 reflectionDirection = reflect(lightDir, s.Normal);
            float towardsReflection = dot(viewDir, -reflectionDirection);

            //make specular highlight all off towards outside of model
            float specularFalloff = dot(viewDir, s.Normal);
            specularFalloff = pow(specularFalloff, _SpecularFalloff);
            towardsReflection = towardsReflection * specularFalloff;

            //make specular intensity with a hard corner
            float specularChange = fwidth(towardsReflection);
            float specularIntensity = smoothstep(1 - _SpecularSize, 1 - _SpecularSize + specularChange, towardsReflection);
            //factor inshadows
            specularIntensity = specularIntensity * shadow;

            float4 color;
            //calculate final color
            color.rgb = s.Albedo * lightIntensity * _LightColor0.rgb;
            color.rgb = lerp(color.rgb, s.Specular * _LightColor0.rgb, saturate(specularIntensity));

            color.a = s.Alpha;
            return color;
        }


        //input struct which is automatically filled by unity
        struct Input {
            float2 uv_MainTex;
        };

        //the surface shader function which sets parameters the lighting function then uses
        void surf (Input i, inout ToonSurfaceOutput o) {
            //sample and tint albedo texture
            fixed4 col = tex2D(_MainTex, i.uv_MainTex);
            col *= _Color;
            o.Albedo = col.rgb;

            o.Specular = _Specular;

            float3 shadowColor = col.rgb * _ShadowTint;
            o.Emission = _Emission + shadowColor;
        }
        ENDCG
    }
    FallBack "Standard"
}
```

I mainly concentrated on the lighting function in those tutorials, you can easily expand the shader by passint out different values from the surface function including using textures for emissive color or normals. I also think it might be a good call to add the specular size to the surface struct and use that in the lighting function to be able to do drive the look more via textures. Whatever you end up doing I hope this tutorial made you curious about non photorealistic lighting and helped you realise the look you wanted to create.