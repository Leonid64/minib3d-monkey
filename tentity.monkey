Import minib3d
Import matrix
Import monkey.math


''NOTES:
'' - use EntityListAdd()
'' - test transform point, using different global matrix approach, not sure if needed or not
'' - added EntityCollision(type,picktype,x, [y,z,w,d,h]) for faster setup
'' -- if you need faster operations on mobile, you'll need a fixed-point math library


Class TEntity
	Const inverse_255:Float = 1.0/255.0

	Global entity_list:EntityList<TEntity> = New EntityList<TEntity>

	Field child_list:EntityList<TEntity> = New EntityList<TEntity>
	Field entity_link:list.Node<TEntity> '' entity_list node, stored for quick removal of entity from list 
	Field parent_link:list.Node<TEntity> '' allows removal from parent's child_list
	Field pick_link:list.Node<TEntity>
	
	Field parent:TEntity
	
	Field mat:Matrix=New Matrix 'global matrix
	Field loc_mat:Matrix = New Matrix ''local matrix 'rot 'trans 'scale
	'Field mat_sp:Matrix ''moved to TSprite
	Field px#,py#,pz#,sx#=1.0,sy#=1.0,sz#=1.0,rx#,ry#,rz#,qw#,qx#,qy#,qz#
	Field gsx#=1.0,gsy#=1.0,gsz#=1.0 ''global scale
	
	Field name$
	Field classname$
	Field hide:Bool =False
	Field order%,alpha_order#
	Field auto_fade%,fade_near#,fade_far#,fade_alpha#

	Field cull_radius#

	Field brush:TBrush=New TBrush
	Field shader_brush:TShaderBrush ''don't forget to fill in copy, etc.

	Field anim:Int ' =1 if mesh contains bone anim data, =2 if vertex anim data
	Field anim_render:Int ' true to render as anim mesh
	Field anim_mode:Int
	Field anim_time#
	Field anim_speed#
	Field anim_seq:Int
	Field anim_trans:Int
	Field anim_dir:Int=1 ' 1=forward, -1=backward
	Field anim_seqs_first:Int[1]
	Field anim_seqs_last:Int[1]
	Field no_seqs:Int=0
	Field anim_update:Int
	
	''collision, pick
	Field radius_x#=1.0,radius_y#=1.0
	Field box_x#=-1.0,box_y#=-1.0,box_z#=-1.0,box_w#=2.0,box_h#=2.0,box_d#=2.0
	
	Field collision_type:Int
	Field no_collisions:Int
	Field collision:TCollisionImpact[]
	Field collision_pair:TCollisionPair = New TCollisionPair
	Field pick_mode%,obscurer%
	
	' used by TCollisions
	Field old_x#
	Field old_y#
	Field old_z#
	
	'' used by TCamera for camera layer
	Field is_cam_layer:Bool = False
	Field cam_layer:TCamera
	
		
	''blitz3d functions-- can be depricated
	Global global_mat:Matrix = New Matrix
	Global tformed_x#
	Global tformed_y#
	Global tformed_z#
	
	''internal temp use
	Private
	
	Global temp_mat:Matrix = New Matrix
	
	Public
	
	
	Method CopyEntity:TEntity(parent_ent:TEntity=Null) Abstract
	
	Method Update(cam:TCamera=Null) Abstract

	Method New()
		
		mat.LoadIdentity()
		loc_mat.LoadIdentity()
		
	End
	
	Method Delete()
	
	End

	Method FreeEntity()
	
		If entity_link Then entity_link.Remove()
		
		' remove from collision entity lists
		If collision_type<>0 collision_pair.ListRemove(Self, collision_type)
		
		' remove from pick entity list
		If pick_mode<>0 Then pick_link.Remove()
		
			
		' free self from parent's child_list
		If parent<>Null
			parent_link.Remove()
		Endif
		
		parent=Null
		mat=New Matrix
		brush=New TBrush
	
		' free children entities
		For Local ent:TEntity =Eachin child_list
			ent.FreeEntity()
			ent=Null
		Next	
		
		child_list.Clear()
	End 

	' Entity movement

	Method PositionEntity(x#,y#,z#,glob=False)
		
		z=-z

		' conv glob to local. x/y/z always local to parent or global if no parent
		If glob=True And parent<>Null
	
			temp_mat=parent.mat.Copy().Inverse()
			'temp_mat.Scale(1/psx,1/psy,1/psz)
			'z=-z
			Local psx#=parent.gsx
			Local psy#=parent.gsy
			Local psz#=parent.gsz
	
			x=(x+parent.mat.grid[3][0])
			y=(y+parent.mat.grid[3][1])
			z=(z+parent.mat.grid[3][2]) '-z
			Local pos:Float[] = temp_mat.TransformPoint(x,y,-z) '+z

			x=(pos[0]+temp_mat.grid[3][0])/(psx*psx) 'pos[0]/psx
			y=(pos[1]+temp_mat.grid[3][1])/(psy*psy) 'pos[1]/psy
			z=(pos[2]-temp_mat.grid[3][2])/(psz*psz) '-pos[2]/psz
			z=-z
			
		Endif
					
		px=x
		py=y
		pz=z

		If parent<>Null
			''global
			'mat.Overwrite(parent.mat)
			'UpdateMat()
			UpdateMatTrans()
		Else
			''local
			'UpdateMat(True)
			UpdateMatTrans(True)
		Endif
		
		If child_list.IsEmpty()<>True Then UpdateChildren(Self,1)

	End 
		
	Method MoveEntity(mx#,my#,mz#)
		
		'mz=-mz 'transformpoint flips this
		
		Local pos:Float[]		

		If gsx<>1.0 Then mx = mx/gsx
		If gsy<>1.0 Then my = my/gsy
		If gsz<>1.0 Then mz = mz/gsz
		
		''rotate the direction
		pos = mat.TransformPoint(mx,my,mz,0.0) ''0 creates an offset, not a point	
		
		px=px+pos[0]
		py=py+pos[1]
		pz=pz+(-pos[2])
		
		If parent<>Null
			''global	
			'mat.Overwrite(parent.mat)
			'UpdateMat() 
			UpdateMatTrans()

		Else
			''Local
			'UpdateMat(True) 
			UpdateMatTrans(True)
		
		Endif
		
		If child_list.IsEmpty()<>True Then UpdateChildren(Self,1)

	End 

	Method TranslateEntity(tx#,ty#,tz#,glob=False)
		
		'Local tx#=x
		'Local ty#=y
		tz=-tz

		' conv glob to local. x/y/z always local to parent or global if no parent
		If glob=True And parent<>Null
						
			'Local temp_mat:Matrix=New Matrix
			temp_mat = parent.mat.Copy().Inverse()
			'temp_mat.LoadIdentity()
			'temp_mat.Rotate(-ax,-ay,-az)
			'temp_mat.Translate(tx,ty,tz)

			tx=temp_mat.grid[3][0]
			ty=temp_mat.grid[3][1]
			tz=temp_mat.grid[3][2]
			
		Endif
		
		px=px+tx
		py=py+ty
		pz=pz+tz

		If parent<>Null
			''global
			'mat.Overwrite(parent.mat)
			'UpdateMat()

			UpdateMatTrans()
		Else
			''local
			'UpdateMat(True)
			UpdateMatTrans(True)
		Endif
		
		If child_list.IsEmpty()<>True Then UpdateChildren(Self,1)

	End 
	
	Method ScaleEntity(x#,y#,z#,glob=False)
		
		sx=x
		sy=y
		sz=z


		' conv glob to local. x/y/z always local to parent or global if no parent
		If glob=True And parent<>Null

			sx = sx/parent.gsx
			sy = sy/parent.gsy
			sz = sz/parent.gsz
	
		Endif

		If parent<>Null	
			gsx=parent.gsx*sx
			gsy=parent.gsy*sy
			gsz=parent.gsz*sz
			'mat.Overwrite(parent.mat)
			'UpdateMat()
			UpdateMatSca()
			
		Else
		
			'UpdateMat(True)
			gsx=sx
			gsy=sy
			gsz=sz
			UpdateMatSca(True)
		Endif
		
		If child_list.IsEmpty()<>True Then UpdateChildren(Self,3)

	End 

	Method RotateEntity(x#,y#,z#,glob=False)
		
		rx=-x
		ry=y
		rz=z
		
		' conv glob to local. pitch/yaw/roll always local to parent or global if no parent
		If glob=True And parent<>Null

			rx=rx+parent.EntityPitch(True)
			ry=ry-parent.EntityYaw(True)
			rz=rz-parent.EntityRoll(True)
		
		Endif
		
		If parent<>Null
		
			'mat.Overwrite(parent.mat)
			'UpdateMat()
			UpdateMatRot()
		Else
		
			'UpdateMat(True)
			UpdateMatRot(True)
		Endif
		
		If child_list.IsEmpty()<>True Then UpdateChildren(Self,0)

	End 

	Method TurnEntity(x#,y#,z#,glob=False)

		' conv glob to local. x/y/z always local to parent or global if no parent
		If glob=True And parent<>Null
			'		
		Endif
				
		rx=rx+(-x)
		ry=ry+y
		rz=rz+z

		If parent<>Null
		
			'mat.Overwrite(parent.mat)
			'UpdateMat()
			UpdateMatRot()
		Else ' glob=true or false
		
			'UpdateMat(True)
			UpdateMatRot(True)
		Endif
		
		If child_list.IsEmpty()<>True Then UpdateChildren(Self)

	End 

	' Function by mongia2
	Method PointEntity(target_ent:TEntity,roll#=0)
		
		Local x#=target_ent.EntityX(True)
		Local y#=target_ent.EntityY(True)
		Local z#=target_ent.EntityZ(True)

		Local xdiff#=Self.EntityX(True)-x
		Local ydiff#=Self.EntityY(True)-y
		Local zdiff#=Self.EntityZ(True)-z

		Local dist22#=Sqrt((xdiff*xdiff)+(zdiff*zdiff))
		Local pitch#=ATan2(ydiff,dist22)
		Local yaw#=ATan2(xdiff,-zdiff)

		Self.RotateEntity pitch,yaw,roll,True

	End 
	
	
	Method AlignToVector(vx:Float,vy:Float,vz:Float, axi:Int=1, rate:Float=1.0)
		
		Local dvec:Vector = New Vector(vx,vy,-vz)
		Local avec:Vector
		Local cvec:Vector
		'Local p1#, p2#, p3#
		
		Local dd# = dvec.Length()
		If dd < 0.0001 Then Return
		dd=1.0/dd
		dvec.Update(dvec.x*dd, dvec.y*dd, dvec.z*dd )
		'dvec = dvec.Normalize()
		
	
		''slerp or lerp between the dvec and the current matrix forward, up, or left axis
		If (axi=1) Then cvec = New Vector(mat.grid[0][0],mat.grid[0][1],mat.grid[0][2])
		If (axi=2) Then cvec = New Vector(mat.grid[1][0],mat.grid[1][1],mat.grid[1][2])
		If (axi=3) Then cvec = New Vector(mat.grid[2][0],mat.grid[2][1],mat.grid[2][2])
		
		cvec = cvec.Normalize()
		
		''lerp is inaccurate, but only on large distances
		If rate>=0.0
			dvec.Update( (cvec.x+dvec.x)*rate+cvec.x, (cvec.y+dvec.y)*rate+cvec.y, (cvec.z+dvec.z)*rate+cvec.z )
			dvec = dvec.Normalize()
		Endif
		
			
		''get axis to get our angle from (b/c rotations start at axis)	

		If (axi=1) Then avec = New Vector(1.0,0.0,0.0)
		If (axi=2) Then avec = New Vector(0.0,1.0,0.0)
		If (axi=3) Then avec = New Vector(0.0,0.0,1.0)
			
		''use axis-angle quat for slerp and convert to matrix,euler
		Local angle:Float = ACos( dvec.Dot(avec) )
		Local axis:Vector = dvec.Cross(avec)


		If angle < 0.00001
			mat.LoadIdentity()
			mat.Scale(sx,sy,sz)
			Return
		Elseif angle > 179.9999
			''flip
			'ent.mat.LoadIdentity()
			axis.Update(0.0,-1.0,0.0)
			angle=179.9
		Endif

		axis = axis.Normalize()

		
		Local c:Float = Cos(angle)
		Local s:Float = Sin(angle)
		Local t:Float = 1.0 - c
		''  axis is normalised, include scaling
		
		'Local new_mat:Matrix = New Matrix
		temp_mat.grid[0][0] = (c + axis.x*axis.x*t) *Self.sx
		temp_mat.grid[1][1] = (c + axis.y*axis.y*t) *Self.sy
		temp_mat.grid[2][2] = (c + axis.z*axis.z*t) *Self.sz
				
		Local tmp1:Float = axis.x*axis.y*t
		Local tmp2:Float = axis.z*s
		temp_mat.grid[1][0] = (tmp1 + tmp2) *Self.sy
		temp_mat.grid[0][1] = (tmp1 - tmp2) *Self.sx
		
		tmp1 = axis.x*axis.z*t
		tmp2 = axis.y*s
		temp_mat.grid[2][0] = (tmp1 - tmp2) *Self.sz
		temp_mat.grid[0][2] = (tmp1 + tmp2) *Self.sx
		
		tmp1 = axis.y*axis.z*t
		tmp2 = axis.x*s
		temp_mat.grid[2][1] = (tmp1 + tmp2) *Self.sz
		temp_mat.grid[1][2] = (tmp1 - tmp2) *Self.sy
		
		temp_mat.grid[3][0] = Self.px
		temp_mat.grid[3][1] = Self.py
		temp_mat.grid[3][2] = Self.pz
		temp_mat.grid[3][3] = 1.0
		
		If parent<>Null
			mat.Overwrite(parent.mat)
			mat.Multiply(temp_mat)
		Else
			mat.Overwrite(temp_mat )
		Endif
		
		rx = mat.GetPitch()
		ry = mat.GetYaw()
		rz = mat.GetRoll()
	
		Self.UpdateChildren(Self)
		
	End
	
	
	' Entity animation
	
	' load anim seq - copies anim data from mesh to self
	
	Method LoadAnimSeq(file:String)
	
		' mesh that we will load anim seq from
		Local mesh:TMesh=TModel.LoadAnimB3D(file)
		
		If anim=False Then Return 0 ' self contains no anim data
		If mesh.anim=False Then Return 0 ' mesh contains no anim data
	
		no_seqs=no_seqs+1
		
		' expand anim_seqs array
		anim_seqs_first=anim_seqs_first[..no_seqs+1]
		anim_seqs_last=anim_seqs_last[..no_seqs+1]
	
		' update anim_seqs array
		anim_seqs_first[no_seqs]=anim_seqs_last[0]
		anim_seqs_last[no_seqs]=anim_seqs_last[0]+mesh.anim_seqs_last[0]
	
		' update anim_seqs_last[0] - sequence 0 is for all frames, so this needs to be increased
		' must be done after updating anim_seqs array above
		anim_seqs_last[0]=anim_seqs_last[0]+mesh.anim_seqs_last[0]
	
		If mesh<>Null
	
			' go through all bones belonging to self
			For Local bone:TBone=Eachin TMesh(Self).bones
			
				' find bone in mesh that matches bone in self - search based on bone name
				Local mesh_bone:TBone=TBone(TEntity(mesh).FindChild(bone.name))
			
				If mesh_bone<>Null
			
					' resize self arrays first so the one empty element at the end is removed
					bone.keys.flags=bone.keys.flags[..bone.keys.flags.length-1]
					bone.keys.px=bone.keys.px[..bone.keys.px.length-1]
					bone.keys.py=bone.keys.py[..bone.keys.py.length-1]
					bone.keys.pz=bone.keys.pz[..bone.keys.pz.length-1]
					bone.keys.sx=bone.keys.sx[..bone.keys.sx.length-1]
					bone.keys.sy=bone.keys.sy[..bone.keys.sy.length-1]
					bone.keys.sz=bone.keys.sz[..bone.keys.sz.length-1]
					bone.keys.qw=bone.keys.qw[..bone.keys.qw.length-1]
					bone.keys.qx=bone.keys.qx[..bone.keys.qx.length-1]
					bone.keys.qy=bone.keys.qy[..bone.keys.qy.length-1]
					bone.keys.qz=bone.keys.qz[..bone.keys.qz.length-1]
					
					' add mesh bone key arrays to self bone key arrays
					bone.keys.frames=anim_seqs_last[0]
					bone.keys.flags=bone.keys.flags+mesh_bone.keys.flags
					bone.keys.px=bone.keys.px+mesh_bone.keys.px
					bone.keys.py=bone.keys.py+mesh_bone.keys.py
					bone.keys.pz=bone.keys.pz+mesh_bone.keys.pz
					bone.keys.sx=bone.keys.sx+mesh_bone.keys.sx
					bone.keys.sy=bone.keys.sy+mesh_bone.keys.sy
					bone.keys.sz=bone.keys.sz+mesh_bone.keys.sz
					bone.keys.qw=bone.keys.qw+mesh_bone.keys.qw
					bone.keys.qx=bone.keys.qx+mesh_bone.keys.qx
					bone.keys.qy=bone.keys.qy+mesh_bone.keys.qy
					bone.keys.qz=bone.keys.qz+mesh_bone.keys.qz
				
				Endif
				
			Next
				
		Endif
		
		mesh.FreeEntity()
		
		Return no_seqs
	
	End 
	
	Method ExtractAnimSeq(first_frame,last_frame,seq=0)
	
		no_seqs=no_seqs+1
	
		' expand anim_seqs array
		anim_seqs_first=anim_seqs_first[..no_seqs+1]
		anim_seqs_last=anim_seqs_last[..no_seqs+1]
	
		' if seq specifed then extract anim sequence from within existing sequnce
		Local offset=0
		If seq<>0
			offset=anim_seqs_first[seq]
		Endif
	
		anim_seqs_first[no_seqs]=first_frame+offset
		anim_seqs_last[no_seqs]=last_frame+offset
		
		Return no_seqs
	
	End 
	
	
	Method Animate(mode:Int=1,speed:Float=1.0,seq:Int=0,trans:Int=0)
	
		anim_mode=mode
		anim_speed=speed
		anim_seq=seq
		anim_trans=trans
		If Not anim_time Then anim_time=anim_seqs_first[seq]
		anim_update=True ' update anim for all modes (including 0)
		
		If trans>0
			anim_time=0
		Endif
		
	End 
	

	Method SetAnimTime(time#, seq%=0)
	
		anim_mode=-1 ' use a mode of -1 for setanimtime
		anim_speed=0
		anim_seq=seq
		anim_trans=0
		anim_time=time
		anim_update=False ' set anim_update to false so UpdateWorld won't animate entity
	
		Local first=anim_seqs_first[anim_seq]
		Local last=anim_seqs_last[anim_seq]
		Local first2last=anim_seqs_last[anim_seq]-anim_seqs_first[anim_seq]
		
		time=time+first ' offset time so that anim time of 0 will equal first frame of sequence
		
		If time>last And first2last>0 ' check that first2last>0 to prevent infinite loop
			Repeat
				time=time-first2last
			Until time<=last
		Endif
		If time<first And first2last>0 ' check that first2last>0 to prevent infinite loop
			Repeat
				time=time+first2last
			Until time>=first
		Endif
		
		If anim = 1 Then TAnimation.AnimateMesh(Self,time,first,last)
		If anim = 2 Then TAnimation.AnimateVertex(Self,time,first,last)
	
		anim_time=time ' update anim_time# to equal time#
	
	End 
	
	Method AnimSeq:Int()
	
		Return anim_seq ' current anim sequence
	
	End 
	
	Method AnimLength:Int()
	
		Return anim_seqs_last[anim_seq]-anim_seqs_first[anim_seq] ' no of frames in anim sequence
	
	End 
	
	Method AnimTime:Float()
	
		' if animation in transition, return 0 (anim_time actually will be somewhere between 0 and 1)
		If anim_trans>0 Then Return 0
		
		' for animate and setanimtime we want to return anim_time starting from 0 and ending at no. of frames in sequence
		If anim_mode>0 Or anim_mode=-1
			Return anim_time-anim_seqs_first[anim_seq]
		Endif
	
		Return 0
	
	End 
	
	Method Animating:Bool()
	
		If anim_trans>0 Then Return True
		If anim_mode>0 Then Return True
		
		Return False
	
	End 
		
	' Entity control
	
	Method EntityColor(r#,g#,b#)
	
		brush.red  =r * inverse_255
		brush.green=g * inverse_255
		brush.blue =b * inverse_255
	
	End 
	
	Method EntityColorFloat(r#,g#,b#)
	
		brush.red  =r
		brush.green=g
		brush.blue =b
	
	End
	
	Method EntityAlpha(a#)
	
		brush.alpha=a
			
	End 
	
	Method EntityShininess(s#)
	
		brush.shine=s
	
	End 
	
	''EntityTexture()
	Method EntityTexture(texture:TTexture,frame=0,index=0)
	
		brush.tex[index]=texture
		brush.u_scale = texture.u_scale
		brush.v_scale = texture.v_scale
		
		If index+1>brush.no_texs Then brush.no_texs=index+1
	
		If frame<0 Then frame=0
		If frame>texture.no_frames-1 Then frame=texture.no_frames-1
		brush.tex_frame=frame
		
		If frame>0 And texture.no_frames>1
			''move texture
			Local x:Int = frame Mod texture.frame_xstep
			Local y:Int =( frame/texture.frame_ystep) Mod texture.frame_ystep
			brush.u_pos = x*texture.frame_ustep
			brush.v_pos = y*texture.frame_vstep
		Endif
	
	End 
	
	
	Method AnimateTexture(frame:Int, loop:Bool=False, i:Int=0)
		
		If Not brush Or Not brush.tex[0] Then Return
		
		Local tf:Int = brush.tex[i].no_frames-1
		Local nframe:Int = tf, bframe:Int = 0
		
		If loop
			nframe = frame Mod tf; bframe = frame - (-frame Mod tf)
		Endif
		
		If frame<0 Then frame=bframe
		If frame>tf Then frame= nframe
		brush.tex_frame=frame
		
		If frame>0 And brush.tex[i].no_frames>1
			''move texture
			Local x:Int = frame Mod brush.tex[i].frame_xstep
			Local y:Int =( frame/brush.tex[i].frame_ystep) Mod brush.tex[i].frame_ystep
			brush.u_pos = x*brush.tex[i].frame_ustep
			brush.v_pos = y*brush.tex[i].frame_vstep
		Endif
		
	End
	
	Method EntityBlend(blend_no%)
	
		brush.blend=blend_no
		
		If TMesh(Self)<>Null
		
			' overwrite surface blend modes with master blend mode
			For Local surf:TSurface=Eachin TMesh(Self).surf_list
				If surf.brush<>Null
					surf.brush.blend=brush.blend
				Endif
			Next
			
		Endif
		
	End 
	
	
	'' EntityFX(fx_no)
	''0: nothing (default)
	''1: full-bright
	''2: use vertex colors instead of brush color
	''4: flatshaded
	''8: disable fog
	''16: disable backface culling
	''32: force alpha-blending
	''64: no depth test
	
	Method EntityFX(fx_no%)
	
		brush.fx=fx_no
		
	End 
	
	Method EntityAutoFade(near#,far#)
	
		auto_fade=True
		fade_near=near
		fade_far=far
	
	End 
	
	Method PaintEntity(bru:TBrush)
	
		brush = bru.Copy()

		If TShaderBrush(bru) = bru
			
			DebugLog "TBrush: shader paint"
			shader_brush = TShaderBrush(bru) '.Copy()
			
		Endif

		
	End 
	
	Method PaintEntityGlobal(bru:TBrush)
	
		brush = bru

		If TShaderBrush(bru) = bru
			
			DebugLog "TBrush: shader paint"
			shader_brush = TShaderBrush(bru) '.Copy()
			
		Endif

		
	End
	
	Method EntityOrder(order_no)
	
		order=order_no

		If TCamera(Self)<>Null
		
			TCamera(Self).cam_link.Remove() 
			
			TCamera.cam_list.EntityListAdd(TCamera(Self) )
			
			TCamera.cam_list.Sort()
		Else	
					
			entity_list.Sort()
			
		Endif

		
	End 
	
	Method ShowEntity()
	
		hide=False
		
	End 

	Method HideEntity()

		hide=True

	End 

	Method Hidden:Bool()
	
		If hide=True Return True
		
		Local ent:TEntity=parent
		While ent<>Null
			If ent.hide=True Return True
			ent=ent.parent
		Wend
		
		Return False
	
	End 

	Method NameEntity(e_name$)
	
		name=e_name
	
	End 
	
	Method EntityParent(parent_ent:TEntity,glob:Int=True)

		'' remove old parent

		' get global values
		Local gpx:Float=EntityX(True)
		Local gpy:Float=EntityY(True)
		Local gpz:Float=EntityZ(True)
		
		Local grx:Float=EntityPitch(True)
		Local gry:Float=EntityYaw(True)
		Local grz:Float=EntityRoll(True)
		
		'Local gsx:Float=EntityScaleX(True) 'gsx is now kept
		'Local gsy:Float=EntityScaleY(True)
		'Local gsz:Float=EntityScaleZ(True)
	
		' remove self from parent's child list
		If parent<>Null
			parent_link.Remove()
			parent=Null
		Endif

		' entity no longer has parent, so set local values to equal global values
		' must get global values before we reset transform matrix with UpdateMat
		px=gpx
		py=gpy
		pz=-gpz
		rx=-grx
		ry=gry
		rz=grz
		'sx=gsx
		'sy=gsy
		'sz=gsz
		
		''
		
		' No new parent
		If parent_ent=Null
			UpdateMat(True)
			Return
		Endif
		
		' New parent
	
		If parent_ent<>Null
			
			If glob=True

				AddParent(parent_ent)
				'UpdateMat()

				PositionEntity(gpx,gpy,gpz,True)
				RotateEntity(grx,gry,grz,True)
				ScaleEntity(gsx,gsy,gsz,True)

			Else
			
				AddParent(parent_ent)
				UpdateMat()
				
			Endif
			
		Endif

	End 
		
	Method AddParent(parent_ent:TEntity)
	
		' self.parent = parent_ent
		parent=parent_ent
		
		' add self to parent_ent child list
		If parent<>Null

			mat.Overwrite(parent.mat)
		
			parent_link = parent.child_list.AddLast(Self)
		
		Endif
		
	End
		
	Method GetParent:TEntity()
	
		Return parent
	
	End 

	' Entity state

	Method EntityX#(glob=False)
	
		If glob=False
		
			Return px
		
		Else
		
			Return mat.grid[3][0]
		
		Endif
	
	End 
	
	Method EntityY#(glob=False)
	
		If glob=False
		
			Return py
		
		Else
		
			Return mat.grid[3][1]
		
		Endif
	
	End 
	
	Method EntityZ#(glob=False)
	
		If glob=False
		
			Return -pz
		
		Else
		
			Return -mat.grid[3][2]
		
		Endif
	
	End 

	Method EntityPitch#(glob=False)
		
		If glob=False
		
			Return -rx
			
		Else
		
			Local ang#=ATan2( mat.grid[2][1],Sqrt( mat.grid[2][0]*mat.grid[2][0]+mat.grid[2][2]*mat.grid[2][2] ) )
			If ang<=0.0001 And ang>=-0.0001 Then ang=0
		
			Return ang
			
		Endif
			
	End 
	
	Method EntityYaw#(glob=False)
		
		If glob=False
		
			Return ry
			
		Else
		
			Local a#=mat.grid[2][0]
			Local b#=mat.grid[2][2]
			If a<=0.0001 And a>=-0.0001 Then a=0
			If b<=0.0001 And b>=-0.0001 Then b=0
			Return ATan2(a,b)
			
		Endif
			
	End 
	
	Method EntityRoll#(glob=False)
		
		If glob=False
		
			Return rz
			
		Else
		
			Local a#=mat.grid[0][1]
			Local b#=mat.grid[1][1]
			If a<=0.0001 And a>=-0.0001 Then a=0
			If b<=0.0001 And b>=-0.0001 Then b=0
			Return ATan2(a,b)
			
		Endif
			
	End 
	
	Method EntityClass$()
		
		Return classname
		
	End 
	
	Method EntityName$()
		
		Return name
		
	End 
	
	Method CountChildren()

		Local no_children=0
		
		For Local ent:TEntity=Eachin child_list

			no_children=no_children+1

		Next

		Return no_children

	End 
	
	Method GetChild:TEntity(child_no)
	
		Local no_children=0
		
		For Local ent:TEntity=Eachin child_list

			no_children=no_children+1
			If no_children=child_no Return ent

		Next

		Return Null
	
	End 
	
	Method FindChild:TEntity(child_name$)
	
		Local cent:TEntity
	
		For Local ent:TEntity=Eachin child_list

			If ent.EntityName()=child_name Return ent

			cent=ent.FindChild(child_name)
			
			If cent<>Null Return cent
	
		Next

		Return Null
	
	End 
	
	' Calls function in TPick
	Method EntityPick:TEntity(range#)
	
		Return TPick.EntityPick(Self,range)
	
	End 
	
	' Calls function in TPick
	Method LinePick:TEntity(x#,y#,z#,dx#,dy#,dz#,radius#=0.0)
	
		Return TPick.LinePick(x,y,z,dx,dy,dz,radius)
	
	End 
	
	' Calls function in TPick
	Method EntityVisible(src_entity:TEntity,dest_entity:TEntity)
	
		Return TPick.EntityVisible(src_entity,dest_entity)
	
	End 
	
	Method EntityDistance#(ent2:TEntity)

		Return Sqrt(Self.EntityDistanceSquared(ent2))

	End 
	
	' Function by Vertex
	Method DeltaYaw#(ent2:TEntity)
	
		Local x#=ent2.EntityX(True)-Self.EntityX(True)
		'Local y#=ent2.EntityY#(True)-Self.EntityY#(True)
		Local z#=ent2.EntityZ(True)-Self.EntityZ(True)
		
		Return -ATan2(x,z)

	End 
	
	' Function by Vertex
	Method DeltaPitch#(ent2:TEntity)
	
		Local x#=ent2.EntityX(True)-Self.EntityX(True)
		Local y#=ent2.EntityY(True)-Self.EntityY(True)
		Local z#=ent2.EntityZ(True)-Self.EntityZ(True)
	
		Return -ATan2(y,Sqrt(x*x+z*z))
	
	End 
	
	Function TFormPoint(x#,y#,z#,src_ent:TEntity,dest_ent:TEntity)
		''this routine could be optimized to help TCamera.EntityInFrustum()
		
		'Local mat:Matrix=global_mat.Copy() '***global***
		temp_mat.Overwrite(global_mat)
	
		If src_ent<>Null

			temp_mat.Overwrite(src_ent.mat)
			temp_mat.Translate(x,y,-z)
			
			x=temp_mat.grid[3][0]
			y=temp_mat.grid[3][1]
			z=-temp_mat.grid[3][2]
		
		Endif

		If dest_ent<>Null

			temp_mat.LoadIdentity()
		
			Local ent:TEntity=dest_ent
			
			Repeat
	
				'temp_mat.Scale(1.0/ent.sx,1.0/ent.sy,1.0/ent.sz)
				'temp_mat.RotateRoll(-ent.rz)
				'temp_mat.RotatePitch(-ent.rx)
				'temp_mat.RotateYaw(-ent.ry)
				temp_mat.FastRotateScale(-ent.rz,-ent.rx,-ent.ry,1.0/ent.sx,1.0/ent.sy,1.0/ent.sz)
				temp_mat.Translate(-ent.px,-ent.py,-ent.pz)																																																																																																																																																																																																																																																																																																																																									

				ent=ent.parent
			
			Until ent=Null
		
			temp_mat.Translate(x,y,-z)
			
			x=temp_mat.grid[3][0]
			y=temp_mat.grid[3][1]
			z=-temp_mat.grid[3][2]
			
		Endif
		
		tformed_x=x
		tformed_y=y
		tformed_z=z
		
	End 

	Function TFormVector(x#,y#,z#,src_ent:TEntity,dest_ent:TEntity)
	
		'Local mat:Matrix=global_mat.Copy() '***global***
		temp_mat.Overwrite(global_mat)
		
		If src_ent<>Null

			temp_mat.Overwrite(src_ent.mat)
			
			temp_mat.grid[3][0]=0
			temp_mat.grid[3][1]=0
			temp_mat.grid[3][2]=0
			temp_mat.grid[3][3]=1
			temp_mat.grid[0][3]=0
			temp_mat.grid[1][3]=0
			temp_mat.grid[2][3]=0
				
			temp_mat.Translate(x,y,-z)
	
			x=temp_mat.grid[3][0]
			y=temp_mat.grid[3][1]
			z=-temp_mat.grid[3][2]
		
		Endif

		If dest_ent<>Null

			temp_mat.LoadIdentity()
			'mat.Translate(x#,y#,z#)
		
			Local ent:TEntity=dest_ent
			
			Repeat
	
				temp_mat.Scale(1.0/ent.sx,1.0/ent.sy,1.0/ent.sz)
				temp_mat.RotateRoll(-ent.rz)
				temp_mat.RotatePitch(-ent.rx)
				temp_mat.RotateYaw(-ent.ry)
				'mat.Translate(-ent.px,-ent.py,-ent.pz)																																																																																																																																																																																																																																																																																																																																									

				ent=ent.parent
			
			Until ent=Null
		
			temp_mat.Translate(x,y,-z)
			
			x=temp_mat.grid[3][0]
			y=temp_mat.grid[3][1]
			z=-temp_mat.grid[3][2]
			
		Endif
		
		tformed_x=x
		tformed_y=y
		tformed_z=z
	
	End 

	Function TFormNormal(x#,y#,z#,src_ent:TEntity,dest_ent:TEntity)

		TEntity.TFormVector(x,y,z,src_ent,dest_ent)
		
		Local uv#=Sqrt((tformed_x*tformed_x)+(tformed_y*tformed_y)+(tformed_z*tformed_z))
		
		tformed_x /=uv
		tformed_y /=uv
		tformed_z /=uv
	
	End 
	
	Function TFormedX#()
	
		Return tformed_x
	
	End 
	
	Function TFormedY#()
	
		Return tformed_y
	
	End 
	
	Function TFormedZ#()
	
		Return tformed_z
	
	End 
	
	Method GetMatElement#(row,col)
	
		Return mat.grid[row][col]
	
	End 
	
	' Entity collision
	
	Method ResetEntity()
	
		no_collisions=0
		collision=collision[..0]
		old_x=EntityX(True)
		old_y=EntityY(True)
		old_z=EntityZ(True)
	
	End 
	
	Method EntityRadius(rx#,ry#=0.0)
	
		radius_x=rx
		If ry=0.0 Then radius_y=rx Else radius_y=ry
	
	End 
	
	Method EntityBox(x#,y#,z#,w#,h#,d#)
	
		box_x=x
		box_y=y
		box_z=z
		box_w=w
		box_h=h
		box_d=d
	
	End 

	Method EntityType(type_no:Int ,recursive=False)
	

		' add to collision entity list if new type no<>0 and not previously added
		If collision_type=0 And type_no<>0
		
			collision_pair.ListAddLast(Self, type_no)
			
		Endif
		
		' remove from collision entity list if new type no=0 and previously added
		If collision_type<>0 And type_no=0
			'ListRemove(TCollisionPair.ent_lists[type_no],Self)
			collision_pair.ListRemove(Self,collision_type)
		Endif


		collision_type=type_no
		
		old_x=EntityX(True)
		old_y=EntityY(True)
		old_z=EntityZ(True)
	
		If recursive=True
		
			For Local ent:TEntity=Eachin child_list
			
				ent.EntityType(type_no,True)
			
			Next
		
		Endif
		
	End 
	

	Method EntityPickMode(no:Int,obscure=True)
	
		' add to pick entity list if new mode no<>0 and not previously added
		If pick_mode=0 And no<>0
			pick_link = TPick.ent_list.AddLast(Self)
		Endif
		
		' remove from pick entity list if new mode no=0 and previously added
		If pick_mode<>0 And no=0
			pick_link.Remove()
		Endif
	
		pick_mode=no
		obscurer=obscure
			
	End 
	
	
	
	Method EntityCollided:TEntity(type_no)
	
		' if self is source entity and type_no is dest entity
		For Local i=1 To CountCollisions()
			If CollisionEntity(i).collision_type=type_no Then Return CollisionEntity(i)
		Next
	
		' if self is dest entity and type_no is src entity
		For Local ent:TEntity=Eachin TCollisionPair.ent_lists[type_no]
			For Local i=1 To ent.CountCollisions()
				If CollisionEntity(i)=Self Then Return ent		
			Next
		Next
	
		Return Null

	End 

	'' NEW -- a faster way to setup collisions
	Method EntityCollision(type_no:Int, pick_mode:Int, x:Float, y:Float=0.0, z:Float=0.0, w:Float=0.0, d:Float=0.0, h:Float=0.0)
		
		EntityType(type_no)
		EntityPickMode(pick_mode)
		
		If Not y Then y=x
		
		If Not z And Not w Then EntityRadius(Abs(x),Abs(y))
		
		If z And w Then EntityBox(x,y,z,w,d,h)
		
	End


	Method CountCollisions()
	
		Return no_collisions
	
	End 
	
	Method CollisionX#(index:Int=1)
	
		If index>0 And index<=no_collisions
		
			Return collision[index-1].x
		
		Endif
	
	End 
	
	Method CollisionY#(index:Int=1)
	
		If index>0 And index<=no_collisions
		
			Return collision[index-1].y
		
		Endif
	
	End 
	
	Method CollisionZ#(index:Int=1)
	
		If index>0 And index<=no_collisions
		
			Return collision[index-1].z
		
		Endif
	
	End 

	Method CollisionNX#(index:Int=1)
	
		If index>0 And index<=no_collisions
		
			Return collision[index-1].nx
		
		Endif
	
	End 
	
	Method CollisionNY#(index:Int=1)
	
		If index>0 And index<=no_collisions
		
			Return collision[index-1].ny
		
		Endif
	
	End 
	
	Method CollisionNZ#(index:Int=1)
	
		If index>0 And index<=no_collisions
		
			Return collision[index-1].nz
		
		Endif
	
	End 
	
	Method CollisionTime#(index:Int=1)
	
		If index>0 And index<=no_collisions
		
			Return collision[index-1].time
		
		Endif
	
	End 
	
	Method CollisionEntity:TEntity(index:Int=1)
	
		If index>0 And index<=no_collisions
		
			Return collision[index-1].ent
		
		Endif
	
	End 
	
	Method CollisionSurface:TSurface(index:Int=1)

		If index>0 And index<=no_collisions And TMesh(Self)

			Return TMesh(Self).GetSurface(collision[index-1].surf)
		
		Endif
	
	End 
	
	Method CollisionTriangle(index:Int=1)
	
		If index>0 And index<=no_collisions
		
			Return collision[index-1].tri
		
		Endif
	
	End 
	
	Method GetEntityType()

		Return collision_type

	End 
	
	' Sets an entity's mesh cull radius
	Method MeshCullRadius(radius#)
	
		' set to negative no. so we know when user has set cull radius (manual cull)
		' a check in TMesh.GetBounds then prevents negative no. being overwritten by a positive cull radius (auto cull)
		cull_radius=-radius
	
	End 
	
	Method EntityScaleXYZ:Float[](glob:Int=False)
		
		Local x:Float=sx, y:Float=sy, z:Float=sz

		If glob And parent<>Null
			
			Local ent:TEntity=Self
						
			Repeat

				x=x*ent.parent.sx
				y=y*ent.parent.sy
				z=z*ent.parent.sz

				ent=ent.parent
									
			Until ent.parent=Null
	
		Endif
		
		Return [x,y,z]
		
	End
	
	Method EntityScaleX#(glob=False)
	
		If glob=True

			If parent<>Null
				
				Local ent:TEntity=Self
					
				Local x#=sx
							
				Repeat
	
					x=x*ent.parent.sx

					ent=ent.parent
										
				Until ent.parent=Null
				
				Return x
		
			Endif

		Endif
		
		Return sx
		
	End 
	
	Method EntityScaleY#(glob=False)
	
		If glob=True

			If parent<>Null
				
				Local ent:TEntity=Self
					
				Local y#=sy
							
				Repeat
	
					y=y*ent.parent.sy

					ent=ent.parent
										
				Until ent.parent=Null
				
				Return y
		
			Endif

		Endif
		
		Return sy
		
	End 
	
	Method EntityScaleZ#(glob=False)
	
		If glob=True

			If parent<>Null
				
				Local ent:TEntity=Self
					
				Local z#=sz
							
				Repeat
	
					z=z*ent.parent.sz

					ent=ent.parent
										
				Until ent.parent=Null
				
				Return z
		
			Endif

		Endif
		
		Return sz
		
	End 


	' Returns an entity's bounding sphere
	Method BoundingSphereNew( bsphere:TBoundingSphere )

		Local x#=EntityX(True)
		Local y#=EntityY(True)
		Local z#=EntityZ(True)

		Local radius#=Abs(cull_radius) ' use absolute value as cull_radius will be negative value if set by MeshCullRadius (manual cull)

		' if entity is mesh, we need to use mesh centre for culling which may be different from entity position
		If TMesh(Self)
		
			' mesh centre
			x=TMesh(Self).min_x
			y=TMesh(Self).min_y
			z=TMesh(Self).min_z
			x=x+(TMesh(Self).max_x-TMesh(Self).min_x)*0.5
			y=y+(TMesh(Self).max_y-TMesh(Self).min_y)*0.5
			z=z+(TMesh(Self).max_z-TMesh(Self).min_z)*0.5
			
			' transform mesh centre into world space
			TFormPoint x,y,z,Self,Null
			x=tformed_x
			y=tformed_y
			z=tformed_z
			
			' radius - apply entity scale
			Local rx#=radius*EntityScaleX(True)
			Local ry#=radius*EntityScaleY(True)
			Local rz#=radius*EntityScaleZ(True)
			If rx>=ry And rx>=rz
				radius=Abs(rx)
			Else If ry>=rx And ry>=rz
				radius=Abs(ry)
			Else
				radius=Abs(rz)
			Endif
		
		Endif

		bsphere.x=x
		bsphere.y=y
		bsphere.z=z
		bsphere.r=radius

	End 
	
	Function  CountAllChildren(ent:TEntity,no_children=0)
		
		Local ent2:TEntity
	
		For ent2=Eachin ent.child_list

			no_children=no_children+1
			
			no_children=TEntity.CountAllChildren(ent2,no_children)

		Next

		Return no_children

	End 
	
	Method GetChildFromAll:TEntity(child_no:Int, no_children:Int=0, ent:TEntity=Null)

		If ent=Null Then ent=Self
		
		Local ent3:TEntity=Null
		
		For Local ent2:TEntity=Eachin ent.child_list

			no_children=no_children+1
			
			If no_children=child_no Then Return ent2
			
			If ent3=Null
			
				ent3=GetChildFromAll(child_no,no_children,ent2)

			Endif

		Next

		Return ent3
			
	End 
	
	' Internal - not recommended for general use
	Private
	
	Method UpdateMat(load_identity:Bool =False)

		If load_identity=True
			mat.LoadIdentity()
		Endif
		
		mat.Translate(px,py,pz)
		mat.Rotate(rx,ry,rz)
		mat.Scale(sx,sy,sz)
	
		If load_identity Then loc_mat.Overwrite(mat)

	End 
	
	Method UpdateMatTrans(load_identity:Bool =False)
		
		If load_identity=False And parent
			''load parent mat
			'mat.Overwrite(parent.mat)
			'mat.Translate(px,py,pz)
			mat.grid[3][0] = parent.mat.grid[0][0]*px + parent.mat.grid[1][0]*py + parent.mat.grid[2][0]*pz + parent.mat.grid[3][0]
			mat.grid[3][1] = parent.mat.grid[0][1]*px + parent.mat.grid[1][1]*py + parent.mat.grid[2][1]*pz + parent.mat.grid[3][1]
			mat.grid[3][2] = parent.mat.grid[0][2]*px + parent.mat.grid[1][2]*py + parent.mat.grid[2][2]*pz + parent.mat.grid[3][2]

		Else
			mat.grid[3][0] = px
			mat.grid[3][1] = py
			mat.grid[3][2] = pz
		Endif
	
		If load_identity Then loc_mat.Overwrite(mat)

	End
	
	Method UpdateMatRot(load_identity:Bool =False)
		
		If load_identity=False And parent
			''load parent mat
			mat.grid[0][0] = parent.mat.grid[0][0]; mat.grid[0][1] = parent.mat.grid[0][1]; mat.grid[0][2] = parent.mat.grid[0][2]
			mat.grid[1][0] = parent.mat.grid[1][0]; mat.grid[1][1] = parent.mat.grid[1][1]; mat.grid[1][2] = parent.mat.grid[1][2]
			mat.grid[2][0] = parent.mat.grid[2][0]; mat.grid[2][1] = parent.mat.grid[2][1]; mat.grid[2][2] = parent.mat.grid[2][2]
			'' no need for translate, only in children
			mat.Rotate(rx,ry,rz)
			mat.Scale(sx,sy,sz)
		Else
			mat.FastRotateScale(rx,ry,rz,sx,sy,sz)
		Endif
	
		If load_identity Then loc_mat.Overwrite(mat)

	End
	
	Method UpdateMatSca(load_identity:Bool =False)
		
		If load_identity=False And parent
			''load parent mat
			mat.grid[0][0] = parent.mat.grid[0][0]; mat.grid[0][1] = parent.mat.grid[0][1]; mat.grid[0][2] = parent.mat.grid[0][2]
			mat.grid[1][0] = parent.mat.grid[1][0]; mat.grid[1][1] = parent.mat.grid[1][1]; mat.grid[1][2] = parent.mat.grid[1][2]
			mat.grid[2][0] = parent.mat.grid[2][0]; mat.grid[2][1] = parent.mat.grid[2][1]; mat.grid[2][2] = parent.mat.grid[2][2]
			mat.Rotate(rx,ry,rz)
			mat.Scale(sx,sy,sz)
		Else
			mat.FastRotateScale(rx,ry,rz,sx,sy,sz)
		Endif
		
		
		If load_identity Then loc_mat.Overwrite(mat)

	End
	
	
 	Public
	
	Function UpdateChildren(ent_p:TEntity, type:Int=0)
		
		For Local ent_c:TEntity=Eachin ent_p.child_list
			
			'ent_c.mat.Overwrite(ent_p.mat)
			If Not type
				ent_c.mat.Overwrite(ent_p.mat)
				ent_c.UpdateMat()
			Elseif type = 1
				ent_c.UpdateMatTrans()
			Elseif type = 2
				ent_c.mat.Overwrite(ent_p.mat)
				ent_c.UpdateMat()
				'ent_c.UpdateMatRot() ''wont update positions	
			Elseif type = 3
				'' update global scale for children
				ent_c.gsx=ent_c.parent.gsx*ent_c.sx
				ent_c.gsy=ent_c.parent.gsy*ent_c.sy
				ent_c.gsz=ent_c.parent.gsz*ent_c.sz
				ent_c.UpdateMatSca()
			Endif
				
			UpdateChildren(ent_c,type)
					
		Next

	End 


	Method EntityDistanceSquared#(ent2:TEntity)

		Local xd# = ent2.mat.grid[3][0]-mat.grid[3][0]
		Local yd# = ent2.mat.grid[3][1]-mat.grid[3][1]
		Local zd# = -ent2.mat.grid[3][2]+mat.grid[3][2]
				
		Return xd*xd + yd*yd + zd*zd
		
	End 

End


Class EntityList<T> Extends List<T>
	
	Method EntityListAdd:list.Node<T>(obj:T)
		' if order>0, drawn first
		' if order<0, drawn last
	
		Local llink:list.Node<T>=Self.FirstNode()
	
		If obj.order>0
			' add entity to start of list
			' entites with order>0 should be added to the start of the list
			
			llink = Self.AddFirst(obj)
			
			Return llink
	
		Else ' put entities with order=0 at back of list, so cameras with order=0 are sorted the same as in B3D

			' add entity to end of list
			' only entites with order<=0 should be added to the end of the list
			
			llink = Self.AddLast(obj)
			
			Return llink

		Endif

	End
	
	Method Compare(lh:T, rh:T)
		''sort by order, high to low
		
		If lh.order > rh.order Then Return -1
		Return lh.order < rh.order
		
	End
	
End


Class TBoundingSphere
	Field x:Float, y:Float, z:Float, r:Float
End
