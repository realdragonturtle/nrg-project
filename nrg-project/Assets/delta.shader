Shader "Unlit/delta"
{
    Properties
    {
        _Volume("Volume", 3D) = "blue" {}
        _MaxDensity("Max density", float) = 5.0
    }
        SubShader
        {
            Tags { "RenderType" = "Transparent" "Queue" = "Transparent" }
            LOD 100
            Blend SrcAlpha OneMinusSrcAlpha

            Pass
            {
                CGPROGRAM
                #pragma vertex vert
                #pragma fragment frag
                #pragma multi_compile_fog

                #include "UnityCG.cginc"

                struct appdata
                {
                    float4 vertex : POSITION;
                    float2 uv : TEXCOORD0;
                };

                struct v2f
                {
                    float4 vertex : SV_POSITION;
                    float3 ro : TEXCOORD1;
                    float3 hitPos : TEXCOORD2;
                };

                sampler3D _Volume;
                float4 _Volume_ST;
                float _MaxDensity;

                v2f vert(appdata v)
                {
                    v2f o;
                    o.vertex = UnityObjectToClipPos(v.vertex);
                    o.ro = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos,1));
                    o.hitPos = v.vertex;
                    return o;
                }

                float2 intersect_cube(float3 ro, float3 rd, float boxSize)
                {
                    float3 m = 1.0 / rd;
                    float3 n = m * ro;
                    float3 k = abs(m) * boxSize;
                    float3 t1 = -n - k;
                    float3 t2 = -n + k;
                    float tN = max(max(t1.x, t1.y), t1.z);
                    float tF = min(min(t2.x, t2.y), t2.z);
                    if (tN > tF || tF < 0.0)
                        return float2(-1.0, -1.0); // no intersection

                    return float2(tN, tF); // intersection near, intersection far
                }

                float rand1(float3 p3, float seed = 20) {
                    p3 = frac(p3 * 1031);
                    p3 += dot(p3, p3.zyx + 31.32);
                    return frac((p3.x + p3.y) * p3.z * seed);
                }

                float density(float3 pos)
                {
                    return -log(pos.x);
                }

                float rand(float3 value, float3 dotDir = float3(12.9898, 78.233, 37.719)) {

                    dotDir += float3(1.9898, 7.233, 3.719);

                    float3 smallValue = sin(value);
                    float random = dot(smallValue, dotDir);
                    random = frac(sin(random) * 1438.5453);
                    return random;
                }

                float4 T(float3 x, float3 y, float3 dir)
                {
                    float t = 0;
                    float d = distance(x, y);
                    float e;
                    float sc;
                    int i = 0;
                    float3 pos = float3(0, 0, 0);
                    //_MaxDensity = 5;
                    _MaxDensity = 5 + 95 * (x.y + 0.5);
                    float cp = 0; // tentative collision points

                    do {
                        if (i > 10000)
                            break;
                        i++;
                        t = t - log(1 - rand(x + i + t + _Time.y)) / _MaxDensity;
                        if (t >= d)
                            break;
                        e = rand(y + i + t + _Time.y);

                        //sc = tex3D(_Volume, x + t * dir + float3(0.5f, 0.5f, 0.5f), 0, 0);
                        pos = x + t * dir;
                        
                        sc = density(pos + float3(0.5f, 0.5f, 0.5f)) / _MaxDensity; 
                        cp++;
                    } while (e >= sc); // ne delim z mi ker sc.a ze normalizirana èe uporabim tex3d

                    float s = (t > d);
                    //return float4(s, cp/100, 0, 1);
                    return float4(s, s, s, 1);
                }

                void frag(v2f i, out float4 color : SV_Target)
                {
                    float3 pos = i.ro;
                    float3 dir = normalize(i.hitPos - i.ro);
                    if (unity_OrthoParams.w) //if camera is orthographic, recalculate ray direction
                        dir = mul(unity_WorldToObject, float4(unity_CameraToWorld._m02_m12_m22, 0));
                    float3 hpos = i.hitPos;

                    float r = 0.5;
                    if (unity_OrthoParams.w)
                        color = T(float3(hpos.x, hpos.y, hpos.z), float3(hpos.x, hpos.y, hpos.z + 1), dir);
                    else {
                        float2 t = intersect_cube(pos, dir, r);
                        float3 posn = pos + dir * t[0];
                        float3 posf = pos + dir * t[1];
                        color = T(posn, posf, dir);
                    }

                }
            ENDCG
            }
        }
}
