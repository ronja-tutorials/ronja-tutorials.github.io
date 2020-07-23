---
layout: post
title: "Sprite Outlines"
image: /assets/images/posts/049/Properties.gif
tags: shader, unity, outlines
---

I already talked about 2 ways of generating outlines in your programs, [by analyzing the depth and normals of your scene]({{ site.baseurl }}{% post_url 2018-07-15-postprocessing-outlines %}) or [by rendering the model twice with a hull]({{ site.baseurl }}{% post_url 2018-07-21-hull-outline %}). Both of those assume we're using opaque meshes that write into the depth buffer, if we're using 2d sprites neither approach works.
The approach for this tutorial uses the alpha channel of a texture to generate 2d outlines.

## Basic Implementation

The idea is that we sample the texture at multiple spots around the uv point and remember the biggest value of the alpha channel we find. When a Pixel is not visible for the original texture sample, but we can find a higher alpha value when looking at the neighboring pixels, then we color in the outline.

The base for our code is from [my sprite shader tutorial]({{ site.baseurl }}{% post_url 2018-04-13-sprite-shaders %}). In the fragment function we start by making an array of directions we want to sample in. You could sacrifice some speed for more flexibility and get the directions via `sin` and `cos`, but thats your choice. I chose to sample in 8 directions, the for cardinal directions as well as diagonals. Important here is that the diagonal directions should also have a length of 1, if we just use `(1, 1)` they'd have a length of `sqrt(2)` (you can easily get that via the pythogoras (`sqrt(1² + 1²)`)), instead we divide each component by `sqrt(2)`, so use `1 / sqrt(2)` and all is fine.

```glsl
#define DIV_SQRT_2 0.70710678118
float2 directions[8] = {float2(1, 0), float2(0, 1), float2(-1, 0), float2(0, -1),
  float2(DIV_SQRT_2, DIV_SQRT_2), float2(-DIV_SQRT_2, DIV_SQRT_2),
  float2(-DIV_SQRT_2, -DIV_SQRT_2), float2(DIV_SQRT_2, -DIV_SQRT_2)};
```

Before the loop we declare the "maximum alpha" variable and initialize it to zero. The loop is a simple for loop over all 8 indices of the array (you could also make it count to 4 for a cheaper outline without diagonals). Inside the loop we first calculate the sample point and then put the maximum of the maximum alpha so far and the alpha at that point in the maximum alpha variable.

```glsl
//generate border
float maxAlpha = 0;
for(uint index = 0; index<8; index++){
    float2 sampleUV = i.uv + directions[index] * 0.001/*magic number*/;
    maxAlpha = max(maxAlpha, tex2D(_MainTex, sampleUV).a);
}
```

After figuring out the maximum alpha of those points we can apply the border by first making everything that isn't visible in the original sprite have the color of our outline. Then we set the color to the maximum value between the alpha so far and the maximum alpha of our border samples.

```glsl
//apply border
col.rgb = lerp(float3(1, 0, 0)/*magic color*/, col.rgb, col.a);
col.a = max(col.a, maxAlpha);

return col;
```

This should net you something like this. Not pretty, not flexible, but a outline!

```glsl
fixed4 frag(v2f i) : SV_TARGET{
  //get regular color
  fixed4 col = tex2D(_MainTex, i.uv);
  col *= _Color;
  col *= i.color;

  //sample directions
          #define DIV_SQRT_2 0.70710678118
          float2 directions[8] = {float2(1, 0), float2(0, 1), float2(-1, 0), float2(0, -1),
              float2(DIV_SQRT_2, DIV_SQRT_2), float2(-DIV_SQRT_2, DIV_SQRT_2),
              float2(-DIV_SQRT_2, -DIV_SQRT_2), float2(DIV_SQRT_2, -DIV_SQRT_2)};

  //generate border
  float maxAlpha = 0;
  for(uint index = 0; index<8; index++){
      float2 sampleUV = i.uv + directions[index] * 0.01;
      maxAlpha = max(maxAlpha, tex2D(_MainTex, sampleUV).a);
  }

  //apply border
  col.rgb = lerp(float3(1, 0, 0), col.rgb, col.a);
  col.a = max(col.a, maxAlpha);

  return col;
}
```

![](\assets\images\posts\049\FirstShot.png)

## Cleanup

Lets add two properties so we can change the way our outline looks without having to recompile the shader. One of them is for the width of the outline and one for the color.

```glsl
//in properties block
_OutlineColor ("Outline Color", Color) = (1, 1, 1, 1)
_OutlineWidth ("Outline Width", Range(0, 10)) = 1
```

```glsl
//in CGPROGRAM
fixed4 _OutlineColor;
float _OutlineWidth;
```

Then in our function we use the color property instead of the hardcoded red value.

```glsl
//apply border
col.rgb = lerp(_OutlineColor.rgb, col.rgb, col.a);
```

Next lets fix up the outline size, currently its declared via a magic number in uv space. A easy fix is to declare how many texture pixels we want the outline to be. We can get the size of one texture pixel (or texel) by creating a new variable called \<TextureName\>\_TexelSize, so in our case \_MainTex_TexelSize. Then we can multiply our property with the x and y components of that variable (`x` and `y` are texel size in uv distance, `z` and `w` are texture size in pixels) and use the result as a scale for the outline width instead.

```glsl
float2 sampleDistance = _MainTex_TexelSize.xy * _OutlineWidth;

//generate border
float maxAlpha = 0;
for(uint index = 0; index<8; index++){
  float2 sampleUV = i.uv + directions[index] * sampleDistance;
  maxAlpha = max(maxAlpha, tex2D(_MainTex, sampleUV).a);
}
```

![](\assets\images\posts\049\Properties.gif)

## World Distance Outline

You might not always want to have your outline scale in texture pixels though. You might want a outline width in screen pixels, in screen percent, in world distance. I'm not gonna go through all of those possibilities there, but I am going to show the most complex of those, world space width.

We just need the uv distance per world distance and then we can multiply that with our outline width like we're doing so far with the texel size, so lets write a function for that. Calculating that is possible via [screenspace partial derivatives, better known as ddx, ddy and fwidth]({{ site.baseurl }}{% post_url 2019-11-29-fwidth %}).

The derivatives allow us to get the change in uv per screen pixel as well as the change in worldspace position per screen pixel. We have to get the absolute value of the uv change to not accidentally get negative values as well as get the length of the change in world position to get correct distances in case our camera is rotated.

With those values we can get the uv per unit in both x and y axis by dividing the uv per pixel by the units per pixel. After getting that for x and y we simply add the two values and return it.

```glsl
float2 uvPerWorldUnit(float2 uv, float2 space){
  float2 uvPerPixelX = abs(ddx(uv));
  float2 uvPerPixelY = abs(ddy(uv));
  float unitsPerPixelX = length(ddx(space));
  float unitsPerPixelY = length(ddy(space));
  float2 uvPerUnitX = uvPerPixelX / unitsPerPixelX;
  float2 uvPerUnitY = uvPerPixelY / unitsPerPixelY;
  return (uvPerUnitX + uvPerUnitY);
}
```

You might have notives that I was talking about using the world position even though we don't have access to that yet, so lets quickly add that, I havent made a tutorial specifically about that, but [the planar mapping one]({{ site.baseurl }}{% post_url 2018-04-23-planar-mapping %}) uses the world pos and not much else.

```glsl
struct v2f{
  float4 position : SV_POSITION;
  float2 uv : TEXCOORD0;
  float3 worldPos : TEXCOORD1;
  fixed4 color : COLOR;
};
```

```glsl
v2f vert(appdata v){
  v2f o;
  o.position = UnityObjectToClipPos(v.vertex);
  o.worldPos = mul(unity_ObjectToWorld, v.vertex);
  o.uv = TRANSFORM_TEX(v.uv, _MainTex);
  o.color = v.color;
  return o;
}
```

```glsl
//in fragment function
float2 sampleDistance = uvPerWorldUnit(i.uv, i.worldPos.xy) * _OutlineWidth;
```

with this you can freely scale, rotate, whatever your sprites and you'll always have a consistent outline.

![](/assets/images/posts/049/WorldOutlines.gif)

## Limitations

One huge limitation of this method is that we can only draw the outline where theres already a mesh, setting the mesh type in our sprites to "Full Rect" as well as adding padding to the sprites helps by just rendering more by default, but it also adds overdraw to your scene and it also can't always avoid artefacts, I tried thinking about how to do that but couldn't come up with a quick tutorial-able solution.

In addition to that this method is really bad at generating outlines of small or pointy features, often generating spikes in the outline. If you want to have 2d outlines but a more perfect approach, heres a article about how you might try to do that: <https://medium.com/@bgolus/the-quest-for-very-wide-outlines-ba82ed442cd9>.

## Source

- <https://github.com/ronja-tutorials/ShaderTutorials/blob/master/Assets/049_Sprite_Outline/SpriteOutline.shader>

```glsl
Shader "Tutorial/049_SpriteOutline"{
  Properties{
    _Color ("Tint", Color) = (0, 0, 0, 1)
    _OutlineColor ("OutlineColor", Color) = (1, 1, 1, 1)
    _OutlineWidth ("OutlineWidth", Range(0, 1)) = 1
    _MainTex ("Texture", 2D) = "white" {}
  }

  SubShader{
    Tags{
      "RenderType"="Transparent"
      "Queue"="Transparent"
    }

    Blend SrcAlpha OneMinusSrcAlpha

    ZWrite off
    Cull off

    Pass{
      CGPROGRAM

      #include "UnityCG.cginc"

      #pragma vertex vert
      #pragma fragment frag

      sampler2D _MainTex;
      float4 _MainTex_ST;
      float4 _MainTex_TexelSize;

      fixed4 _Color;
      fixed4 _OutlineColor;
      float _OutlineWidth;

      struct appdata{
        float4 vertex : POSITION;
        float2 uv : TEXCOORD0;
        fixed4 color : COLOR;
      };

      struct v2f{
        float4 position : SV_POSITION;
        float2 uv : TEXCOORD0;
        float3 worldPos : TEXCOORD1;
        fixed4 color : COLOR;
      };

      v2f vert(appdata v){
        v2f o;
        o.position = UnityObjectToClipPos(v.vertex);
        o.worldPos = mul(unity_ObjectToWorld, v.vertex);
        o.uv = TRANSFORM_TEX(v.uv, _MainTex);
        o.color = v.color;
        return o;
      }

      float2 uvPerWorldUnit(float2 uv, float2 space){
        float2 uvPerPixelX = abs(ddx(uv));
        float2 uvPerPixelY = abs(ddy(uv));
        float unitsPerPixelX = length(ddx(space));
        float unitsPerPixelY = length(ddy(space));
        float2 uvPerUnitX = uvPerPixelX / unitsPerPixelX;
        float2 uvPerUnitY = uvPerPixelY / unitsPerPixelY;
        return (uvPerUnitX + uvPerUnitY);
      }

      fixed4 frag(v2f i) : SV_TARGET{
      //get regular color
        fixed4 col = tex2D(_MainTex, i.uv);
        col *= _Color;
        col *= i.color;

        float2 sampleDistance = uvPerWorldUnit(i.uv, i.worldPos.xy) * _OutlineWidth;

        //sample directions
        #define DIV_SQRT_2 0.70710678118
        float2 directions[8] = {float2(1, 0), float2(0, 1), float2(-1, 0), float2(0, -1),
          float2(DIV_SQRT_2, DIV_SQRT_2), float2(-DIV_SQRT_2, DIV_SQRT_2),
          float2(-DIV_SQRT_2, -DIV_SQRT_2), float2(DIV_SQRT_2, -DIV_SQRT_2)};

        //generate border
        float maxAlpha = 0;
        for(uint index = 0; index<8; index++){
          float2 sampleUV = i.uv + directions[index] * sampleDistance;
          maxAlpha = max(maxAlpha, tex2D(_MainTex, sampleUV).a);
        }

        //apply border
        col.rgb = lerp(_OutlineColor.rgb, col.rgb, col.a);
        col.a = max(col.a, maxAlpha);

        return col;
      }
      ENDCG
    }
  }
}
```
