// Retro CRT pixel shader for Windows Terminal.
// Effects: barrel distortion, chromatic aberration, phosphor bloom,
// scanlines, aperture-grille mask, vignette, subtle flicker and noise.
// Tweak the constants below; Windows Terminal reloads the shader on save.

Texture2D shaderTexture;
SamplerState samplerState;

cbuffer PixelShaderSettings
{
    float  Time;
    float  Scale;
    float2 Resolution;
    float4 Background;
};

#define CURVATURE           0.10  // 0 = flat screen
#define CHROMA_OFFSET       0.0012 // RGB channel split near the edges
#define BLOOM_STRENGTH      0.55
#define BLOOM_RADIUS        2.0   // in physical pixels (multiplied by Scale)
#define SCANLINE_STRENGTH   0.30
#define SCANLINE_PERIOD     3.0   // in physical pixels (multiplied by Scale)
#define MASK_STRENGTH       0.10
#define VIGNETTE_STRENGTH   0.35
#define FLICKER_STRENGTH    0.012
#define NOISE_STRENGTH      0.025
#define BRIGHTNESS          1.18

static const float PI = 3.14159265;

float2 curve(float2 uv)
{
    float2 cc = uv - 0.5;
    return uv + cc * dot(cc, cc) * CURVATURE;
}

float hash(float2 p)
{
    return frac(sin(dot(p, float2(12.9898, 78.233))) * 43758.5453);
}

float3 sampleRgb(float2 uv, float2 fromCenter)
{
    float2 shift = fromCenter * CHROMA_OFFSET;
    float r = shaderTexture.Sample(samplerState, uv + shift).r;
    float g = shaderTexture.Sample(samplerState, uv).g;
    float b = shaderTexture.Sample(samplerState, uv - shift).b;
    return float3(r, g, b);
}

float3 bloom(float2 uv)
{
    float2 px = BLOOM_RADIUS * Scale / Resolution;
    float3 sum = 0;
    [unroll] for (int i = 0; i < 8; i++)
    {
        float a = i * (PI / 4.0);
        float2 dir = float2(cos(a), sin(a));
        sum += shaderTexture.Sample(samplerState, uv + dir * px).rgb;
        sum += shaderTexture.Sample(samplerState, uv + dir * px * 2.0).rgb * 0.5;
    }
    return sum / 12.0;
}

float4 main(float4 pos : SV_POSITION, float2 tex : TEXCOORD) : SV_TARGET
{
    float2 uv = curve(tex);

    // Outside the curved glass: dark bezel.
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0)
        return float4(0, 0, 0, 1);

    float3 color = sampleRgb(uv, uv - 0.5);
    color += bloom(uv) * BLOOM_STRENGTH;

    // Horizontal scanlines following the curved surface.
    float scanPos = uv.y * Resolution.y / (SCANLINE_PERIOD * Scale);
    float scan = 0.5 + 0.5 * sin(scanPos * 2.0 * PI);
    color *= 1.0 - SCANLINE_STRENGTH * scan;

    // Aperture-grille (vertical RGB stripes).
    int column = (int)fmod(pos.x, 3.0);
    float3 mask = column == 0 ? float3(1, 0, 0) : (column == 1 ? float3(0, 1, 0) : float3(0, 0, 1));
    color *= 1.0 + MASK_STRENGTH * (mask * 3.0 - 1.0);

    // Vignette and soft rounded edges of the tube.
    float vig = 16.0 * uv.x * uv.y * (1.0 - uv.x) * (1.0 - uv.y);
    color *= lerp(1.0, pow(saturate(vig), 0.25), VIGNETTE_STRENGTH * 2.0);
    float2 edge = smoothstep(0.0, 0.008, uv) * smoothstep(0.0, 0.008, 1.0 - uv);
    color *= edge.x * edge.y;

    // Power-line flicker and analog noise.
    color *= 1.0 + FLICKER_STRENGTH * sin(Time * 110.0);
    color += (hash(pos.xy + frac(Time) * 100.0) - 0.5) * NOISE_STRENGTH;

    return float4(saturate(color * BRIGHTNESS), 1.0);
}
