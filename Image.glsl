// Scene definition
float sceneSDF(vec3 p, out int matID)
{
    float d = 1e5;
    matID = -1;
    vec3 space = vec3(8.0);                 
    p.xyz = mod(p.xyz + space, 2.0*space) - space;

    /*float height = 0.;
    float plane = sdPlane(p, vec3(0.,1.,0.), 1.0);
    if (plane < d) { d = plane; matID = 0; }
    */
    
   
    float s1 = sdSphere(p - vec3(0., 0., 0.), 0.7);
    if (s1 < d) { d = s1; matID = 1; }

    /*float s2 = sdSphere(p - vec3(2., 0., -4.), 0.7);
    if (s2 < d) { d = s2; matID = 2; }
    */
    
    
    /*
    vec3 q = p - vec3(-2., 0., 5.);
    float cyl = sdCylinder(q, vec3(0., 0.5, 1.0));
    if (cyl < d) { d = cyl; matID = 3; }
   
    
    float cyl = sdCappedCylinderY(p - vec3(0., 2.0, 0.0), 6., .3);
    if (cyl < d) {d = cyl; matID = 3; }
    */
    
    return d;
}

// Wrapper used by soft shadows
float map(vec3 p)
{
    int _;
    return sceneSDF(p, _);
}

float hash21(vec2 p)
{
    return fract(sin(dot(p, vec2(120., 310.))) * 4000.);
}

float noise2(vec2 p)
{
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f*f*(3.0 - 2.0*f);

    float a = hash21(i + vec2(0.0, 0.0));
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));

    return mix(mix(a,b,f.x), mix(c,d,f.x), f.y);
}

float fbm2(vec2 p)
{
    float s = 0.0;
    float a = 0.5;
    for (int i = 0; i < 5; i++)
    {
        s += a * noise2(p);
        p *= 2.02;
        a *= 0.5;
    }
    return s;
}

vec3 sandAlbedo(vec3 p)
{
    vec3 base = vec3(0.8, 0.8, 0.60);
    float dune = fbm2(p.xz * 0.12);

    // Ripple direction varies slowly with dune
    float ang = 1.0 + 2.0*dune;
    vec2 dir = normalize(vec2(cos(ang), sin(ang)));
    float rip = sin(10.0 * dot(p.xz, dir) + 6.0*dune);
    float t = 0.5 + 0.5*rip;

    // Micro grain variation
    float micro = fbm2(p.xz * 1.6);

    vec3 col = base;
    col *= 0.90 + 0.20*dune;          // dune brightness
    col *= 0.92 + 0.10*t;             // ripple contrast
    col += 0.25*(micro - 0.5);        // small noise

    return clamp(col, 0.0, 1.0);
}

// Geometry utilities
vec3 getNormal(vec3 p)
{
    vec2 e = vec2(0.001, 0.0);
    return normalize(vec3(
        map(p + e.xyy) - map(p - e.xyy),
        map(p + e.yxy) - map(p - e.yxy),
        map(p + e.yyx) - map(p - e.yyx)
    ));
}

// Soft shadows
float calcSoftshadow(in vec3 ro, in vec3 rd,
                     in float mint, in float tmax,
                     in float w, int technique)
{
    float res = 1.0;
    float t   = mint;
    float ph  = 1e10;

    for(int i=0; i<64; i++)
    {
        float h = map(ro + rd*t);

        // traditional technique
        if(technique==0)
        {
            res = min(res, h/(w*t));
        }
        // improved technique
        else
        {
            float y = h*h/(2.0*ph);
            float d = sqrt(max(h*h - y*y, 0.0));
            res = min(res, d/(w*max(0.0, t - y)));
            ph = h;
        }

        t += h;
        if(res < 0.0001 || t > tmax) break;
    }

    res = clamp(res, 0.0, 1.0);
    return res*res*(3.0 - 2.0*res);
}

// Lighting (Phong + shadow factor)
vec3 calculateLighting(vec3 p, vec3 normal, vec3 viewDir,
                       vec3 lightPos, vec3 lightColor,
                       float sha)
{
    float ambientStrength  = 0.25;
    float diffuseStrength  = 0.25;
    float specularStrength = 0.45;
    float shininess        = 16.0;

    // Ambient
    vec3 ambient = ambientStrength * lightColor;

    // Diffuse
    vec3 lightDir = normalize(lightPos - p);
    float diff = max(dot(normal, lightDir), 0.0);
    vec3 diffuse = diff * diffuseStrength * lightColor * sha;

    // Specular
    vec3 reflectDir = reflect(-lightDir, normal);
    float spec = pow(max(dot(viewDir, reflectDir), 0.0), shininess);
    vec3 specular = spec * specularStrength * lightColor * sha;

    return ambient + diffuse + specular;
}

// Raymarcher
vec3 raymarch(vec3 ro, vec3 rd, out int matID)
{
    float t = 0.0;
    matID = -1;

    for(int i=0; i<256; i++)
    {
        vec3 p = ro + rd*t;

        int stepID;
        float d = sceneSDF(p, stepID);

        // Hit
        if(d < 0.001)
        {
            matID = stepID;
            return p;
        }

        t += d;
        if(t > 500.0) break;
    }

    matID = -1;
    return ro + rd*t;
}

vec3 phongLighting(vec3 p, vec3 normal, vec3 viewDir,
                   vec3 lightPos, vec3 lightColor,
                   float specMul, float shinMul,
                   float sha)
{
    float ambientStrength  = 0.30;
    float diffuseStrength  = 0.70;
    float specularStrength = 0.50 * specMul;
    float shininess        = 32.0 * shinMul;

    vec3 ambient = ambientStrength * lightColor;

    vec3 lightDir = normalize(lightPos - p);
    float diff = max(dot(normal, lightDir), 0.0);
    vec3 diffuse = diff * diffuseStrength * lightColor * sha;

    vec3 reflectDir = reflect(-lightDir, normal);
    float spec = pow(max(dot(viewDir, reflectDir), 0.0), shininess);
    vec3 specular = spec * specularStrength * lightColor * sha;

    return ambient + diffuse + specular;
}

void getMaterial(in int matID, in vec3 p, out vec3 albedo, out float specMul, out float shinMul)
{
    specMul = 1.0;
    shinMul = 1.0;

    if (matID == 0)
    {
        albedo  = sandAlbedo(p);
        specMul = 0.15;
        shinMul = 0.50;
    }
    else if (matID == 1)
    {
        albedo = vec3(0.0, 0.5, 0.5);
    }
    else if (matID == 2)
    {
        albedo = vec3(0.0, 0.5, 0.5);
    }
    else if (matID == 3)
    {
        albedo = vec3(0.0, 0.5, 0.5);
    }
}

// Main
void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;

    // Load camera pose
    mat4 camPose;
    camPose[0] = texelFetch(iChannel1, ivec2(0,0), 0);
    camPose[1] = texelFetch(iChannel1, ivec2(1,0), 0);
    camPose[2] = texelFetch(iChannel1, ivec2(2,0), 0);
    camPose[3] = texelFetch(iChannel1, ivec2(3,0), 0);

    mat3 camRot = mat3(camPose);
    vec3 camPos = camPose[3].xyz;

    vec3 ro = camPos;
    vec3 rd = normalize(camRot * normalize(vec3(uv, 1.5)));

    // Raymarch
    int matID;
    vec3 p = raymarch(ro, rd, matID);

    // Background
    if(matID < 0)
    {
        vec3 sky = vec3(0.6, 0.8, 1.0) * (1.0 - 0.5 * rd.y);
        fragColor = vec4(sky, 1.0);
        return;
    }

    // Material base color
    vec3 colors[4];
    colors[0] = vec3(0.4, 0.9, 0.7);
    colors[1] = vec3(.5, .3, .6 );
    colors[2] = vec3(0.1, 0.6, 0.4);
    colors[3] = vec3(0.5, 0.5, 0.3);
    vec3 baseColor = colors[matID];

    vec3 normal  = getNormal(p);
    vec3 viewDir = normalize(ro - p);

    vec3 lightPos   = vec3(-10.0, 15.0, 5.0);
    vec3 lightColor = vec3(1.0);

    // Soft shadow factor
    vec3 lightDir = normalize(lightPos - p);
    float sha = calcSoftshadow(p, lightDir, 0.01, 25.0, 0.12, 1);



    // Lighting
    vec3 lit = calculateLighting(p, normal, viewDir, lightPos, lightColor, sha);

    vec3 col = baseColor * lit * 3.;
    fragColor = vec4(col, 1.0);
}

