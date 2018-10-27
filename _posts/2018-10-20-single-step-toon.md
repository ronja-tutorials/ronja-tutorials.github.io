---
layout: post
title: "Single Step Toon Light"
image: /assets/images/posts/031/Result.gif
hidden: false
---

I thought about how to make a toon shader and this is the result. There are obviously many different toon styles, so this is just one possiblity of many, but even if it's not the result you want in your game this tutorial can give you some insight in how I work and how to do stuff with shaders. The main advantage for me to use this toon shader in opposition to one that reads from ramp texures is that I can dynamically change the parameters without editing a texture first.

I explain the basics of custom lighting models more indepth in [this tutorial]({{ site.baseurl }}{% post_url 2018-06-02-custom-lighting %}), but you should be fine if you know the basics of surface shaders in unity.

![](/assets/images/posts/031/Result.gif)

## Antialiased Step

We start the shader by using a basic surface shader.

```glsl
CGPROGRAM

//the shader is a surface shader, meaning that it will be extended by unity in the background to have fancy lighting and other features
//our surface shader function is called surf and we use our custom lighting model
//fullforwardshadows makes sure unity adds the shadow passes the shader might need
#pragma surface surf Standard fullforwardshadows
#pragma target 3.0

sampler2D _MainTex;
fixed4 _Color;
half3 _Emission;

//input struct which is automatically filled by unity
struct Input {
    float2 uv_MainTex;
};

//the surface shader function which sets parameters the lighting function then uses
void surf (Input i, inout SurfaceOutput o) {
    //sample and tint albedo texture
    fixed4 col = tex2D(_MainTex, i.uv_MainTex);
    col *= _Color;
    o.Albedo = col.rgb;

    o.Emission = _Emission;
}
ENDCG
```

Then we change the lighting model to our own and create a new function to match it. The function has to be called Lighting`OurLightingModelName`. The lighting model then has the name of the function name after `Lighting`. We'll take the `SurfaceOutput` of the surf function, the light direction, the view direction and the shadow attenuation as parameters for our lighing function to calculate the lighting.

```glsl
#pragma surface surf Stepped fullforwardshadows
```

```glsl
//our lighting function. Will be called once per light
float4 LightingStepped(SurfaceOutput s, float3 lightDir, half3 viewDir, float shadowAttenuation){
    return 1;
}
```

The most basic start to most lighting functions is to calculate how much the surface point points towards the light we're calculating the illumination for. For that we'll use use the dot function, it returns 1 when the vectors you pass it point in the same direction and -1 if they're opposing if they're both normalised. In this case the vectors are normalised when they're passed into the function so we don't have to worry about that. For the normal we simply use use normal of the surface output, it's also prepared by unity to already be in worldspace, just like the light and view direction.

```glsl
//our lighting function. Will be called once per light
float4 LightingStepped(SurfaceOutput s, float3 lightDir, half3 viewDir, float shadowAttenuation){
    //how much surface normal points towards the light
    flaot towardsLight = dot(s.Normal, lightDir);
    return towardsLight;
}
```

![](/assets/images/posts/031/Dot.png)

Then, to get a hard cut for the toon effect, we can use a `step` function, it'll return 0 if the first argument is greater, otherwise 1. The dot function returns 0 when the vectors are orthogonal which is the case at the half point of our surface. The side thats away from the light has negative values and the side towards the light positive ones. That's why we pass the `towardsLight` parameter as the second parameter into the step function and 0 as the first.

```glsl
//our lighting function. Will be called once per light
float4 LightingStepped(SurfaceOutput s, float3 lightDir, half3 viewDir, float shadowAttenuation){
    //how much does the normal point towards the light?
    float towardsLight = dot(s.Normal, lightDir);
    float lightIntensity = step(0, towardsLight);
    return lightIntensity;
}
```

![](/assets/images/posts/031/Step.png)

Now we have a nice hard cut, but ironically it's too hard, we get pixel steps often called aliasing. We can avoid aliasing by not jumping from 0 to 1 at one point, instead we interpolate between them over the range of one pixel. For that we'll have to find out how much the value we're evaluating (`towardsLight`) changes in a single pixel. We get that value by passing the variable to fwidth. The fwidth function will compare the value to the same variable in neighboring pixels and tell us how much it changes approximately. When we know the change of the variable we can then exchange step with smoothstep, it takes 3 parameters, the first two mark the minimum(where the output value is 0) and maximum (where the output value is 1). So we pass 0 as the first value here, the value change as the second one and the value of how much the surface points at the light as the third parameter. With this we have almost the same result as previously, but the edge looks less jaggy.

```glsl
//our lighting function. Will be called once per light
float4 LightingStepped(SurfaceOutput s, float3 lightDir, half3 viewDir, float shadowAttenuation){
    //how much does the normal point towards the light?
    float towardsLight = dot(s.Normal, lightDir);
    float towardsLightChange = fwidth(towardsLight);
    float lightIntensity = smoothstep(0, towardsLightChange, towardsLight);
    return lightIntensity;
}
```

![](/assets/images/posts/031/Smoothstep.png)

## Shadows

We use the shadowAttenuation variable to add shadows to our shader, but when we just it by itself it's too soft, something that clashes a bit with the style of this shader.

![](/assets/images/posts/031/Atten.png)

We can give it the same treatment we gave the dot value. First find out how much the variable changes in the neighboring pixels and then do a smoothstep. Because we want to cut the shadow at the middle of the gradient and not just before it's completely black, we'll half the pixel change value and then use `0.5 - changevalue` as the minimum and `0.5 + changeValue` as the maximum.

```glsl
float attenuationChange = fwidth(shadowAttenuation) * 0.5;
float shadow = smoothstep(0.5 - attenuationChange, 0.5 + attenuationChange, shadowAttenuation);

lightIntensity = lightIntensity * shadow;

return lightIntensity;
```

![](/assets/images/posts/031/Shadow.png)

The problem with hardening the shadows like this is that point lights also have their falloff encoded into the shadow attenuation property. We can sidestep this by branching our shader and doing the smoothstep from 0 to the change instead of around 0.5. This will lead to some artefacts, but at least we can have shadows for point lights. We do the branching by writing compiler directives into the shader. If the flag `USING_DIRECTIONAL_LIGHT` is defined, the shader is going to put the border around 0.5, just like we did so far and if it isn't it's going to put the border at 0.

```glsl
#ifdef USING_DIRECTIONAL_LIGHT
    float attenuationChange = fwidth(shadowAttenuation) * 0.5;
    float shadow = smoothstep(0.5 - attenuationChange, 0.5 + attenuationChange, shadowAttenuation);
#else
    float attenuationChange = fwidth(shadowAttenuation);
    float shadow = smoothstep(0, attenuationChange, shadowAttenuation);
#endif
    lightIntensity = lightIntensity * shadow;
```

![](/assets/images/posts/031/PointShadows.png)

## Colors

Now that we have a clear differentiation between shadow and light, we can add colors to the shader. The Color on the light side of the object will be the diffuse color of the object. The color on the shadowed side is the diffuse color multiplied a new shadow color, this way we can tint the shadow in any color we want. The result of the combination of light and shadow side will then we multiplied by the light color. We could also only multiply the light side color with the light color, but this can lead to the dark side being brighter than the bright side for low intensity lights which would be odd. We also get the alpha from the surface output struct to use it as the alpha channel of the output color.

```glsl
Properties {
    [Header(Base Parameters)]
    _Color ("Tint", Color) = (1, 1, 1, 1)
    _MainTex ("Texture", 2D) = "white" {}
    [HDR] _Emission ("Emission", color) = (0 ,0 ,0 , 1)
    
    [Header(Lighting Parameters)]
    _ShadowTint ("Shadow Color", Color) = (0, 0, 0, 1)
}
```
```glsl
//global hlsl variable

float3 _ShadowTint;
```
```glsl
float3 shadowColor = s.Albedo * _ShadowTint;
float4 color;
color.rgb = lerp(shadowColor, s.Albedo, lightIntensity) * _LightColor0.rgb;
color.a = s.Alpha;
return color;
```

With this we have a shader with simple shading with a hard cut.

## Source

- <https://github.com/ronja-tutorials/ShaderTutorials/blob/master/Assets/031_StepToon/SteppedToonLighting.shader>

```glsl
Shader "Tutorial/031_SteppedToon" {
    //show values to edit in inspector
    Properties {
        [Header(Base Parameters)]
        _Color ("Tint", Color) = (0, 0, 0, 1)
        _MainTex ("Texture", 2D) = "white" {}
        [HDR] _Emission ("Emission", color) = (0 ,0 ,0 , 1)

        [Header(Lighting Parameters)]
        _ShadowTint ("Shadow Color", Color) = (0.5, 0.5, 0.5, 1)
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

        float3 _ShadowTint;

        //our lighting function. Will be called once per light
        float4 LightingStepped(SurfaceOutput s, float3 lightDir, half3 viewDir, float shadowAttenuation){
            //how much does the normal point towards the light?
            float towardsLight = dot(s.Normal, lightDir);
            // make the lighting a hard cut
            float towardsLightChange = fwidth(towardsLight);
            float lightIntensity = smoothstep(0, towardsLightChange, towardsLight);

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

            //calculate shadow color and mix light and shadow based on the light. Then taint it based on the light color
            float3 shadowColor = s.Albedo * _ShadowTint;
            float4 color;
            color.rgb = lerp(shadowColor, s.Albedo, lightIntensity) * _LightColor0.rgb;
            color.a = s.Alpha;
            return color;
        }


        //input struct which is automatically filled by unity
        struct Input {
            float2 uv_MainTex;
        };

        //the surface shader function which sets parameters the lighting function then uses
        void surf (Input i, inout SurfaceOutput o) {
            //sample and tint albedo texture
            fixed4 col = tex2D(_MainTex, i.uv_MainTex);
            col *= _Color;
            o.Albedo = col.rgb;

            o.Emission = _Emission;
        }
        ENDCG
    }
    FallBack "Standard"
}
```

I hope it's interresting for you to you to see how to do simple stuff like antialiased lighting and that it'll help you in writing your own cool shaders. 💕