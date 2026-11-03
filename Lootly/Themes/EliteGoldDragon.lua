local ADDON, NS = ...

-- Anillo de dragón dorado + barra de bronce cálido con borde dorado claro.
-- Proporciones sobre la textura 512x512 (imagen original centrada).
NS:RegisterRingTheme("EliteGoldDragon", {
  label = "Elite Gold Dragon",
  texture = "Interface\\AddOns\\Lootly\\Media\\gold_dragon_ring",
  circleX = 0.39, circleY = 0.4575, circleD = 0.4375,
  textX = 0.46, -- el ala del dragón ocupa más barra
  bar = { 0.36, 0.24, 0.09 },
  border = { 1, 0.83, 0.42 },
})
