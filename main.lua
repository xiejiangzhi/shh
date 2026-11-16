local shh = require 'shh'

skybox = lovr.graphics.newTexture('assets/industrial_workshop_foundry_2k.hdr', {
  usage = { 'storage', 'sample' }
})
shh_tex = lovr.graphics.newTextureView(skybox, {
  mipmap = 1
})

local DefaultColors = {}
for i = 1, 27 do DefaultColors[i] = 0 end

colors = shh.new(skybox)

print('Coefficients:')
for i, color in ipairs(colors) do
  print(i, ('% 6f % 6f % 6f'):format(unpack(color)))
end

colors:set(DefaultColors)

local tempPass = lovr.graphics.newPass()
local tempBuffer = lovr.graphics.newBuffer({ 'vec3', layout = 'std140' }, 9)
local readback

local function compute_shh(tex)
  shh.compute(tempPass, tex, tempBuffer)
end

local shhShaderPass = lovr.graphics.newShader(
  lovr.filesystem.read('shh_pass1.glsl'), { flags = { FORMAT = 2 } }
)
local shhShaderPass2 = lovr.graphics.newShader(lovr.filesystem.read('shh_pass2.glsl'))

local tex_w = shh_tex:getWidth()
local tex_h = shh_tex:getHeight()
local shh_x, shh_y = math.ceil(tex_w / 16 / 4), math.ceil(tex_h / 16 / 4)
print('shh tex size', tex_w, tex_h)
print('workgroups', shh_x, shh_y)

local PI = math.pi
local totalAngle = 2.0 * PI * PI / tex_h * (1.0 / math.tan(PI / (2.0 * tex_h)))
local tempBuffer2 = lovr.graphics.newBuffer({ 'vec3', layout = 'std140' }, shh_x * shh_y * 9)

local function compute_shh2(tex, n)
  tempBuffer:clear()

  tempPass:push('state')

  tempPass:setShader(shhShaderPass)
  tempPass:send('Texture' .. tex:getFormat():upper(), tex)
  tempPass:send('ResultBlock', tempBuffer2)
  tempPass:send('Scale', 4. * PI / totalAngle)
  tempPass:send('Basis', tempBuffer)
  tempPass:compute(shh_x, shh_y)

  -- tempPass:barrier()
  -- tempPass:setShader(shhShaderPass2)
  -- tempPass:send('ResultBlock', tempBuffer2)
  -- tempPass:send('Basis', tempBuffer)
  -- tempPass:send('Scale', 4. * PI / totalAngle)
  -- tempPass:compute(1)

  tempPass:pop('state')
end

local mode = 2

lovr.graphics.setTimingEnabled(true)

function lovr.draw(pass)
  if readback and readback:isComplete() then
    local r = readback:getData()
    colors:set(r)
    readback = nil
  end

  local stats = tempPass:getStats()
  local tpass
  if not readback then
    tempPass:reset()
    tpass = tempPass

    if mode == 1 then
      compute_shh(shh_tex)
    else
      compute_shh2(shh_tex)
    end
  end

  pass:skybox(skybox)
  shh.setShader(pass, colors)
  pass:sphere(0, 1.7, -2)
  local fps = lovr.timer.getFPS()
  pass:setShader()
  pass:text(
    "mode: "..mode..", FPS: "..fps..', stats: '
      ..string.format("cpu:%.6f, gpu: %.6f", stats.submitTime, stats.gpuTime),
    { 0, 4, -4 }
  )

  lovr.graphics.submit(tpass, pass)

  if not readback then
    readback = tempBuffer:newReadback()
  end

  return true
end

function lovr.keypressed(key)
  if key == 'space' then
    if mode == 1 then
      mode = 2
    else
      mode = 1
    end
    colors:set(DefaultColors)
    tempBuffer:setData(DefaultColors)
  end
end