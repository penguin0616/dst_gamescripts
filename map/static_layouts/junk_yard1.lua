return {
  version = "1.1",
  luaversion = "5.1",
  orientation = "orthogonal",
  width = 24,
  height = 24,
  tilewidth = 16,
  tileheight = 16,
  properties = {},
  tilesets = {
    {
      name = "tiles",
      firstgid = 1,
      tilewidth = 64,
      tileheight = 64,
      spacing = 0,
      margin = 0,
      image = "../../../../tools/tiled/dont_starve/tiles.png",
      imagewidth = 512,
      imageheight = 512,
      properties = {},
      tiles = {}
    }
  },
  layers = {
    {
      type = "tilelayer",
      name = "BG_TILES",
      x = 0,
      y = 0,
      width = 24,
      height = 24,
      visible = true,
      opacity = 1,
      properties = {},
      encoding = "lua",
      data = {
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 4, 0, 0, 0, 4, 0, 0, 0, 4, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 4, 0, 0, 0, 4, 0, 0, 0, 4, 0, 0, 0, 4, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 4, 0, 0, 0, 4, 0, 0, 0, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 4, 0, 0, 0, 4, 0, 0, 0, 4, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
      }
    },
    {
      type = "objectgroup",
      name = "FG_OBJECTS",
      visible = true,
      opacity = 1,
      properties = {},
      objects = {
        {
          name = "",
          type = "fence_junk_pre_rotator",
          shape = "rectangle",
          x = 24,
          y = 104,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "fence_junk_pre_rotator",
          shape = "rectangle",
          x = 24,
          y = 120,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "fence_junk_pre_rotator",
          shape = "rectangle",
          x = 24,
          y = 136,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "fence_junk_pre_rotator",
          shape = "rectangle",
          x = 40,
          y = 88,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "random",
          type = "junk_pile",
          shape = "rectangle",
          x = 313,
          y = 292,
          width = 0,
          height = 0,
          visible = true,
          properties = {
            ["data.random"] = "true"
          }
        },
        {
          name = "",
          type = "fence_junk_pre_rotator",
          shape = "rectangle",
          x = 40,
          y = 72,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "fence_junk_pre_rotator",
          shape = "rectangle",
          x = 40,
          y = 40,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "fence_junk_pre_rotator",
          shape = "rectangle",
          x = 40,
          y = 56,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "fence_junk_pre_rotator",
          shape = "rectangle",
          x = 56,
          y = 24,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "fence_junk_pre_rotator",
          shape = "rectangle",
          x = 72,
          y = 24,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "fence_junk_pre_rotator",
          shape = "rectangle",
          x = 248,
          y = 40,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "fence_junk_pre_rotator",
          shape = "rectangle",
          x = 264,
          y = 40,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "fence_junk_pre_rotator",
          shape = "rectangle",
          x = 280,
          y = 40,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "fence_junk_pre_rotator",
          shape = "rectangle",
          x = 232,
          y = 40,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "fence_junk_pre_rotator",
          shape = "rectangle",
          x = 296,
          y = 40,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "fence_junk_pre_rotator",
          shape = "rectangle",
          x = 312,
          y = 40,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "fence_junk_pre_rotator",
          shape = "rectangle",
          x = 328,
          y = 40,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "fence_junk_pre_rotator",
          shape = "rectangle",
          x = 312,
          y = 360,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "fence_junk_pre_rotator",
          shape = "rectangle",
          x = 264,
          y = 360,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "fence_junk_pre_rotator",
          shape = "rectangle",
          x = 344,
          y = 360,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "fence_junk_pre_rotator",
          shape = "rectangle",
          x = 280,
          y = 360,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "fence_junk_pre_rotator",
          shape = "rectangle",
          x = 296,
          y = 360,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "fence_junk_pre_rotator",
          shape = "rectangle",
          x = 328,
          y = 360,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "fence_junk_pre_rotator",
          shape = "rectangle",
          x = 360,
          y = 360,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "fence_junk_pre_rotator",
          shape = "rectangle",
          x = 376,
          y = 328,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "fence_junk_pre_rotator",
          shape = "rectangle",
          x = 376,
          y = 296,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "fence_junk_pre_rotator",
          shape = "rectangle",
          x = 376,
          y = 344,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "fence_junk_pre_rotator",
          shape = "rectangle",
          x = 376,
          y = 280,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "fence_junk_pre_rotator",
          shape = "rectangle",
          x = 376,
          y = 264,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "fence_junk_pre_rotator",
          shape = "rectangle",
          x = 376,
          y = 312,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "random",
          type = "junk_pile",
          shape = "rectangle",
          x = 285,
          y = 125,
          width = 0,
          height = 0,
          visible = true,
          properties = {
            ["data.random"] = "true"
          }
        },
        {
          name = "random",
          type = "junk_pile",
          shape = "rectangle",
          x = 190,
          y = 282,
          width = 0,
          height = 0,
          visible = true,
          properties = {
            ["data.random"] = "true"
          }
        },
        {
          name = "",
          type = "fence_junk_pre_rotator",
          shape = "rectangle",
          x = 56,
          y = 376,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "fence_junk_pre_rotator",
          shape = "rectangle",
          x = 136,
          y = 376,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "fence_junk_pre_rotator",
          shape = "rectangle",
          x = 120,
          y = 376,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "fence_junk_pre_rotator",
          shape = "rectangle",
          x = 88,
          y = 376,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "fence_junk_pre_rotator",
          shape = "rectangle",
          x = 72,
          y = 376,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "fence_junk_pre_rotator",
          shape = "rectangle",
          x = 104,
          y = 376,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "random",
          type = "junk_pile",
          shape = "rectangle",
          x = 68,
          y = 218,
          width = 0,
          height = 0,
          visible = true,
          properties = {
            ["data.random"] = "true"
          }
        },
        {
          name = "",
          type = "junk_pile_big",
          shape = "rectangle",
          x = 141,
          y = 138,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "fence_junk_pre_rotator",
          shape = "rectangle",
          x = 24,
          y = 296,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "fence_junk_pre_rotator",
          shape = "rectangle",
          x = 24,
          y = 328,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "fence_junk_pre_rotator",
          shape = "rectangle",
          x = 24,
          y = 312,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "fence_junk_pre_rotator",
          shape = "rectangle",
          x = 24,
          y = 344,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "fence_junk_pre_rotator",
          shape = "rectangle",
          x = 120,
          y = 24,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "fence_junk_pre_rotator",
          shape = "rectangle",
          x = 88,
          y = 24,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "fence_junk_pre_rotator",
          shape = "rectangle",
          x = 104,
          y = 24,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "fence_junk_pre_rotator",
          shape = "rectangle",
          x = 200,
          y = 24,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "fence_junk_pre_rotator",
          shape = "rectangle",
          x = 216,
          y = 24,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "fence_junk_pre_rotator",
          shape = "rectangle",
          x = 24,
          y = 184,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "fence_junk_pre_rotator",
          shape = "rectangle",
          x = 24,
          y = 152,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "fence_junk_pre_rotator",
          shape = "rectangle",
          x = 24,
          y = 168,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "fence_junk_pre_rotator",
          shape = "rectangle",
          x = 344,
          y = 104,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "fence_junk_pre_rotator",
          shape = "rectangle",
          x = 344,
          y = 88,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "fence_junk_pre_rotator",
          shape = "rectangle",
          x = 344,
          y = 72,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "fence_junk_pre_rotator",
          shape = "rectangle",
          x = 344,
          y = 56,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "fence_junk_pre_rotator",
          shape = "rectangle",
          x = 40,
          y = 360,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "random",
          type = "junk_pile",
          shape = "rectangle",
          x = 242,
          y = 96,
          width = 0,
          height = 0,
          visible = true,
          properties = {
            ["data.random"] = "true"
          }
        },
        {
          name = "random",
          type = "junk_pile",
          shape = "rectangle",
          x = 84,
          y = 71,
          width = 0,
          height = 0,
          visible = true,
          properties = {
            ["data.random"] = "true"
          }
        },
        {
          name = "random",
          type = "junk_pile",
          shape = "rectangle",
          x = 125,
          y = 247,
          width = 0,
          height = 0,
          visible = true,
          properties = {
            ["data.random"] = "true"
          }
        },
        {
          name = "random",
          type = "junk_pile",
          shape = "rectangle",
          x = 101,
          y = 312,
          width = 0,
          height = 0,
          visible = true,
          properties = {
            ["data.random"] = "true"
          }
        },
        {
          name = "random",
          type = "junk_pile",
          shape = "rectangle",
          x = 334,
          y = 239,
          width = 0,
          height = 0,
          visible = true,
          properties = {
            ["data.random"] = "true"
          }
        },
        {
          name = "",
          type = "wagstaff_machinery_marker",
          shape = "rectangle",
          x = 244,
          y = 213,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "wobot_area",
          shape = "rectangle",
          x = 230,
          y = 70,
          width = 66,
          height = 67,
          visible = true,
          properties = {
            ["data.fueled.fuel"] = "0"
          }
        },
        {
          name = "",
          type = "grass_area",
          shape = "rectangle",
          x = 14,
          y = -2,
          width = 111,
          height = 105,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "grass_area",
          shape = "rectangle",
          x = 1,
          y = 198,
          width = 136,
          height = 196,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "grass_area",
          shape = "rectangle",
          x = 213,
          y = 6,
          width = 150,
          height = 137,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "grass_area",
          shape = "rectangle",
          x = 280,
          y = 220,
          width = 130,
          height = 159,
          visible = true,
          properties = {}
        }
      }
    }
  }
}
