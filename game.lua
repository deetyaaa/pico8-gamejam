pico-8 cartridge // http://www.pico-8.com
version 16
__lua__

-- linear interpolation function
function lerp(v0, v1, t)
  return v0 + t * (v1 - v0)
end

function _init()
  tilesize = 8

  skin = 1
  skin_timer = 0
  skin_period = 60
  skin_offsets = { 0, 8, 32, 40 }
  -- skin_offsets = { 0, 0, 0, 0 }


  player = { x = 3, y = 13 }
  player.speed = { x = 0, y = 0 }
  player.collision = {
    size = {
      horizontal = {
        width = 10 / tilesize,
        height = 9 / tilesize
      },
      vertical = {
        width = 6 / tilesize,
        height = 13 / tilesize
      }
    }
  }
  player.anims = {
    standing = { 64 },
    jumping = { 128, 70, 128},
    gliding = { 128 },
    walking = {66, 68, 70, 68, 66, 64}
  }

  player.animt = 0
  player.anim = player.anims.standing
  player.animframes = 0
  player.frame = 1
  player.mirror = false
  player.onground = true
  player.bob_t = 0
  player.max_jumps = 1
  player.jumps_left = 0

  updatecollisionbox(player)
  screensize = {
    width = 128,
    height = 128
  }
  mapsize = {
    width = 53,
    height = 32
  }

  
  
  -- pixels of downward speed applied each frame
  grav = 1.0 / tilesize
  grav_up   = 0.8 / tilesize   -- gravity while rising
  grav_down = 0.7 / tilesize  -- gravity while falling
  maxgrav = 5 / tilesize
  
  -- horizontal movement speed
  movspeed = 1.5 / tilesize
  
  -- jump speed
  -- jumpspeed = 11 / tilesize
  jump_v = 9.5 / tilesize       -- initial upward velocity (try 10-12)

  jump_hold_max = 0.2           -- extra lift frames while holding jump (try 4-8)
  jump_cut_mult = 0.9         -- how hard we cut jump on release (0.35-0.7)

  player.jump_hold = 0
  
  -- jump buffering
  jumpbuffer = 3 -- number of frames allowed to buffer jumps
  jumpframes = jumpbuffer + 1
  wasjumppressed = false
  
  -- jump grace period
  jumpgrace = 3 -- number of frames allowed after being on the ground to still jump
  fallingframes = jumpgrace + 1
  
  -- screen bounding box beyond which the camera will snap back to the player
  camerasnap = { left = 40, top = 16, right = screensize.width - 40, bottom = screensize.height - 48 }
  cam = { x = 0, y = 0 }
end

function _update()
  player.speed.x = 0

  player.max_jumps = (skin <= 2 and 2 or 1)      -- skins 1-2: double jump
  player.jumps_left = mid(0, player.jumps_left, player.max_jumps - 1) -- clamp if skin changes mid-air

  player.bob_t += 1
  jumpframes = min(jumpbuffer + 1, jumpframes + 1)
  fallingframes = min(jumpgrace + 1, fallingframes + 1)

  if btn(0) then
    player.speed.x -= movspeed
  end
  if btn(1) then
    player.speed.x += movspeed
  end
  
  if btn(4) and not wasjumppressed then
    jumpframes = 0
  end
  
  if jumpframes <= jumpbuffer then
    -- ground / coyote jump
    if player.onground or fallingframes <= jumpgrace then
      jump(player)
      player.jumps_left = player.max_jumps - 1

    -- air jump (double jump only when max_jumps=2)
    elseif player.jumps_left > 0 then
      jump(player)
      player.jumps_left -= 1
    end
  end

  skin_timer += 1
  if skin_timer >= skin_period then
    skin_timer = 0
    skin = (skin % 4) + 1
  end

  applyphysics(player)
  animate(player)
  
  wasjumppressed = btn(4)

  -- update camera position
  local screenx, screeny = player.x * tilesize - cam.x, player.y * tilesize - cam.y
  
  if screenx < camerasnap.left then
    cam.x += screenx - camerasnap.left
  elseif screenx > camerasnap.right then
    cam.x += screenx - camerasnap.right
  else
    local center = player.x * tilesize - screensize.width / 2
    cam.x += (center - cam.x) / 6
  end
  
  if screeny < camerasnap.top then
    cam.y += screeny - camerasnap.top
  elseif screeny > camerasnap.bottom then
    cam.y += screeny - camerasnap.bottom
  elseif player.onground then
    local center = player.y * tilesize - screensize.height / 2
    cam.y += (center - cam.y) / 6
  end

  local maxcamx, maxcamy = 
    max(0, mapsize.width * tilesize - screensize.width), 
    max(0, mapsize.height * tilesize - screensize.height)
    
  cam.x = mid(0, cam.x, maxcamx)
  cam.y = mid(0, cam.y, maxcamy)
end

function animate(entity)
  if not entity.onground then
    if entity.speed.y < 0 then          -- going up -> flap
      setanim(entity,"jumping")
    else                           -- falling / apex -> no flap
      setanim(entity,"gliding")
    end
  elseif entity.speed.x ~= 0 then
    setanim(entity,"walking")
  else
    setanim(entity,"standing")
  end
  
  entity.animframes += 1
  -- entity.animt += 0.05                    -- bigger = faster flap, smaller = smoother/slower

  local rate = 12          -- standing slower
  if entity.anim == entity.anims.walking then rate = 6 end
  if entity.anim == entity.anims.jumping then rate = 1.75 end  -- faster (shows all jump frames)
  if entity.anim == entity.anims.gliding then rate = 9999 end

  -- end

  entity.frame = (flr(entity.animframes / rate) % #entity.anim) + 1
  
  if entity.speed.x < 0 then
    entity.mirror = true
  elseif entity.speed.x > 0 then
    entity.mirror = false
  end
end

function setanim(entity, name)
  if entity.anim ~= entity.anims[name] then
    entity.anim = entity.anims[name]
    entity.animframes = 0
    entity.frame = 1
  end
end

function jump(entity)
  entity.onground = false
  entity.jumping = true
  entity.jump_hold = jump_hold_max
  entity.speed.y = -jump_v
  jumpframes = jumpbuffer + 1
end

function applyphysics(entity)
  local speed = entity.speed

  -- natural jump physics using velocity + gravity
  if speed.y < 0 then
    -- rising
    if entity.jumping and btn(4) and entity.jump_hold > 0 then
      -- holding jump: lighter gravity for a higher jump
      speed.y += grav_up
      entity.jump_hold -= 1
    else
      -- released or out of hold time: cut jump once, then normal rise gravity
      if entity.jumping and not btn(4) then
        speed.y *= jump_cut_mult
      end
      entity.jumping = false
      speed.y += grav_up
    end
  else
    -- falling
    entity.jumping = false
    speed.y = min(maxgrav, speed.y + grav_down)
  end

  speed.y = min(maxgrav, speed.y)

  local wasonground = entity.onground
  entity.onground = false

  
  -- increase precision by applying physics in smaller steps
  -- the more steps, the faster things can go without going through terrain
  local steps = 1
  local highestspeed = max(abs(speed.x), abs(speed.y))
  
  if highestspeed >= 0.25 then
    steps = ceil(highestspeed / 0.25)
  end
  
  for i = 1, steps do
    entity.x += speed.x / steps
    entity.y += speed.y / steps
    
    updatecollisionbox(entity)
    
    -- slope collisions
    for tile in gettiles(entity, "floor") do
      if tile.slope then
        local tiletop = tile.y
      
        if tile.slope then
          local slope = tile.slope
          local xoffset = entity.x - tile.x
          
          if xoffset < 0 or xoffset > 1 then
            -- only do slopes if the entity's center x coordinate is inside the tile space
            -- otherwise ignore this tile
            tiletop = nil
          else
            local alpha
            if slope.reversed then
              alpha = 1 - xoffset
            else
              alpha = xoffset
            end
            
            local slopeheight = lerp(slope.offset, slope.offset + slope.height, alpha)
            tiletop = tile.y + 1 - slopeheight
            
            -- only snap the entity down to the slope's height if it wasn't jumping or on the ground
            if entity.y < tiletop and speed.y < 0 then
              tiletop = nil
            end
          end
        else
          tiletop = nil
        end
        
        if tiletop then
          speed.y = 0
          entity.y = tiletop
          entity.onground = true
          entity.jump_hold = 0
          entity.jumping = false
          fallingframes = 0
          entity.jumps_left = entity.max_jumps - 1

        end
      end
    end
    
    updatecollisionbox(entity)
    
    -- wall collisions
    for tile in gettiles(entity, "horizontal") do
      if tile.solid and not tile.slope then
        entity.jumps_left = entity.max_jumps - 1

        if entity.x < tile.x + 0.5 then
          -- push out to the left
          entity.x = tile.x - entity.collision.size.horizontal.width / 2
        else
          -- push out to the right
          entity.x = tile.x + 1 + entity.collision.size.horizontal.width / 2
        end
      end
    end
    
    updatecollisionbox(entity)
    
    -- floor collisions
    for tile in gettiles(entity, "floor") do
      if tile.solid and not tile.slope then
        speed.y = 0
        entity.y = tile.y
        entity.onground = true
        entity.jumping = false
        entity.jump_hold = 0
        fallingframes = 0
      end
    end
    
    updatecollisionbox(entity)
    
    -- ceiling collisions
    for tile in gettiles(entity, "ceiling") do
      if tile.solid and not tile.slope then
        speed.y = 0
        entity.y = tile.y + 1 + entity.collision.size.vertical.height
        entity.jumping = false
      end
    end
  end
end

-- gets all tiles that might be intersecting entity's collision box
function gettiles(entity, boxtype)
  local box = entity.collision.box[boxtype]
  local left, top, right, bottom =
    flr(box.left), flr(box.top), flr(box.right), flr(box.bottom)
    
  local x, y = left, top
    
  -- iterator function
  return function()
    if y > bottom then
      return nil
    end
    
    local sprite = mget(x, y)
    local ret = { sprite = sprite, x = x, y = y }

    local flags = fget(sprite)

    if sprite > 0 then
      local flags = fget(sprite)
      ret.solid = band(flags, 1) == 1 

      if band(flags, 128) == 128 then
        -- this is a slope if flag 7 is set
        ret.slope = {
          reversed = band(flags, 64) == 64, -- reversed if flag 6 is set,
          height = (band(flags, 7) + 1) / tilesize, -- the first 3 bits/flags set the slope height from 1-8
          offset = band(lshr(flags, 3), 7) / tilesize -- bits/flags 4 through 6 set the offset from the bottom of the tile between 0 and 7
        }
      end

    else
      ret.solid = false
    end
    x += 1
    if x > right then
      x = left
      y += 1
    end
    
    return ret
  end
end

function updatecollisionbox(entity)
  local size = entity.collision.size

  entity.collision.box = {
    horizontal = {
      left = entity.x - size.horizontal.width / 2,
      top = entity.y - size.vertical.height + (size.vertical.height - size.horizontal.height) / 2,
      right = entity.x + size.horizontal.width / 2,
      bottom = entity.y - (size.vertical.height - size.horizontal.height) / 2
    },
    floor = {
      left = entity.x - size.vertical.width / 2,
      top = entity.y - size.vertical.height / 2,
      right = entity.x + size.vertical.width / 2,
      bottom = entity.y
    },
    ceiling = {
      left = entity.x - size.vertical.width / 2,
      top = entity.y - size.vertical.height,
      right = entity.x + size.vertical.width / 2,
      bottom = entity.y - size.vertical.height / 2
    }
  }
end

function _draw()
  camera(cam.x, cam.y)

  pal()
  palt(0, false)
  palt(14, true)

  cls(1)
  map(0, 0, 0, 0)

  palt(14, false)


  palt(4, true)

  local bob = sin(player.bob_t/30) * 0.5
  local spr_id = player.anim[player.frame] + skin_offsets[skin]
  spr(spr_id, player.x * tilesize - 8, player.y * tilesize - 16 + bob, 2, 2, player.mirror)

  palt(7,false)
end