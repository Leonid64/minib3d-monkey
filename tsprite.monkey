Import minib3d

Class TSprite Extends TMesh

	Field angle#
	Field scale_x#=1.0,scale_y#=1.0
	Field handle_x#,handle_y# 
	Field view_mode:Int=1
	Field mat_sp:Matrix = New Matrix
	
	Private
	
	Global temp_mat:Matrix = New Matrix
	
	Public
	
	Method New()
		
		is_sprite = True '' used for sprite batching
		
	End 
	
	Method Delete()
	
	End 

	Method CopyEntity:TEntity(parent_ent:TEntity=Null)
	
		' new sprite
		Local sprite:TSprite=New TSprite
		
		' copy contents of child list before adding parent
		For Local ent:TEntity=Eachin child_list
			ent.CopyEntity(sprite)
		Next
		
		' add parent, add to list
		sprite.AddParent(parent_ent)
		sprite.entity_link = entity_list.EntityListAdd(sprite)
				
		' lists
		
		' add to collision entity list
		If collision_type<>0
			TCollisionPair.ent_lists[collision_type].AddLast(sprite)
		Endif
		
		' add to pick entity list
		If pick_mode<>0
			sprite.pick_link = TPick.ent_list.AddLast(sprite)
		Endif
		
		' update matrix
		If sprite.parent<>Null
			sprite.mat.Overwrite(sprite.parent.mat)
		Else
			sprite.mat.LoadIdentity()
		Endif
		
		' copy entity info
			
		sprite.mat.Multiply(mat)
		
		sprite.px=px
		sprite.py=py
		sprite.pz=pz
		sprite.sx=sx
		sprite.sy=sy
		sprite.sz=sz
		sprite.rx=rx
		sprite.ry=ry
		sprite.rz=rz
		sprite.qw=qw
		sprite.qx=qx
		sprite.qy=qy
		sprite.qz=qz

		sprite.name=name
		sprite.classname=classname
		sprite.order=order
		sprite.hide=False
		sprite.auto_fade=auto_fade
		sprite.fade_near=fade_near
		sprite.fade_far=fade_far
		
		sprite.brush=Null
		sprite.brush=brush.Copy()
		
		sprite.cull_radius=cull_radius
		sprite.radius_x=radius_x
		sprite.radius_y=radius_y
		sprite.box_x=box_x
		sprite.box_y=box_y
		sprite.box_z=box_z
		sprite.box_w=box_w
		sprite.box_h=box_h
		sprite.box_d=box_d
		sprite.collision_type=collision_type
		sprite.pick_mode=pick_mode
		sprite.obscurer=obscurer
	
		' copy mesh info
		
		sprite.no_surfs=no_surfs
		sprite.surf_list=surf_list ' pointer to surf list

		' copy sprite info
		
		sprite.mat_sp.Overwrite(mat_sp)
		sprite.angle=angle
		sprite.scale_x=scale_x
		sprite.scale_y=scale_y
		sprite.handle_x=handle_x
		sprite.handle_y=handle_y
		sprite.view_mode=view_mode

		Return sprite
		
	End 
		
	Function CreateSprite:TSprite(parent_ent:TEntity=Null)

		Local sprite:TSprite=New TSprite
		sprite.classname="Sprite"
		
		sprite.AddParent(parent_ent)
		sprite.entity_link = entity_list.EntityListAdd(sprite)

		' update matrix
		If sprite.parent<>Null
			sprite.mat.Overwrite(sprite.parent.mat)
			sprite.UpdateMat()
		Else
			sprite.UpdateMat(True)
		Endif
		
		Local surf:TSurface=sprite.CreateSurface()
		
		'' create a smaller buffer so we dont have to resize
		surf.vert_coords=FloatBuffer.Create(12)
		surf.vert_tex_coords0=FloatBuffer.Create(8)
		surf.vert_tex_coords1=FloatBuffer.Create(8)
		surf.vert_norm=FloatBuffer.Create(12)
		surf.vert_col=FloatBuffer.Create(16)		
		surf.vert_array_size=4
		surf.tris=ShortBuffer.Create(12)
		surf.tri_array_size=4

		surf.AddVertex(-1,-1,0, 0, 1)
		surf.AddVertex(-1, 1,0, 0, 0)
		surf.AddVertex( 1, 1,0, 1, 0)
		surf.AddVertex( 1,-1,0, 1, 1)
		surf.AddTriangle(0,1,2)
		surf.AddTriangle(0,2,3)
		
		'surf.CropSurfaceBuffers() ''set inital size to 16
		
		
		sprite.EntityFX 1

		Return sprite

	End 

	Function LoadSprite:TSprite(tex_file$,tex_flag=1,parent_ent:TEntity=Null)

		Local sprite:TSprite=CreateSprite(parent_ent)
		
		Local tex:TTexture=TTexture.LoadTexture(tex_file,tex_flag)
		sprite.EntityTexture(tex)
		
		' additive blend if sprite doesn't have alpha or masking flags set
		If tex_flag&2=0 And tex_flag&4=0
			sprite.EntityBlend 3
		Endif
	
		Return sprite

	End 
	
	Method RotateSprite(ang#)
	
		angle=ang
	
	End 
	
	Method ScaleSprite(s_x#,s_y#)
	
		scale_x=s_x
		scale_y=s_y
	
	End 
	
	Method HandleSprite(h_x#,h_y#)
	
		handle_x=h_x
		handle_y=h_y
	
	End 
	
	Method SpriteViewMode(mode)
	
		view_mode=mode
	
	End 
	
	Method Update(cam:TCamera )

		''rolled into main render loop (2012)

		If view_mode<>2
		
			Local x#=mat.grid[3][0]
			Local y#=mat.grid[3][1]
			Local z#=mat.grid[3][2]
		
			temp_mat.Overwrite(cam.mat)
			temp_mat.grid[3][0]=x
			temp_mat.grid[3][1]=y
			temp_mat.grid[3][2]=z
			mat_sp.Overwrite(temp_mat)
			
			If angle<>0.0
				mat_sp.RotateRoll(angle)
			Endif
			
			If scale_x<>1.0 Or scale_y<>1.0
				mat_sp.Scale(scale_x,scale_y,1.0)
			Endif
			
			If handle_x<>0.0 Or handle_y<>0.0
				mat_sp.Translate(-handle_x,-handle_y,0.0)
			Endif
			
		Else
		
			mat_sp.Overwrite(mat)
			
			If scale_x<>1.0 Or scale_y<>1.0
				mat_sp.Scale(scale_x,scale_y,1.0)
			Endif

		Endif
	
	End 

End 





''batchsprites
''
'' these batchsprites are one mesh
''
'' - notes:
'' - may have to add a check that camera position <> origin position. If so, move origin out a touch from camera

Class TBatchSpriteMesh Extends TMesh

	Field surf:TSurface 
	Field free_stack:IntStack ''list of available vertex
	Field num_sprites =0
	Field sprite_list:List<TBatchSprite>
	'Field mat_sp:Matrix = New Matrix
	
	
	Function Create:TBatchSpriteMesh(parent_ent:TEntity=Null)
	
		Local mesh:TBatchSpriteMesh = New TBatchSpriteMesh
		
		mesh.AddParent(parent_ent)
		entity_list.EntityListAdd(mesh)

		' update matrix
		If mesh.parent<>Null
			mesh.mat.Overwrite(mesh.parent.mat)
			mesh.UpdateMat()
		Else
			mesh.UpdateMat(True)
		Endif
		
		mesh.surf = mesh.CreateSurface()
		mesh.surf.ClearSurface()
		mesh.surf.vbo_dyn = True
		mesh.num_sprites = 0
		mesh.free_stack = New IntStack
				'mainlist
				
		mesh.EntityFX 1+2'+32 '' full bright+ use vertex colors + alpha
		mesh.brush.shine=0.0	
				
		mesh.classname = "BatchSpriteMesh"
		'mesh.is_sprite = True 'no
		mesh.is_update = True
		mesh.cull_radius = -999999.0
		
		mesh.sprite_list = New List<TBatchSprite>
	
		Return mesh
	End
	
	Method Update(cam:TCamera)
		
		'' wipe out rotation matrix
		mat.grid[0][0] = 1.0; mat.grid[0][1] = 0.0; mat.grid[0][2] = 0.0
		mat.grid[1][0] = 0.0; mat.grid[1][1] = 1.0; mat.grid[1][2] = 0.0
		mat.grid[2][0] = 0.0; mat.grid[2][1] = 0.0; mat.grid[2][2] = 1.0
		
		TBatchSprite.min_x=999999999.0
		TBatchSprite.max_x=-999999999.0
		TBatchSprite.min_y=999999999.0
		TBatchSprite.max_y=-999999999.0
		TBatchSprite.min_z=999999999.0
		TBatchSprite.max_z=-999999999.0
		
		For Local ent:TEntity = Eachin sprite_list
			
			ent.Update(cam)
			
			surf.reset_vbo=surf.reset_vbo|16
			
		Next
		
		''do our own bounds
		
		If num_sprites>0
		
			Local width#=TBatchSprite.max_x-TBatchSprite.min_x
			Local height#=TBatchSprite.max_y-TBatchSprite.min_y
			Local depth#=TBatchSprite.max_z-TBatchSprite.min_z
	
			' get bounding sphere (cull_radius#) from AABB
			' only get cull radius (auto cull), if cull radius hasn't been set to a negative no. by TEntity.MeshCullRadius (manual cull)
	
			If width>=height And width>=depth
				cull_radius=width
			Else
				If height>=width And height>=depth
					cull_radius=height
				Else
					cull_radius=depth
				Endif
			Endif
			cull_radius=cull_radius * 0.5
			Local crs#=cull_radius*cull_radius
			cull_radius= Sqrt(crs+crs+crs)
		
		
			min_x = TBatchSprite.min_x
			min_y = TBatchSprite.min_y
			min_z = TBatchSprite.min_z
			max_x = TBatchSprite.max_x
			max_y = TBatchSprite.max_y
			max_z = TBatchSprite.max_z

		Else
			''no more sprites in batch, reduce overhead
			surf.ClearSurface()
			free_stack.Clear()
			
		Endif
		
	End
End

Class TBatchSprite Extends TSprite
		
		Field batch_id:Int ''ids start at 1
		Field vertex_id:Int
		Field sprite_link:list.Node<TBatchSprite>
		
		Global min_x:Float, min_y:Float, max_x:Float, max_y:Float, min_z:Float, max_z:Float
		
		Global mainsprite:TBatchSpriteMesh[] = New TBatchSpriteMesh[10]	
		Global total_batch:Int =0
		
		Private
	
		Global temp_mat:Matrix = New Matrix
	
		Public
		
		Method New()
			
			''new batch sprite
						
		End
		
		Method FreeEntity()
			
			mainsprite[batch_id].surf.VertexColor(vertex_id+0, 0,0,0,0)
			mainsprite[batch_id].surf.VertexColor(vertex_id+1, 0,0,0,0)
			mainsprite[batch_id].surf.VertexColor(vertex_id+2, 0,0,0,0)
			mainsprite[batch_id].surf.VertexColor(vertex_id+3, 0,0,0,0)
			
			mainsprite[batch_id].free_stack.Push(vertex_id)
			mainsprite[batch_id].num_sprites -=1
			
			sprite_link.Remove()
			
			If parent
				parent_link.Remove()
				parent=Null
			Endif
			mat=Null
			brush=Null
			
		End
		
		
		Method Copy()
			
			''use CreateSprite(), since they should all be the same
			
		End
		
				
		''
		''add a parent to the entire batch mesh
		''-- position only
		Function BatchSpriteParent(id:Int=0, ent:TEntity,glob:Int=True)
			
			If id = 0 Then id = total_batch
			If id = 0 Then Return
			
			mainsprite[id].EntityParent(ent, glob)
		
		End
		
		''
		''return the sprite batch main mesh entity
		''
		Method BatchSpriteEntity:TEntity()
			
			Return mainsprite[batch_id]
		
		End
		
		''
		''move the batch sprite origin for depth sorting
		''
		Method BatchSpriteOrigin(x:Float,y:Float,z:Float)
			
			mainsprite[batch_id].PositionEntity(x,y,z)
			
		End
		
		Function CreateBatchMesh:TBatchSpriteMesh( batchid:Int )

			While total_batch < batchid Or total_batch =0
			
				total_batch +=1
				If total_batch >= mainsprite.Length() Then mainsprite = mainsprite.Resize(total_batch+5)
		
				mainsprite[total_batch] = TBatchSpriteMesh.Create()
				
			Wend
			
			Return mainsprite[total_batch]
		End


		Function CreateSprite:TBatchSprite(idx:Int=0)
			''add sprite to batch
			'' never added to entity_list
			'' if idx=0 add to last created batch
				
			Local sprite:TBatchSprite=New TBatchSprite
			sprite.classname="BatchSprite"
	
			' update matrix
			If sprite.parent<>Null
				sprite.mat.Overwrite(sprite.parent.mat)
				sprite.UpdateMat()
			Else
				sprite.UpdateMat(True)
			Endif
			
			If idx = 0 Then sprite.batch_id = total_batch Else sprite.batch_id = idx
			If sprite.batch_id = 0 Then sprite.batch_id = 1
			Local id:Int = sprite.batch_id
			
			''create main mesh
			Local mesh:TBatchSpriteMesh
	
			If id > total_batch
			
				mesh = CreateBatchMesh(id)
				If id=0 Then id = 1
				
			Else
			
				mesh = mainsprite[id]
				
			Endif

			''get vertex id
			Local v:Int, v0:Int
			
			If mesh.free_stack.IsEmpty()
				
				mesh.num_sprites +=1
				v = (mesh.num_sprites-1) * 4 ''4 vertex per quad
				
				mesh.surf.AddVertex(-1,-1,0, 0, 1) ''v0
				mesh.surf.AddVertex(-1, 1,0, 0, 0)
				mesh.surf.AddVertex( 1, 1,0, 1, 0)
				mesh.surf.AddVertex( 1,-1,0, 1, 1)
				mesh.surf.AddTriangle(0+v,1+v,2+v)
				mesh.surf.AddTriangle(0+v,2+v,3+v)
				''v isnt guarateed to be v0, but seems to match up

				''since vbo expands, make sure to reset so we dont use subbuffer
				mesh.surf.reset_vbo=-1
				
			Else
			
				v = mesh.free_stack.Pop()
				mesh.num_sprites +=1
				
			Endif
					
			
			mesh.reset_bounds = False ''we control our own bounds
		
			sprite.vertex_id = v
			sprite.sprite_link = mesh.sprite_list.AddLast(sprite)

			Return sprite
	
		End 
		
		
		Function LoadBatchTexture(tex_file$,tex_flag:Int=1,id:Int=0)
			''
			''does not create sprite, just loads texture
			''
			
			If id<=0 Or id>total_batch Then id=total_batch
			If id=0 Then id=1
			
			CreateBatchMesh(id)
	
			Local tex:TTexture=TTexture.LoadTexture(tex_file,tex_flag)
			mainsprite[id].EntityTexture(tex)

			' additive blend if sprite doesn't have alpha or masking flags set
			If tex_flag&2=0 And tex_flag&4=0
			
				mainsprite[id].EntityBlend 3
				
			Endif

	
		End
		
		
		Method Update(cam:TCamera )


			If view_mode<>2
				
				'' add in mainsprite position offset
				
				Local x#=mat.grid[3][0] - mainsprite[batch_id].mat.grid[3][0]
				Local y#=mat.grid[3][1] - mainsprite[batch_id].mat.grid[3][1]
				Local z#=mat.grid[3][2] - mainsprite[batch_id].mat.grid[3][2]
			
				temp_mat.Overwrite(cam.mat)
				temp_mat.grid[3][0]=x
				temp_mat.grid[3][1]=y
				temp_mat.grid[3][2]=z
				mat_sp.Overwrite(temp_mat)

				
				If angle<>0.0
					mat_sp.RotateRoll(angle)
				Endif
				
				If scale_x<>1.0 Or scale_y<>1.0
					mat_sp.Scale(scale_x,scale_y,1.0)
				Endif
				
				If handle_x<>0.0 Or handle_y<>0.0
					mat_sp.Translate(-handle_x,-handle_y,0.0)
				Endif
				
			Else
				
				mat_sp.Overwrite(mat)
			
				If scale_x<>1.0 Or scale_y<>1.0
					mat_sp.Scale(scale_x,scale_y,1.0)
				Endif
				
			Endif
					
			''update main mesh
			
			'' rotate each point corner offset to face the camera with cam_mat
			'' use the mat.x.y.z for position and offset from that
			Local p0:Float[], p1:Float[], p2:Float[], p3:Float[]
			'Local temp_mat:Matrix = mat_sp.Copy() 'Inverse()
			Local o:Float[] = [mat_sp.grid[3][0],mat_sp.grid[3][1],mat_sp.grid[3][2]]
			
			Local m00:Float = mat_sp.grid[0][0]
			Local m01:Float = mat_sp.grid[0][1]
			Local m10:Float = mat_sp.grid[1][0]
			Local m11:Float = mat_sp.grid[1][1]
			Local m02:Float = mat_sp.grid[0][2]
			Local m12:Float = mat_sp.grid[1][2]
			
			'p0 = mat_sp.TransformPoint(-1.0,-1.0,0.0)
			p0 = [-m00 + -m10 + o[0] , -m01 + -m11 + o[1], m02 + m12 - o[2]]		
			'p1 = mat_sp.TransformPoint(-1.0,1.0,0.0)		
			p1 = [-m00 + m10 + o[0] , -m01 + m11 + o[1], m02 - m12 - o[2]]	
			'p2 = mat_sp.TransformPoint(1.0,1.0,0.0)
			p2 = [m00 + m10 + o[0] , m01 + m11 + o[1], -m02 - m12 - o[2]]			
			'p3 = mat_sp.TransformPoint(1.0,-1.0,0.0)
			p3 = [m00 - m10 + o[0] , m01 - m11 + o[1], -m02 + m12 - o[2]]
			
			
			mainsprite[batch_id].surf.VertexCoords(vertex_id+0,p0[0],p0[1],p0[2])
			mainsprite[batch_id].surf.VertexCoords(vertex_id+1,p1[0],p1[1],p1[2])
			mainsprite[batch_id].surf.VertexCoords(vertex_id+2,p2[0],p2[1],p2[2])
			mainsprite[batch_id].surf.VertexCoords(vertex_id+3,p3[0],p3[1],p3[2])
			
			Local r# = brush.red'*brush.alpha
			Local g# = brush.green'*brush.alpha
			Local b# = brush.blue'*brush.alpha
			Local a# = brush.alpha '*0.5
		
			mainsprite[batch_id].surf.VertexColorFloat(vertex_id+0, r,g,b,a)
			mainsprite[batch_id].surf.VertexColorFloat(vertex_id+1, r,g,b,a)
			mainsprite[batch_id].surf.VertexColorFloat(vertex_id+2, r,g,b,a)
			mainsprite[batch_id].surf.VertexColorFloat(vertex_id+3, r,g,b,a)
						
			''determine our own bounds
			
			min_x = Min5(p0[0],p1[0],p2[0],p3[0],min_x )
			min_y = Min5(p0[1],p1[1],p2[1],p3[1],min_y )
			min_z = Min5(p0[2],p1[2],p2[2],p3[2],min_z )
			
			max_x = Max5(p0[0],p1[0],p2[0],p3[0],max_x )
			max_y = Max5(p0[1],p1[1],p2[1],p3[1],max_y )
			max_z = Max5(p0[2],p1[2],p2[2],p3[2],max_z )
			
		End
		
End

Function Min5:Float(a:Float, b:Float, c:Float, d:Float, e:Float)
	
	Local r:Float = a
	Local t:Float = c
	
	If b<r Then r=b
	If d<t Then t=d
	If t<r Then r=t
	
	If r < e Then Return r Else Return e
	
End

Function Max5:Float(a:Float, b:Float, c:Float, d:Float, e:Float)
	
	Local r:Float = a
	Local t:Float = c
	
	If b>r Then r=b
	If d>t Then t=d
	If t>r Then r=t
	
	If r > e Then Return r Else Return e
	
End
