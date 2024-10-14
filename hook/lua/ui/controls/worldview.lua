local function AveragePositionOfUnits(units)
    local unitCount = table.getn(units)

    local px = 0
    local py = 0
    local pz = 0
    for k = 1, unitCount do
        local ux, uy, uz = unpack(units[k]:GetPosition())
        px = px + ux
        py = py + uy
        pz = pz + uz
    end

    px = px / unitCount
    py = py / unitCount
    pz = pz / unitCount

    return {
        px,
        py,
        pz
    }

end

--- Get the weapon "damage spread", which is how much the weapon's damage spreads out depending on the distance to target
---@param weapon WeaponBlueprint
---@return number
local function GetWeaponDamageSpread(weapon)
    local dist = VDist3(AveragePositionOfUnits(GetSelectedUnits()), GetMouseWorldPos())
    local weaponMaxRadius = weapon.MaxRadius
    local weaponMinRadius = weapon.MinRadius
    if weaponMinRadius and dist < weaponMinRadius then
        dist = weaponMinRadius
    elseif weaponMaxRadius and dist > weaponMaxRadius then
        dist = weaponMaxRadius
    end
    return (weapon.DamageRadius or 0) + (weapon.FixedSpreadRadius or (weapon.FiringRandomness or 0) / 12 * dist)
end

local maxSpreadWeaponCached

--- Get the maximum damage spread from multiple weapons, and cache the max spread weapon
---@param weapons WeaponBlueprint[]
---@return number
local function GetMaxDamageSpread(weapons)
    local maxRadius = 0
    for _, w in weapons do
        newRad = GetWeaponDamageSpread(w)
        if newRad > maxRadius then
            maxRadius = newRad
            maxSpreadWeaponCached = w
        end
    end
    return maxRadius
end

local function RadiusDecalScaleUpdate()
    return GetWeaponDamageSpread(maxSpreadWeaponCached) * 2
end

--- A generic decal texture / size computation function that uses the damage and spread radius
---@param predicate function<WeaponBlueprint[]>
---@return WorldViewDecalData[]
RadiusDecalFunction = function(predicate)
    local weapons = GetSelectedWeaponsWithReticules(predicate)

    local maxRadius = GetMaxDamageSpread(weapons)

    if maxRadius > 0 then
        local damageRadius = maxSpreadWeaponCached.DamageRadius
        local decalData = { }
        if damageRadius > 0 then
            table.insert(decalData,
                { --Damage radius display
                    texture = "/textures/ui/common/game/AreaTargetDecal/weapon_icon_small.dds",
                    scale = damageRadius * 2
                }
            )
        end
        if damageRadius ~= maxRadius then
            table.insert(decalData,
                { --Inaccuracy display
                    texture = "/textures/ui/common/game/AreaTargetDecal/nuke_icon_inner.dds",
                    scaleUpdateFunction = RadiusDecalScaleUpdate
                }
            )
        end

        return decalData
    end

    return false
end

local oldWorldView = WorldView

WorldView = Class(oldWorldView) {

    --- Manages the decals of a cursor event
    ---@param self WorldView
    ---@param identifier CommandCap
    ---@param enabled boolean
    ---@param changed boolean
    ---@param getDecalsBasedOnSelection function # See the radial decal functions
    OnCursorDecals = function(self, identifier, enabled, changed, getDecalsBasedOnSelection)
        if enabled then
            if changed then

                -- prepare decals based on the selection
                local data = getDecalsBasedOnSelection()
                if data then
                    -- clear out old decals, if they exist
                    self.CursorDecalTrash:Destroy();
                    for k, instance in data do
                        local decal = UserDecal()
                        decal:SetTexture(instance.texture)

                        local scaleUpdate = instance.scaleUpdateFunction
                        if scaleUpdate then
                            decal.scaleUpdate = scaleUpdate
                        else
                            local scale = instance.scale
                            decal:SetScale({scale, 1, scale})
                        end

                        self.CursorDecalTrash:Add(decal);
                        self.Trash:Add(decal)
                    end
                end
            end

            -- update their scale and then locations
            for k, decal in self.CursorDecalTrash do
                if decal.scaleUpdate then
                    local scale = decal.scaleUpdate()
                    decal:SetScale({scale, 1, scale})
                end
                decal:SetPosition(GetMouseWorldPos())
            end
        else
            -- command ended, destroy the current decals to make room for new decals
            self.CursorDecalTrash:Destroy();
        end
    end,

}
