#define PI 3.141592653589793238
// Scene definition
float mapp( in vec3 p )
{

    float ksmooth = 0.3;
  //float s = max(600.0 - 200.0 * iTime, 1.);
    
    const float s = 3.;

    const vec3 rep = vec3(1,1,1);

    vec3 id = round(p/s);

    vec3 off = sign(p-s*id);

    float d = 1e20;
    for( int k=0; k<2; k++)
    for( int j=0; j<2; j++ )
    for( int i=0; i<2; i++ )
    {
        vec3 grid = id + vec3(i,j,k)*off;
        //grid = clamp(grid,-rep,rep); // limited repetition
        vec3 r = p - s*grid;

        
    float xdir = sin(10.*  iTime);    
    float zdir = -cos(10.* iTime);
    //float s1 = sdSphere(r - vec3(0.,0.,0.), .4);
    //float s1 = sdSphere(r - vec3(xdir, -xdir * .2, zdir), .7);
    //float s1 = sdSphere(p - vec3(0.,heightjump,0.), 0.4);
    //float d1 = smin(d, s1, k);
    
    float left = mod(20. * iTime + 0.5 *s, s) - 0.5*s;
    float sphere = sdSphere(r - vec3(1.5,1.5,1.5), .6);

    //float torus = sdTorus(r - vec3(1.,1.0,1.), vec2(1.4,.5));
    float frame = sdBoxFrame(r - vec3(3.), vec3(3.0), .07);
    

    float cell = min(sphere, frame);
    d = min(d, cell);
    //d = min(d, torus);
    //d = smin(d, cell, ksmooth);

    }
    
    return d;
}    


/*float sceneSDF(vec3 p, out int matID)
{
    
    
    
    float k = 0.7;
    matID = -1;
    p.xz = mod(p.xz + 1.0, 2.0 ) - 1.0;  
    float heightjump = 0.2 + 0.2*sin(5. * iTime);

    float d = sdPlane(p, vec3(0.,0.,0.), 1.0);
    matID = 0;

    float s1 = sdSphere(p - vec3(heightjump,0.,0.), 0.2);
    float d1 = smin(d, s1, k);
    if (d1 != d) matID = 1;
    d = d1;
    


    
    return d;
    
}*/

// Wrapper used by soft shadows
/*float map(vec3 p)
{
    int _;
    return sceneSDF(p, _);
}*/

// Geometry utilities
vec3 getNormal(vec3 p)
{
    vec2 e = vec2(0.001, 0.0);
    return normalize(vec3(
        mapp(p + e.xyy) - mapp(p - e.xyy),
        mapp(p + e.yxy) - mapp(p - e.yxy),
        mapp(p + e.yyx) - mapp(p - e.yyx)
    ));
}

// Soft shadows
/*float calcSoftshadow(in vec3 ro, in vec3 rd,
                     in float mint, in float tmax,
                     in float w)
{
    float res = 1.0;
    float t   = mint;
    float ph  = 1e10;

    for(int i=0; i<32; i++)
    {
        float h = mapp(ro + rd*t);
        float y = h*h/(2.0*ph);
        float d = sqrt(max(h*h - y*y, 0.0));
        res = min(res, d/(w*max(0.0, t - y)));
        ph = h;


        t += h;
        if(res < 0.0001 || t > tmax) break;
    }

    res = clamp(res, 0.0, 1.0);
    return res*res*(3.0 - 2.0*res);
}*/
float softshadow( in vec3 ro, in vec3 rd, float mint, float maxt, float k )
{
    float res = 1.0;
    float t = mint;
    for( int i=0; i<256 && t<maxt; i++ )
    {
        float h = mapp(ro + rd*t);
        if( h<0.001 )
            return 0.0;
        res = min( res, k*h/t );
        t += h;
    }
    return res;
}


// Lighting (Phong + shadow factor)
vec3 calculateLighting(vec3 p, vec3 normal, vec3 viewDir,
                       vec3 lightPos, vec3 lightColor,
                       float sha)
{
    float ambientStrength  = .25;
    float diffuseStrength  = .95;
    float specularStrength = .45;
    float shininess        = 0.;

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

    for(int i=0; i<2560; i++)
    {
        vec3 p = (ro + rd*t);

        int stepID;
        float d = mapp(p);

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

// Main
void mainImage( out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;

    // Load camera pose
    mat4 camPose;
    camPose[0] = texelFetch(iChannel1, ivec2(0,0), 0);
    camPose[1] = texelFetch(iChannel1, ivec2(1,0), 0);
    camPose[2] = texelFetch(iChannel1, ivec2(2,0), 0);
    camPose[3] = texelFetch(iChannel1, ivec2(3,0), 0);

    mat3 camRot = mat3(camPose);
    vec3 camPos = camPose[3].xyz - vec3(0.,0.0,-.75);

    vec3 ro = camPos;
    vec3 rd = normalize(camRot * normalize(vec3(uv, 1.5)));

    // Raymarch
    int matID;
    vec3 p = raymarch(ro, rd, matID);

    // Background
    if(matID < 0)
    {
        //vec3 sky = vec3(0.6, 0.8, 1.0) * (1.0 - 0.5 * rd.y);
        vec3 sky = vec3(0.0);
        fragColor = vec4(sky, 1.0);
        return;
    }

    // Material base color
    vec3 colors[4];
    colors[0] = vec3(.2, .4, .7);
    colors[1] = vec3(1.,1.,1.);
    colors[2] = vec3(.5);
    colors[3] = vec3(0.5, 0.5, 0.3);
    vec3 baseColor = colors[matID];

    vec3 normal  = getNormal(p);
    vec3 viewDir = normalize(ro - p);

    //vec3 lightPos   = vec3(0., 1., 0.);
    vec3 lightPos = ro - vec3(0.0, 0.5, 0.0);
    vec3 lightColor = vec3(1.0);
    

    // Soft shadow factor
    vec3 lightDir = normalize(lightPos - p);
    float dist = length(p - lightPos);
    float fade = 2.0/ (1.0 + dist * dist * 0.2) + 2.0;
    float sha = softshadow(p, lightDir, .12, dist, 205.);

    // Lighting
    vec3 lit = calculateLighting(p, normal, viewDir, lightPos, lightColor, sha);

    vec3 col = baseColor * lit * fade;
    fragColor = vec4(col, 1.0);
}
