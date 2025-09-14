/* SPDX-FileCopyrightText: 2025 D.Jorkin
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Portions adapted from Blender common hash library:
 *  - source/blender/gpu/shaders/common/gpu_shader_common_hash.glsl
 *    https://raw.githubusercontent.com/blender/blender/main/source/blender/gpu/shaders/common/gpu_shader_common_hash.glsl
 * Copyright (c) Blender Authors, licensed under GPL-2.0-or-later.
 */

uint _rot(uint x, uint k) {
    return (x << k) | (x >> (32u - k));
}

void JENKINS_mix(inout uint a, inout uint b, inout uint c) {
    a -= c; a ^= _rot(c, 4u); c += b;
    b -= a; b ^= _rot(a, 6u); a += c;
    c -= b; c ^= _rot(b, 8u); b += a;
    a -= c; a ^= _rot(c, 16u); c += b;
    b -= a; b ^= _rot(a, 19u); a += c;
    c -= b; c ^= _rot(b, 4u); b += a;
}

void JENKINS_final(inout uint a, inout uint b, inout uint c) {
    c ^= b; c -= _rot(b, 14u);
    a ^= c; a -= _rot(c, 11u);
    b ^= a; b -= _rot(a, 25u);
    c ^= b; c -= _rot(b, 16u);
    a ^= c; a -= _rot(c, 4u);
    b ^= a; b -= _rot(a, 14u);
    c ^= b; c -= _rot(b, 24u);
}

uint hash_uint(uint kx) {
    uint a = 0xdeadbeefu + (1u << 2u) + 13u;
    uint b = a;
    uint c = a;
    a += kx;
    JENKINS_final(a, b, c);
    return c;
}

uint hash_uint2(uint kx, uint ky) {
    uint a = 0xdeadbeefu + (2u << 2u) + 13u;
    uint b = a;
    uint c = a;
    a += kx;
    b += ky;
    JENKINS_final(a, b, c);
    return c;
}

uint hash_uint3(uint kx, uint ky, uint kz) {
    uint a = 0xdeadbeefu + (3u << 2u) + 13u;
    uint b = a;
    uint c = a;
    a += kx;
    b += ky;
    c += kz;
    JENKINS_final(a, b, c);
    return c;
}

uint hash_uint4(uint kx, uint ky, uint kz, uint kw) {
    uint a = 0xdeadbeefu + (4u << 2u) + 13u;
    uint b = a;
    uint c = a;
    a += kx;
    b += ky;
    c += kz;
    JENKINS_mix(a, b, c);
    a += kw;
    JENKINS_final(a, b, c);
    return c;
}


uint hash_int(int kx) { return hash_uint(uint(kx)); }
uint hash_int2(int kx,int ky){ return hash_uint2(uint(kx),uint(ky)); }
uint hash_int3(int kx,int ky,int kz){ return hash_uint3(uint(kx),uint(ky),uint(kz)); }
uint hash_int4(int kx,int ky,int kz,int kw){ return hash_uint4(uint(kx),uint(ky),uint(kz),uint(kw)); }


const float _HASH_UINV = 1.0 / 4294967295.0;

float hash_uint_to_float(uint kx){ return float(hash_uint(kx)) * _HASH_UINV; }
float hash_uint2_to_float(uint kx,uint ky){ return float(hash_uint2(kx,ky)) * _HASH_UINV; }
float hash_uint3_to_float(uint kx,uint ky,uint kz){ return float(hash_uint3(kx,ky,kz)) * _HASH_UINV; }
float hash_uint4_to_float(uint kx,uint ky,uint kz,uint kw){ return float(hash_uint4(kx,ky,kz,kw)) * _HASH_UINV; }


float hash_float_to_float(float k){ return hash_uint_to_float(floatBitsToUint(k)); }
float hash_vec2_to_float(vec2 k){ return hash_uint2_to_float(floatBitsToUint(k.x), floatBitsToUint(k.y)); }
float hash_vec3_to_float(vec3 k){ return hash_uint3_to_float(floatBitsToUint(k.x), floatBitsToUint(k.y), floatBitsToUint(k.z)); }
float hash_vec4_to_float(vec4 k){ return hash_uint4_to_float(floatBitsToUint(k.x), floatBitsToUint(k.y), floatBitsToUint(k.z), floatBitsToUint(k.w)); }


vec2 hash_vec2_to_vec2(vec2 k){ return vec2(hash_vec2_to_float(k), hash_vec3_to_float(vec3(k,1.0))); }
vec3 hash_vec3_to_vec3(vec3 k){ return vec3(hash_vec3_to_float(k), hash_vec4_to_float(vec4(k,1.0)), hash_vec4_to_float(vec4(k,2.0))); }
vec4 hash_vec4_to_vec4(vec4 k){ return vec4(hash_vec4_to_float(k.xyzw), hash_vec4_to_float(k.wxyz), hash_vec4_to_float(k.zwxy), hash_vec4_to_float(k.yzwx)); } 