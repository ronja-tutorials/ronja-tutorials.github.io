---
layout: post
title: "HSV Color Space"
image: /assets/images/posts/041/Result.gif
hidden: true
---

So far we always used RGB colors in our shaders, meaning the components of our color vector always map to the red green and blue components of the color. This is great if we want to render the color or tint it, but adjusting the hue or saturation becomes very bothersome. For those kinds of operations we can use the HSV color space. In addition to the HSV color space there are also other similar color spaces, like the HSL or CIE color models. Some of them are very similar to the HSL model while others get way closer to the visible spectrum at the cost of higher cost of calculating them. For simplicities sake I'm only going to explain the HSV model here. 

![](/assets/images/posts/041/Result.gif)

## How does it work?

When using the HSV model we also have 3 components which define our color, but in this case they map to the hue, saturation and value of the color. Because the maximum and minimum value of the hue map to the same value (red), we can view it as a circle. This concept can be taken a step further to imagine the color space as a cylinder where the hue is the rotation around the center, the saturation is the proximity to the center and the value is represented by the relative height of the point in the cylinder.

![](/assets/images/posts/041/hsvCylinder.png)

## Generating a RGB Color from Hue

The most critical step in converting colors from HSV to RGB is to convert the hue of a HSV color to a RGB color, that's why we're writing a function to do only this. In our implementation the hue will be between 0 and 1. Other implementations define it to be between 0 and 360, similar to degree numbers in a circle, but I personally prefer 0 to 1 scaling since it makes it easier to work with functions like `saturate` or `frac` which assume we're working in those dimensions.

In the range from 0 to 1 each of the 3 components has one third where it has a value of 1, one third where it has a value of 0 and two sixths where it's linearly growing from 0 to 1 or decreasing from 1 to 0 accordingly. Those changes in values are offset in a way that each hue generates a different color.

![](/assets/images/posts/041/rgbHueValues.png)

In code we can most efficiently represent this by taking the absolute value of a value that's first multiplied by 6(because it has to reach a value of 1 over the change of a sixth) and shifted to the side. The green and blue values both go up and then down again in the range, that's why they are subtracted from 2, flipping them. The red value instead first decreases and then later increases again. To archieve this, 1 is subtracted from it.

After the increase and decrease of the values is set up the values are combined and the saturate function is called on it. The saturate function ensures that no value is below 0 or above 1.

If we want to make sure that hue values above 1 or below 0 don't result in a red hue and instead wrap around the color spectrum like expected we can just take the fractional part of the hue and ignore the decimal part. In hlsl, the `frac` function does exactly that.

```glsl
float3 hue2rgb(float hue) {
    hue = frac(hue); //only use fractional part of hue, making it loop
    float r = abs(hue * 6 - 3) - 1; //red
    float g = 2 - abs(hue * 6 - 2); //green
    float b = 2 - abs(hue * 6 - 4); //blue
    float3 rgb = float3(r,g,b); //combine components
    rgb = saturate(rgb); //clamp between 0 and 1
    return rgb;
}
```

After setting up this method you can simply use it in any other method to generate a rgb color with a specific hue.

```glsl
//the fragment shader
fixed4 frag(v2f i) : SV_TARGET{
	float3 col = hue2rgb(i.uv);
	return float4(col, 1);
}
```

![](/assets/images/posts/041/SimpleRainbow.png)

## Full HSV to RGB conversion

After being able to convert the hue into a rgb color that looks correct we next also have to make the output color respect the saturation and value. To apply the saturation to the already generated color, we do a linear interpolation from 1 to the color and use the saturation component of the vector as the argument. Since 1 stands for full white in thic context, this makes the hue vanish for low saturation color while preserving it for high saturation ones.

The last step to take is to appy the value. Since the value stands for the brightness of the color the operation to apply it is to simply multiply the color so far by the value component.

```glsl
float3 hsv2rgb(float3 hsv)
{
    float3 rgb = hue2rgb(hsv.x); //apply hue
    rgb = lerp(1, rgb, hsv.y); //apply saturation
    rgb = rgb * hsv.z; //apply value
    return rgb;
}
```

To test this we can make a new example shader. In this one I used the x uv coordinate as the saturation, the y coordinate as the value and generated the hue by taking a value that increases diagonally by subtracting the y from the x UV component.

```glsl
//the fragment shader
fixed4 frag(v2f i) : SV_TARGET
{
	float diagonal = i.uv.x - i.uv.y;
	float3 col = hsv2rgb(float3(diagonal, i.uv.x, i.uv.y));
	return float4(col, 1);
}
```

![](/assets/images/posts/041/FullHsvTest.png)

## RGB to HSV conversion



## Source

- <https://github.com/ronja-tutorials/ShaderTutorials/blob/master/Assets/ETC ETC>

```glsl

```

As always thank you so much for reading and supporting me, your messages of support mean the world to me 💖.