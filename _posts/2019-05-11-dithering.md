---
layout: post
title: "Dithering"
image: /assets/images/posts/042/Result.gif
hidden: true
---

We often use gradients of some kind in shaders, but there are cases where we're limited to less shades of colors than we want to express. One common technique to fake having many different colors with only a few is dithering. In this tutorial I explain how to dither between two colors based on a given ratio, but it's also possible to use dithering for more shades of color with more complex algorithms.

![](/assets/images/posts/042/Result.gif)

## Simple Dithering

For this first version we're taking the red channel of the input texture as the ratio between the two colors. For the pattern how to combine them we use a "bayer dithering" pattern, it's optimized to have as much difference between the neighboring pixels in the pattern. As the base for this shader I used the result of [the unlit shader with texture access]({{ site.baseurl }}{% post_url 2018-03-23-textures %}).

Getting access to the base color we want to dither is already done with with this texture sample, but we don't know how to read from the dither pattern texture. Unless you use fancy mapping techniques like Return of Obra Dinn did, the most straightforward approach here is to use screenspace UV coordinates. I explain how to get the basic screenspace coordinates in [this tutorial]({{ site.baseurl }}{% post_url 2019-01-20-screenspace-texture %}). One thing that's pretty special about dithering is that we don't care about how big the dither texture is or how often it repeats on the screen. The only thing we care about is that one texture pixel maps to one screen pixel to use it exactly as intended. To archieve that we first multiply the sceenspace UVs by the screen size itself, creating a UV set that increases by 1 for every pixel. Then we divide that UV by the amount of pixels of the dither texture, creating a texture that goes from 0 to 1 every "dither texture size" pixels, always sampling the middle of the pixels.

When doing those calculations we can easily get the screen size from the x and y components of the builtin `_ScreenParams` variable. To get the size of the dither pattern we add a new variable to the shader that has the same name as the texture we want to know the size of, but with `_TexelSize` to the end of it's name. Then instead of dividing by the size of the texture (the z and w components of this vector) we can also multiply with one divided by the size, this value is already saved in the x and y components of this vector. We do this because a multiplication is usually faster than a division.

Here are the 4x4 and 8x8 versions of the dither texture I used:

![](/assets/images/posts/042/BayerDither4x4.png)
![](/assets/images/posts/042/BayerDither8x8.png)

It's important to disable compression completely in unity, otherwise it will mess with your textures and it will look bad (the textures are so tiny that compression wouldn't make much of a difference anyways). Which texture you use doesn't matter that much, the 8x8 texture gives you similar results in small areas and leads to less banding with slowly changing values, so if you're not sure use the bigger one.

```glsl
//Shader Property
_DitherPattern ("Dithering Pattern", 2D) = "white" {}
```

```glsl
//Shader Variables

//The dithering pattern
sampler2D _DitherPattern;
float4 _DitherPattern_TexelSize;
```

```glsl
//the data that's used to generate fragments and can be read by the fragment shader
struct v2f{
    float4 position : SV_POSITION;
    float2 uv : TEXCOORD0;
    float4 screenPosition : TEXCOORD1;
};
```

```glsl
//test fragment shader
fixed4 frag(v2f i) : SV_TARGET{
    float2 screenPos = i.screenPosition.xy / i.screenPosition.w;
    float2 ditherCoordinate = screenPos * _ScreenParams.xy * _DitherPattern_TexelSize.xy;
    float ditherValue = tex2D(_DitherPattern, ditherCoordinate).r;
    return ditherValue;
}
```

![](/assets/images/posts/042/DitherPattern.png)

With this value in hand we can already compare it to the density of the dithering and render the result. For this case the `step` function is ideal, we can pipe in the dither value and the value of our texture to get a 0 or 1 binary result that'll represent the value of the texture value by regulating the density of the pixels.

```glsl
//the fragment shader
fixed4 frag(v2f i) : SV_TARGET{
    //texture value the dithering is based on
    float texColor = tex2D(_MainTex, i.uv).r;

    //value from the dither pattern
    float2 screenPos = i.screenPosition.xy / i.screenPosition.w;
    float2 ditherCoordinate = screenPos * _ScreenParams.xy * _DitherPattern_TexelSize.xy;
    float ditherValue = tex2D(_DitherPattern, ditherCoordinate).r;

    //combine dither pattern with texture value to get final result
    float col = step(ditherValue, texColor);
    return col;
}
```

![](/assets/images/posts/042/DitherGradient.png)

If you want to make the dither colors anything but black/white you can use a linear interpolation with the value we just used as a color as the interpolation parameter.

```glsl
//Shader Properties
_Color1 ("Dither Color 1", Color) = (0, 0, 0, 1)
_Color2 ("Dither Color 2", Color) = (1, 1, 1, 1)
```

```glsl
//Shader variables
float4 _Color1;
float4 _Color2;
```

```glsl
//the fragment shader
fixed4 frag(v2f i) : SV_TARGET{
    //texture value the dithering is based on
    float texColor = tex2D(_MainTex, i.uv).r;

    //value from the dither pattern
    float2 screenPos = i.screenPosition.xy / i.screenPosition.w;
    float2 ditherCoordinate = screenPos * _ScreenParams.xy * _DitherPattern_TexelSize.xy;
    float ditherValue = tex2D(_DitherPattern, ditherCoordinate).r;

    //combine dither pattern with texture value to get final result
    float ditheredValue = step(ditherValue, texColor);
    float4 col = lerp(_Color1, _Color2, ditheredValue);
    return col;
}
```


![](/assets/images/posts/042/DyedDither.png)