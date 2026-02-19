// Scene definition
float sceneSDF( in vec3 p, out int matID)
{

    // Constant between 0.0-1.0 used to control strength of object smoothing
    float ksmooth = 0.3;
    
    /* s: Determines the size of the domain. Ex. if s=3.0, then the fundamental domain 
    is a 3x3x3 unit cube centered at the origin.*/
    float s = max(600.0 - 200.0 * iTime, 6.0);
    //const float s = 4.;
    
    /*rep: Only used when rendering limited repetition. Below, the fund. dom. is
    duplicated once in both x directions, 2 in both y dirs, and 3 in both z dirs.*/
    //const vec3 rep = vec3(3,1, 2);
    vec3 id = round(p/s);
    vec3 off = sign(p-s*id);

    float d = 1e20;
    for( int k=0; k<2; k++)
    for( int j=0; j<2; j++)
    for( int i=0; i<2; i++ )
    {
        vec3 grid = id + vec3(i,j,k)*off;
        
        // Uncomment below for limited repetition
        //grid = clamp(grid,-rep,rep); 
        vec3 p = p - s*grid;        
        
        // Use move in the position vector to move the sdf in that direction without glitching out.
        //float move = mod(20. * iTime + 0.5 *s, s) - 0.5*s;
        float sphere = sdSphere(p, 0.8);
        
        // extra object to add. May impact performance.
        float torus = sdTorus(p - vec3(0.0, -0.2, 0.0), vec2(1.2, 0.1));
        float sphere2 = sdSphere(p - vec3(0.4, 1.0, 0.3), 0.3);
        float sphere3 = sdSphere(p- vec3(-0.4, 1.4, -1.0), 0.3);
        float box = sdBoxFrame(p - vec3(0.0, 4.0, 0.0), vec3(0.5, 1.0,  0.5), 0.035);

    
    if (sphere < d){
        d = sphere;
        matID = 0;
    }
    if (torus < d){
        d = torus;
        matID = 1;
    }
    if (sphere2 < d){
        d = sphere2;
        matID = 2;
    }
    if (sphere3 < d){
        d = sphere3;
        matID = 3;
    }    
    if (box < d){
        d = box;
        matID = 4;
    }
    
    //float cell = smin(sphere, torus, ksmooth);
    //d = smin(d, cell, ksmooth);

    }
    
    return d;
}    

// Calculates normal at p
vec3 getNormal(vec3 p)
{
    vec2 e = vec2(0.001, 0.0);
    int _;
    return normalize(vec3(
        sceneSDF(p + e.xyy, _) - sceneSDF(p - e.xyy, _),
        sceneSDF(p + e.yxy, _) - sceneSDF(p - e.yxy, _),
        sceneSDF(p + e.yyx, _) - sceneSDF(p - e.yyx, _)
    ));
}

// Creates smooth shadows with gradient penumbra
float softshadow( in vec3 ro, in vec3 rd, float mint, float maxt, float k )
{
    float res = 1.0;
    float t = mint;
    for( int i=0; i<256 && t<maxt; i++ )
    {
        int _;
        float h = sceneSDF(ro + rd*t, _);
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
    float ambientStrength  = 0.25;
    float diffuseStrength  = 0.95;
    float specularStrength = 0.45;
    float shininess = 0.0;

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
// Note: lower render distance for performance (t > 1000 is rather high)
vec3 raymarch(vec3 ro, vec3 rd, out int matID)
{
    float t;
    
    for(int i=0; i<550; i++)
    {
        vec3 p = (ro + rd*t);
        int stepID;
        float d = sceneSDF(p, stepID);

        // Hit
        if(d < 0.001)
        {
            matID = stepID;
            return p;
        }

        t += d;
        if(t > 1000.0) break;
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
    vec3 camPos = camPose[3].xyz - vec3(0.0,0.0,-0.85);

    vec3 ro = camPos;
    vec3 rd = normalize(camRot * normalize(vec3(uv, 1.5)));

    // Raymarch
    int matID;
    vec3 p = raymarch(ro, rd, matID);

    // Background
    if(matID < 0)
    {        
        vec3 sky = vec3(0.0);
        fragColor = vec4(sky, 1.0);
        return;
    }

    // Material base color
    // If adding more objects, update colors here
    vec3 colors[5];
    colors[0] = vec3(0.4, 0.1, 0.9);
    colors[1] = vec3(0.1, 0.2, 0.6);
    colors[2] = vec3(0.1, 0.6, 0.4);
    colors[3] = vec3(0.5, 0.5, 0.3);
    colors[4] = vec3(0.7, 0.7, 0.0);
    vec3 baseColor = colors[matID];

    vec3 normal  = getNormal(p);
    vec3 viewDir = normalize(ro - p);

    // Stationary light source
    //vec3 lightPos   = vec3(0., 1., 0.);
    
    // Light follows camera
    vec3 lightPos = ro - vec3(0.0, 0.5, 0.0);
    vec3 lightColor = vec3(1.0);
    

    // Soft shadow factor
    vec3 lightDir = normalize(lightPos - p);
    float dist = length(p - lightPos);
    float fade = 2.0/(1.0 + dist * dist * 0.2) + 2.0;
    float sha = softshadow(p, lightDir, .12, dist, 200.0);

    // Lighting
    vec3 lit = calculateLighting(p, normal, viewDir, lightPos, lightColor, sha);

    vec3 col = baseColor * lit * fade;
    fragColor = vec4(col, 1.0);
}
