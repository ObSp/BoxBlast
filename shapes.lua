local function xLine(segms, yPos)
  yPos = yPos or 0
  local t = {}
  for i = 0, segms-1 do
    table.insert(t, {i, yPos})
  end
  return t
end

local function yLine(segms)
  local t = {}
  for i = 0, segms-1 do
    table.insert(t, {0, i})
  end
  return t
end

local function box(w, h)
  local t = {}
  for x=0, w-1 do
    for y = 0, h-1 do
      table.insert(t, {x, y})
    end
  end
  return t
end

local function conc(t1, t2) 
  local t = {}
  
  for i, v in pairs(t1) do
    t[i] = v
  end
  
  for i, v in pairs(t2) do
    t[#t1 + i] = v
  end
  
  return t
end

return setmetatable({
   {
     name = "s1",
     verts = xLine(3),
     size = {3, 1}
  },
  {
    name = "s2",
    verts = xLine(4),
    size = {4, 1}
  },
  {
    name = "s3",
    verts = xLine(6),
    size = {5, 1}
  },
  {
    name = "s4",
    verts = xLine(5),
    size = {5, 1}
  },
  {
    name = "s5",
    verts = xLine(2),
    size = {2, 1}
  },
  {
    name = "d1",
    verts = yLine(4),
    size = {1, 4}
  },
  {
    name = "d2",
    verts = yLine(2),
    size = {1, 2}
  },
  {
    name = "d3",
    verts = yLine(6),
    size = {1, 6}
  },
  {
    name = "d4",
    verts = yLine(5),
    size = {1, 5}
  },
  {
    name = "b1",
    verts = box(2, 2),
    size = {2, 2}
  },
  {
    name = "b2",
    verts = box(3, 3),
    size = {3, 3}
  },
  {
    name = "b3",
    verts = box(3, 2),
    size = {3, 2}
  },
  {
    name = "b4",
    verts = box(2, 3),
    size = {2, 3}
  },
  {
    name = "tri1",
    verts = conc(xLine(3), {
      {1, -1}
    }),
    size = {3, 2}
  },
  {
    name = "tri2",
    verts = conc(xLine(3), {
      {1, 1}
    }),
    size = {3, 2}
  },
  {
    name = "tri3",
    verts = conc(yLine(3), {
      {1, 1}
    }),
    size = {2, 3}
  },
  {
    name = "tri4",
    verts = conc(yLine(3), {
      {-1, 1}
    }),
    size = {2, 3}
  },
  {
    name = "edge1",
    verts = conc(xLine(3), {
      {2, 1},
      {2, 2}
    }),
    size = {3, 3}
  },
  {
    name = "edge2",
    verts = conc(xLine(3), {
      {2, -1},
      {2, -2}
    }),
    size = {3, 3}
  },
  {
    name = "sedge1",
    verts = {
      {0, 0},
      {1, 0},
      {1,1}
    },
    size = {2, 2}
  },
  {
    name = "sedge2",
    verts = {
      {0, 0},
      {1, 0},
      {0,1}
    },
    size = {2, 2}
  },
  {
    name = "sedge3",
    verts = {
      {0, 0},
      {1, 0},
      {1,-1}
    },
    size = {2, 2}
  },
  {
    name = "sedge4",
    verts = {
      {0, 0},
      {1, 0},
      {0,-1}
    },
    size = {2, 2}
  },
  {
    name = "l1",
    verts = conc(yLine(3), {
      {1, 2}
    }),
    size = {2, 3}
  },
  {
    name = "l2",
    verts = conc(yLine(3), {
      {1, 0}
    }),
    size = {2, 3}
  },
  {
    name = "l3",
    verts = conc(yLine(3), {
      {-1, 0}
    }),
    size = {2, 3}
  },
  {
    name = "l4",
    verts = conc(yLine(3), {
      {-1, 2}
    }),
    size = {2, 3}
  },
}, {
  __index = function(self, k) 
    for i, v in pairs(self) do
      if v.name == k then return v end
    end
  end
})