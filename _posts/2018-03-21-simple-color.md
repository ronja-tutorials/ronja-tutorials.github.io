---
layout: post
title: "Simple color"
---

## Summary
Here I’m gonna explain what you have to do to make a unity shader show anything. You’ll end up with a object with a single color, but we can add onto that later. If you find you have troubles understanding everything, I recommend you read the tutorial on hlsl language basics: https://ronja-tutorials.tumblr.com/post/172421924392/surface-shader-basics

![Result]({{ "/assets/images/posts/002/result.png" | absolute_url }})

## Shaderlab Framework
When writing shaders in unity, we can’t start by writing the code, we first have to tell Unity how it should use our shader. That’s why we start by defining the “Shader” section with the name of the shader and inside of that the “SubShader” section. We can define multiple subshaders per shader and tell unity when to use which one, but most of the time we want to use the same subshader everywhere so we only write that one.
```glsl  
Shader "Tutorial/02_Simple"{
    Subshader{

    }
}
```

In that subshader we will write our shader pass. When a subshader is rendered, all passes are drawn consecutively, but for now we only need one pass.
In that pass we add a few tags to tell unity how we want it to handle that pass. For this shader we want the object we render to be completely opaque and we want it to be renderered together with the other opaque objects.
```glsl  
Shader "Tutorial/02_Simple"{
    Subshader{
        Pass{
            Tags{
                "RenderType"="Opaque"
                "Queue"="Geometry"
            }

        }
    }
}
```

## HLSL Code
After we did all that, we can start writing the hlsl part of the shader. It’s important to understand how the information flows in the shader. First the information from the 3d model is given to the vertex shader, which changes the information so it’s relative to the screen, then the result of that goes through the rasterizer which converts the points and triangles to pixels which can be drawn on the screen. But at that point the shader doesn’t know yet which color each pixel has, so for each pixel of the object, the fragment shader is called. It recieves the output of the vertex shader, with interpolated values between the vertices. The fragment shader then returns the color that is drawn on the screen.

![Shader Pipeline]({{ "/assets/images/posts/002/pipeline.png" | absolute_url }})

To communicate to unity that we’re writing hlsl code here, we start that part with CGPROGRAM and end it with ENDCG. To use utility functions given to us by unity, we include the “UnityCG.cginc“ file.
```glsl  
Shader "Tutorial/02_Simple"{
    Subshader{
        Pass{
            Tags{
                "RenderType"="Opaque"
                "Queue"="Geometry"
            }

            CGPROGRAM
            #include "unityCG.cginc"

            ENDCG
        }
    }
}
```

We start by adding a struct for the input data. It’s commonly referred to as “appdata” and for now we’ll only get the vertex positions of the object. To do that, we have to mark the variable that’s going to be filled with the object space position with the position attribute.
```glsl
struct appdata{
    float4 vertex : POSITION;
}
```

Then we write a struct which will be returned by the vertex shader. For now we only need the position of the vertices relative to the screen. For unity to know that that’s the data in the variable, we mark it with the sv_position attribute.
```glsl
struct v2f{
    float4 vertex : SV_POSITION;
}
```

Next is the vertex shader, it returns the vertex to fragment struct and it takes the object information in appdata. First we initialize the new instance of the struct, then we fill it with the screen position of the vertex and return it to be handled by the rasterizer. The UnityObjectToClipPos function is inside the UnityCG.cginc file and allows us to not worry about matrix multiplication for now.
```glsl
v2f vert(appdata v){
    v2f o;
    o.vertex = UnityObjectToClipPos(v.vertex);
    return o;
}
```

And finally we write the fragment shader. For now we will just return a red color, this will become more interresting in following tutorials. We have to mark the function as sv_target, so unity knows that the result of this function is going to be drawn on the screen.
```glsl
fixed4 frag(v2f i) : SV_TARGET{
    return fixed4(0.5, 0, 0, 1);
}
```

After writing our data types and functions we have to tell unity which function is used for what, this is done via `#pragma shaderFunction`, so we write `#pragma vertex vert` to show unity to our vertex shader and `#pragma fragment frag` to show unity to our fragment shader.
```glsl
Shader "Tutorial/01_Basic"{
	SubShader{
		Tags{
				"RenderType"="Opaque" 
				"Queue"="Geometry"
			}
		Pass{
			

			CGPROGRAM
			#include "UnityCG.cginc"

			#pragma vertex vert
			#pragma fragment frag

			struct appdata{
				float4 vertex : POSITION;
			};

			struct v2f{
				float4 vertex : SV_POSITION;
			};

			v2f vert(appdata v){
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				return o;
			}

			fixed4 frag(v2f i) : SV_TARGET{
				return fixed4(0.5, 0, 0, 1);
			}

			ENDCG
		}
	}
}
```
With all of this we now should be able to apply our new shader to a material and see it in the color the fragment shader returns.
![Apply]({{ "/assets/images/posts/002/apply_shader.gif" | absolute_url }})

I hope this helped you write your first shader and you'll learn much more in the future.

You can find the source code of the shader here: <https://github.com/ronja-tutorials/ShaderTutorials/blob/master/Assets/002_basic/basic_color.shader>