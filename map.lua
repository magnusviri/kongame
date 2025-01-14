--[[
-- Map class
-- The map is in charge of creaating the scenario where the game is played - it spawns a bunch of rocks, walls, floors and guardians, and a player.
-- Map:reset() restarts the map. It can be done when the player dies, or manually.
-- Map:update() updates the visible entities on a given rectangle (by default, what's visible on the screen). See main.lua to see how to update
-- all entities instead.
--]]
local class       = require 'lib.middleclass'
local bump        = require 'lib.bump'
local bump_debug  = require 'lib.bump_debug'

local media       = require 'media'

local Player      = require 'entities.player'
local Block       = require 'entities.block'
local Guardian    = require 'entities.guardian'
local Lava        = require 'entities.lava'
local Platform    = require 'entities.platform'
local Pickup      = require 'entities.pickup'
local Bug         = require 'entities.bug'

local random = math.random

local sortByUpdateOrder = function(a,b)
  return a:getUpdateOrder() < b:getUpdateOrder()
end

local sortByCreatedAt = function(a,b)
  return a.created_at < b.created_at
end

local Map = class('Map')

function Map:initialize(game, width, height, camera)
  self.game = game
  self.width  = width
  self.height = height
  self.camera = camera

  self:reset()
end

function Map:reset()
  local music = media.music
  music:seek(0)
  music:play()

  local width, height = self.width, self.height
  self.world  = bump.newWorld()
  self.player = Player:new(self, self.world, 60, 60)

  -- walls & ceiling
  Block:new(self.world,        0,         0, width,        32, true)
  Block:new(self.world,        0,        32,    32, height-64, true)
  Block:new(self.world, width-32,        32,    32, height-64, true)

  -- tiled floor
  local tilesOnFloor = 40
  for i=0,tilesOnFloor - 1 do
    Block:new(self.world, i*width/tilesOnFloor, height-32, width/tilesOnFloor, 32, true)
  end


  -- Upper-left quadrant

  for i=1, 20 do
    local prev = { x = math.random(100, width/2-100), y = math.random(100, height/2 - 100) }
    local waypoints = {prev}
    for i=2, math.random(2,6) do
      local point = {
        x = math.random(math.max(100, prev.x - 200), math.min(width/2-100, prev.x + 200)),
        y = math.random(math.max(100, prev.y - 200), math.min(height/2-100, prev.y + 200))
      }
      waypoints[i] = point
      prev = point
    end
    Platform:new(self.world, waypoints)
  end

  Pickup:new( self,
              self.world,
              random(100, width/2-200),
              random(100, height/2-150),
              media.img.K)

  -- Lower-left quadrant

  local l,t,w,h, area
  for i=1,15 do
    w = random(100, 400)
    h = random(100, 400)
    area = w * h
    l = random(100, width/2-w-200)
    t = random(height/2 + 100, height-h-100)

    for i=1, math.floor(area/7000) do
      Block:new( self.world,
                 random(l, l+w),
                 random(t, t+h),
                 random(32, 100),
                 random(32, 100),
                 random() > 0.75 )
    end
  end

  for i=1,7 do
    Guardian:new( self.world,
                  self.player,
                  self.camera,
                  random(100, width/2-200),
                  random(height/2 + 100, height-150) )
  end

  Pickup:new( self,
              self.world,
              random(100, width/5),
              random(height/2 + 300, height - 150),
              media.img.N)


  -- Upper-right
  for i=1,15 do
    w = random(100, 400)
    h = random(100, 400)
    area = w * h
    l = random(width/2+100, width-w-200)
    t = random(100, height-h-100)

    for i=1, math.floor(area/7000) do
      Block:new( self.world,
                 random(l, l+w),
                 random(t, t+h),
                 random(32, 100),
                 random(32, 100),
                 random() > 0.75 )
    end
  end

  for i=1,7 do
    Bug:new( self.world,
             self.player,
             self.camera,
             random(width/2 + 100, width-200),
             random(100, height/2-150) )
  end

  Pickup:new( self,
              self.world,
              random(width/2 + 300, width - 150),
              random(100, height/2-150),
              media.img.O)


  -- Lower-right
  for i=1,7 do
    local min_w, max_w = 100, 500
    local min_h, max_h = 100, 500
    local edge_distance = 100
    local w = min_w + random(max_w - min_w)
    local h = min_h + random(max_h - min_h)
    Lava:new( self.world,
              width/2 + edge_distance + random(width/2 - w - 2 * edge_distance),
              height/2 + edge_distance + random(height/2 - h - 2 * edge_distance),
              w,
              h,
              self.player )
  end


  Pickup:new( self,
              self.world,
              random(width/2 + 300, width - 150),
              random(height/2 + 300, height - 150),
              media.img.G)

  self.pickupCounter = 4

end


function Map:update(dt, l,t,w,h)
  l,t,w,h = l or 0, t or 0, w or self.width, h or self.height
  local visibleThings, len = self.world:queryRect(l,t,w,h)

  table.sort(visibleThings, sortByUpdateOrder)

  for i=1, len do
    visibleThings[i]:update(dt)
  end
end

function Map:draw(drawDebug, l,t,w,h)
  if drawDebug then bump_debug.draw(self.world, l,t,w,h) end

  local visibleThings, len = self.world:queryRect(l,t,w,h)

  table.sort(visibleThings, sortByCreatedAt)

  for i=1, len do
    visibleThings[i]:draw(drawDebug)
  end
end

function Map:countItems()
  return self.world:countItems()
end

function Map:victory()
  self.game:gotoState('Victory')
end

function Map:pickup()
  self.pickupCounter = self.pickupCounter - 1
  if self.pickupCounter == 0 then
    self:victory()
  end
end


return Map
