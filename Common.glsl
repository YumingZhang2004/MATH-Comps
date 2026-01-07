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

const float turn_eps = 0.03;
const float move_eps = 0.03;

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
