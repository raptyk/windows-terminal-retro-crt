// Everyday CRT pixel shader for Windows Terminal: clearly retro, still easy to read.
// Scanlines, a phosphor halo around glyphs, darker tube edges,
// faint static grain and aperture mask (rounded corners optional). Glyph pixels are never resampled,
// so pixel fonts stay sharp at their native size (PxPlus fonts: 12pt = 16px em).
// No animation (Time is not used), so the terminal only redraws when text changes.
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

#define CURVATURE           0.0   // any curvature resamples the image and blurs pixel fonts
#define CORNER_RADIUS       0.0   // rounded tube corners in physical pixels; the shader area starts
                                  // at the text (inside the padding), so > 0 clips corner glyphs
#define EDGE_SHADE          0.12  // darkening only in the last few % near the edges
#define GLOW_STRENGTH       0.35  // halo around glyphs; glyph pixels themselves stay sharp
#define GLOW_RADIUS         1.5   // in physical pixels (multiplied by Scale)
#define SCANLINE_STRENGTH   0.16
#define SCANLINE_PERIOD     2.0   // in physical pixels (multiplied by Scale)
#define MASK_STRENGTH       0.03
#define GRAIN_STRENGTH      0.012
#define BRIGHTNESS          1.06
static const float3 BEZEL_COLOR = float3(0.012, 0.018, 0.014);

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

// Two rings of taps: a tight halo plus a wider, fainter phosphor spread.
float3 glow(float2 uv)
{
    float2 px = GLOW_RADIUS * Scale / Resolution;
    float3 sum = 0;
    [unroll] for (int i = 0; i < 8; i++)
    {
        float a = i * (PI / 4.0) + PI / 8.0;
        float2 dir = float2(cos(a), sin(a));
        sum += shaderTexture.Sample(samplerState, uv + dir * px).rgb;
        sum += shaderTexture.Sample(samplerState, uv + dir * px * 2.5).rgb * 0.3;
    }
    return sum / 10.4;
}

float roundedCornerMask(float2 uv)
{
    if (CORNER_RADIUS <= 0.0)
        return 1.0;
    float2 p = uv * Resolution;
    float r = CORNER_RADIUS * Scale;
    float2 q = max(abs(p - Resolution * 0.5) - (Resolution * 0.5 - r), 0.0);
    return 1.0 - smoothstep(r - 1.5, r + 0.5, length(q));
}

float4 main(float4 pos : SV_POSITION, float2 tex : TEXCOORD) : SV_TARGET
{
    float2 uv = curve(tex);
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0)
        return float4(BEZEL_COLOR, 1.0);

    float3 source = shaderTexture.Sample(samplerState, uv).rgb;
    // Glow only lights up the dark surroundings, so glyph edges are not smeared.
    float3 color = source + max(glow(uv) - source, 0.0) * GLOW_STRENGTH;

    // Scanlines: dark gaps between beam rows.
    float scan = 0.5 + 0.5 * cos(pos.y / (SCANLINE_PERIOD * Scale) * 2.0 * PI);
    color *= 1.0 - SCANLINE_STRENGTH * scan;

    // Aperture-grille: faint vertical RGB stripes.
    int column = (int)fmod(pos.x, 3.0);
    float3 mask = column == 0 ? float3(1, 0, 0) : (column == 1 ? float3(0, 1, 0) : float3(0, 0, 1));
    color *= 1.0 + MASK_STRENGTH * (mask * 3.0 - 1.0);

    // Shade only a thin band at the edges, not the whole screen.
    float2 edge = min(uv, 1.0 - uv);
    float shade = smoothstep(0.0, 0.06, min(edge.x, edge.y * Resolution.y / Resolution.x));
    color *= lerp(1.0 - EDGE_SHADE, 1.0, shade);

    // Static glass grain (no animation).
    color += (hash(pos.xy) - 0.5) * GRAIN_STRENGTH;

    color = saturate(color * BRIGHTNESS);
    color = lerp(BEZEL_COLOR, color, roundedCornerMask(uv));
    return float4(color, 1.0);
}
