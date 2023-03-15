
AddCSLuaFile()

if CLIENT then

TOOL.Information = {
    { name = "left" },
    { name = "reload" },
}

    
language.Add("tool.lambdadupecreator", "Lambda Dupe Creator")

language.Add("tool.lambdadupecreator.name", "Lambda Dupe Creator")
language.Add("tool.lambdadupecreator.desc", "Creates a Dupe file that Lambda Players can use to build with" )
language.Add("tool.lambdadupecreator.left", "Fire onto a contraption to turn it into a dupe file" )
language.Add("tool.lambdadupecreator.reload", "Switch between Normal Duplicator and Area Copy" )

end

TOOL.Tab = "Lambda Player"
TOOL.Category = "Tools"
TOOL.Name = "#tool.lambdadupecreator"
TOOL.ClientConVar = {
    [ "areacopysize" ] = "1000",
    [ "renderthroughworld" ] = "0"
}


-- Network strings --
if SERVER then
    util.AddNetworkString( "lambdaplayers_buildsystem_savedupe" )
    util.AddNetworkString( "lambdaplayers_buildsystem_enableareacopy" )

end
----------------

-- Locals --

local characters = { "a", "b", "c", "d", "e", "f", "g", "h", "i", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0" }
local IsValid = IsValid
local JSONToTable = util.JSONToTable
local ipairs = ipairs
local TableToJSON = util.TableToJSON
local compress = util.Compress
local decompress = util.Decompress
local string_StripExtension = string.StripExtension
local table_IsEmpty = table.IsEmpty
local random = math.random
local ents_FindInBox = ents.FindInBox
local string_sub = string.sub
local green = Color( 0, 255, 0 )
local table_concat = table.concat
local Angle = Angle
local LocalToWorld = LocalToWorld
local Vector = Vector

local function DataSplit( data )
    local index = 1
    local result = {}
    local buffer = {}

    for i = 0, #data do
        buffer[ #buffer + 1 ] = string_sub( data, i, i )
                
        if #buffer == 32768 then
            result[ #result + 1 ] = table_concat( buffer )
                index = index + 1
            buffer = {}
        end
    end
            
    result[ #result + 1 ] = table_concat( buffer )
    
    return result
end

-------------

local function SaveDupe( dupe, ply )

    local filename = ""
    local chunks = DataSplit( dupe )
    for i = 1, 32 do
        filename = filename .. characters[ random( #characters ) ]
    end 

    LambdaCreateThread( function()
        for k, v in ipairs( chunks ) do
            net.Start( "lambdaplayers_buildsystem_savedupe" )
            net.WriteString( "lambdaplayers/duplications/" .. filename .. ".vmt" )
            net.WriteString( v )
            net.WriteBool( k == #chunks )
            net.Send( ply )

            coroutine.wait( 0.1 )
        end
    end )

end

function TOOL:LeftClick( tr )
    if CLIENT then return end
    local ent = tr.Entity
    local owner = self:GetOwner()

    -- Normal duplicator mode
    if !owner.l_areacopyenabled and IsValid( ent ) then

        local angs = owner:EyeAngles() angs[ 1 ] = 0 angs[ 3 ] = 0

        duplicator.SetLocalAng( angs )
        duplicator.SetLocalPos( tr.HitPos )

        local dupedata = duplicator.Copy( ent )

        duplicator.SetLocalAng( Angle() )
        duplicator.SetLocalPos( Vector() )

        local json
        local ok = pcall( function() json = TableToJSON( dupedata ) end )
        if !ok then owner:ChatPrint( "This contraption contains a Entity that cannot be saved" ) return end

        SaveDupe( json, owner )

    else    -- Area copy mode

        local size = self:GetClientNumber( "areacopysize", 1000 )
        local maxs = LocalToWorld( Vector( size, size, size ), Angle( 0, 0, 0 ), tr.HitPos, Angle( 0, 0, 0 ) )
        local mins = LocalToWorld( Vector( -size, -size, -size ), Angle( 0, 0, 0 ), tr.HitPos, Angle( 0, 0, 0 ) )


        local areacopy = ents_FindInBox( mins, maxs )
        
        for k, v in ipairs( areacopy ) do
            if !duplicator.IsAllowed( v:GetClass() ) or !IsValid( v:GetPhysicsObject() ) then areacopy[ k ] = nil end
        end

        if table_IsEmpty( areacopy ) then return end

        local angs = owner:EyeAngles() angs[ 1 ] = 0 angs[ 3 ] = 0

        duplicator.SetLocalPos( tr.HitPos )
        duplicator.SetLocalAng( angs )

        local dupedata = duplicator.CopyEnts( areacopy )

        duplicator.SetLocalPos( Vector() )
        duplicator.SetLocalAng( Angle() )

        local json
        local ok = pcall( function() json = TableToJSON( dupedata ) end )
        if !ok then owner:ChatPrint( "This contraption contains a Entity that cannot be saved" ) return end

        SaveDupe( json, owner )

    end

    return true
end

function TOOL:Reload()
    if CLIENT then return end
    self:GetOwner().l_areacopyenabled = !self:GetOwner().l_areacopyenabled
    net.Start( "lambdaplayers_buildsystem_enableareacopy" )
    net.WriteEntity( self:GetOwner() )
    net.WriteBool( self:GetOwner().l_areacopyenabled )
    net.Send( self:GetOwner() )
end

function TOOL:Holster()
    if CLIENT then return end
    self:GetOwner().l_areacopyenabled = false
    net.Start( "lambdaplayers_buildsystem_enableareacopy" )
    net.WriteEntity( self:GetOwner() )
    net.WriteBool( false )
    net.Send( self:GetOwner() )
end

function TOOL:Think()

    if CLIENT then

        if self:GetOwner().l_areacopyenabled then
            
            hook.Add( "PostDrawOpaqueRenderables", "LambdaPreviewAreaCopy", function()
                if !self:GetOwner().l_areacopyenabled then hook.Remove( "PostDrawOpaqueRenderables", "LambdaPreviewAreaCopy" ) end
                
                local size = self:GetClientNumber( "areacopysize", 1000 )
                local pos = self:GetOwner():GetEyeTrace().HitPos
                render.DrawWireframeBox( pos, Angle( 0, 0, 0 ), Vector( -size, -size, -size ), Vector( size, size, size ), color_white, self:GetClientNumber( "renderthroughworld", 0 ) != 1 )

                local maxs = LocalToWorld( Vector( size, size, size ), Angle( 0, 0, 0 ), pos, Angle( 0, 0, 0 ) )
                local mins = LocalToWorld( Vector( -size, -size, -size ), Angle( 0, 0, 0 ), pos, Angle( 0, 0, 0 ) )
        
        
                self.primedents = ents_FindInBox( mins, maxs )

                for k, v in ipairs( self.primedents ) do
                    if !IsValid( v ) then continue end
                    v:SetColor( green )

                    timer.Create( "lambdaentityprimed" .. v:EntIndex(), 0.1, 0, function() if !IsValid( v ) then return end v:SetColor( color_white ) end )

                end
            
            end)

        else
            hook.Remove( "PostDrawOpaqueRenderables", "LambdaPreviewAreaCopy" )
        end

    end
    
end


if CLIENT then
    local render = render
    local Material = Material
    local string_Explode = string.Explode

    net.Receive( "lambdaplayers_buildsystem_enableareacopy", function()  
        local ply = net.ReadEntity()
        local bool = net.ReadBool()
        if !IsValid( ply ) then return end
        ply.l_areacopyenabled = bool
    end )

    local function CreateDupeIcon( filename, Dupe )
        if !Dupe then return end
        Dupe = JSONToTable( Dupe )

        hook.Add( "PostRender", "RenderDupeIcon", function() -- Gmod's function to creating a icon for a duplication. We are using this too to make a icon in the data folder so players know what dupe is what via visual reference

            local FOV = 17

            --
            -- This is gonna take some cunning to look awesome!
            --
            local Size = Dupe.Maxs - Dupe.Mins
            local Radius = Size:Length() * 0.5
            local CamDist = Radius / math.sin( math.rad( FOV ) / 2 ) -- Works out how far the camera has to be away based on radius + fov!
            local Center = LerpVector( 0.5, Dupe.Mins, Dupe.Maxs )
            local CamPos = Center + Vector( -1, 0, 0.5 ):GetNormal() * CamDist
            local EyeAng = ( Center - CamPos ):GetNormal():Angle()

            --
            -- The base view
            --
            local view = {
                type	= "3D",
                origin	= CamPos,
                angles	= EyeAng,
                x		= 0,
                y		= 0,
                w		= 512,
                h		= 512,
                aspect	= 1,
                fov		= FOV
            }


            local entities = {}
            local i = 0
            for k, v in pairs( Dupe.Entities ) do

                if ( v.Class == "prop_ragdoll" ) then

                    entities[ k ] = ClientsideRagdoll( v.Model or "error.mdl", RENDERGROUP_OTHER )

                    if ( istable( v.PhysicsObjects ) ) then

                        for boneid, v in pairs( v.PhysicsObjects ) do

                            local obj = entities[ k ]:GetPhysicsObjectNum( boneid )
                            if ( IsValid( obj ) ) then
                                obj:SetPos( v.Pos )
                                obj:SetAngles( v.Angle )
                            end

                        end

                        entities[ k ]:InvalidateBoneCache()

                    end

                else

                    entities[ k ] = ClientsideModel( v.Model or "error.mdl", RENDERGROUP_OTHER )

                end
                i = i + 1

            end

            render.SetMaterial( Material( "lambdaplayers/dupebg.jpg" ) )
            render.DrawScreenQuadEx( 0, 0, 512, 512 )
            render.UpdateRefractTexture()


            --
            -- BLACK OUTLINE
            -- AWESOME BRUTE FORCE METHOD
            --
            render.SuppressEngineLighting( true )

            -- Rendering icon the way we do is kinda bad and will crash the game with too many entities in the dupe
            -- Try to mitigate that to some degree by not rendering the outline when we are above 800 entities
            -- 1000 was tested without problems, but we want to give it some space as 1000 was tested in "perfect conditions" with nothing else happening on the map
            if ( i < 800 ) then
                local BorderSize	= CamDist * 0.004
                local Up			= EyeAng:Up() * BorderSize
                local Right			= EyeAng:Right() * BorderSize

                render.SetColorModulation( 1, 1, 1, 1 )
                render.MaterialOverride( Material( "models/debug/debugwhite" ) )

                -- Render each entity in a circle
                for k, v in pairs( Dupe.Entities ) do

                    for i = 0, math.pi * 2, 0.2 do

                        view.origin = CamPos + Up * math.sin( i ) + Right * math.cos( i )

                        -- Set the skin and bodygroups
                        entities[ k ]:SetSkin( v.Skin or 0 )
                        for bg_k, bg_v in pairs( v.BodyG or {} ) do entities[ k ]:SetBodygroup( bg_k, bg_v ) end

                        cam.Start( view )

                            render.Model( {
                                model	= v.Model,
                                pos		= v.Pos,
                                angle	= v.Angle
                            }, entities[ k ] )

                        cam.End()

                    end

                end

                -- Because we just messed up the depth
                render.ClearDepth()
                render.SetColorModulation( 0, 0, 0, 1 )

                -- Try to keep the border size consistent with zoom size
                local BorderSize	= CamDist * 0.002
                local Up			= EyeAng:Up() * BorderSize
                local Right			= EyeAng:Right() * BorderSize

                -- Render each entity in a circle
                for k, v in pairs( Dupe.Entities ) do

                    for i = 0, math.pi * 2, 0.2 do

                        view.origin = CamPos + Up * math.sin( i ) + Right * math.cos( i )
                        cam.Start( view )

                        render.Model( {
                            model	= v.Model,
                            pos		= v.Pos,
                            angle	= v.Angle
                        }, entities[ k ] )

                        cam.End()

                    end

                end
            end

            --
            -- ACUAL RENDER!
            --

            -- We just fucked the depth up - so clean it
            render.ClearDepth()

            -- Set up the lighting. This is over-bright on purpose - to make the ents pop
            render.SetModelLighting( 0, 0, 0, 0 )
            render.SetModelLighting( 1, 2, 2, 2 )
            render.SetModelLighting( 2, 3, 2, 0 )
            render.SetModelLighting( 3, 0.5, 2.0, 2.5 )
            render.SetModelLighting( 4, 3, 3, 3 ) -- top
            render.SetModelLighting( 5, 0, 0, 0 )
            render.MaterialOverride( nil )

            view.origin = CamPos
            cam.Start( view )

            -- Render each model
            for k, v in pairs( Dupe.Entities ) do

                render.SetColorModulation( 1, 1, 1, 1 )

                -- EntityMods override this
                if ( v._DuplicatedColor ) then render.SetColorModulation( v._DuplicatedColor.r / 255, v._DuplicatedColor.g / 255, v._DuplicatedColor.b / 255, v._DuplicatedColor.a / 255 ) end
                if ( v._DuplicatedMaterial ) then render.MaterialOverride( Material( v._DuplicatedMaterial ) ) end

                if ( istable( v.EntityMods ) ) then

                    if ( istable( v.EntityMods.colour ) ) then
                        render.SetColorModulation( v.EntityMods.colour.Color.r / 255, v.EntityMods.colour.Color.g / 255, v.EntityMods.colour.Color.b / 255, v.EntityMods.colour.Color.a / 255 )
                    end

                    if ( istable( v.EntityMods.material ) ) then
                        render.MaterialOverride( Material( v.EntityMods.material.MaterialOverride ) )
                    end

                end

                render.Model( {
                    model	= v.Model,
                    pos		= v.Pos,
                    angle	= v.Angle
                }, entities[ k ] )

                render.MaterialOverride( nil )

            end

            cam.End()

            -- Enable lighting again (or it will affect outside of this loop!)
            render.SuppressEngineLighting( false )
            render.SetColorModulation( 1, 1, 1, 1 )

            --
            -- Finished with the entities - remove them all
            --
            for k, v in pairs( entities ) do
                v:Remove()
            end

            --
            -- This captures a square of the render target, copies it to a jpg file
            -- and returns it to us as a (binary) string.
            --
            local jpegdata = render.Capture( {
                format		=	"jpg",
                x			=	0,
                y			=	0,
                w			=	512,
                h			=	512,
                quality		=	95
            } )

            file.Write( string_StripExtension( filename ) .. ".jpg", jpegdata )

            hook.Remove("PostRender", "RenderDupeIcon")
        end )   


    end

    local icon
    local editpanel
    local renameentry
    local deletebutton
    local filenamelabel
    local filepath
    local dupename

    local function UpdateCPanel( filename )
        if !IsValid( filenamelabel ) or !IsValid( renameentry ) or !IsValid( icon ) then return end

        LambdaCreateThread( function()
            local mat = Material( "../data/" .. string_StripExtension( filename ) .. ".jpg" )

            while mat:IsError() do
                mat = Material( "../data/" .. string_StripExtension( filename ) .. ".jpg" )
                coroutine.wait( 0.4 )
            end            
            
            icon:SetMaterial( mat )
        end )
        filenamelabel:SetText( "File Name: " .. dupename )

    end

    
    local buildstring = ""
    local receiving = false
    net.Receive( "lambdaplayers_buildsystem_savedupe", function()
        if !receiving then buildstring = "" end
        receiving = true

        local filename = net.ReadString()
        local chunk = net.ReadString()
        local isdone = net.ReadBool()

        buildstring = buildstring .. chunk

        if isdone then
            LAMBDAFS:WriteFile( filename, JSONToTable( buildstring ), "compressed" ) 

            CreateDupeIcon( filename, buildstring )

            local explode = string_Explode( "/", filename )
            filepath = filename
            dupename = string_StripExtension( explode[ #explode ] )

            timer.Simple( 0, function() UpdateCPanel( filename ) end )
            chat.AddText( "Saved contraption to " .. filename )
            receiving = false
        end

    end )


    

    function TOOL.BuildCPanel( panel )

        panel:NumSlider( "Area Copy Size", "lambdadupecreator_areacopysize", 10, 50000, 0 )
        panel:ControlHelp( "The size of the Area Copy Box" )

        panel:CheckBox( "Render Through World", "lambdadupecreator_renderthroughworld" )
        panel:ControlHelp( "If the Area Copy Box should render through the world" )

        panel:Help("\n\n")

        icon = vgui.Create( "DImage", panel )
        icon:SetSize( 400, 400 )
        panel:AddItem( icon )
        
        editpanel = vgui.Create( "EditablePanel", panel )
        editpanel:SetSize( 20, 20 )
        panel:AddItem( editpanel )
    
        panel:Help("\n\n")

        renameentry = vgui.Create( "DTextEntry", editpanel )
        renameentry:SetPlaceholderText( "Rename" )
        renameentry:Dock( LEFT )

        deletebutton = vgui.Create( "DButton", editpanel )
        deletebutton:SetText( "Delete File" )
        deletebutton:Dock( RIGHT )

        filenamelabel = vgui.Create( "DLabel", editpanel )
        filenamelabel:SetText( "File Name: " .. "" )
        filenamelabel:Dock( BOTTOM )

        function renameentry:OnEnter( val )
            if val == "" or !filepath or !dupename then return end

            renameentry:SetText( "" )

            file.Rename( filepath, "lambdaplayers/duplications/" .. val .. ".vmt" )
            file.Rename( string_StripExtension( filepath ) .. ".jpg", "lambdaplayers/duplications/" .. val .. ".jpg" )

            dupename = val
            filepath = "lambdaplayers/duplications/" .. val .. ".vmt"

            UpdateCPanel( "lambdaplayers/duplications/" .. val .. ".vmt" )
        end

        function deletebutton:DoClick()
            if !filepath or !dupename then return end

            file.Delete( filepath )
            file.Delete( string_StripExtension( filepath ) .. ".jpg" )

            filepath = nil
            dupename = nil

            icon:SetMaterial( "nil" )
            filenamelabel:SetText( "File Name: " )

        end


    end


end

