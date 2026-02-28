#version 150
uniform sampler2D DiffuseSampler;
uniform float Time;
uniform float SignalStrength;
in vec2 texCoord;
out vec4 fragColor;
float hash11(float p) {
    p = fract(p * 0.1031);
    p *= p + 33.33;
    p *= p + p;
    return fract(p);
}
float hash21(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}
float valueNoise(float x) {
    float i = floor(x);
    float f = fract(x);
    float u = f * f * (3.0 - 2.0 * f);
    return mix(hash11(i), hash11(i + 1.0), u);
}
float syncJitter(float y, float time, float badness) {
    float slow = sin(y * 3.0 + time * 1.3) * 0.4;
    float band = step(0.7, valueNoise(y * 8.0 + time * 0.7));
    float fast = (hash21(vec2(y * 200.0, time * 5.0)) - 0.5) * 2.0 * band;
    return (slow + fast) * 0.012 * badness;
}
float bandTear(float y, float time, float badness) {
    float scroll = fract(y * 2.3 - time * 0.15 * badness);
    float tearNoise = valueNoise(y * 40.0 + time * 3.0);
    float threshold = mix(1.0, 0.6, badness * badness);
    return step(threshold, tearNoise) * (hash21(vec2(y * 100.0, floor(time * 8.0))) - 0.5) * 0.06 * badness;
}
float rollingBar(float y, float time, float badness) {
    float barY = fract(y + time * 0.07 * (0.5 + badness));
    float bar = smoothstep(0.0, 0.04, barY) * (1.0 - smoothstep(0.04, 0.08, barY));
    return bar * 0.35 * badness * badness;
}
float interlaceComb(float y, float badness) {
    float line = mod(floor(y * 480.0), 2.0);
    return mix(0.0, line * 0.06 - 0.03, badness * 0.7);
}
vec2 blockCorrupt(vec2 uv, float time, float badness) {
    if (badness < 0.25) return vec2(0.0);
    vec2 blockUV = floor(uv * 32.0) / 32.0;
    float blockNoise = hash21(blockUV + floor(time * 4.0));
    float corruptThreshold = mix(1.0, 0.65, (badness - 0.25) / 0.75);
    if (blockNoise < corruptThreshold) return vec2(0.0);
    float dx = (floor(hash21(blockUV + vec2(0.1, time)) * 8.0) - 4.0) / 320.0;
    float dy = (floor(hash21(blockUV + vec2(0.2, time)) * 4.0) - 2.0) / 240.0;
    return vec2(dx, dy);
}
float frameFreezeAlpha(float y, float time, float badness) {
    if (badness < 0.4) return 0.0;
    float sliceKey = floor(y * 12.0 + time * 2.0);
    float frozen = step(0.82, hash21(vec2(sliceKey, floor(time * 1.5))));
    return frozen * smoothstep(0.4, 0.9, badness);
}
void main() {
    vec2 uv = texCoord;
    float badness = 1.0 - clamp(SignalStrength, 0.0, 1.0);
    float b2 = badness * badness;
    float b3 = b2 * badness;
    uv.x += syncJitter(uv.y, Time, badness);
    uv.x += bandTear(uv.y, Time, badness);
    uv += blockCorrupt(uv, Time, badness);
    vec2 uvC = clamp(uv, 0.0, 1.0);
    float aberration = (0.002 + b2 * 0.018) * (1.0 + sin(Time * 1.7) * 0.3 * badness);
    float vAberr = b3 * 0.005;
    float r = texture(DiffuseSampler, clamp(vec2(uvC.x - aberration,       uvC.y + vAberr), 0.0, 1.0)).r;
    float g = texture(DiffuseSampler, clamp(vec2(uvC.x,                    uvC.y),           0.0, 1.0)).g;
    float b = texture(DiffuseSampler, clamp(vec2(uvC.x + aberration * 0.6, uvC.y - vAberr), 0.0, 1.0)).b;
    vec3 col = vec3(r, g, b);
    float freeze = frameFreezeAlpha(uv.y, Time, badness);
    if (freeze > 0.5) {
        vec3 frozenLine = texture(DiffuseSampler, clamp(vec2(uvC.x, uvC.y - 1.0/240.0), 0.0, 1.0)).rgb;
        col = mix(col, frozenLine, freeze);
    }
    col *= 1.0 - rollingBar(uv.y, Time, badness);
    col += interlaceComb(uv.y, badness);
    float grain = (hash21(uv + vec2(Time * 0.037, Time * 0.019)) - 0.5);
    col += grain * (0.04 + badness * 0.10);
    float luma = dot(col, vec3(0.299, 0.587, 0.114));
    if (badness > 0.15) {
        vec3 smeared = texture(DiffuseSampler, clamp(vec2(uvC.x - 0.008 * badness, uvC.y), 0.0, 1.0)).rgb;
        float smearedLuma = dot(smeared, vec3(0.299, 0.587, 0.114));
        vec3 chromaOnly = smeared - smearedLuma;
        col = luma + chromaOnly * (1.0 - badness * 0.6);
    }
    col = mix(col, vec3(luma), b2 * 0.7);
    float dropoutTime = floor(Time * 24.0); 
    float dropoutNoise = hash11(dropoutTime * 0.731 + 0.5);
    float dropoutProb = b3 * 0.4; 
    if (dropoutNoise < dropoutProb) {
        col = mix(col, vec3(0.9), 0.7);
    } else if (dropoutNoise < dropoutProb * 1.5) {
        col = mix(col, vec3(0.0), 0.8);
    }
    float scanline = 0.5 + 0.5 * sin(uv.y * 480.0 * 3.14159);
    col *= 1.0 - scanline * 0.04 * (1.0 + badness * 0.3);
    vec2 vigUV = texCoord - 0.5;
    vigUV.x *= 1.1; 
    float vignette = 1.0 - dot(vigUV, vigUV) * (1.8 + badness * 1.0);
    col *= clamp(vignette, 0.0, 1.0);
    col = mix(col, col * 1.05 - 0.02, badness * 0.5); 
    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
