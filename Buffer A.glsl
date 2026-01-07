// Keyboard setup
#define KEYCODE_UP    38
#define KEYCODE_LEFT  37
#define KEYCODE_DOWN  40
#define KEYCODE_RIGHT 39
#define KEYCODE_W     87
#define KEYCODE_A     65
#define KEYCODE_S     83
#define KEYCODE_D     68
#define KEYCODE_Q     81
#define KEYCODE_E     69
#define KEYCODE_SPACE 32


float keyDown(int keyCode) {
    return textureLod(iChannel0, vec2((float(keyCode)+0.5)/256., .5/3.), 0.0)[0];
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    ivec2 coord = ivec2(fragCoord);

    // Initialize on first frame
    if (iFrame == 0) {
        if (coord.x == 0) fragColor = vec4(1.,0.,0.,0.);
        else if (coord.x == 1) fragColor = vec4(0.,1.,0.,0.);
        else if (coord.x == 2) fragColor = vec4(0.,0.,1.,0.);
        else fragColor = vec4(0.,0.,0.,1.);
        return;
    }

    if (coord.x < 4 && coord.y < 1) {
        // Retrieve previous camera pose
        mat4 camera_pose;
        camera_pose[0] = texelFetch(iChannel1, ivec2(0,0), 0);
        camera_pose[1] = texelFetch(iChannel1, ivec2(1,0), 0);
        camera_pose[2] = texelFetch(iChannel1, ivec2(2,0), 0);
        camera_pose[3] = texelFetch(iChannel1, ivec2(3,0), 0);

        // Rotation
        if (keyDown(KEYCODE_LEFT)  > 0.) camera_pose *= YAW_LEFT;
        if (keyDown(KEYCODE_RIGHT) > 0.) camera_pose *= YAW_RIGHT;
        if (keyDown(KEYCODE_UP)    > 0.) camera_pose *= PITCH_UP;
        if (keyDown(KEYCODE_DOWN)  > 0.) camera_pose *= PITCH_DOWN;
        if (keyDown(KEYCODE_Q)     > 0.) camera_pose *= ROLL_COUNTER;
        if (keyDown(KEYCODE_E)     > 0.) camera_pose *= ROLL_CLOCK;

        // Translation updates
        vec3 translation = vec3(0.0);

        if (keyDown(KEYCODE_W) > 0.) translation.z += move_eps;
        if (keyDown(KEYCODE_S) > 0.) translation.z -= move_eps;
        if (keyDown(KEYCODE_A) > 0.) translation.x -= move_eps;
        if (keyDown(KEYCODE_D) > 0.) translation.x += move_eps;

        mat3 R = mat3(camera_pose);
        vec3 localMove = R * translation;

        camera_pose[3].xyz += localMove;
        
        // Height constraint
        float minHeight = -0.8;
        if (camera_pose[3].y < minHeight) {
            camera_pose[3].y = minHeight;
        }

        // Output updated camera pose
        if (coord.x == 0) fragColor = camera_pose[0];
        else if (coord.x == 1) fragColor = camera_pose[1];
        else if (coord.x == 2) fragColor = camera_pose[2];
        else if (coord.x == 3) fragColor = camera_pose[3];
    }
}
