---
layout: post
title: "Variables"
image: /assets/images/posts/003/Result.png
---

## Summary

After making clear how the shader stages are put together and the rough outline of shaderlab outside of the actual shader code, lets talk about what variables our shader needs to function and how we add them to our code. This includes the variables that we set per material, the variables that are part of the mesh data and the data thats passed from the vertex to the fragment.

## Object Data

What I called object data when explaining the shader flow and just called mesh data doesn't really have to be either. On a low program levels they're data streams that define what will be rendered, but imagining it at a higher level as a mesh makes it easier to think about. For most cases this data has to include the vertex positions and the triangles that span between them. Other data thats often passed in via this are the vertex normals, uv coordinates and vertex colors. The per vertex data (so everything except the triangles) is then processed by the vertex stage before being rendered. The positions and directions are all in local space, so no matter how the object is scaled or moved, we can use the same vertex data without additional preparation.

In unity shaders this data is usually passed to the vertex shader in a struct thats most commonly named `appdata` (if you know why, please tell me, I'm curious). You can give the data any name, but you have to add identifiers to tell unity which variable should be filled with what data, for example like this:

```glsl
struct appdata{
  float4 vertex : POSITION;
  float2 uv : TEXCOORD0;
};
```

You can find a list of common vertex streams here: <https://docs.unity3d.com/Manual/SL-VertexProgramInputs.html>

## Interpolators

After the data was modified in the vertex stage it gets used by the rasterizer to generate the pixels that are drawn. For that we have to set the position in the local position how it's on the screen (in clip space) so the rasterizer knows where to draw it and mark the variable with the `SV_POSITION` tag. Any other data is optional and can be used by the fragment stage to generate the colors including reading from textures and lighting effects. For the pixels that are generated inbetween the vertices with the data, the data is interpolated, hence the name interpolator. Another common descriptor is`v2f` for "vertex to fragment".

An example for a simple interpolator struct looks like this:

```glsl
//the data thats passed from the vertex to the fragment shader and interpolated by the rasterizer
struct v2f{
  float4 position : SV_POSITION;
  float2 uv : TEXCOORD0;
};
```

## Output color

For the output we most commonly use a simple 4d vector for the red/green/blue/alpha channels of the output color. It's important to tag the fragment function as `SV_Target` to tell the compiler that the output is used as the color.

## Uniform data

In addition to the data in the shader thats part of the rendered mesh theres the data we set per material. This kind of data is commonly refered to as uniform data since it's uniform over the whole draw. This can be numbers, textures, vectors, whatever. Part of this data are also the matrices that define the camera thats currently rendering as well as the transform of the object thats being rendered. Luckily for us all of that is automatically set up by unity so we don't have to worry about it for now.

To define new uniform data we just have to add variables to the shader program we're writing outside of all structs or functions.

```glsl
//texture and transforms of the texture
sampler2D _MainTex;
float4 _MainTex_ST;

//tint of the texture
fixed4 _Color;
```

As soon as those variables exist we can set them via code ([Material.Set`Type`](https://docs.unity3d.com/ScriptReference/Material.SetFloat.html)). But to show them in the inspector we have to declare them as properties at the top of our file. Properties are always in the pattern `_Variable ("Inspector Name", Type) = DefaultValue` with [property drawers](https://docs.unity3d.com/ScriptReference/MaterialPropertyDrawer.html) in front. A special case in this is textures since they not only write the texture into the variable you provide, but also take the tiling and the offset and write them into a variable of the same name but with at `_ST` at the end (ST stands of scale and translate, in old versions of unity it was called that instead of tiling and offset).

The properties section can for example look like this:

```glsl
Properties{
  _Color ("Tint", Color) = (0, 0, 0, 1)
  _MainTex ("Texture", 2D) = "white" {}
}
```

## Spaces?

When talking about positions in shaders theres often talk about object/world/view/screen/clip space. In this context space is a context to a coordinate to be in.

Object space coordinates are the coordinates in the context of the object. 0, 0 in object space is at the origin of that object. If the object is rotated or scaled coordinates in object space are rotated or scaled with it (mainly in relation to worldspace, the "closest" space). The coordinates of vertices are saved in object space in files and uploaded as such to the GPU.

World space coordinates are coordinates in relation to everything else. Theres a word 0, 0 point but it's largely arbitrary. If you think about positions, chances are big you're thinking in world space.

View space is the position of the object in relation to the camera. Clip space is the position after the projection matrix is applied, so the positions are scaled based on the camera and if you do perspective projection objects that are further away from the camera in worldspace are smaller in clipspace. Screenspace is the position after some tricks we need for rendering have been applied, so most of the time you can ignore view and clip space and try to get screen space coordinates (and theres nice utility functions so you don't have to understand matrix multiplication).

## Source

All tutorials have the source of the resulting shader linked at the bottom. Since we're just analyzing right now I'm just gonna put the code of a full shader here for now.

- <https://github.com/ronja-tutorials/ShaderTutorials/blob/master/Assets/001-004_basic_unlit/basic_unlit.shader>

```glsl
Shader "Tutorial/001-004_Basic_Unlit"{
  //show values to edit in inspector
  Properties{
    _Color ("Tint", Color) = (0, 0, 0, 1)
    _MainTex ("Texture", 2D) = "white" {}
  }

  SubShader{
    //the material is completely non-transparent and is rendered at the same time as the other opaque geometry
    Tags{ "RenderType"="Opaque" "Queue"="Geometry" }

    Pass{
      CGPROGRAM

      //include useful shader functions
      #include "UnityCG.cginc"

      //define vertex and fragment shader functions
      #pragma vertex vert
      #pragma fragment frag

      //texture and transforms of the texture
      sampler2D _MainTex;
      float4 _MainTex_ST;

      //tint of the texture
      fixed4 _Color;

      //the mesh data thats read by the vertex shader
      struct appdata{
        float4 vertex : POSITION;
        float2 uv : TEXCOORD0;
      };

      //the data thats passed from the vertex to the fragment shader and interpolated by the rasterizer
      struct v2f{
        float4 position : SV_POSITION;
        float2 uv : TEXCOORD0;
      };

      //the vertex shader function
      v2f vert(appdata v){
        v2f o;
        //convert the vertex positions from object space to clip space so they can be rendered correctly
        o.position = UnityObjectToClipPos(v.vertex);
        //apply the texture transforms to the UV coordinates and pass them to the v2f struct
        o.uv = TRANSFORM_TEX(v.uv, _MainTex);
        return o;
      }

      //the fragment shader function
      fixed4 frag(v2f i) : SV_TARGET{
          //read the texture color at the uv coordinate
        fixed4 col = tex2D(_MainTex, i.uv);
        //multiply the texture color and tint color
        col *= _Color;
        //return the final color to be drawn on screen
        return col;
      }

      ENDCG
    }
  }
  Fallback "VertexLit"
}
```
