local ADDON, NS = ...

-- Anillo de dragón plateado + barra de acero con borde dorado (diseño D3).
-- Proporciones sobre la textura 256x256.
NS:RegisterRingTheme("EliteDragon", {
  label = "Elite Dragon",
  texture = "Interface\\AddOns\\Lootly\\Media\\dragon_ring",
  circleX = 0.393, circleY = 0.45, circleD = 0.427,
  textX = 0.42, -- el ala del dragón ocupa parte de la barra
  bar = { 0.14, 0.15, 0.18 },
  border = { 0.72, 0.53, 0.17 },
})
