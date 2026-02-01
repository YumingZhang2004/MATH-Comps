#define PI 3.14159265358979323846

// SDF primitives
float sdSphere(vec3 p, float s) {
    return length(p) - s;
}

float sdCylinder(vec3 p, vec3 c) {
    return length(p.xz - c.xy) - c.z;
}

float sdPlane(vec3 p, vec3 n, float h) {
    return dot(p, n) + h;
}

float sdBox(vec3 p, vec3 b){
    vec3 q = abs(p) - b;
    return length(max(q,0.0)) + min(max(q.x, max(q.y,q.z)), 0.0);
}

float sdRoundBox(vec3 p, vec3 b, float r){
    vec3 q = abs(p) - b;
    return length(max(q,0.0)) - r + min(max(q.x, max(q.y,q.z)), 0.0);
}

float sdTorus(vec3 p, vec2 t){
    vec2 q = vec2(length(p.xz)-t.x, p.y);
    return length(q) - t.y;
}

float sdCappedCylinderY(vec3 p, float h, float r){
    vec2 d = abs(vec2(length(p.xz), p.y)) - vec2(r, h);
    return min(max(d.x,d.y), 0.0) + length(max(d,0.0));
}

struct Hit {
    float t;
    int id;
};

const float INF = 1e6;

// Ray-sphere intersection
float intersectSphere(vec3 ro, vec3 rd, vec3 center, float radius) {
    vec3 oc = ro - center;
    float b = dot(oc, rd);
    float c = dot(oc, oc) - radius * radius;
    float h = b * b - c;
    if (h < 0.0) return -1.0;
    return -b - sqrt(h); // nearest positive t
}

// Ray-plane intersection
float intersectPlane(vec3 ro, vec3 rd, vec3 n, float h) {
    float denom = dot(rd, n);
    if (abs(denom) < 1e-6) return -1.0;
    float t = -(dot(ro, n) + h) / denom;
    return (t > 0.0) ? t : -1.0;
}

// Ray-cylinder intersection
float intersectCylinder(vec3 ro, vec3 rd, vec3 center, float radius) {
    // y-axis aligned cylinder at center.xz
    vec2 oc = ro.xz - center.xy;
    vec2 rd2 = rd.xz;
    float a = dot(rd2, rd2);
    float b = dot(oc, rd2);
    float c = dot(oc, oc) - radius * radius;
    float h = b*b - a*c;
    if (h < 0.0) return -1.0;
    return (-b - sqrt(h)) / a;
}

const float turn_eps = 0.01;
const float move_eps = 0.01;

// Rotations
const mat4 YAW_LEFT = mat4(
    cos(turn_eps), 0., sin(turn_eps), 0.,
    0., 1., 0., 0.,
   -sin(turn_eps), 0., cos(turn_eps), 0.,
    0., 0., 0., 1.
);
const mat4 YAW_RIGHT = transpose(YAW_LEFT);

const mat4 PITCH_UP = mat4(
    1., 0., 0., 0.,
    0., cos(turn_eps), -sin(turn_eps), 0.,
    0., sin(turn_eps),  cos(turn_eps), 0.,
    0., 0., 0., 1.
);
const mat4 PITCH_DOWN = transpose(PITCH_UP);

const mat4 ROLL_CLOCK = mat4(
     cos(turn_eps),  sin(turn_eps), 0., 0.,
    -sin(turn_eps),  cos(turn_eps), 0., 0.,
     0.,              0.,            1., 0.,
     0.,              0.,            0., 1.
);
const mat4 ROLL_COUNTER = transpose(ROLL_CLOCK);

// Smooth minimum helper
float smin(float a, float b, float k)
{
    // k: smoothing radius (larger = smoother blend)
    float h = clamp(0.5 + 0.5*(b - a)/k, 0.0, 1.0);
    return mix(b, a, h) - k*h*(1.0 - h);
}

// Dihedral group action on R^2 utilities

// 2D rotation matrix
mat2 rot2(float a){
    float c = cos(a), s = sin(a);
    return mat2(c,-s, s, c);
}

// Reflection across x-axis: (x,y)->(x,-y)
vec2 reflectX(vec2 p){
    return vec2(p.x, -p.y);
}

// Apply r^k
vec2 Dn_apply_rot(vec2 p, int n, int k){
    float ang = (2.0*PI/float(n)) * float(k);
    return rot2(ang) * p;
}

// Apply s r^k
vec2 Dn_apply_ref(vec2 p, int n, int k){
    float ang = (2.0*PI/float(n)) * float(k);
    return reflectX(rot2(ang) * p);
}

// Unified apply: refl=0 => r^k ; refl=1 => s r^k
vec2 Dn_apply(vec2 p, int n, int k, int refl){
    return (refl==0) ? Dn_apply_rot(p,n,k) : Dn_apply_ref(p,n,k);
}

// Fold into wedge theta in [0, PI/n]
vec2 Dn_fold(vec2 p, int n, out int k, out int reflFlag)
{
    reflFlag = 0;
    if (p.y < 0.0) { p.y = -p.y; reflFlag = 1; }

    float theta = atan(p.y, p.x);
    theta = max(theta, 0.0);

    float sector = (2.0*PI)/float(n);
    k = int(floor(theta / sector));
    float thetaLocal = theta - float(k)*sector;

    float halfSector = 0.5 * sector;
    if (thetaLocal > halfSector) {
        thetaLocal = sector - thetaLocal;
        reflFlag ^= 1;
    }

    float r = length(p);
    // Outputs coarse sector k and reflection parity reflFlag
    return r * vec2(cos(thetaLocal), sin(thetaLocal));
}
