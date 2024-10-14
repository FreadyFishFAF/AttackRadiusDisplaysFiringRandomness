local maxSpreadWeaponCached

-- Helper function to calculate the average position of a group of units.
local function AveragePositionOfUnits(units)
    local unitCount = table.getn(units)

    local px, py, pz = 0, 0, 0

    for k = 1, unitCount do
        local ux, uy, uz = unpack(units[k]:GetPosition())
        px = px + ux
        py = py + uy
        pz = pz + uz
    end

    px = px / unitCount
    py = py / unitCount
    pz = pz / unitCount

    return { px, py, pz }
end

--- Get the weapon's damage spread, which accounts for both the explosion radius and firing randomness.
--- The spread increases with distance from the target.
---@param weapon WeaponBlueprint
---@return number
local function GetWeaponDamageSpread(weapon)
    local dist = VDist3(AveragePositionOfUnits(GetSelectedUnits()), GetMouseWorldPos())

    local weaponMaxRadius = weapon.MaxRadius
    local weaponMinRadius = weapon.MinRadius

    -- Clamp distance to within the weapon's firing radius
    if weaponMinRadius and dist < weaponMinRadius then
        dist = weaponMinRadius
    elseif weaponMaxRadius and dist > weaponMaxRadius then
        dist = weaponMaxRadius
    end

    -- Calculate spread as a combination of damage radius and firing randomness
    return (weapon.DamageRadius or 0) + (weapon.FixedSpreadRadius or 0) + ((weapon.FiringRandomness or 0) * dist / 10)
end

-- Helper function to get the maximum damage spread from a set of weapons.
---@param weapons WeaponBlueprint[]
---@return number
local function GetMaxDamageSpread(weapons)
    local maxRadius = 0

    -- FF Fix, don't know the exact source but I guess some FAF update makes this necessary
    for key, weaponData in pairs(weapons) do
        for _, w in pairs(weaponData or {}) do
            local newRad = GetWeaponDamageSpread(w)

            if newRad > maxRadius then
                maxRadius = newRad
                maxSpreadWeaponCached = w
            end
        end
    end

    return maxRadius
end

-- Helper function to update the scale of the radius decal based on the current weapon's damage spread.
local function RadiusDecalScaleUpdate()
    return GetWeaponDamageSpread(maxSpreadWeaponCached) * 2
end

--- Override to compute the decal texture and size based on the weapon's damage and spread radius.
---@param predicate function<WeaponBlueprint[]>
---@return WorldViewDecalData[]
RadiusDecalFunction = function(predicate)
    local weapons = GetSelectedWeaponsWithReticules(predicate)

    local maxRadius = GetMaxDamageSpread(weapons)

    if maxRadius > 0 then
        local damageRadius = maxSpreadWeaponCached.DamageRadius
        local decalData = {}
        -- Create decal for damage radius
        if damageRadius > 0 then
            table.insert(decalData,
                { --Damage radius display
                    texture = "/textures/ui/common/game/AreaTargetDecal/weapon_icon_small.dds",
                    scale = damageRadius * 2
                }
            )
        end
        -- Create decal for inaccuracy if the spread radius differs from damage radius
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

-- Extension of the WorldView class to handle cursor decals for command actions.
WorldView = Class(oldWorldView) {

    --- Manages the decals of a cursor event based on selection and weapon stats.
    ---@param self WorldView
    ---@param identifier CommandCap
    ---@param enabled boolean
    ---@param changed boolean
    ---@param getDecalsBasedOnSelection function # See the radial decal functions
    OnCursorDecals = function(self, identifier, enabled, changed, getDecalsBasedOnSelection)
        if enabled then
            if changed then

                -- Prepare decals based on the current selection
                local data = getDecalsBasedOnSelection()
                if data then
                    -- Clear out old decals if they exist
                    self.CursorDecalTrash:Destroy();

                    -- Add new decals
                    for k, instance in data do
                        local decal = UserDecal()
                        decal:SetTexture(instance.texture)

                        local scaleUpdate = instance.scaleUpdateFunction
                        if scaleUpdate then
                            decal.scaleUpdate = scaleUpdate
                        else
                            local scale = instance.scale
                            decal:SetScale({ scale, 1, scale })
                        end

                        self.CursorDecalTrash:Add(decal);
                        self.Trash:Add(decal)
                    end
                end
            end

            -- Update their scale and positions
            for k, decal in self.CursorDecalTrash do
                if decal.scaleUpdate then
                    local scale = decal.scaleUpdate()
                    decal:SetScale({ scale, 1, scale })
                end
                decal:SetPosition(GetMouseWorldPos())
            end
        else
            -- Destroy current decals when command ends
            self.CursorDecalTrash:Destroy();
        end
    end,
}
