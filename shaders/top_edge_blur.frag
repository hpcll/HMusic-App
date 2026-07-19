#version 460 core

#include <flutter/runtime_effect.glsl>

// 顶部滚动消融的真·渐进模糊（配 dart:ui ImageFilter.shader，Impeller 专属）：
// 模糊半径随视觉高度逐像素连续衰减到 0——结构上不存在分带与裁剪缝，
// 这是 backdrop 分条近似做不到的（每条带都会在裁剪边自造一条线）。
//
// 引擎契约（见 ImageFilter.shader 文档）：首个 uniform 必须是 vec2，
// 引擎写入输入纹理的物理像素尺寸；首个 sampler2D 由引擎绑定为 backdrop。
uniform vec2 u_size;        // 引擎注入：输入纹理尺寸（物理像素）
uniform float u_zone_px;    // 模糊衰减区高度（物理像素），其下半径恒为 0
uniform float u_max_radius; // 顶缘最大采样半径（物理像素）

uniform sampler2D u_texture;

out vec4 frag_color;

const float GOLDEN_ANGLE = 2.39996323;
const int TAPS = 12;

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 center = frag / u_size;
  float vis_y = frag.y;
  // GLES 后端 y 轴反向（官方契约明示）：采样坐标与视觉距顶距离一起翻转。
#ifdef IMPELLER_TARGET_OPENGLES
  center.y = 1.0 - center.y;
  vis_y = u_size.y - vis_y;
#endif
  // 衰减位置用绝对物理像素（vis_y = 距屏顶距离，消融区恰好贴屏顶），
  // 不依赖引擎绑定的纹理尺寸口径——backdrop 纹理可能远大于裁剪区，
  // 用纹理高度归一化会让整条区域吃满血模糊（曾经的真实事故）。
  // 立方 ease-in：顶部重涂抹、尾部快速趋零，静止首屏内容（约 top+24）
  // 处半径低于 1 物理像素截断线，完全不糊；底缘平滑归零天然无缝。
  float t = clamp(1.0 - vis_y / u_zone_px, 0.0, 1.0);
  float radius = u_max_radius * t * t * t;
  vec4 color = texture(u_texture, center);
  if (radius < 1.0) {
    frag_color = color;
    return;
  }
  // 黄金角螺旋盘采样 + 逐像素随机相位：稀疏采样的残余环带被打散成
  // 细颗粒噪声，观感即磨砂质感（圆盘对 y 对称，无需再管轴向）。
  float phase =
      fract(sin(dot(frag, vec2(12.9898, 78.233))) * 43758.5453) * 6.2831853;
  for (int i = 0; i < TAPS; i++) {
    float ang = phase + GOLDEN_ANGLE * float(i);
    float rad = radius * sqrt((float(i) + 0.5) / float(TAPS));
    vec2 uv = center + vec2(cos(ang), sin(ang)) * rad / u_size;
    color += texture(u_texture, clamp(uv, vec2(0.0), vec2(1.0)));
  }
  frag_color = color / float(TAPS + 1);
}
