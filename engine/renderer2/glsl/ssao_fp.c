const char *fallbackShader_ssao_fp =
"uniform sampler2D u_ScreenDepthMap;\n"
"\n"
"uniform vec4   u_ViewInfo; // zfar / znear, zfar, 1/width, 1/height\n"
"\n"
"varying vec2   var_ScreenTex;\n"
"\n"
"#if 0\n"
"vec2 poissonDisc[9] = vec2[9](\n"
"vec2(-0.7055767, 0.196515),    vec2(0.3524343, -0.7791386),\n"
"vec2(0.2391056, 0.9189604),    vec2(-0.07580382, -0.09224417),\n"
"vec2(0.5784913, -0.002528916), vec2(0.192888, 0.4064181),\n"
"vec2(-0.6335801, -0.5247476),  vec2(-0.5579782, 0.7491854),\n"
"vec2(0.7320465, 0.6317794)\n"
");\n"
"#endif\n"
"\n"
"#define NUM_SAMPLES 3\n"
"\n"
"// Input: It uses texture coords as the random number seed.\n"
"// Output: Random number: [0,1), that is between 0.0 and 0.999999... inclusive.\n"
"// Author: Michael Pohoreski\n"
"// Copyright: Copyleft 2012 :-)\n"
"// Source: http://stackoverflow.com/questions/5149544/can-i-generate-a-random-number-inside-a-pixel-shader\n"
"\n"
"float random( const vec2 p )\n"
"{\n"
"  // We need irrationals for pseudo randomness.\n"
"  // Most (all?) known transcendental numbers will (generally) work.\n"
"  const vec2 r = vec2(\n"
"    23.1406926327792690,  // e^pi (Gelfond's constant)\n"
"     2.6651441426902251); // 2^sqrt(2) (Gelfond-Schneider constant)\n"
"  //return fract( cos( mod( 123456789., 1e-7 + 256. * dot(p,r) ) ) );\n"
"  return mod( 123456789., 1e-7 + 256. * dot(p,r) );  \n"
"}\n"
"\n"
"mat2 randomRotation( const vec2 p )\n"
"{\n"
"	float r = random(p);\n"
"	float sinr = sin(r);\n"
"	float cosr = cos(r);\n"
"	return mat2(cosr, sinr, -sinr, cosr);\n"
"}\n"
"\n"
"float getLinearDepth(sampler2D depthMap, const vec2 tex, const float zFarDivZNear)\n"
"{\n"
"	float sampleZDivW = texture2D(depthMap, tex).r;\n"
"	return 1.0 / mix(zFarDivZNear, 1.0, sampleZDivW);\n"
"}\n"
"\n"
"float ambientOcclusion(sampler2D depthMap, const vec2 tex, const float zFarDivZNear, const float zFar, const vec2 scale)\n"
"{\n"
"	vec2 poissonDisc[9];\n"
"\n"
"	poissonDisc[0] = vec2(-0.7055767, 0.196515);\n"
"	poissonDisc[1] = vec2(0.3524343, -0.7791386);\n"
"	poissonDisc[2] = vec2(0.2391056, 0.9189604);\n"
"	poissonDisc[3] = vec2(-0.07580382, -0.09224417);\n"
"	poissonDisc[4] = vec2(0.5784913, -0.002528916);\n"
"	poissonDisc[5] = vec2(0.192888, 0.4064181);\n"
"	poissonDisc[6] = vec2(-0.6335801, -0.5247476);\n"
"	poissonDisc[7] = vec2(-0.5579782, 0.7491854);\n"
"	poissonDisc[8] = vec2(0.7320465, 0.6317794);\n"
"\n"
"	float result = 0.0;\n"
"\n"
"	float sampleZ = getLinearDepth(depthMap, tex, zFarDivZNear);\n"
"	float scaleZ = zFarDivZNear * sampleZ;\n"
"\n"
"	vec2 slope = vec2(dFdx(sampleZ), dFdy(sampleZ)) / vec2(dFdx(tex.x), dFdy(tex.y));\n"
"\n"
"	if (length(slope) * zFar > 5000.0)\n"
"		return 1.0;\n"
"\n"
"	vec2 offsetScale = vec2(scale * 1024.0 / scaleZ);\n"
"\n"
"	mat2 rmat = randomRotation(tex);\n"
"\n"
"	float invZFar = 1.0 / zFar;\n"
"	float zLimit = 20.0 * invZFar;\n"
"	int i;\n"
"	for (i = 0; i < NUM_SAMPLES; i++)\n"
"	{\n"
"		vec2 offset = rmat * poissonDisc[i] * offsetScale;\n"
"		float sampleDiff = getLinearDepth(depthMap, tex + offset, zFarDivZNear) - sampleZ;\n"
"\n"
"		bool s1 = abs(sampleDiff) > zLimit;\n"
"		bool s2 = sampleDiff + invZFar > dot(slope, offset);\n"
"		result += float(s1 || s2);\n"
"	}\n"
"\n"
"	result *= 1.0 / float(NUM_SAMPLES);\n"
"\n"
"	return result;\n"
"}\n"
"\n"
"void main()\n"
"{\n"
"	float result = ambientOcclusion(u_ScreenDepthMap, var_ScreenTex, u_ViewInfo.x, u_ViewInfo.y, u_ViewInfo.wz);\n"
"\n"
"	gl_FragColor = vec4(vec3(result), 1.0);\n"
"}\n"
;
