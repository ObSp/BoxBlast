require "lib.roundrect"

local shapes = require "shapes"
local numShapes = #shapes

local lume = require "lib.lume"

local boxSize = 45
local numBoxes = 8

local highScore = 0

math.randomseed(os.time())

local streak = 0
local movesSinceStreak = 0

local boxScale = boxSize/32

local score = 0
local displayScore = score
local finalScore = score

local topDiff = 50

local boxes = {}
local tempBoxes 

local shapeQueue = {}
local shapeQueueButtons
local queueBoxSize = 15
local queueBoxScale = queueBoxSize/32

local curI = 0

local mx, my = 0,0

local mouseDown = false

local btnY = 660

local endangeredBoxes = {}

local draggingShape
local draggingTL
local draggingCol
local draggingColliding = false
local draggingB

local cols = {
  red = love.graphics.newImage("assets/blockRed.png"),
  green = love.graphics.newImage("assets/blockGreen.png"),
  blue = love.graphics.newImage("assets/blockBlue.png"),
  yellow = love.graphics.newImage("assets/blockYellow.png")
}

local cList = {
  "red",
  "green",
  "blue",
  "yellow"
}

local function randShape()
  local randI = math.random(1, numShapes)

  return shapes[randI]
end

local function randCol()
  return cList[math.random(1, #cList)]
end

local function box(x, y, c)
  return {
    x = x,
    y = y,
    c = c
  }
end

local function queueShape(shape)
  shape = {
    name = shape.name,
    verts = shape.verts
  }
  shape.c = cList[math.random(1, #cList)]
  table.insert(shapeQueue, shape)
end

local function refillQueue()
  for i = 1, 3 do 
    local s = randShape()
    queueShape(s)
    shapeQueueButtons[i].curShape = s
    shapeQueueButtons[i].c = randCol()
  end
end

local function getStreakMultiplier()
  return streak + 1
end

local function isEndangered(x, y)
  for _, t in pairs(endangeredBoxes) do
    if t[1] == x and t[2] == y then return true end
  end
  return false
end

local function addScore(amount)
  score = score + amount
  if score > highScore then
    highScore = score
  end
end

local function unpackCol(c)
  return c[1], c[2], c[3]
end

local function toCol(r, g, b, a)
  if r and not g then
    return r/255, r/255, r/255
  end
  return r/255, g/255, b/255, (a and a/255 or nil)
end

local function selectEndangeredBoxes()
  for x, t in pairs(tempBoxes) do
    --vertical(column) check
    for i=1, numBoxes do
      if not t[i] then break end

      if i == numBoxes then
        for j=1, numBoxes do
          table.insert(endangeredBoxes, {x, j})
        end
      end
    end
  end

  -- horizontal(row) check
  for y=1, numBoxes do
    local success = false
    for x, t in pairs(tempBoxes) do
      if not t[y] then break end
      if x == numBoxes then
        success = true
      end
    end

    if success then
      for x, t in pairs(boxes) do
        table.insert(endangeredBoxes, {x, y})
      end
    end
  end
end

local function doDestroyCheck()
  local destrX = {}
  local destr = 0
  local scoreToAdd = 0
  for x, t in pairs(boxes) do
    --vertical(column) check
    for i=1, numBoxes do
      if not t[i] then break end

      if i == numBoxes then
        table.insert(destrX, x)
      end
    end
  end

  -- horizontal(row) check
  for y=1, numBoxes do
    local success = false

    for x = 1, numBoxes do
      if not boxes[x][y] then break end
      if x == numBoxes then
        print("row ", y, "is full!")
        destr = destr + 1
        success = true
      end
    end

    if success then
      for x, t in pairs(boxes) do
        scoreToAdd = scoreToAdd + numBoxes * 2
        boxes[x][y] = nil
      end
    end
  end
  
  for _, x in pairs(destrX) do
    boxes[x] = {}
    scoreToAdd = scoreToAdd + numBoxes * 2
    destr = destr + 1
  end

  if destr > 0 then
    destrSound:stop()
    destrSound:setPitch(math.min(streak, 5)/20 + 1)
    destrSound:play()
  end
  
  return scoreToAdd, destr
end

local function placeShape(shape, x, y, c)
  for _, vert in pairs(shape.verts) do
    local posX = x+vert[1]
    local posY = y+vert[2]

    if boxes[posX] then
      boxes[posX][posY] = box(posX, posY, c)
    end
  end
  local scrAdd, destr = doDestroyCheck()
  if destr == 0 then
    movesSinceStreak = movesSinceStreak + 1
    if movesSinceStreak > 3 then
      streak = 0
    end
  else
    streak = streak + destr
    movesSinceStreak = 0
  end

  addScore(scrAdd*getStreakMultiplier())
  if score > highScore then
    highScore = score
  end
  placeSound:play()
end

local function isPointInRect(px, py, bx, by, bw, bh)
  return bx <= px and px <= bx + bw and by <= py and py <= by + bh
end

local function tblClone(t)
  local c = {}
  for i, v in pairs(t) do
    if type(v) == "table" then v = tblClone(v) end
    c[i] = v
  end
  return c
end

local function getGridPosFromPoint(px, py)
  for x, t in pairs(boxes) do
    for y = 1, numBoxes do
      local rx = bgX + ((x-1)*boxSize)
      local ry = bgY + ((y-1)*boxSize)

      if isPointInRect(px, py, rx, ry, boxSize, boxSize) then
        return x, y
      end
    end
  end
end

local function getDraggingShapeVertPos(vert)
  local rx = mx + (vert[1] * boxSize) - (draggingShape.size[1]/2 * boxSize)
  local ry = my + (vert[2] * boxSize) - (draggingShape.size[2]*boxSize + (h-my)/2)

  return rx, ry
end

local function getGridPosWithOffset(x, y)
  return getGridPosFromPoint(x, y)
end

local function lerp(a,b,t)
  return a * (1-t) + b * t
end

local function isInGame()
  return not didLose and not inMenu
end

local function updateMusicVolume()
  music:setVolume(musicOn and .5 or 0)
  destrSound:setVolume(musicOn and 1 or 0)
  placeSound:setVolume(musicOn and 1 or 0)
  clickSound:setVolume(musicOn and .3 or 0)
end

function love.load()
  if love.system.getOS() == 'iOS' or love.system.getOS() == 'Android' then
    love.window.setMode(love.graphics.getHeight(), love.graphics.getWidth())
    else
      love.window.setMode(411, 890, {resizable=true})
      --love.window.maximize()
  end
  h, w = love.graphics.getDimensions()

  love.window.setTitle("Box Blast!")
  
  scoreFont = love.graphics.newFont("assets/font.ttf", 50)
  hsFont = love.graphics.newFont("assets/font.ttf", 25)

  background = love.graphics.newImage("assets/background.png")
  backhgroundSize = background:getHeight()

  tilesBackground = love.graphics.newImage("assets/tilesBackground.png")

  boxBackground = love.graphics.newImage("assets/boxBg.png")
  boxBackgroundSize = boxBackground:getHeight()

  placeSound = love.audio.newSource("assets/place.wav", "static")
  destrSound = love.audio.newSource("assets/destr.mp3", "static")
  destrSound:setVolume(1)

  music = love.audio.newSource("assets/music.mp3", "stream")
  music:setLooping(true)
  music:setVolume(.5)
  music:play()

  crownImage = love.graphics.newImage("assets/crown.png")
  crownSize = crownImage:getHeight()
  crownScale = 22/crownSize

  giveUpButton = love.graphics.newImage("assets/giveUp.png")
  giveUpButtonSize = 50
  giveUpButtonScale = giveUpButtonSize/giveUpButton:getHeight()
  giveUpButtonW = giveUpButton:getWidth() * giveUpButtonScale
  giveUpButtonH = giveUpButton:getHeight() * giveUpButtonScale

  giveUpX = function()
    return w/2 - giveUpButtonW/2
  end

  giveUpY = function()
    return h - giveUpButtonH - 10
  end

  volumeOn = love.graphics.newImage("assets/volumeOn.png")
  volumeOff = love.graphics.newImage("assets/volumeOff.png")
  volumeOnSize = 30
  volumeOnScale = volumeOnSize/volumeOn:getHeight()
  volumeOnW = volumeOn:getWidth() * volumeOnScale
  volumeOnH = volumeOn:getHeight() * volumeOnScale

  musicOn = true


  --menu stuff
  inMenu = true

  playButton = love.graphics.newImage("assets/playButton.png")
  playButtonY = function()
    return h/2 - giveUpButtonH/2 + 100
  end

  logoButton = love.graphics.newImage("assets/logo.png")
  logoButtonSize = 70
  logoButtonScale = logoButtonSize/logoButton:getHeight()
  logoButtonW = logoButton:getWidth() * logoButtonScale

  clickSound = love.audio.newSource("assets/click.mp3", "static")
  clickSound:setVolume(.3)

  --game over stuff
  didLose = false

  gameOverDisplayScore = 0

  returnButtonY = 600

  gameOver = love.graphics.newImage("assets/gameOver.png")
  gameOverSize = 55
  gameOverScale = gameOverSize/gameOver:getHeight()
  gameOverW = gameOver:getWidth() * gameOverScale
  gameOverH = gameOver:getHeight() * gameOverScale
  gameOverX = function()
    return w/2 - gameOverW/2
  end
  gameOverY = function()
    return 300
  end

  gameOverSubHeadingFont = love.graphics.newFont("assets/font.ttf", 18)
  gameOverHeadingFont = love.graphics.newFont("assets/fontBold.ttf", 50)

  gameOverSubHeadingCol = {33, 89, 181}

  
  _G.bSize = function(mult)
    mult = mult or 1
    return boxSize * mult, boxSize * mult
  end

  for i=1, numBoxes do
    boxes[i] = {}
  end
  local queueBSize = 100
  local bH = 100
  local bY = 625
  shapeQueueButtons = {
    {
      pos = function()
        return {w/2 - queueBSize/2, bY}
      end,
      size = {queueBSize, bH},
      curShape = nil,
      i = 1
    },
    {
      pos = function()
        return {w/2 - queueBSize/2 - queueBSize - 15, bY}
      end,
      size = {queueBSize, bH},
      curShape = nil,
      i = 2
    },
    {
      pos = function()
        return {w/2 + queueBSize/2 + 15, bY}
      end,
      size = {queueBSize, bH},
      curShape = nil,
      i = 3
    },
  }

  if not love.filesystem.getInfo("save.txt") then
    love.filesystem.newFile("save.txt")
    love.filesystem.write("save.txt", "")
  end

  local savedData = lume.deserialize(love.filesystem.read("save.txt"))
  if savedData and type(savedData) == "table" then
    score = savedData.score or score
    displayScore = score
    streak = savedData.streak or streak
    movesSinceStreak = savedData.movesSinceStreak or movesSinceStreak
    boxes = savedData.boxes or boxes
    highScore = savedData.highScore or highScore
    musicOn = savedData.musicOn

    if musicOn == nil then
      musicOn = true
    end
    
    if savedData.curShapes then
      for i, b in pairs(shapeQueueButtons) do
        if savedData.curShapes[i] ~= 0 then
          b.curShape = savedData.curShapes[i]
          b.c = b.curShape.c
        end
      end
    else
      refillQueue()
    end
  else
    refillQueue()
  end

  updateMusicVolume()
end

function love.update()
  mx, my = love.mouse.getX(), love.mouse.getY()

  displayScore = lerp(displayScore, score, .1)
  
  if not bgX then return end --first frame, bgX is undeclared
  if not mouseDown or not draggingShape then return end

  tempBoxes = tblClone(boxes)
  
  --collision check
  draggingColliding = false
  for _, vert in pairs(draggingShape.verts) do
    local rx, ry = getDraggingShapeVertPos(vert)

    local x, y = getGridPosWithOffset(rx, ry)
    if not x or not y then
      draggingColliding = true
    elseif boxes[x][y] then
      draggingColliding = true
    end
  end
  
  if draggingShape and not draggingColliding then
    --adding hover vertices to tempBoxes
    for _, vert in pairs(draggingShape.verts) do
        local rX, rY = getDraggingShapeVertPos(vert)
        local gridX, gridY = getGridPosFromPoint(rX, rY)
        if gridX and gridY then
          tempBoxes[gridX][gridY] = box(gridX, gridY, "red")
        end
    end
  end
    
  --detect endangeredBoxes
  endangeredBoxes = {}
  selectEndangeredBoxes()
end

local function drawMenu()
  love.graphics.draw(playButton, w/2 - giveUpButtonW/2, h/2-giveUpButtonH/2 + 100, 0, giveUpButtonScale)

  love.graphics.draw(logoButton, w/2 - logoButtonW/2, 350, 0, logoButtonScale)
end

local function drawGameOver()
  gameOverDisplayScore = lerp(gameOverDisplayScore, finalScore, .1)

  love.graphics.setColor(toCol(255))

  love.graphics.draw(gameOver, gameOverX(), gameOverY(), 0, gameOverScale)

  love.graphics.setFont(gameOverSubHeadingFont)
  local prStr = "Score"
  local prWidth = gameOverSubHeadingFont:getWidth(prStr)
  love.graphics.setColor(toCol(unpackCol(gameOverSubHeadingCol)))
  love.graphics.print(prStr, w/2 - prWidth/2, gameOverY() + gameOverH + 40)

  love.graphics.setColor(toCol(255))
  prStr = tostring(math.floor(gameOverDisplayScore + 1))
  prWidth = gameOverHeadingFont:getWidth(prStr)
  love.graphics.setFont(gameOverHeadingFont)
  love.graphics.print(prStr, w/2 - prWidth/2, gameOverY() + gameOverH + 43 + gameOverSubHeadingFont:getHeight())

  love.graphics.setFont(gameOverSubHeadingFont)
  prStr = "High Score"
  prWidth = gameOverSubHeadingFont:getWidth(prStr)
  love.graphics.setColor(toCol(unpackCol(gameOverSubHeadingCol)))
  love.graphics.print(prStr, w/2 - prWidth/2, gameOverY() + gameOverH + 43 + gameOverSubHeadingFont:getHeight() + 80)

  love.graphics.setColor(toCol(240, 204, 2))
  prStr = tostring(highScore)
  prWidth = gameOverHeadingFont:getWidth(prStr)
  love.graphics.setFont(gameOverHeadingFont)
  love.graphics.print(prStr, w/2 - prWidth/2, gameOverY() + gameOverH + 43 + gameOverSubHeadingFont:getHeight() + 80 + gameOverSubHeadingFont:getHeight())

  love.graphics.setColor(toCol(255))
  love.graphics.draw(playButton, w/2 - giveUpButtonW/2, returnButtonY, 0, giveUpButtonScale)
end

function love.draw()
  w, h = love.graphics.getDimensions()

  love.graphics.setBackgroundColor(toCol(54,84,153))

  love.graphics.setColor(toCol(255))

  love.graphics.draw(background, 0, 0, 0, (h + 100)/backhgroundSize)

  if inMenu then
    return drawMenu()
  elseif didLose then
    return drawGameOver()
  end

  --draw box background
  bgSize = boxSize * numBoxes
  bgX = (w/2) - (bgSize/2)
  bgY = 150 + topDiff

  local bgPadding = 10

  local tBgSize = bgSize + bgPadding * 2
  tbgX = (w/2) - (tBgSize/2)
  tbgY = bgY - bgPadding

  love.graphics.setColor(1,1,1, .5)
  love.graphics.draw(tilesBackground, tbgX, tbgY, 0, (tBgSize/tilesBackground:getWidth()), (tBgSize/tilesBackground:getHeight()))

  love.graphics.setColor(toCol(255))

  --draw boxes
  for x, t in pairs(boxes) do
    for y=1, numBoxes do
      local box = t[y]

      local aX = x-1
      local aY = y-1

      local xPos = bgX + (aX * boxSize)
      local yPos = bgY + (aY * boxSize)

      if box then
        love.graphics.draw(cols[isEndangered(x, y) and draggingCol or box.c], xPos, yPos, 0, boxScale)
      else
        love.graphics.setColor(1,1,1, .05)
        love.graphics.draw(boxBackground, xPos, yPos, 0, boxSize/boxBackgroundSize)
        love.graphics.setColor(toCol(255))
      end
    end
  end

  -- draw shape queue buttons
  for _, b in pairs(shapeQueueButtons) do
    
    --render queued shape
    if b.curShape and not b.hide then
      for _, vert in pairs(b.curShape.verts) do
        local xPos = vert[1] * queueBoxSize + b.pos()[1] + b.size[1]/2 - (b.curShape.size[1]*queueBoxSize)/2
        local yPos = vert[2] * queueBoxSize + b.pos()[2] + b.size[2]/2 - (b.curShape.size[2]*queueBoxSize)/2
        love.graphics.draw(cols[b.c], xPos, yPos, 0, queueBoxScale)
      end
    end
  end

  --draw give up button
  local giveUpX = w/2 - giveUpButtonW/2
  local giveUpY = h - giveUpButtonH - 10
  love.graphics.draw(giveUpButton, giveUpX, giveUpY, 0, giveUpButtonScale)

  -- draw "shadow" shape to show final position of dragging shape
  if draggingShape and mouseDown and not draggingColliding then
    local dCol = cols[draggingCol]
    love.graphics.setColor(1,1,1,.5)
    for _, vert in pairs(draggingShape.verts) do
      local rX, rY = getDraggingShapeVertPos(vert)
      local gridX, gridY = getGridPosWithOffset(rX, rY)
      if gridX and gridY then
        local xPos = bgX + ((gridX-1) * boxSize)
        local yPos = bgY + ((gridY-1) * boxSize)
        love.graphics.draw(dCol, xPos, yPos, 0, boxScale)
      end
    end
  end
  love.graphics.setColor(1,1,1,1)

  -- draw dragging shape
  if mouseDown and draggingShape then
    for i, vert in pairs(draggingShape.verts) do
      local rX, rY = getDraggingShapeVertPos(vert)
      if vert[1] == 0 and vert[2] == 0 then
        draggingTL = {rX, rY}
      end

      love.graphics.draw(cols[draggingCol], rX, rY, 0, boxScale)
    end
  end

  if not musicOn then
    love.graphics.setColor(toCol(250, 125, 125))
  end
  love.graphics.draw(musicOn and volumeOn or volumeOff, w - volumeOnW - 10, 55, 0, volumeOnScale)

  --text
  love.graphics.setFont(scoreFont)
  love.graphics.setColor(toCol(255))
  local scoreText = tostring(math.ceil(displayScore))
  local scoreWidth = scoreFont:getWidth(scoreText)
  love.graphics.print(scoreText, w/2 - scoreWidth/2, 125)

  love.graphics.draw(crownImage, 10, 60, 0, crownScale)

  love.graphics.setFont(hsFont)
  love.graphics.setColor(toCol(240, 204, 2))
  love.graphics.print(tostring(highScore), 45, 60)

  love.graphics.setColor(toCol(255))
end

function love.mousepressed(mb)
  mx, my = love.mouse.getX(), love.mouse.getY()
  for i, b in pairs(shapeQueueButtons) do
    if isPointInRect(mx, my, b.pos()[1], b.pos()[2], b.size[1], b.size[2]) and b.curShape and isInGame() then
      mouseDown = true
      draggingCol = b.c
      draggingShape = b.curShape
      b.hide = true
      draggingB = b
      return
    end
  end

  if isPointInRect(mx, my, giveUpX(), giveUpY(), giveUpButtonW, giveUpButtonH) and isInGame() then
    clickSound:stop()
    clickSound:play()

    finalScore = score

    streak = 0
    movesSinceStreak = 0
    score = 0
    displayScore = score
    boxes = {}
    for i=1, numBoxes do
      boxes[i] = {}
    end
    shapeQueue = {}

    for _, b in pairs(shapeQueueButtons) do
      b.curShape = nil
      b.hide = false
    end
    refillQueue()

    didLose = true

    return
  end

  if isPointInRect(mx, my, giveUpX(), playButtonY(), giveUpButtonW, giveUpButtonH) and inMenu then
    clickSound:stop()
    clickSound:play()
    inMenu = false
  end

  if isPointInRect(mx, my, giveUpX(), returnButtonY, giveUpButtonW, giveUpButtonH) and didLose then
    clickSound:stop()
    clickSound:play()

    didLose = false
    gameOverDisplayScore = 0
  end

  if isPointInRect(mx, my, w - volumeOnW - 10, 55, volumeOnW, volumeOnH) and isInGame() then
    musicOn = not musicOn
    updateMusicVolume()
  end
end

function love.mousereleased(mb)
  if not mouseDown then return end
  mouseDown = false
  if not draggingTL then return end
  
  local x, y = getGridPosWithOffset(draggingTL[1], draggingTL[2])
  if x and y and not draggingColliding then
    placeShape(draggingShape, x, y, draggingCol)
    addScore(#draggingShape.verts * getStreakMultiplier())
    draggingB.curShape = nil
    draggingB.hide = false
    
    for i, b in pairs(shapeQueueButtons) do
      if b.curShape then break end
      
      if i == #shapeQueueButtons then
        refillQueue()
      end
    end
    
  else
    draggingB.hide = false
  end
end

function love.keypressed(k)
  if k == "f11" then
      love.window.setFullscreen(not love.window.getFullscreen())
  end
end

function love.quit()
  local curShapes = {}

  for _, b in pairs(shapeQueueButtons) do
    if b.curShape then b.curShape.c = b.c end
    table.insert(curShapes, b.curShape or 0)
  end

  local data = {
    score = score,
    streak = streak,
    movesSinceStreak = movesSinceStreak,
    boxes = boxes,
    curShapes = curShapes,
    highScore = highScore,
    musicOn = musicOn
  }

  local serialized = lume.serialize(data)
  love.filesystem.write("save.txt", serialized)

  print("Saved data: "..serialized)
end