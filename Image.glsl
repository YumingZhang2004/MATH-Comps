float U_fn(vec3 p);
vec3 gradU(vec3 p);

const int BH_COUNT = 2;
const vec3 BH_POS[2] = vec3[2](
    vec3(1.0, 0.0, 5.0),
    vec3( 0.5, 0.0, 4.0)
);
const float BH_MASS[2] = float[2](0.07, 0.07);

float U_fn(vec3 p) {
    float U = 1.0;
    for (int i = 0; i < BH_COUNT; i++) {
        vec3 d = p - BH_POS[i];
        float r = length(d);
        r = max(r, 1e-4);  // avoid division by very small r
        U += BH_MASS[i] / r;
    }
    return U;
}

vec3 gradU(vec3 p) {
    vec3 g = vec3(0.0);
    for (int i = 0; i < BH_COUNT; i++) {
        vec3 d = p - BH_POS[i];
        float r2 = max(dot(d,d), 1e-8);
        float r = sqrt(r2);
        // gradient of (m / r) = m * (-d / r^3)
        g += -BH_MASS[i] * d / (r2 * r);
    }
    return g;
}

vec3 accel(vec3 x, vec3 v){
    float U  = U_fn(x);
    vec3 gU  = gradU(x);
    float v2 = dot(v,v);
    float s  = dot(v,gU);
    return (2.0/U)*v2*gU - (4.0/U)*s*v;
}

void rk4(inout vec3 x, inout vec3 v, float h){
    vec3 k1x = v;
    vec3 k1v = accel(x, v);

    vec3 k2x = v + 0.5*h*k1v;
    vec3 k2v = accel(x + 0.5*h*k1x,
                     v + 0.5*h*k1v);

    vec3 k3x = v + 0.5*h*k2v;
    vec3 k3v = accel(x + 0.5*h*k2x,
                     v + 0.5*h*k2v);

    vec3 k4x = v + h*k3v;
    vec3 k4v = accel(x + h*k3x,
                     v + h*k3v);

    x += (h/6.0) * (k1x + 2.0*k2x + 2.0*k3x + k4x);
    v += (h/6.0) * (k1v + 2.0*k2v + 2.0*k3v + k4v);
}


//----------------------------------



float sceneSDF(vec3 p, out int matID) {
    float d = 1e5;
    matID = -1;
   
    float plane = sdPlane(p, vec3(0.,1.,0.), 1.);
    if (plane < d) { d = plane; matID = 0; }

    float s1 = sdSphere(p - vec3(0., 0., 4.), 1.0);
    if (s1 < d) { d = s1; matID = 1; }

    float s2 = sdSphere(p - vec3(2., 0., 6.), 0.7);
    if (s2 < d) { d = s2; matID = 2; }

    vec3 q = p - vec3(-2., 0., 5.);
    float cyl = sdCylinder(q, vec3(0., 0.5, 1.0));
    if (cyl < d) { d = cyl; matID = 3; }

    return d;
}

vec3 getNormal(vec3 p) {
    vec2 eps = vec2(0.001, 0.0);
    int _;
    vec3 n = normalize(vec3(
        sceneSDF(p + eps.xyy, _) - sceneSDF(p - eps.xyy, _),
        sceneSDF(p + eps.yxy, _) - sceneSDF(p - eps.yxy, _),
        sceneSDF(p + eps.yyx, _) - sceneSDF(p - eps.yyx, _)
    ));
    return n;
}

vec3 calculateLighting(vec3 p, vec3 normal, vec3 viewDir, vec3 lightPos, vec3 lightColor, int matID) {
    // Material properties
    float ambientStrength = 0.3;
    float diffuseStrength = 0.7;
    float specularStrength = 0.5;
    float shininess = 32.0;

    // Ambient
    vec3 ambient = ambientStrength * lightColor;

    // Diffuse
    vec3 lightDir = normalize(lightPos - p);
    float diff = max(dot(normal, lightDir), 0.0);
    vec3 diffuse = diff * diffuseStrength * lightColor;

    // Specular
    vec3 reflectDir = reflect(-lightDir, normal);
    float spec = pow(max(dot(viewDir, reflectDir), 0.0), shininess);
    vec3 specular = spec * specularStrength * lightColor;

    return ambient + diffuse + specular;
}


// Raymarcher
vec3 raymarch(vec3 ro, vec3 rd, out int matID) {
    float t = 0.0;

    for (int i = 0; i < 256; i++) {
        vec3 p = ro + rd * t;
        float d = sceneSDF(p, matID);

        if (d < 0.001) {
            return p; // hit
        }

        t += d;

        if (t > 50.0) break;
    }

    matID = -1;
    return ro + rd * t;
}

// Main Render
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
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

    int matID;
    vec3 p = raymarch(ro, rd, matID);
   
    vec3 col;
    if (matID >= 0) {
        vec3 colors[4];
        colors[0] = vec3(0.9, 0.8, 0.7);
        colors[1] = vec3(0.0, 0.5, 0.4);
        colors[2] = vec3(0.0, 0.6, 0.4);
        colors[3] = vec3(0.0, 0.5, 0.3);
        vec3 baseColor = colors[matID];
       
        if (matID == 1 || matID == 2 || matID == 3) {
            vec2 texCoords = p.xz * 0.5; // Scale the texture
            vec3 cactusColor = texture(iChannel2, texCoords).rgb;
            baseColor = cactusColor;
        }
       
       
        vec3 normal = getNormal(p); // Surface normal
        vec3 viewDir = normalize(ro - p); // Direction from hit point to camera

        // Define a light source
        vec3 lightPos = vec3(5.0, 10.0, 5.0);
        vec3 lightColor = vec3(1.0, 1.0, 1.0);

        // Calculate final color with lighting
        vec3 litColor = calculateLighting(p, normal, viewDir, lightPos, lightColor, matID);
        col = baseColor * litColor; // Multiply base color by lighting intensity/color
       
    } else if (matID == -2) {
        col = vec3(0.0);
    } else {
        col = vec3(0.6, 0.8, 1.0) * (1.0 - 0.5 * rd.y);
    }

    fragColor = vec4(col, 1.0);
}