Shader "Unlit/analitycal-transmittance"
{
    Properties
    {
        //_MainTex ("Texture", 2D) = "white" {}
        _Volume("Volume", 3D) = "blue" {}
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue" = "Transparent" }
        LOD 100
        //Cull Off
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
                //float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 ro : TEXCOORD1;
                float3 hitPos : TEXCOORD2;
            };

            sampler3D _Volume;
            float4 _Volume_ST;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.ro = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos,1));
                o.hitPos = v.vertex;
                return o;
            }

            float2 intersect_cube(float3 ro, float3 rd, float boxSize)
            {
                float3 m = 1.0 / rd; // can precompute if traversing a set of aligned boxes
                float3 n = m * ro;   // can precompute if traversing a set of aligned boxes
                float3 k = abs(m) * boxSize;
                float3 t1 = -n - k;
                float3 t2 = -n + k;
                float tN = max(max(t1.x, t1.y), t1.z);
                float tF = min(min(t2.x, t2.y), t2.z);
                if (tN > tF || tF < 0.0) 
                    return float2(- 1.0, -1.0); // no intersection

                //float3 outNormal = -sign(rd) * step(t1.yzx, t1.xyz) * step(t1.zxy, t1.xyz);
                return float2(tN, tF); // intersection near, intersection far
            }

            float rand1(float3 value) {
                //make value smaller to avoid artefacts
                float3 smallValue = sin(value);
                //get scalar value from 3d vector
                float random = dot(smallValue, float3(12.9898, 78.233, 37.719));
                //make value more random by making it bigger and then taking teh factional part
                random = frac(sin(random) * 143758.5453);
                return random;
            }

            float rand(float3 p3, float seed=20) {
                p3 = frac(p3 * 1031);
                p3 += dot(p3, p3.zyx + 31.32);
                return frac((p3.x + p3.y) * p3.z * seed);
            }

            float4 T(float3 x, float3 y)
            {
                float step = 0.005;
                float sigmat = 2;
                float tau = 0;
                float3 pos = x;
                float3 dir = y - x;
                float r = 0.7;
                float4 c = float4(0, 0, 0, 0);

                for (int i = 0; i < 1000; i++)
                {
                    pos += step * dir;
                    if (max(abs(pos.x), max(abs(pos.y), abs(pos.z))) <= 0.5f)
                    {
                        //tau += sigmat * step;
                        float4 sampledColor = tex3D(_Volume, pos + float3(0.5f, 0.5f, 0.5f));
                        float t = sampledColor.a * step;
                        tau += t;
                        //color += sampledColor.xyz * step * (  exp(-tau));
                    }
                }
                //float4 c;
                c.a = 1 - exp(-tau);
                //c.xyz = color;

                return c;
            }


            float4 Tmc(float3 x, float3 y, float3 dir)
            {
                int num_steps = 1000;
                float t = distance(x, y);
                float step = t / num_steps;

                float sigmat = 2;
                float tau = 0;
                float3 pos = x;
                //float3 dir = y - x;
                float4 color = float4(0, 0, 0, 0);

                for (int i = 0; i < num_steps; i++)
                {
                    //pos += step * dir;
                    float ti = -(log(1-rand(pos)));
                    float3 cpos = x + dir * ti * step;
                    if (max(abs(cpos.x), max(abs(cpos.y), abs(cpos.z))) <= 0.5f)
                    {
                        //tau += sigmat * step;
                        
                        //float pt = 1; // same as regular sum
                        float4 sc = tex3D(_Volume, cpos + float3(0.5f, 0.5f, 0.5f));
                        //float pt = sc.a * exp(sc.a * ti);
                        tau += (sc.a/num_steps) ;
                    }
                }
                
                color.a = 1 - exp(-tau);
                return color;
            }

            float kernel(float3 ti, float3 t, float step)
            {
                float d = distance(ti, t);
                float w = 5;
                if (d <= w / 2)
                    return 1 / w;
                else
                    return 0;
            }

            float4 Tc(float3 x, float3 y, float3 dir)
            {
                int num_steps = 1000;
                float d = distance(x, y);
                float step = d / num_steps;

                float sigmat = 2;
                float t = 0;
                float3 pos = x;
                //float3 dir = y - x;
                float4 color = float4(0, 0, 0, 0);

                for (int i = 0; i < num_steps; i++)
                {
                    float ti = rand(pos+i*dir) * d;
                    pos = x + dir * ti;
                    float4 sc = tex3D(_Volume, pos + float3(0.5f, 0.5f, 0.5f), 0, 0);
                    if (sc.a == 0)
                        t += 1;
                        //color = float4(1- kernel(pos, x, step), 0, 0, 0);
                    //float pt = sc.a * exp(sc.a * ti);
                    else
                    {
                        t += kernel(pos, x, step) / sc.a;
                        //t += min(1, kernel(pos, x, step) / sc.a); // with low alpha we get very high values ... white shine around object borders
                    }
                }

                color.a = 1 - t / num_steps;
                return color;
            }

            

            float4 Trt(float3 x, float3 y, float3 dir)
            {
                int num_steps = 1000;
                float d = distance(x, y);
                float step = d / num_steps;
                int null_coll = 1000; // number of collision before real collision

                float t = 1;
                float3 pos = x;
                //float3 dir = y - x;
                float4 color = float4(0, 0, 0, 0);
                bool fin = true;
                float mi = 10;
                int nc = 1;

                for (int i = 0; i < null_coll; i++)
                {
                    float ti = -log(1 - rand(pos + _Time.a)) / mi;
                    pos += dir * ti;

                    if (max(abs(pos.x), max(abs(pos.y), abs(pos.z))) <= 0.5f)
                    {
                        float4 sc = tex3D(_Volume, pos + float3(0.5f, 0.5f, 0.5f), 0, 0);

                        float real_c = rand(pos + _Time.a, mi) * mi;
                        if (real_c > sc.a && fin)
                        {
                            t *= (mi - sc.a) / mi;
                            nc++;
                        }
                        else
                            fin = false;
                        //t *= 1; // terminated but for tex3d has to be fixed loop?
                    }
                }

                color.a = 1 - t;
                //color.r = nc;
                return color;
            }

            float4 Tdelta(float3 x, float3 y, float3 dir)
            {
                float t = 0;
                float mi = 5;
                float d = distance(x, y);
                float e;
                float4 sc;
                int i = 0;
                float r = 0.2;

                do {
                    if (i > 1000)
                        break;
                        //return float4(0, 0, 0, 0);
                    i++;
                    t = t - log(1 - rand(x  + i) / mi);
                    if (t >= d)
                        break;
                        //return float4(0, 0, 0, 0);
                    e = rand(y + i); 
                    //sc.a = length(x + t * dir) < r ? 1 : 0;
                    sc = tex3D(_Volume, x + t*dir + float3(0.5f, 0.5f, 0.5f), 0, 0);
                } while (e >= sc.a); // ne delim z mi ker sc.a ze normaklizirana
                return float4(0, 0, 0, 1 - (t > d));
            }

            float4 Tratio(float3 x, float3 y, float3 dir)
            {
                float t = 0;
                float T = 1;
                int i = 0;
                float4 sc;
                float d = distance(x, y);
                float mi = 5;
                do {
                    if (i > 1000)
                        break;
                        //return float4(0, 0, 0, 0);
                    i++;
                    t = t - log(1 - rand(x + i) / mi);
                    if (t >= d)
                        break;
                        //return float4(0, 0, 1, 1);
                    sc = tex3D(_Volume, x + t * dir + float3(0.5f, 0.5f, 0.5f), 0, 0);
                    T = T * (1 - sc.a); // 1-sc.a = mi_n
                } while (true);
                return float4(0, 0, 0, 1-T);
            }

            float4 Tsmc(float3 x, float3 y, float3 dir)
            {
                int num_steps = 1000;
                float t = distance(x, y);
                float step = t / num_steps;

                float sigmat = 5;
                float tau = 0;
                float3 pos = x;
                //float3 dir = y - x;
                float4 color = float4(0, 0, 0, 0);

                for (int i = 0; i < num_steps; i++)
                {
                    //pos += step * dir;
                    float ti = (i - rand(pos)) * step;
                    float3 cpos = x + dir * ti;
                    if (max(abs(cpos.x), max(abs(cpos.y), abs(cpos.z))) <= 0.5f)
                    {
                        //tau += sigmat * step;

                        //float pt = 1; // same as regular sum
                        float4 sc = tex3D(_Volume, cpos + float3(0.5f, 0.5f, 0.5f));
                        //float pt = sc.a * exp(sc.a * ti);
                        tau += sc.a * step;
                    }
                }

                color.a = 1 - exp(-tau);
                return color;
            }


            float4 Ls(float3 x, float3 w)
            {
                //inscattering
                // samo od luci, no phasing fun???
                float3 light_pos = float3(1, 1, 1);
                w = light_pos - x;

                float4 l = float4(1, 1, 1, 1);

                float r = 0.5;
                float3 pos = x;

                //float t = Tmc(x, light_pos);
                //l *= t;
                return l;
            }

            float4 L(float3 x, float3 y, float3 w)
            {
                float r = 0.5;
                float step = 0.01;
                float sc = 0.6; // scattering coef
                float3 pos = x;
                float4 light = float4(0, 0, 0, 0);


                float4 t = Tsmc(x, y, w);
                //float4 s = float4(0, 0, 0, 0);
                /*
                for (int i = 0; i < 1000; i++)
                {
                    pos += step * w;
                    if (length(pos) < r)
                        s += sc * T(pos, x) * Ls(pos, w);
                }
                //s.x = 0;
                s.y = 0;
                s.z = 0;
                */
                //s.a = 1 - t;
                //float ls = sc * Ls(pos, w);
                //light += t;// *ls;
                
                return t;
            }
            
            void frag(v2f i, out float4 color : SV_Target)
            {
                // directly compute stuff
                /*
                float3 pos = i.ro;
                float3 dir = normalize(i.hitPos - i.ro);
                float3 hpos = i.hitPos;
                float3 oghpos = hpos;

                float r = 0.5;
                float omega = 1.0;

                float delta = pow(dot(dir, hpos), 2) - (pow(normalize(hpos), 2) - pow(r, 2));
                if (delta <= 0)
                {
                    color = float4(0, 0, 0, 0);
                    return;
                }
                else
                {
                    // delta should be > 0
                    float d1 = -dot(dir, oghpos) + sqrt(delta);
                    float d2 = -dot(dir, oghpos) - sqrt(delta);
                    float d = abs(d1 - d2); //d1 > d2 ? d1 : d2;

                    //float3 exit = oghpos + d * dir;

                    float t = exp(-omega * (1 - d)); 

                    color = float4(0, 0, 0, t);
                    return;
                }
                */

                // raymarch
                /*
                float3 pos = i.ro;
                float3 dir = normalize(i.hitPos - i.ro);
                float3 hpos = i.hitPos;
                float3 oghpos = hpos;

                float r = 0.5;
                float omega = 0.5;
                float step = 0.005;
                int steps_inside = 0;

                for (int i = 0; i < 1 / step; i++)
                {
                    hpos = hpos + dir*step;
                    if (length(hpos) <= r)
                    {
                        steps_inside += 1;
                    }
                }

                if (steps_inside > 0)
                {
                    float d = (steps_inside * step);
                    float t = exp(-omega * d);
                    color = float4(0, 0, 0, 1-t);
                }
                else
                {
                    color = float4(0, 0, 0, 0);
                } 
                */

                // random twexture
                /*
                float3 pos = i.ro;
                float3 dir = normalize(i.hitPos - i.ro);
                float3 hpos = i.hitPos;
                float3 oghpos = hpos;

                float r = 0.5;
                float omega = 0.5;
                float step = 0.005;
                int steps_inside = 0;
                float tau = 0;


                for (int i = 0; i < 1 / step; i++)
                {
                    hpos = hpos + dir * step;
                    if (length(hpos) <= r)
                    {
                        steps_inside += 1;
                        
                        tau += rand(hpos) * step;
                    }
                }

                if (steps_inside > 0)
                {
                    float t = exp(-tau);
                    color = float4(0, 0, 0, 1 - t);
                }
                else
                {
                    color = float4(0, 0, 0, 0);
                }
                */

                // dragged texture cloud/torus
                /*
                float3 pos = i.ro;
                float3 dir = normalize(i.hitPos - i.ro);
                float3 hpos = i.hitPos;
                float3 oghpos = hpos;

                float r = 0.5;
                float omega = 0.5;
                float step = 0.005;
                int steps_inside = 0;
                float tau = 0;

                for (int i = 0; i < sqrt(2) / step; i++)
                {
                    hpos = hpos + dir * step;
                    if (length(hpos) <= r)
                    {
                        float4 sampledColor = tex3D(_Volume, hpos + float3(0.5f, 0.5f, 0.5f));
                        tau += sampledColor.a * step;
                    }
                }

                if (tau > 0)
                {
                    float t = exp(-tau);
                    color = float4(0, 0, 0, 1 - t);
                }
                else
                {
                    color = float4(0, 0, 0, 0);
                }
                */

                float r = 0.5;
                float3 pos = i.ro;
                float3 dir = normalize(i.hitPos - i.ro);
                float3 hpos = i.hitPos;
                float3 oghpos = hpos;
                color = float4(0, 0, 0, 0);

                //float tn, tf;
                float2 t = intersect_cube(pos, dir, r);
                float3 posn = pos + dir * t[0];
                float3 posf = pos + dir * t[1];
                float4 light = L(posn, posf, dir);
                //float4 light = L(hpos, hpos+dir*sqrt(2), dir);
                color = light;
            }
            ENDCG
        }
    }
}
