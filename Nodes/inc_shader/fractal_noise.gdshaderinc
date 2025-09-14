/* SPDX-FileCopyrightText: 2025 D.Jorkin
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Portions adapted from Blender noise shaders and utilities.
 * Copyright (c) Blender Authors, licensed under GPL-2.0-or-later.
 */

#ifdef INCLUDE_WRAPPER

// 3D FRACTAL NOISE 
	float noise_fbm(vec3 co,
	               float detail,
	               float roughness,
	               float lacunarity,
	               float offset,
	               float gain,
	               bool  normalize)
	{
		vec3 p = co;
		float fscale = 1.0;
		float amp    = 1.0;
		float maxamp = 0.0;
		float sum    = 0.0;

		int icalc = int(floor(detail));
		for (int i = 0; i <= icalc; i++) {
			float t = snoise(fscale * p);
			sum    += t * amp;
			maxamp += amp;
			amp    *= roughness;
			fscale *= lacunarity;
		}

		float rmd = detail - float(icalc);
		if (rmd != 0.0) {
			float t     = snoise(fscale * p);
			float sum2  = sum + t * amp;
			if (normalize) {
				return mix(0.5 * sum / maxamp + 0.5,
				           0.5 * sum2 / (maxamp + amp) + 0.5,
				           rmd);
			} else {
				return mix(sum, sum2, rmd);
			}
		}
		else {
			return normalize ? (0.5 * sum / maxamp + 0.5) : sum;
		}
	}

	float noise_multi_fractal(vec3 co,
	                         float detail,
	                         float roughness,
	                         float lacunarity,
	                         float offset,
	                         float gain,
	                         bool  normalize)
	{
		vec3 p = co;
		float value = 1.0;
		float pwr   = 1.0;

		int icalc = int(floor(detail));
		for (int i = 0; i <= icalc; i++) {
			value *= (pwr * snoise(p) + 1.0);
			pwr   *= roughness;
			p     *= lacunarity;
		}

		float rmd = detail - float(icalc);
		if (rmd != 0.0) {
			value *= (rmd * pwr * snoise(p) + 1.0);
		}
		return value;
	}

	float noise_hetero_terrain(vec3 co,
	                           float detail,
	                           float roughness,
	                           float lacunarity,
	                           float offset,
	                           float gain,
	                           bool  normalize)
	{
		vec3 p = co;
		float pwr = roughness;
		float value = offset + snoise(p);
		p *= lacunarity;

		int icalc = int(floor(detail));
		for (int i = 1; i <= icalc; i++) {
			float increment = (snoise(p) + offset) * pwr * value;
			value += increment;
			pwr   *= roughness;
			p     *= lacunarity;
		}

		float rmd = detail - float(icalc);
		if (rmd != 0.0) {
			float increment = (snoise(p) + offset) * pwr * value;
			value += rmd * increment;
		}
		return value;
	}

	float noise_hybrid_multi_fractal(vec3 co,
	                                 float detail,
	                                 float roughness,
	                                 float lacunarity,
	                                 float offset,
	                                 float gain,
	                                 bool  normalize)
	{
		vec3 p = co;
		float pwr = 1.0;
		float value = 0.0;
		float weight = 1.0;

		int icalc = int(floor(detail));
		for (int i = 0; (weight > 0.001) && (i <= icalc); i++) {
			if (weight > 1.0) weight = 1.0;
			float signal = (snoise(p) + offset) * pwr;
			pwr   *= roughness;
			value += weight * signal;
			weight *= gain * signal;
			p *= lacunarity;
		}

		float rmd = detail - float(icalc);
		if ((rmd != 0.0) && (weight > 0.001)) {
			if (weight > 1.0) weight = 1.0;
			float signal = (snoise(p) + offset) * pwr;
			value += rmd * weight * signal;
		}
		return value;
	}

	float noise_ridged_multi_fractal(vec3 co,
	                                 float detail,
	                                 float roughness,
	                                 float lacunarity,
	                                 float offset,
	                                 float gain,
	                                 bool  normalize)
	{
		vec3 p = co;
		float pwr = roughness;

		float signal = offset - abs(snoise(p));
		signal *= signal;
		float value = signal;
		float weight = 1.0;

		int icalc = int(floor(detail));
		for (int i = 1; i <= icalc; i++) {
			p *= lacunarity;
			weight = clamp(signal * gain, 0.0, 1.0);
			signal = offset - abs(snoise(p));
			signal *= signal;
			signal *= weight;
			value += signal * pwr;
			pwr   *= roughness;
		}
		return value;
	}

// 3D wrappers 
	float noise_fbm_np(vec3 co, NoiseParams params) {
		return noise_fbm(
			co,
			params.detail,
			params.roughness,
			params.lacunarity,
			params.offset,
			params.gain,
			params.normalize
		);
	}

	float noise_multi_fractal_np(vec3 co, NoiseParams params) {
		return noise_multi_fractal(
			co,
			params.detail,
			params.roughness,
			params.lacunarity,
			params.offset,
			params.gain,
			params.normalize
		);
	}

	float noise_hetero_terrain_np(vec3 co, NoiseParams params) {
		return noise_hetero_terrain(
			co,
			params.detail,
			params.roughness,
			params.lacunarity,
			params.offset,
			params.gain,
			params.normalize
		);
	}

	float noise_hybrid_multi_fractal_np(vec3 co, NoiseParams params) {
		return noise_hybrid_multi_fractal(
			co,
			params.detail,
			params.roughness,
			params.lacunarity,
			params.offset,
			params.gain,
			params.normalize
		);
	}

	float noise_ridged_multi_fractal_np(vec3 co, NoiseParams params) {
		return noise_ridged_multi_fractal(
			co,
			params.detail,
			params.roughness,
			params.lacunarity,
			params.offset,
			params.gain,
			params.normalize
		);
	}

// 4D FRACTAL NOISE 
	float noise_fbm(vec4 co,
	               float detail,
	               float roughness,
	               float lacunarity,
	               float offset,
	               float gain,
	               bool  normalize)
	{
		vec4 p = co;
		float fscale = 1.0;
		float amp = 1.0;
		float maxamp = 0.0;
		float sum = 0.0;
		
		int icalc = int(floor(detail));
		for(int i = 0; i <= icalc; i++) {
			float t = snoise(fscale * p);
			sum += t * amp;
			maxamp += amp;
			amp *= roughness;
			fscale *= lacunarity;
		}
		
		float rmd = detail - float(icalc);
		if(rmd != 0.0) {
			float t = snoise(fscale * p);
			float sum2 = sum + t * amp;
			return normalize ? 
				mix(0.5 * sum / maxamp + 0.5, 
				    0.5 * sum2 / (maxamp + amp) + 0.5, 
				    rmd) :
				mix(sum, sum2, rmd);
		}
		return normalize ? 0.5 * sum / maxamp + 0.5 : sum;
	}

	float noise_multi_fractal(vec4 co,
	                          float detail,
	                          float roughness,
	                          float lacunarity,
	                          float offset,
	                          float gain,
	                          bool normalize)
	{
		vec4 p = co;
		float value = 1.0;
		float pwr = 1.0;
		
		int icalc = int(floor(detail));
		for(int i = 0; i <= icalc; i++) {
			value *= (pwr * snoise(p) + 1.0);
			pwr *= roughness;
			p *= lacunarity;
		}
		
		float rmd = detail - float(icalc);
		if(rmd != 0.0) {
			value *= (rmd * pwr * snoise(p) + 1.0);
		}
		return value;
	}

	float noise_hetero_terrain(vec4 co,
	                           float detail,
	                           float roughness,
	                           float lacunarity,
	                           float offset,
	                           float gain,
	                           bool normalize)
	{
		vec4 p = co;
		float pwr = roughness;
		float value = offset + snoise(p);
		p *= lacunarity;
		
		int icalc = int(floor(detail));
		for(int i = 1; i <= icalc; i++) {
			float increment = (snoise(p) + offset) * pwr * value;
			value += increment;
			pwr *= roughness;
			p *= lacunarity;
		}
		
		float rmd = detail - float(icalc);
		if(rmd != 0.0) {
			float increment = (snoise(p) + offset) * pwr * value;
			value += rmd * increment;
		}
		return value;
	}

	float noise_hybrid_multi_fractal(vec4 co,
	                                 float detail,
	                                 float roughness,
	                                 float lacunarity,
	                                 float offset,
	                                 float gain,
	                                 bool normalize)
	{
		vec4 p = co;
		float pwr = 1.0;
		float value = 0.0;
		float weight = 1.0;
		
		int icalc = int(floor(detail));
		for(int i = 0; (weight > 0.001) && (i <= icalc); i++) {
			if(weight > 1.0) weight = 1.0;
			float signal = (snoise(p) + offset) * pwr;
			pwr *= roughness;
			value += weight * signal;
			weight *= gain * signal;
			p *= lacunarity;
		}
		
		float rmd = detail - float(icalc);
		if((rmd != 0.0) && (weight > 0.001)) {
			if(weight > 1.0) weight = 1.0;
			float signal = (snoise(p) + offset) * pwr;
			value += rmd * weight * signal;
		}
		return value;
	}

	float noise_ridged_multi_fractal(vec4 co,
	                                 float detail,
	                                 float roughness,
	                                 float lacunarity,
	                                 float offset,
	                                 float gain,
	                                 bool normalize)
	{
		vec4 p = co;
		float pwr = roughness;
		float signal = offset - abs(snoise(p));
		signal *= signal;
		float value = signal;
		float weight = 1.0;
		
		int icalc = int(floor(detail));
		for(int i = 1; i <= icalc; i++) {
			p *= lacunarity;
			weight = clamp(signal * gain, 0.0, 1.0);
			signal = offset - abs(snoise(p));
			signal *= signal;
			signal *= weight;
			value += signal * pwr;
			pwr *= roughness;
		}
		return value;
	}

// 4D wrappers 
	float noise_fbm4_np(vec4 p, NoiseParams pr) {
		return noise_fbm(p, pr.detail, pr.roughness, pr.lacunarity, 
		                 pr.offset, pr.gain, pr.normalize);
	}
	
	float noise_multi_fractal4_np(vec4 p, NoiseParams pr) {
		return noise_multi_fractal(p, pr.detail, pr.roughness, pr.lacunarity, 
		                           pr.offset, pr.gain, pr.normalize);
	}
	
	float noise_hetero_terrain4_np(vec4 p, NoiseParams pr) {
		return noise_hetero_terrain(p, pr.detail, pr.roughness, pr.lacunarity, 
		                            pr.offset, pr.gain, pr.normalize);
	}
	
	float noise_hybrid_multi_fractal4_np(vec4 p, NoiseParams pr) {
		return noise_hybrid_multi_fractal(p, pr.detail, pr.roughness, pr.lacunarity, 
		                                  pr.offset, pr.gain, pr.normalize);
	}
	
	float noise_ridged_multi_fractal4_np(vec4 p, NoiseParams pr) {
		return noise_ridged_multi_fractal(p, pr.detail, pr.roughness, pr.lacunarity, 
		                                  pr.offset, pr.gain, pr.normalize);
	}

// 2D FRACTAL NOISE 

	float noise_fbm(vec2 co,
				float detail,
				float roughness,
				float lacunarity,
				float offset,
				float gain,
				bool  normalize)
	{
		vec2 p = co;
		float fscale = 1.0;
		float amp    = 1.0;
		float maxamp = 0.0;
		float sum    = 0.0;

		int icalc = int(floor(detail));
		for (int i = 0; i <= icalc; i++) {
			float t = snoise(fscale * p);
			sum    += t * amp;
			maxamp += amp;
			amp    *= roughness;
			fscale *= lacunarity;
		}

		float rmd = detail - float(icalc);
		if (rmd != 0.0) {
			float t     = snoise(fscale * p);
			float sum2  = sum + t * amp;
			if (normalize) {
				return mix(0.5 * sum / maxamp + 0.5,
						0.5 * sum2 / (maxamp + amp) + 0.5,
						rmd);
			} else {
				return mix(sum, sum2, rmd);
			}
		}
		else {
			return normalize ? (0.5 * sum / maxamp + 0.5) : sum;
		}
	}

	float noise_multi_fractal(vec2 co,
							float detail,
							float roughness,
							float lacunarity,
							float offset,
							float gain,
							bool  normalize)
	{
		vec2 p = co;
		float value = 1.0;
		float pwr   = 1.0;

		int icalc = int(floor(detail));
		for (int i = 0; i <= icalc; i++) {
			value *= (pwr * snoise(p) + 1.0);
			pwr   *= roughness;
			p     *= lacunarity;
		}

		float rmd = detail - float(icalc);
		if (rmd != 0.0) {
			value *= (rmd * pwr * snoise(p) + 1.0);
		}
		return value;
	}

	float noise_hetero_terrain(vec2 co,
							float detail,
							float roughness,
							float lacunarity,
							float offset,
							float gain,
							bool  normalize)
	{
		vec2 p = co;
		float pwr = roughness;
		float value = offset + snoise(p);
		p *= lacunarity;

		int icalc = int(floor(detail));
		for (int i = 1; i <= icalc; i++) {
			float increment = (snoise(p) + offset) * pwr * value;
			value += increment;
			pwr   *= roughness;
			p     *= lacunarity;
		}

		float rmd = detail - float(icalc);
		if (rmd != 0.0) {
			float increment = (snoise(p) + offset) * pwr * value;
			value += rmd * increment;
		}
		return value;
	}

	float noise_hybrid_multi_fractal(vec2 co,
									float detail,
									float roughness,
									float lacunarity,
									float offset,
									float gain,
									bool  normalize)
	{
		vec2 p = co;
		float pwr = 1.0;
		float value = 0.0;
		float weight = 1.0;

		int icalc = int(floor(detail));
		for (int i = 0; (weight > 0.001) && (i <= icalc); i++) {
			if (weight > 1.0) weight = 1.0;
			float signal = (snoise(p) + offset) * pwr;
			pwr   *= roughness;
			value += weight * signal;
			weight *= gain * signal;
			p     *= lacunarity;
		}

		float rmd = detail - float(icalc);
		if ((rmd != 0.0) && (weight > 0.001)) {
			if (weight > 1.0) weight = 1.0;
			float signal = (snoise(p) + offset) * pwr;
			value += rmd * weight * signal;
		}
		return value;
	}

	float noise_ridged_multi_fractal(vec2 co,
									float detail,
									float roughness,
									float lacunarity,
									float offset,
									float gain,
									bool  normalize)
	{
		vec2 p = co;
		float pwr = roughness;

		float signal = offset - abs(snoise(p));
		signal *= signal;
		float value = signal;
		float weight = 1.0;

		int icalc = int(floor(detail));
		for (int i = 1; i <= icalc; i++) {
			p *= lacunarity;
			weight = clamp(signal * gain, 0.0, 1.0);
			signal = offset - abs(snoise(p));
			signal *= signal;
			signal *= weight;
			value += signal * pwr;
			pwr   *= roughness;
		}
		return value;
	}


	// 2D wrappers 
	float noise_fbm_np(vec2 co, NoiseParams params){
		return noise_fbm(co, params.detail, params.roughness, params.lacunarity, params.offset, params.gain, params.normalize);
	}

	float noise_multi_fractal_np(vec2 co, NoiseParams params){
		return noise_multi_fractal(co, params.detail, params.roughness, params.lacunarity, params.offset, params.gain, params.normalize);
	}

	float noise_hetero_terrain_np(vec2 co, NoiseParams params){
		return noise_hetero_terrain(co, params.detail, params.roughness, params.lacunarity, params.offset, params.gain, params.normalize);
	}

	float noise_hybrid_multi_fractal_np(vec2 co, NoiseParams params){
		return noise_hybrid_multi_fractal(co, params.detail, params.roughness, params.lacunarity, params.offset, params.gain, params.normalize);
	}

	float noise_ridged_multi_fractal_np(vec2 co, NoiseParams params){
		return noise_ridged_multi_fractal(co, params.detail, params.roughness, params.lacunarity, params.offset, params.gain, params.normalize);
	}

	float _compute_fractal(vec2 p, int type, NoiseParams pr){
		if(type==0)  return noise_multi_fractal_np(p, pr);
		if(type==1)  return noise_ridged_multi_fractal_np(p, pr);
		if(type==2)  return noise_hybrid_multi_fractal_np(p, pr);
		if(type==3)  return noise_fbm_np(p, pr);
		return noise_hetero_terrain_np(p, pr);
	}

	//  1D FRACTAL NOISE 

	float noise_fbm(float co,
				float detail,
				float roughness,
				float lacunarity,
				float offset,
				float gain,
				bool  normalize)
	{
		float p = co;
		float fscale = 1.0;
		float amp    = 1.0;
		float maxamp = 0.0;
		float sum    = 0.0;

		int icalc = int(floor(detail));
		for(int i=0;i<=icalc;i++){
			float t = snoise(fscale * p);
			sum    += t * amp;
			maxamp += amp;
			amp    *= roughness;
			fscale *= lacunarity;
		}

		float rmd = detail - float(icalc);
		if(rmd!=0.0){
			float t = snoise(fscale * p);
			float sum2 = sum + t*amp;
			return normalize ? mix(0.5*sum/maxamp + 0.5,
									0.5*sum2/(maxamp+amp)+0.5,
									rmd)
							: mix(sum,sum2,rmd);
		}
		return normalize ? 0.5*sum/maxamp + 0.5 : sum;
	}

	float noise_multi_fractal(float p,
							float detail,
							float roughness,
							float lacunarity,
							float offset,
							float gain,
							bool normalize)
	{
		float value = 1.0;
		float pwr = 1.0;
		int icalc = int(floor(detail));
		float pp = p;
		for(int i=0;i<=icalc;i++){
			value *= (pwr * snoise(pp) + 1.0);
			pwr *= roughness;
			pp  *= lacunarity;
		}
		float rmd = detail - float(icalc);
		if(rmd!=0.0){
			value *= (rmd * pwr * snoise(pp) + 1.0);
		}
		return value;
	}

	float noise_hetero_terrain(float p,
							float detail,
							float roughness,
							float lacunarity,
							float offset,
							float gain,
							bool normalize)
	{
		float pwr = roughness;
		float value = offset + snoise(p);
		float pp = p * lacunarity;
		int icalc = int(floor(detail));
		for(int i=1;i<=icalc;i++){
			float increment = (snoise(pp)+offset)*pwr*value;
			value += increment;
			pwr   *= roughness;
			pp    *= lacunarity;
		}
		float rmd = detail - float(icalc);
		if(rmd!=0.0){
			float increment = (snoise(pp)+offset)*pwr*value;
			value += rmd*increment;
		}
		return value;
	}

	float noise_hybrid_multi_fractal(float p,
									float detail,
									float roughness,
									float lacunarity,
									float offset,
									float gain,
									bool normalize)
	{
		float pwr = 1.0;
		float value = 0.0;
		float weight = 1.0;
		float pp = p;
		int icalc = int(floor(detail));
		for(int i=0;(weight>0.001)&&(i<=icalc);i++){
			if(weight>1.0) weight=1.0;
			float signal = (snoise(pp)+offset)*pwr;
			pwr  *= roughness;
			value += weight*signal;
			weight *= gain*signal;
			pp *= lacunarity;
		}
		float rmd = detail - float(icalc);
		if((rmd!=0.0)&&(weight>0.001)){
			if(weight>1.0) weight=1.0;
			float signal = (snoise(pp)+offset)*pwr;
			value += rmd*weight*signal;
		}
		return value;
	}

	float noise_ridged_multi_fractal(float p,
									float detail,
									float roughness,
									float lacunarity,
									float offset,
									float gain,
									bool normalize)
	{
		float pwr = roughness;
		float signal = offset - abs(snoise(p));
		signal *= signal;
		float value = signal;
		float weight = 1.0;
		float pp = p;
		int icalc = int(floor(detail));
		for(int i=1;i<=icalc;i++){
			pp *= lacunarity;
			weight = clamp(signal*gain,0.0,1.0);
			signal = offset - abs(snoise(pp));
			signal *= signal;
			signal *= weight;
			value += signal * pwr;
			pwr *= roughness;
		}
		return value;
	}

	// wrappers 1D
	float noise_fbm_np(float p, NoiseParams params){
		return noise_fbm(p, params.detail, params.roughness, params.lacunarity, params.offset, params.gain, params.normalize);
	}

	float noise_multi_fractal_np(float p, NoiseParams params){
		return noise_multi_fractal(p, params.detail, params.roughness, params.lacunarity, params.offset, params.gain, params.normalize);
	}

	float noise_hetero_terrain_np(float p, NoiseParams params){
		return noise_hetero_terrain(p, params.detail, params.roughness, params.lacunarity, params.offset, params.gain, params.normalize);
	}

	float noise_hybrid_multi_fractal_np(float p, NoiseParams params){
		return noise_hybrid_multi_fractal(p, params.detail, params.roughness, params.lacunarity, params.offset, params.gain, params.normalize);
	}

	float noise_ridged_multi_fractal_np(float p, NoiseParams params){
		return noise_ridged_multi_fractal(p, params.detail, params.roughness, params.lacunarity, params.offset, params.gain, params.normalize);
	}

	float _compute_fractal(float p, int type, NoiseParams pr){
		if(type==0)  return noise_multi_fractal_np(p, pr);
		if(type==1)  return noise_ridged_multi_fractal_np(p, pr);
		if(type==2)  return noise_hybrid_multi_fractal_np(p, pr);
		if(type==3)  return noise_fbm_np(p, pr);
		return noise_hetero_terrain_np(p, pr);
	}

#endif 