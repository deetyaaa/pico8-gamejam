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
  
  bird_top_color = 12
  bird_bottom_color = 8
  bird_top_outline = 1
  bird_bottom_outline = 2


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
    jumping = { 96, 98, 100, 98},
    gliding = { 100 },
    walking = {66, 68, 70, 68}
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
  player.air_grant = false -- prevents re-granting multiple times in same airtime
  player.has_boots = true

  platform_rows = {
    { 3,  4,  5,     6,  7,  8},
    {19, 20, 21,    22, 23, 24},
    {35, 36, 37,    38, 39, 40},
    {51, 52, 53,    54, 55, 56},
  }

  -- rain
  rain = {} 
  rain_sprite = 49
  rain_max = 120
  rain_spawn = 3
  rain_spd_min = 1.75 -- px/frame (component speed)
  rain_spd_max = 2.8 

  updatecollisionbox(player)
  screensize = {
    width = 128,
    height = 128
  }
  mapsize = {
    width = 53,
    height = 32
  }

  local sw = screensize.width / tilesize  -- 16
  local sh = screensize.height / tilesize -- 16

  local dy = 6

  rooms = {
    [1] = { mapx=21,  mapy=10, wx=0*sw, wy=0, w=16, h=16, spawnx=7, spawny=13 },
    [2] = { mapx=0,  mapy=0-dy, wx=1*sw, wy=0, w=20, h=32, spawnx=2, spawny=13 },
    [3] = { mapx=0, mapy=0-dy, wx=2*sw, wy=0, w=20, h=32, spawnx=2, spawny=13 },
    [4] = { mapx=0, mapy=0-dy, wx=3*sw, wy=0, w=20, h=32, spawnx=2, spawny=13 },
  }

  coins_by_room = {
    [1] = {
    --   -- {x=12, y=22},
    --   -- {x=13, y=10},
    },
    [2] = {
      -- {x=12, y=22},
      {x=13, y=10},
    },
    [3] = {
      {x=18, y=10},
      {x=12, y=18},
      -- {x=11, y=15},
      {x=14, y=11},
    },
    [4] = {
      {x=6, y=13},
    },
  }

  platforms_by_room = {
    -- [1] = {

    -- },
    [2] = {
      {x=8, y=25, w=3, row=2, variant=2},
      {x=10, y=21, w=3},
      {x=5, y=15, w=4},
      {x=13, y=11, w=4, row=4, variant=1},
      {x=18, y=9, w=4},
      -- {x=24, y=9, w=4},
    },
    [3] = {
      --upper
      {x=-1, y=9, w=4},
      {x=5, y=8, w=3},
      {x=13, y=6, w=3},
      {x=18, y=6, w=3},

      --cloud route
      {x=5, y=16, w=4},
      {x=8, y=24, w=3},
      {x=10, y=18, w=3, row=4, variant=1},
      {x=14, y=21, w=3, row=4, variant=1},
      {x=14, y=15, w=3, row=4, variant=1},
    },
    [4] = {
      --upper
      {x=-1, y=6, w=4},

      --lower
    }
  }

  npcs_by_room = {
    [1] = {
      {id="snaily", x=5, y=13, mirror=false, idle={102, 104}, on_interact=talk_snaily},
    },
    [2] = {
      {id="mousy", x=4, y=28,  mirror=false,idle={108}, on_interact=talk_mousy} 
    }
  }

  for i = 1, #rooms do
    rooms[i].left  = (i>1) and (i-1) or nil
    rooms[i].right = (i<#rooms) and (i+1) or nil
  end

  -- coins
  coin_sprite = 33
  coin_margin = 0.1 -- shrinks coin hitbox
  
  coin_count = 0

  -- pickup radius (in tiles).
  coin_pickup_r = 0.6
  
  -- pixels of downward speed applied each frame
  grav_up   = 0.75 / tilesize   -- gravity while jumping
  grav_down = 0.8 / tilesize  -- gravity while falling
  maxgrav = 6 / tilesize
  
  -- horizontal movement speed
  movspeed = 1.5 / tilesize
  
  -- jump speed
  jump_v = 7.5 / tilesize       -- initial upward velocity

  jump_hold_max = 3      -- extra lift frames while holding jump (between 4-8 is good)
  jump_cut_mult = 0.45         -- how hard jump stops on release (0.35-0.7)

  player.jump_hold = 0
  
  -- jump buffering
  jumpbuffer = 3 -- number of frames allowed to buffer jumps
  jumpframes = jumpbuffer + 1
  wasjumppressed = false
  
  -- jump grace period
  jumpgrace = 3 -- # of frames allowed after being on the ground to still jump (coyote)
  fallingframes = jumpgrace + 1
  
  -- screen bounding box: beyond it, camera snaps back to player
  camerasnap = { left = 40, top = 16, right = screensize.width - 40, bottom = screensize.height - 48 }
  cam = { x = 0, y = 0 }

  load_room(1)
end

function room_px() return room.wx * tilesize end
function room_py() return room.wy * tilesize end


-------------------------------------------------------------------------


function start_game()
  coin_count = 0
  skin_timer = 0
  skin = 1

  cam.x = 0
  cam.y = 0

  load_room(1)
end

function set_room(id)
  room_id = id
  room = rooms[id]
end


function load_room(id)
  set_room(id)
  player.x = room.spawnx
  player.y = room.spawny
  player.speed.x = 0
  player.speed.y = 0
  set_platforms_for_room()
end

function enter_room(id, side)

  local old_rx = room_px()
  local old_ry = room_py()
  local old_mapy = room.mapy 

  set_room(id)

  local new_rx = room_px()
  local new_ry = room_py()

  -- keep camera aligned relative to world when changing rooms
  cam.x += (new_rx - old_rx)
  cam.y += (new_ry - old_ry)

  player.speed.x = 0
  player.speed.y = 0

  if side == "right" then
    player.x = 0.5
  elseif side == "left" then
    player.x = room.w - 0.5
  
  end

  player.y = (old_mapy + player.y) - room.mapy

  player.onground = false
  player.jumping = false
  player.jump_hold = 0

  updatecollisionbox(player)
  set_platforms_for_room() 
end

-------------------------------------------------------------------------


function update_coins()
  local list = coins_by_room and coins_by_room[room_id] or {}
  local b = player.collision.box.horizontal

  for i =# list, 1, -1 do
    local c = list[i]

    local cl = c.x - coin_margin
    local ct = c.y - coin_margin
    local cr = c.x + 1 + coin_margin
    local cb = c.y + 1 + coin_margin

    -- overlap test
    if b.right > cl and b.left < cr and b.bottom > ct and b.top < cb then
      sfx(8)
      deli(list, i) --delete from list of this room's coins
      coin_count += 1
      
    end
    
  end
end

function draw_coins(rx, ry) 
  local list = coins_by_room and coins_by_room[room_id] or {}
  for c in all(list) do
    palt(0,true)
    spr(coin_sprite, rx + c.x*tilesize, ry + c.y*tilesize)
  end
  pal()
end

-------------------------------------------------------------------------


function update_rain()
  -- spawn from top + left so the diagonal flow fills the screen
  for i=1,rain_spawn do
    if #rain < rain_max then
      local spd = rain_spd_min + rnd(rain_spd_max - rain_spd_min) -- same for x and y
      local x,y

      if rnd(1) < 0.5 then
        -- from top
        x = cam.x + rnd(screensize.width)
        y = cam.y - 8
      else
        -- from left
        x = cam.x - 8
        y = cam.y + rnd(screensize.height)
      end

      add(rain, { x=x, y=y, vx=spd, vy=spd }) -- 45° down-right
    end
  end

  -- move + remove
  for i=#rain,1,-1 do
    local d = rain[i]
    d.x += d.vx
    d.y += d.vy

    if d.y > cam.y + screensize.height + 16 or d.x > cam.x + screensize.width + 16 then
      deli(rain, i)
    end
  end
end

function draw_rain()
  for d in all(rain) do
    spr(rain_sprite, d.x, d.y)
  end
end

-------------------------------------------------------------------------


-- (x, y, w) = tile coords relative to room
-- v = variant 
function draw_one_platform(x, y, w, row, variant) 
  if w <= 0 then return end
  row = row or 1
  variant = variant or 1


  local set = platform_rows[row] or platform_rows[1]
  local base = (variant==2) and 4 or 1  -- start index in the 6-pack

  local left = set[base]
  local mid = set[base+1]
  local right = set[base+2]

  local rx, ry = room_px(), room_py() -- world origin in pixels

  if w == 1 then
    -- single-tile platform: just use middle
    spr(mid, rx + x*8, ry + y*8)
    return
  end

  -- left
  spr(left, rx + x*8, ry + y*8)

  -- middle fill
  for i=1,w-2 do
    spr(mid, rx + (x+i)*8, ry + y*8)
  end

  -- right
  spr(right, rx + (x+w-1)*8, ry + y*8)
end


function set_platforms_for_room()
  local list = platforms_by_room[room_id] or {}
  for p in all(list) do
    p.flash = 0
    p._lastv = nil
  end
end

function player_touches_platform(p)
  local b = player.collision.box.horizontal

  local pl = p.x
  local pr = p.x + p.w
  local pt = p.y
  local pb = p.y + 1

  return b.right > pl and b.left < pr and b.bottom > pt and b.top < pb
end

function player_on_platform(p)
  -- p.x/p.y/p.w are in tile coords relative to room
  return player.onground
    and abs(player.y - p.y) < 0.02
    and player.x >= p.x
    and player.x < p.x + p.w
end

function platform_solid_from_top(p, entity, prevy)
  -- only collide if falling and coming from above
  return entity.speed.y >= 0 and prevy <= p.y
end

function platform_solid_from_bottom(p, entity, prevy)
  -- collide if moving up & coming from below
  return entity.speed.y < 0 and prevy >= p.y + 1
end

function draw_platforms()
  local list = platforms_by_room[room_id] or {}
  for p in all(list) do
    local v = p.variant or 1
    if (p.row or 1) == 4 then
       v = (p.flash and p.flash > 0) and 2 or 1
    end
    draw_one_platform(p.x, p.y, p.w, p.row, v)
  end
end

function is_cloud_sprite(s)
  local set = platform_rows[4]
  if not set then return false end
  for i=1,#set do
    if s == set[i] then return true end
  end
  return false
end

function repaint_clouds()
  local list = platforms_by_room[room_id] or {}

  for p in all(list) do
    if (p.row or 1) == 4 then
      -- countdown
      if p.flash and p.flash > 0 then
        p.flash -= 1
      else
        p.flash = 0
      end

      if player_touches_platform(p) or player_on_platform(p) then
        p.flash = 30
      end
    end
  end
end

-------------------------------------------------------------------------


function game_update()

  if dialogue.active then
    update_dialogue()
    return
  end

  -- press ❎ to interact with nearest NPC
  if btnp(5) then
    local npcs = npcs_by_room[room_id] or {}
    for n in all(npcs) do
      if n.on_interact and can_interact(n) then
        n.on_interact(n)
        break
      end
    end
  end

  player.speed.x = 0

  local old_max = player.max_jumps
  player.max_jumps = (skin <= 2 and 2 or 1)      -- skins 1-2: double jump

  if player.onground then
    -- landing resets everything
    player.air_grant = false
    player.jumps_left = player.max_jumps - 1
  else
    -- if we SWITCH to double-jump while airborne, grant 1 jump (once per airtime)
    if player.max_jumps > old_max and not player.air_grant then
      player.jumps_left = max(player.jumps_left, player.max_jumps - 1) -- becomes 1
      player.air_grant = true
    end

    -- if we SWITCH back to single-jump while airborne, clamp to 0
    if player.max_jumps == 1 then
      player.jumps_left = 0
    end
  end


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
  repaint_clouds()
  update_coins()
  animate(player)
  update_npcs()

  if player.x > room.w and room.right then
    enter_room(room.right, "right")
  end

  if player.x < 0 and room.left then
    enter_room(room.left, "left")
  end
  
  wasjumppressed = btn(4)

  -- update camera position
  -- local screenx, screeny = player.x * tilesize - cam.x, player.y * tilesize - cam.y
  local px = room_px() + player.x * tilesize
  local py = room_py() + player.y * tilesize
  local screenx, screeny = px - cam.x, py - cam.y


  if screenx < camerasnap.left then
    cam.x += screenx - camerasnap.left
  elseif screenx > camerasnap.right then
    cam.x += screenx - camerasnap.right
  else
    local center = px - screensize.width / 2
    cam.x += (center - cam.x) / 6
  end
  
  if screeny < camerasnap.top then
    cam.y += screeny - camerasnap.top
  elseif screeny > camerasnap.bottom then
    cam.y += screeny - camerasnap.bottom
  elseif player.onground then
    local center = py - screensize.height / 2
    cam.y += (center - cam.y) / 6
  end


  local mincamx = room_px()
  local mincamy = room_py()
  local maxcamx = room_px() + max(0, room.w * tilesize - screensize.width)
  local maxcamy = room_py() + max(0, room.h * tilesize - screensize.height)

  cam.x = mid(mincamx, cam.x, maxcamx)
  cam.y = mid(mincamy, cam.y, maxcamy)

  update_rain()
end

function animate(entity)
  if not entity.onground then
    if entity.speed.y < 0 then          -- going up -> flap
      setanim(entity,"jumping")
    else                           -- falling / apex -> no flap
      setanim(entity,"jumping")
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
  if entity.anim == entity.anims.jumping then rate = 2 end  -- faster (shows all jump frames)
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
        entity.jump_hold = 0
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
  entity.just_landed = false

  
  -- increase precision by applying physics in smaller steps
  -- the more steps, the faster things can go without going through terrain
  local steps = 1
  local highestspeed = max(abs(speed.x), abs(speed.y))
  
  if highestspeed >= 0.25 then
    steps = ceil(highestspeed / 0.25)
  end
  
  for i=1,steps do
    local prevy = entity.y
    local prevx = entity.x
    
    entity.x += speed.x / steps
    entity.y += speed.y / steps

    updatecollisionbox(entity)

    -- slope collisions (only slopes)
    for tile in gettiles(entity, "floor") do
      if tile.slope then
        local tiletop = tile.y
        local slope = tile.slope
        local xoffset = entity.x - tile.x

        if xoffset < 0 or xoffset > 1 then
          tiletop = nil
        else
          local alpha = slope.reversed and (1 - xoffset) or xoffset
          local slopeheight = lerp(slope.offset, slope.offset + slope.height, alpha)
          tiletop = tile.y + 1 - slopeheight

          -- don't snap upward through slope while jumping
          if entity.y < tiletop and speed.y < 0 then
            tiletop = nil
          end
        end

        if tiletop then
          speed.y = 0
          entity.y = tiletop
          entity.onground = true
          if not wasonground then entity.just_landed = true end
          entity.air_grant = false
          entity.jumps_left = entity.max_jumps - 1
          entity.jump_hold = 0
          entity.jumping = false
          fallingframes = 0
        end
      end
    end

    updatecollisionbox(entity)

    -- wall collisions (ignore clouds)
    for tile in gettiles(entity, "horizontal") do
      if tile.solid and not tile.slope and not tile.cloud then
        entity.jumps_left = entity.max_jumps - 1
        if entity.x < tile.x + 0.5 then
          entity.x = tile.x - entity.collision.size.horizontal.width / 2
        else
          entity.x = tile.x + 1 + entity.collision.size.horizontal.width / 2
        end
      end
    end

    updatecollisionbox(entity)

    -- floor collisions (clouds are one-way + require boots)
    for tile in gettiles(entity, "floor") do
      local solid_here = tile.solid and not tile.slope

      if tile.cloud then
        solid_here = entity.has_boots and speed.y >= 0 and prevy <= tile.y
      end

      if solid_here then
        speed.y = 0
        entity.y = tile.y
        entity.onground = true
        if not wasonground then entity.just_landed = true end
        entity.air_grant = false
        entity.jumps_left = entity.max_jumps - 1
        entity.jumping = false
        entity.jump_hold = 0
        fallingframes = 0
      end
    end

    local list = platforms_by_room[room_id] or {}
    for p in all(list) do
      local row = p.row or 1
      local is_cloud = (row == 4)

      local solid_here = true

      if not is_cloud then
        local b = entity.collision.box.horizontal
        local pl, pr = p.x, p.x + p.w
        local pt, pb = p.y, p.y + 1

        if b.right > pl and b.left < pr and b.bottom > pt and b.top < pb then
          -- resolve based on which side we came from
          local halfw = entity.collision.size.horizontal.width / 2

          if prevx + halfw <= pl then
            entity.x = pl - halfw
          elseif prevx - halfw >= pr then
            entity.x = pr + halfw
          else
            -- fallback: use current motion direction if we spawned inside
            if speed.x > 0 then
              entity.x = pl - halfw
            elseif speed.x < 0 then
              entity.x = pr + halfw
            end
          end

          speed.x = 0
          updatecollisionbox(entity)
        end

        if platform_solid_from_bottom(p, entity, prevy) then
          local b = entity.collision.box.ceiling
          local pl, pr = p.x, p.x + p.w
          local pt = p.y + 1  -- underside of platform

          -- if your head overlaps the underside band
          if b.right > pl and b.left < pr and b.top <= pt and b.bottom > pt - 0.2 then
            entity.speed.y = 0
            -- push player down so head is just below platform
            entity.y = pt + entity.collision.size.vertical.height
            entity.jumping = false
            entity.jump_hold = 0
          end
        end
      end

      --if boots=true, solid!
      if is_cloud then
        solid_here = entity.has_boots
      end

      if solid_here and platform_solid_from_top(p, entity, prevy) then
        -- overlap with entity floor box
        local b = entity.collision.box.floor
        local pl, pr = p.x, p.x + p.w
        local py = p.y

        if b.right > pl and b.left < pr and b.bottom >= py and b.top < py + 0.2 then
          entity.speed.y = 0
          entity.y = py
          entity.onground = true
          if not wasonground then entity.just_landed = true end
          fallingframes = 0
        end
      end
    end

    updatecollisionbox(entity)

    -- ceiling collisions (ignore clouds)
    for tile in gettiles(entity, "ceiling") do
      if tile.solid and not tile.slope and not tile.cloud then
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
    
    local sprite = mget(room.mapx + x, room.mapy + y)
    local ret = { sprite = sprite, x = x, y = y }

    local flags = fget(sprite)

    if sprite > 0 then
      local flags = fget(sprite)
      ret.solid = band(flags, 1) == 1 
      ret.cloud = is_cloud_sprite(sprite)

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
      ret.cloud = false
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

-------------------------------------------------------------------------

-- defines a radius where player can interact w npc
interact_r = 2.5
function can_interact(n) 
  local dx = (player.x - n.x)
  local dy = (player.y - n.y)
  return (dx*dx + dy*dy) <= interact_r*interact_r
end

-- function on_dialogue_choice(i)
--   if i==1 then
--     start_dialogue("snaily", "i'm snaily. i vibe here.", nil)
--   elseif i==2 then
--     start_dialogue("snaily", "double-jump when your skin is blue!", nil)
--   end
-- end

-- function talk_snaily(n)
--   -- example: just show a message / start dialogue
--   dialogue.node = {
--     -- speaker="snaily",
--     text="yo! are you okay? why you keep turnin' red?? looks like you got asthma mate", "look, i have some stuff that could help you out in the storm--but for a price."
--     opts={
--       {label="whatcha got?", next=function()
--         start_dialogue("")
--       end},
--       {label="any tips?", next=function()
--         start_dialogue("watch your skin color. blue gives extra jump.")
--       end},
--       {label="bye", next=function()
--         dialogue.active=false
--       end}
--     }
--   }
--   start_dialogue_node(dialogue.node)
-- end

function talk_snaily(n)
  local function end_dialogue()
    dialogue.active = false
  end

  local function snaily_sell_menu()
    start_dialogue_node({
      text="look, i have some stuff that could help you out in this weather--but for a price.",
      opts={
        {
          label="puddle boots",
          next=function()
            start_dialogue_node({
              text="actually... i lied. i lost the hat out in the storm.. wanted to test it out but it flew right off my head. if you find it, i could reinforce it for ya",
              opts={
                {label="ok", next=end_dialogue}
              }
            })
          end
        },
        {
          label="propeller hat",
          next=function()
            start_dialogue_node({
              text="that'll be 20 coins, buddy",
              opts={
                {
                  label="buy                              (i have "..coin_count.." coins)",
                  next=function()
                    if coin_count >= 20 then
                      coin_count -= 20
                      player.has_hat = true
                      start_dialogue_node({
                        text="pleasure doin' business with ya",
                        opts={{label="bye", next=end_dialogue}}
                      })
                    else
                      start_dialogue_node({
                        text="come back when you've got enough coins.",
                        opts={{label="ok", next=end_dialogue}}
                      })
                    end
                  end
                },
                {label="nah", next=end_dialogue}
              }
            })
          end
        },
        {
          label="nah",
          next=function()
            start_dialogue_node({
              text="pleasure doin' business with ya",
              opts={{label="bye", next=end_dialogue}}
            })
          end
        }
      }
    })
  end

  start_dialogue_node({
    text="yo, are you okay? why you keep turnin' red?? looks like you got asthma mate",
    opts={
      {
        label="not the time for jokes. my best friend went missing, and i can't leave her out there in the storm",
        next=snaily_sell_menu
      },
      {
        label="idk this wind is making it hard to breathe",
        next=snaily_sell_menu
      }
    }
  })
end

function talk_mousy(n)
  dialogue.node = {
    text="hey birby! sure is rainy out.. i have some stuff that could help with that?",
    opts={
      {label="whatcha got?", next=function()
        start_dialogue("")
      end},
      {label="any tips?", next=function()
        start_dialogue("watch your skin color. blue gives extra jump.")
      end},
      {label="bye", next=function()
        dialogue.active=false
      end}
    }
  }
  start_dialogue_node(dialogue.node)
end

dialogue = {
  active=false,
  text="",
  opts=nil,  
  sel=1
}

function start_dialogue_node(node)
  dialogue.node = node
  dialogue.active = true
  dialogue.text = node.text or ""
  dialogue.opts = {}
  dialogue.sel = 1

  if node.opts then
    for opt in all(node.opts) do
      add(dialogue.opts, opt.label)
    end
  end
end

function start_dialogue(text, opts)
  dialogue.active=true
  dialogue.text=text or ""
  dialogue.opts=opts
  dialogue.sel=1
end

function wrap_text(msg, max_px, px_per_char)
  px_per_char = px_per_char or 4
  local max_chars = max(1, flr(max_px / px_per_char))
  local lines = {}
  local line = ""

  for w in all(split(msg, " ")) do
    local test = (line=="" and w) or (line.." "..w)
    if #test > max_chars then
      if line ~= "" then add(lines, line) end
      line = w
    else
      line = test
    end
  end

  if line ~= "" then add(lines, line) end
  return lines
end

function update_dialogue()
  if not dialogue.active then return end

  if dialogue.opts then
    if btnp(2) then dialogue.sel = max(1, dialogue.sel-1) end
    if btnp(3) then dialogue.sel = min(#dialogue.opts, dialogue.sel+1) end

    if btnp(5) then
      on_dialogue_choice(dialogue.sel)
    end
  else
    if btnp(5)then
      dialogue.active=false
    end
  end
end

function on_dialogue_choice(i)
  local opt = dialogue.node.opts[i]
  if opt and opt.next then opt.next() end
end


function draw_dialogue()
  if not dialogue.active then return end

  local pad=6
  local x=pad
  local y=pad
  local w=128-pad*2


  -- estimate width needed by longest option
  local longest = 0
  if dialogue.opts then
    for i=1,#dialogue.opts do
      longest = max(longest, #dialogue.opts[i])
    end
  end

  local opt_w = mid(60, longest * 4 + 12, 96)
  local ox = 128 - 6 - opt_w

  local gap = (dialogue.opts and 6 or 0)
  local text_w = w

  -- npc dialogue has softer wrap
  local lines = wrap_text(dialogue.text, text_w - 8, 4)

  local text_h = #lines * 6
  local box_h = max(16, text_h + 10)
  local box_y2 = y + box_h

  rectfill(x, y, x+w, box_y2, 9)
  rect(x, y, x+w, box_y2, 7)

  local ty = y + 5
  for l in all(lines) do
    print(l, x+4, ty, 7)
    ty += 6
  end

  if dialogue.opts then
    local ox = x + w - opt_w
    local oy = box_y2 + 4

    local wrapped_opts = {}
    local total_h = 0
    local opt_pad = 4 
    local line_h = 6

    for i=1,#dialogue.opts do
      local prefix = (i==dialogue.sel) and "▶ " or "  "
      local o_lines = wrap_text(prefix..dialogue.opts[i], opt_w - 8, 4)
      wrapped_opts[i] = o_lines
      total_h += #o_lines * line_h + opt_pad
    end

    rectfill(ox, oy, ox + opt_w, oy + total_h + opt_pad*2, 1)
    rect(ox, oy, ox + opt_w, oy + total_h + opt_pad*2, 7)

    local cy = oy + opt_pad
    for i = 1, #wrapped_opts do
      for l in all(wrapped_opts[i]) do
        print(l, ox + 3, cy, 7)
        cy += line_h
      end
      if i < #wrapped_opts then
        cy += opt_pad
      end
    end
  end
end
---------------------------------------------------

function update_npcs()
 local npcs = npcs_by_room[room_id] or {}
  for n in all(npcs) do
    if player.x < n.x then
      n.mirror = true
    elseif player.x > n.x then
      n.mirror = false
    end
    
    if n.idle then
      n.animframes = (n.animframes or 0) + 1
      local rate = n.idle_rate or 12
      n.frame = (flr(n.animframes / rate) % #n.idle) + 1
    end
  end
end

function draw_npcs(list)
  local npcs = npcs_by_room[room_id] or {}
  local rx, ry = room_px(), room_py()

  for n in all(npcs) do
    if (not list) or list[n.id] then
      -- apply_skin_by_id(n.skin or 1)
      pal() 
      palt()
      palt(13,true)
      palt(0, false)

      local spr_id = (n.idle and n.idle[n.frame or 1]) or n.spr
      spr(spr_id, 
          rx + n.x*8 - 8, 
          ry + n.y*8 - 16, 
          2, 2, n.mirror
      )

      pal()
      palt()
    end
  end
end

function apply_skin_by_id(s)
  pal() -- reset first

  if s==1 then
    -- dj1: BLUE-BLUE
    pal(bird_bottom_color,12)
    pal(bird_bottom_outline, 1)

  elseif s==2 then
    -- dj2: BLUE-RED
    
  elseif s==3 then
    -- sj1: RED-RED
    pal(bird_top_color,    8)
    pal(bird_top_outline,  2)

  else
    -- sj2: RED-BLUE (skin==4)
    pal(bird_top_color,    8)
    pal(bird_bottom_color, 12)
    pal(bird_top_outline,  2)
    pal(bird_bottom_outline, 1)
  end
end

function game_draw()
  camera(cam.x, cam.y)

  palt()
  palt(0, true)
  palt(13, false)

  cls(1)
  map(room.mapx, room.mapy, room_px(), room_py(), room.w, room.h)
  
  palt(13, true)
  draw_rain()
  draw_coins(room_px(), room_py())
  draw_platforms()
  draw_npcs()

  local bob = 0
  if player.anim == player.anims.standing then
    bob = sin(player.bob_t/30) * 0.0002
  end

  local spr_id = player.anim[player.frame]

  apply_skin_by_id(skin)
  palt(13, true)

  spr(spr_id,
    room_px() + player.x * tilesize - 8,
    room_py() + player.y * tilesize - 15 - bob,
    2, 2, player.mirror
  )

  pal()

  camera()

  if not dialogue.active then
    local npcs = npcs_by_room[room_id] or {}
    for n in all(npcs) do
      if n.on_interact and can_interact(n) then
        
        print("❎ talk", 52, 84, 7)
        break
      end
    end
  end

  draw_dialogue()
  print( coin_count, 13, 5, 7)
  spr(34, 3, 3)
  palt(0, false)
end

-------------------------------------------------------------------------

scene="title" -- or "title"

function _update()
  if scene=="title" then title_update()
  else game_update() end
end

function _draw()
  if scene=="title" then title_draw()
  else game_draw() end
end

function title_update()
  if btnp(5) then
    start_game()
    scene="game"
  end
end

function title_draw()
  cls(1)
  print("birby", 34, 40, 7)
  print("press ❎ to start", 32, 70, 6)
end