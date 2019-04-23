---
layout: post
title: "Properties"
image: /assets/images/posts/003/Result.png
---
## Summary
When we write shaders, we usually want to be able to change parameters on a per material basis. Properties allow us to do that in unity. In this simple example we’re just going to make color of our unlit shader adjustable.

For this tutorial you should know how to make a super basic unlit shader, you can find a tutorial for that [here]({{ site.baseurl }}{% post_url 2018-03-21-simple-color %}).

![](/assets/images/posts/003/Result.png)

## Properties
The first thing we do is change our shader to use a variable as output value instead of a fixed value. We can declare the variable anywhere in the HLSL section of the shader outside of functions or structs. After that the material should look solid black in the editor.
```glsl
fixed4 _Color;

fixed4 frag(v2f i) : SV_TARGET{
    return _Color
}
```

![](/assets/images/posts/003/Black.png)

Next we add the Properties section to the top of the shader, outside of our subshader. And we add our _Color Property, tell unity to show it as Color in the inspector, define the type as a Color and set the default value to black.
```glsl
Shader "Tutorial/03_Properties"{
    Properties{
        _Color("Color", Color) = (0, 0, 0, 1)
    }
    ...
```

![](/assets/images/posts/003/White.png)

The material then looks white. The reason why it didn’t use our default value we defined in the shader is that our material was originally a material with a default shader and had the Color property set to white, that transferred to our new shader. To change the color we can now select the object our material is applied to or the material in the edtitor and change it in the inspector.

![](/assets/images/posts/003/Apply.gif)

I hope it's clear now how to use properties to change variables in the materials that use your shader instead of writing a lot of slightly different shaders.

You can find the source code here: <https://github.com/ronja-tutorials/ShaderTutorials/blob/master/Assets/003_Properties/properties.shader>

```glsl
Shader "Tutorial/003_Properties"{
	//show values to edit in inspector
	Properties{
		_Color ("Color", Color) = (0, 0, 0, 1)
	}

	SubShader{
		//the material is completely non-transparent and is rendered at the same time as the other opaque geometry
		Tags{ "RenderType"="Opaque" "Queue"="Geometry"}

		Pass{
			CGPROGRAM
			#include "UnityCG.cginc"

			#pragma vertex vert
			#pragma fragment frag

			fixed4 _Color;

			struct appdata{
				float4 vertex : POSITION;
			};

			struct v2f{
				float4 position : SV_POSITION;
			};

			v2f vert(appdata v){
				v2f o;
				//calculate the position in clip space to render the object
				o.position = UnityObjectToClipPos(v.vertex);
				return o;
			}

			fixed4 frag(v2f i) : SV_TARGET{
				//Return the color the Object is rendered in
				return _Color;
			}

			ENDCG
		}
	}
}
```