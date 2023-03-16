file.CreateDir( "lambdaplayers/duplications" )


local table_Copy = table.Copy
local pairs = pairs
local IsValid = IsValid
local table_insert = table.insert
local random = math.random
local Trace = util.TraceLine
local Vector = Vector
local Angle = Angle
local tracetable = {}

-- Returns the center
local function MinsMaxsCenter( mins, maxs )
    return LerpVector( 0.5, mins, maxs )
end

-- Ripped this function out so that we can directly input the local stuff.
local function CreateEntityFromTable( Player, EntTable, LocalPos, LocalAng )

    --
    -- Convert position/angle to `local`
    --
    if ( EntTable.Pos and EntTable.Angle ) then

        EntTable.Pos, EntTable.Angle = LocalToWorld( EntTable.Pos, EntTable.Angle, LocalPos, LocalAng )

    end

    local EntityClass = duplicator.FindEntityClass( EntTable.Class )

    -- This class is unregistered. Instead of failing try using a generic
    -- Duplication function to make a new copy..
    if ( !EntityClass ) then

        return duplicator.GenericDuplicatorFunction( Player, EntTable )

    end

    -- Build the argument list
    local ArgList = {}

    for iNumber, Key in pairs( EntityClass.Args ) do

        local Arg = nil

        -- Translate keys from old system
        if ( Key == "pos" or Key == "position" ) then Key = "Pos" end
        if ( Key == "ang" or Key == "Ang" or Key == "angle" ) then Key = "Angle" end
        if ( Key == "model" ) then Key = "Model" end

        Arg = EntTable[ Key ]

        -- Special keys
        if ( Key == "Data" ) then Arg = EntTable end

        -- If there's a missing argument then unpack will stop sending at that argument so send it as `false`
        if ( Arg == nil ) then Arg = false end

        ArgList[ iNumber ] = Arg

    end

    -- Create and return the entity
    return EntityClass.Func( Player, unpack( ArgList ) )

end


-- Returns a random table of dupe data if available 
local function GetDupeData()
    local files, _ = file.Find( "lambdaplayers/duplications/*.vmt", "DATA", "nameasc" )
    if #files == 0 then return end
    return LAMBDAFS:ReadFile( "lambdaplayers/duplications/" .. files[ random( #files ) ], "compressed", nil, true ) 
end


-- Manually Build a dupe using both physgun and toolgun
local function BuildDupe( self )
    local owner = ( game.SinglePlayer() and Entity( 1 ) or self:GetCreator() )

    -- Dupes can only be built if a Lambda has a creator or the game is currently in singleplayer. This is because dupes require a player to built with.
    if !self:CanEquipWeapon( "physgun" ) or !self:CanEquipWeapon( "toolgun" ) or ( !IsValid( owner ) or !owner:IsPlayer() ) then return end

    local dupedata = GetDupeData()
    if !dupedata then return end

    self.l_dupedata = dupedata
    self.l_dupeposition = self:GetPos() + ( self:GetForward() * 100 )
    self.l_dupeangles = self:GetAngles()

    self:SetState( "BuildingDupe" )

    return true
end

AddBuildFunctionToLambdaBuildingFunctions( "Dupes", "Allow Building Dupes", "Allows Lambdas to build dupes. This requires the Physics Gun and Toolgun to be allowed. To add dupes for Lambdas to build, use the Lambda Dupe Creator Tool", BuildDupe )

-- Pastes a dupe
local function DuplicatorTool( self, ent )
    local ply = ( game.SinglePlayer() and Entity( 1 ) or self:GetCreator() )
    if !IsValid( ply ) or !ply:IsPlayer() then return end 

    local dupedata = GetDupeData()

    if !dupedata then return end
    local result = self:Trace( self:GetPos() + Vector( random( -1000, 1000 ), random( -1000, 1000 ), random( -100, 30 ) ) )
    local pos = result.HitPos
    local angs = self:GetAngles()
    

    self:LookTo( pos, 3 )

    coroutine.wait( 1 )

    self:UseWeapon( pos )

    self:Thread( function()

        local unfrozenents = {}
        local EntityList = dupedata.Entities
        local ConstraintList = dupedata.Constraints

        local CreatedEntities = {}

        for k, v in pairs( EntityList ) do

            local e = nil

            -- Apparently this is the only way to get the entities to spawn in the correct positions
            duplicator.SetLocalPos( pos )
            duplicator.SetLocalAng( angs )
            local b = ProtectedCall( function() e = CreateEntityFromTable( ply, v, pos, angs ) end )
            duplicator.SetLocalPos( Vector() )
            duplicator.SetLocalAng( Angle() )
            if !b then continue end

            if IsValid( e ) then

                -- "claim" this entity
                e.LambdaOwner = self
                e.IsLambdaSpawned = true

                table_insert( self.l_SpawnedEntities, 1, e )
                self:ContributeEntToLimit( e, "Prop" )

                if ( e.RestoreNetworkVars ) then
                    e:RestoreNetworkVars( v.DT )
                end

                if ( e.OnDuplicated ) then
                    e:OnDuplicated( v )
                end

                -- Freeze any unfrozen entities and we will unfreeze them later
                for i = 0, e:GetPhysicsObjectCount() do
                    local phys = e:GetPhysicsObjectNum( i )
                    if IsValid( phys ) and phys:IsMotionEnabled() then phys:EnableMotion( false ) unfrozenents[ #unfrozenents + 1 ] = phys end
                end


            end

            CreatedEntities[ k ] = e

            if CreatedEntities[ k ] then

                CreatedEntities[ k ].BoneMods = table_Copy( v.BoneMods )
                CreatedEntities[ k ].EntityMods = table_Copy( v.EntityMods )
                CreatedEntities[ k ].PhysicsObjects = table_Copy( v.PhysicsObjects )

            else

                CreatedEntities[ k ] = nil

            end

            coroutine.wait( 0.05 )
        end


        for EntID, Ent in pairs( CreatedEntities ) do
            if !IsValid( Ent ) then continue end

            duplicator.ApplyEntityModifiers( ply, Ent )
            duplicator.ApplyBoneModifiers( ply, Ent )

            if Ent.PostEntityPaste then
                Ent:PostEntityPaste( ply, Ent, CreatedEntities )
            end

            coroutine.wait( 0.05 )
        end

        local CreatedConstraints = {}

        for k, Constraint in pairs( ConstraintList ) do

            local Entity = nil
            ProtectedCall( function() Entity = duplicator.CreateConstraintFromTable( Constraint, CreatedEntities, ply ) end )

            if IsValid( Entity ) then
                table_insert( CreatedConstraints, Entity )
            end

            coroutine.wait( 0.05 )
        end

        -- Unfreeze any previously frozen unfrozen props
        for i = 1, #unfrozenents do
            local phys = unfrozenents[ i ]
            if IsValid( phys ) then phys:EnableMotion( true ) end
        end



    end, "duplicatorpaste", true )

    return true
end

AddToolFunctionToLambdaTools( "Duplicator", DuplicatorTool )

local function Initialize( self )
    if CLIENT then return end

    self.l_dupedata = nil -- The dupe data we are currently building
    self.l_dupeposition = self:GetPos() -- The position to build the dupe at
    self.l_dupeangles = self:GetAngles() -- the desired angles to build the dupe with




    -- The state that makes Lambdas build dupes
    function self:BuildingDupe()

        self:SwitchWeapon( "physgun" )

        self.l_NoWeaponSwitch = true -- Do not switch weapons

        local EntityList = self.l_dupedata.Entities -- Entity list
        local ConstraintList = self.l_dupedata.Constraints -- Constraint list
        local unfrozenents = {}
        local maxslength = self.l_dupedata.Maxs:Length()

        local CreatedEntities = {}


        for k, v in pairs( EntityList ) do
            if self:GetState() != "BuildingDupe" then break end 
            -- Randomly move to a position that we can still see the dupe from
            if random( 1, 4 ) == 1 then
                local randomvec = VectorRand( -maxslength - 100, maxslength + 100 ) randomvec[ 3 ] = 5

                tracetable.start = self.l_dupeposition + MinsMaxsCenter( self.l_dupedata.Mins, self.l_dupedata.Maxs )
                tracetable.endpos = self.l_dupeposition + randomvec 
                tracetable.collisiongroup = COLLISION_GROUP_WORLD
                tracetable.mask = MASK_SOLID_BRUSHONLY
                local result = Trace( tracetable )

                if !result.Hit then
                    self:MoveToPos( self.l_dupeposition + randomvec  )
                end

            end

            -- Look somewhere random
            local pos = self:GetPos() + Vector( random( -100, 100 ), random( -100, 100 ), random( -200, -10 ) )
            self:LookTo( pos, 3 )

            coroutine.wait( 1 )

            -- Spawn the entity
            local e = nil
            local b = ProtectedCall( function() e = CreateEntityFromTable( ( game.SinglePlayer() and Entity( 1 ) or self:GetCreator() ), v, self.l_dupeposition, self.l_dupeangles ) end )
            if !b then continue end

            if IsValid( e ) then

                local ragdolldata = {}

                -- Claim the prop as ours
                e.LambdaOwner = self
                e.IsLambdaSpawned = true

                -- Yes the entities are being labeled as props but it doesn't really matter as typically dupes are just made of props.
                table_insert( self.l_SpawnedEntities, 1, e )
                self:ContributeEntToLimit( e, "Prop" )

                if ( e.RestoreNetworkVars ) then
                    e:RestoreNetworkVars( v.DT )
                end

                if ( e.OnDuplicated ) then
                    e:OnDuplicated( v )
                end

                -- Save unfrozen props for later
                for i = 0, e:GetPhysicsObjectCount() do
                    local phys = e:GetPhysicsObjectNum( i )
                    if IsValid( phys ) and phys:IsMotionEnabled() then unfrozenents[ #unfrozenents + 1 ] = phys end
                end

                -- Save the positioning of ragdoll physics objects so we can properly re-apply them later
                if e:IsRagdoll() then
                    for i = 0, e:GetPhysicsObjectCount() do
                        local phys = e:GetPhysicsObjectNum( i )
                        if IsValid( phys ) then ragdolldata[ #ragdolldata + 1 ] = { phys, phys:GetPos(), phys:GetAngles() } phys:EnableMotion( true ) end
                    end
                end
                
                -- "fake" spawning a prop by saving the old positions and angles and teleporting the prop in front of us 
                local oldpos = e:GetPos()
                local oldangs = e:GetAngles()

                e:SetPos( self:GetPos() + self:GetForward() * math.random( 100, 200 ) )
                e:SetAngles( Angle( 0, self:GetAngles()[ 2 ], 0 ) )

                for i = 0, e:GetPhysicsObjectCount() do
                    local phys = e:GetPhysicsObjectNum( i )
                    if IsValid( phys ) then phys:SetPos( self:GetPos() + self:GetForward() * math.random( 100, 200 ) ) end
                end

                local oldcollisiongroup = e:GetCollisionGroup()
                e:SetCollisionGroup( COLLISION_GROUP_WORLD )

                local mins = e:OBBMins()
                local newpos = e:GetPos()
                local phys = e:GetPhysicsObject()
                newpos.z = newpos.z - mins.z
                
                -- Teleport the prop so it isn't in the ground
                e:SetPos( ( newpos + Vector( 0, 0, 5 ) ) )
                if IsValid( phys ) then
                    phys:SetPos( ( newpos + Vector( 0, 0, 5 ) ) )
                end

                self:LookTo( e )

                coroutine.wait( 0.5 )
                if !IsValid( e ) then continue end

                self:UseWeapon( e ) -- Pick up the prop with the physgun

                coroutine.wait( 1 )
                if !IsValid( e ) then continue end


                -- Move the prop to the old position and angles
                self:LookTo( oldpos )

                self.l_physholdpos = oldpos
                self.l_physholdang = oldangs

                coroutine.wait( 2 )
                if !IsValid( e ) then continue end

                -- Stop holding the prop
                self:UseWeapon() 

                self.l_physholdpos = nil
                self.l_physholdang = nil

                e:SetCollisionGroup( oldcollisiongroup )

                if IsValid( phys ) then
                    phys:EnableMotion(false)
                    phys:SetPos( oldpos )
                end
            
                -- Teleport the prop in place
                e:SetPos( oldpos )
                e:SetAngles( oldangs )

                -- Re-apply the ragdoll pose
                if e:IsRagdoll() then
                    for i = 1, #ragdolldata do
                        local phys = ragdolldata[ i ][ 1 ]
                        local oldposition = ragdolldata[ i ][ 2 ]
                        local oldangles = ragdolldata[ i ][ 3 ]

                        if IsValid( phys ) then
                            phys:SetPos( self.l_dupeposition + oldposition )
                            phys:SetAngles( self.l_dupeangles + oldangles )
                            phys:EnableMotion( false )
                        end
                    end
                end

            end

            CreatedEntities[ k ] = e

            if ( CreatedEntities[ k ] ) then

                CreatedEntities[ k ].BoneMods = table_Copy( v.BoneMods )
                CreatedEntities[ k ].EntityMods = table_Copy( v.EntityMods )
                CreatedEntities[ k ].PhysicsObjects = table_Copy( v.PhysicsObjects )

            else

                CreatedEntities[ k ] = nil

            end

        end

        self.l_NoWeaponSwitch = false

        -- Switch to the toolgun
        self:SwitchWeapon( "toolgun" )

        self.l_NoWeaponSwitch = true

        for EntID, Ent in pairs( CreatedEntities ) do
            if !IsValid( Ent ) then continue end

            if random( 1, 4 ) == 1 then
                local randomvec = VectorRand( -maxslength - 100, maxslength + 100 ) randomvec[ 3 ] = 5

                tracetable.start = self.l_dupeposition + MinsMaxsCenter( self.l_dupedata.Mins, self.l_dupedata.Maxs )
                tracetable.endpos = self.l_dupeposition + randomvec 
                tracetable.collisiongroup = COLLISION_GROUP_WORLD
                tracetable.mask = MASK_SOLID_BRUSHONLY
                local result = Trace( tracetable )

                if !result.Hit then
                    self:MoveToPos( self.l_dupeposition + randomvec  )
                end

            end

            self:LookTo( Ent, 3 )

            coroutine.wait( 1 )
            if !IsValid( Ent ) then continue end

            -- Use the toolgun on the entity
            self:UseWeapon( Ent:WorldSpaceCenter() )

            duplicator.ApplyEntityModifiers( ( game.SinglePlayer() and Entity( 1 ) or self:GetCreator() ), Ent )
            duplicator.ApplyBoneModifiers( ( game.SinglePlayer() and Entity( 1 ) or self:GetCreator() ), Ent )

            if ( Ent.PostEntityPaste ) then
                Ent:PostEntityPaste( ( game.SinglePlayer() and Entity( 1 ) or self:GetCreator() ), Ent, CreatedEntities )
            end

        end

        for k, Constraint in pairs( ConstraintList ) do

            local entity
            ProtectedCall( function() entity = duplicator.CreateConstraintFromTable( Constraint, CreatedEntities, ( game.SinglePlayer() and Entity( 1 ) or self:GetCreator() ) ) end )

            -- Use the toolgun wherever a visible constraint is found. Basically anything that isn't at the origin
            if IsValid( entity ) and entity:GetPos() != Vector() then
                
                -- Random movement again
                if random( 1, 4 ) == 1 then
                    local randomvec = VectorRand( -maxslength - 100, maxslength + 100 ) randomvec[ 3 ] = 5
        
                    tracetable.start = self.l_dupeposition + MinsMaxsCenter( self.l_dupedata.Mins, self.l_dupedata.Maxs )
                    tracetable.endpos = self.l_dupeposition + randomvec 
                    tracetable.collisiongroup = COLLISION_GROUP_WORLD
                    tracetable.mask = MASK_SOLID_BRUSHONLY
                    local result = Trace( tracetable )
        
                    if !result.Hit then
                        self:MoveToPos( self.l_dupeposition + randomvec  )
                    end
        
                end

                self:LookTo( entity, 3 )

                coroutine.wait( 1 )
                if !IsValid( entity ) then continue end
        
                self:UseWeapon( entity:GetPos() )
            end

        end

        -- Unfreeze any frozen unfrozen props that we saved earlier
        for i = 1, #unfrozenents do
            local phys = unfrozenents[ i ] 
            if IsValid( phys ) then phys:EnableMotion( true ) end
        end

        -- The dupe is finished and we can continue with whatever we want to do now
        self.l_NoWeaponSwitch = false
        self:SetState( "Idle" )
    end



end


hook.Add( "LambdaOnInitialize", "lambdabuildingsystem_init", Initialize )