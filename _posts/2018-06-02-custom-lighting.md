---
layout: post
title: "Custom Lighting"
image: /assets/images/posts/013/Result.png
---

## Summary
Surface shaders are wonderful and being able to use the Standard PBR model is very powerful. But we don’t always want the PBR light. Sometimes we want to change the way we treat lighting to get a different, often more cartoonish, look. Custom lighting functions allow us to do exactly that.

This tutorial is about a surface shader specific feature, while the basics of lighting are the same in all shaders, you need a lot more code to archieve the same result from a non-surface shader and I won’t explain it in this tutorial.

This tutorial will build on the result of the [surface shader basics tutorial]({{ site.baseurl }}{% post_url 2018-03-30-simple-surface %}) and I recommend you to have understood it first. 

![Result](/assets/images/posts/013/Result.png)

## Use Custom Lighting Function
We start by changing the lighting function to a custom lighting function we’ll write ourselves.

```glsl
//the shader is a surface shader, meaning that it will be extended by unity in the background to have fancy lighting and other features
//our surface shader function is called surf and we use our custom lighting model
//fullforwardshadows makes sure unity adds the shadow passes the shader might need
#pragma surface surf Custom fullforwardShadows
```

Then we add a method to our shader which will be our lighting function. The name of this function has to be LightingX where X is the name of our lighting method we reference in the surface definition. In this definition of the method we’re using here, we get the surfaceoutput we return from the surface shader, as well as the direction the light is hitting the surface point from and the attenuation (I’ll explain later what that does).

```glsl
//our lighting function. Will be called once per light
float4 LightingCustom(SurfaceOutput s, float3 lightDir, float atten){
    return 0;
}
```

You might notice that I use the SurfaceOutput struct here instead of SurfaceOutputStandart struct. That’s because our custom lighting model won’t use metalness and softness, so we can use the struct meant for non-PBR materials (you can use SurfaceOutputStandard for your custom lighting functions if you want to, but you’ll have to import UnityPBSLighting.cginc). To use the SurfaceOutput struct, we also have to return it in our surface shader function and remove the parts where we set the metal and smoothness values.

I also removed metalness and smoothness from the shader variables and properties because we don’t use them anymore, but it’s not critical that you do this.

```glsl
//the surface shader function which sets parameters the lighting function then uses
void surf (Input i, inout SurfaceOutput o) {
    //sample and tint albedo texture
    fixed4 col = tex2D(_MainTex, i.uv_MainTex);
    col *= _Color;
    o.Albedo = col.rgb;

    //o.Emission = _Emission;
}
```

After doing this, we should have a lighting function that unity uses, but it returns 0 (black), so we can’t see any lights.

![A model with only global illumination](/assets/images/posts/013/Dark.png)

The reason we can still make out shapes and it’s not solid black is that unity does global illumination and tries to approximate environment lighing by looking at the skybox, if we change environment lighting to black in the lighting tab, we will see our shape solid black, but our lighting will work anyways, so you can try out what you think makes your game look most like you want it to (I’ll keep it at the default settings).

## Implement Lighting Ramp
Next we’ll implement a simple lighting model. The first step is to get the dot product between the vector from the surface to the light and the normal. Luckily unity provides both to us, and both are already in worldspace as well as normalized(they have the length of 1), so we don’t have to convert them.

The dot product then tells us how much the surface points towards the light. It has a value of 0 where the surface is paralell to the direction to the light, is has a value of 1 where the light points towards the light and a value of -1 where the surface points away.

```glsl
//our lighting function. Will be called once per light
float4 LightingCustom(SurfaceOutput s, float3 lightDir, float atten){
    //how much does the normal point towards the light?
    float towardsLight = dot(s.Normal, lightDir);
    return towardsLight;
}
```
![Simple lighting](/assets/images/posts/013/DotLight.png)

The lighting method we’re going to implement is pretty simple, but also very versatile. We’re going to use the amount the surface points towards the light to look up a value of a texture and use that as our brightness.

For that we have to change the variable from values that go from -1 to 1 to values between 0 and 1 (because UV variables go from 0 to 1), we do that by multiplying it by 0.5 (then it has a range from -0.5 to 0.5) and then adding 0.5 (shifting the range to 0 to 1 where we want it).

Next we add a new texture to our shader as a shader variable as well as a property. I’ll name it ramp, because the lighting technique is usually called toon ramp. Then we read from that texture in the lighting function and return the value we read from that. I’ll use a function that’s half black and half white so we should see a clear cut on the model.

```glsl
//show values to edit in inspector
Properties {
    _Color ("Tint", Color) = (0, 0, 0, 1)
    _MainTex ("Texture", 2D) = "white" {}
    [HDR] _Emission ("Emission", color) = (0,0,0)

    _Ramp ("Toon Ramp", 2D) = "white" {}
}

//...

sampler2D _Ramp;
```

This is the texture I use in this example:

![A image thats black on the right and black on the left side](/assets/images/posts/013/HardRamp.png)

```glsl
//our lighting function. Will be called once per light
float4 LightingCustom(SurfaceOutput s, float3 lightDir, float atten){
    //how much does the normal point towards the light?
    float towardsLight = dot(s.Normal, lightDir);
    //remap the value from -1 to 1 to between 0 and 1
    towardsLight = towardsLight * 0.5 + 0.5;

    //read from toon ramp
    float3 lightIntensity = tex2D(_Ramp, towardsLight).rgb;

    return float4(lightIntensity, 1);
}
```
![surface thats completely white towards the light source](/assets/images/posts/013/DrawRamp.png)

You can see that we can already see the albedo in the shadows here, that’s again because of the environment lighting calculations unity adds in the background, but it will look better soon.

Namely, to make it look better, we’re going to multiply the light intensity with the albedo of the material so we see our colors correctly as well as the attenuation, which includes casted shadows as well as the light falloff, so the light gets darker in the distance and the light color, so the object gets tinted in the color it gets illuminated in.

```glsl
//our lighting function. Will be called once per light
float4 LightingCustom(SurfaceOutput s, float3 lightDir, float atten){
    //how much does the normal point towards the light?
    float towardsLight = dot(s.Normal, lightDir);
    //remap the value from -1 to 1 to between 0 and 1
    towardsLight = towardsLight * 0.5 + 0.5;

    //read from toon ramp
    float3 lightIntensity = tex2D(_Ramp, towardsLight).rgb;

    //combine the color
    float4 col;
    //intensity we calculated previously, diffuse color, light falloff and shadowcasting, color of the light
    col.rgb = lightIntensity * s.Albedo * atten * _LightColor0.rgb;
    //in case we want to make the shader transparent in the future - irrelevant right now
    col.a = s.Alpha; 

    return col;
}
```
![A surface with a hard light cutoff](/assets/images/posts/013/CorrectRampLighting.png)

That’s the whole shader. The advantage of it is that we can now add all kinds of different toon ramps, including ramps with colors. For example this ramp which has a warm front side and a blueish cold backside with a exaggerated transition I got from the unity examples <https://docs.unity3d.com/Manual/SL-SurfaceShaderLightingExamples.html>.

![A lighting ramp with blue values on the left and red ones on the right](/assets/images/posts/013/HotColdRamp.png)

![the red/blue ramp applied, the surface has cold shadows](/assets/images/posts/013/HotColdRampModel.png)

One thing we didn’t write for our shader, which still works though is emission. Because emission is the light the object itself emits it’s independent from other lights and not calculated in the lighting function.

This toon shader is wonderful and flexible and I’ve seen it used in many places.

Lighting functions in general are very useful and powerful. One thing to keep in mind though is that they only work in forward rendering. When you switch your render mode to deferred you can still see the objects like you’re used to, but they can’t take advantage of deferred rendering (don’t worry about it and stick to forward rendering if you don’t know the difference).

```glsl
Shader "Tutorial/013_CustomSurfaceLighting" {
    //show values to edit in inspector
    Properties {
        _Color ("Tint", Color) = (0, 0, 0, 1)
        _MainTex ("Texture", 2D) = "white" {}
        [HDR] _Emission ("Emission", color) = (0,0,0)

        _Ramp ("Toon Ramp", 2D) = "white" {}
    }
    SubShader {
        //the material is completely non-transparent and is rendered at the same time as the other opaque geometry
        Tags{ "RenderType"="Opaque" "Queue"="Geometry"}

        CGPROGRAM

        //the shader is a surface shader, meaning that it will be extended by unity in the background to have fancy lighting and other features
        //our surface shader function is called surf and we use our custom lighting model
        //fullforwardshadows makes sure unity adds the shadow passes the shader might need
        #pragma surface surf Custom fullforwardshadows
        #pragma target 3.0

        sampler2D _MainTex;
        fixed4 _Color;
        half3 _Emission;

        sampler2D _Ramp;

        //our lighting function. Will be called once per light
        float4 LightingCustom(SurfaceOutput s, float3 lightDir, float atten){
            //how much does the normal point towards the light?
            float towardsLight = dot(s.Normal, lightDir);
            //remap the value from -1 to 1 to between 0 and 1
            towardsLight = towardsLight * 0.5 + 0.5;

            //read from toon ramp
            float3 lightIntensity = tex2D(_Ramp, towardsLight).rgb;

            //combine the color
            float4 col;
            //intensity we calculated previously, diffuse color, light falloff and shadowcasting, color of the light
            col.rgb = lightIntensity * s.Albedo * atten * _LightColor0.rgb;
            //in case we want to make the shader transparent in the future - irrelevant right now
            col.a = s.Alpha; 

            return col;
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

            //o.Emission = _Emission;
        }
        ENDCG
    }
    FallBack "Standard"
}
```

I hope I could explain how to implement custom lighting functions into surface shaders.

You can also find the source code for this shader here: <https://github.com/ronja-tutorials/ShaderTutorials/blob/master/Assets/013_CustomSurfaceLighting/CustomLighting.shader>