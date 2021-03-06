Import minib3d
Import minib3d.math.vector
Import minib3d.math.geom
Import minib3d.math.matrix

''
''
'' need to rewrite mesh collider
''
'' NOTES:
'' - changed TreeCheck to CreateMeshTree() to reflect what its actually doing
''
'' - need to move createtreemesh() routine to somewhere we can init it in OnCreate() rather than during click time
'' 
'' - collider_tree.tri_verts[] could be a floatbuffer for speed/better cache hits


Const MAX_COLL_TRIS:Int =16 '24 '8'16


Class VecStack Extends Stack<Vector>
	Method Equals : Bool ( lhs:Vector, rhs:Vector )
		Return (lhs.x=rhs.x And lhs.y=rhs.y And lhs.z=rhs.z)
	End
End

Class TColTree
	
	Public
	
	Const ONETHIRD:Float = 1.0/3.0
	Const SQRT2:Float = 1.4142135623
	
	Field reset_col_tree=False
	Field collider_tree:MeshCollider
	
	'Field divSphere_total:Int=0
	Field divSphere_r:Float[1]
	Field divSphere_p:Vector[1] ''offset from center
	
	
	Private
	
	Global searchNode:Node[128]
	
	
	Method New()
	
	
	End Method
	

	' creates a collision tree for a mesh if necessary
	'' -- could we use an alternate/low-poly mesh?
	'' -- start with tris index 1 to remove weird null triangles (where index =0)
	Method CreateMeshTree:MeshCollider(mesh:TMesh, max_tris:Int = MAX_COLL_TRIS )
		
		' if reset_col_tree flag is true clear tree
		If reset_col_tree=True

			If collider_tree<>Null
				collider_tree=Null
			Endif
			reset_col_tree=False
				
		Endif

		If collider_tree=Null

	
			Local total_verts_count:Int=0
			Local vindex:Int=0
			Local triindex:Int =1 ''start at 1 to eliminate null errors
			
			''get total tris and verts so we don't need to resize
			Local total_tris:Int=0, total_verts:Int=0
			
			For Local surf:TSurface =Eachin mesh.surf_list
				total_tris +=surf.no_tris
				total_verts +=surf.no_verts
				
			Next
			
			
			collider_tree =  New MeshCollider(total_verts, total_tris+1) ''mesh_coll
			
			''combine all surfaces and vertex into one array
			Local s:Int=0
			Local temp_vec0:Vector = New Vector()
			Local temp_vec1:Vector = New Vector()
			Local temp_vec2:Vector = New Vector()
			For Local surf:TSurface = Eachin mesh.surf_list
				
				s+=1
				
				Local no_tris:Int =surf.no_tris
				Local no_verts:Int =surf.no_verts
										
				If no_tris<>0
					
					
					
					''SPEEDUP MOD 2/4/2013
					'do vert coords first
					'For Local i:=0 To no_verts-1
						
						'collider_tree.tri_verts[i+total_verts_count].x = surf.vert_data.VertexX(i) 'surf.vert_coords.Peek(i*3+0)
						'collider_tree.tri_verts[i+total_verts_count].y = surf.vert_data.VertexY(i) 'surf.vert_coords.Peek(i*3+1)
						'collider_tree.tri_verts[i+total_verts_count].z = -surf.vert_data.VertexZ(i) '-surf.vert_coords.Peek(i*3+2) ' negate z vert coords
						
					'Next
				
					' inc vert index
					' per tri
					For Local i:=0 To no_tris-1
						
						Local i3% = i*3
						Local v0:Int = surf.tris.Peek(i3+0) '+ total_verts_count
						Local v1:Int = surf.tris.Peek(i3+1) '+ total_verts_count
						Local v2:Int = surf.tris.Peek(i3+2) '+ total_verts_count
						
						' reverse vert order
						Local ti% = triindex*3
						collider_tree.tri_vix[ti+0]= v2 + total_verts_count
						collider_tree.tri_vix[ti+1]= v1 + total_verts_count
						collider_tree.tri_vix[ti+2]= v0 + total_verts_count			
		
						''Add to MeshCollider
						
						'collider_tree.tri_centres[triindex].x = collider_tree.tri_verts[v0].x+collider_tree.tri_verts[v1].x+collider_tree.tri_verts[v2].x
						'collider_tree.tri_centres[triindex].y = collider_tree.tri_verts[v0].y+collider_tree.tri_verts[v1].y+collider_tree.tri_verts[v2].y
						'collider_tree.tri_centres[triindex].z = collider_tree.tri_verts[v0].z+collider_tree.tri_verts[v1].z+collider_tree.tri_verts[v2].z
						
						''SPEEDUP MOD 2/4/2013
						surf.vert_data.GetVertCoords(temp_vec0, v0); temp_vec0.z=-temp_vec0.z
						surf.vert_data.GetVertCoords(temp_vec1, v1); temp_vec1.z=-temp_vec1.z
						surf.vert_data.GetVertCoords(temp_vec2, v2); temp_vec2.z=-temp_vec2.z
						collider_tree.tri_verts[v0 + total_verts_count]=temp_vec0.Copy()
						collider_tree.tri_verts[v1 + total_verts_count]=temp_vec1.Copy()
						collider_tree.tri_verts[v2 + total_verts_count]=temp_vec2.Copy()
						collider_tree.tri_centres[triindex].x = (temp_vec0.x + temp_vec1.x + temp_vec2.x)*ONETHIRD
						collider_tree.tri_centres[triindex].y = (temp_vec0.y + temp_vec1.y + temp_vec2.y)*ONETHIRD
						collider_tree.tri_centres[triindex].z = (temp_vec0.z + temp_vec1.z + temp_vec2.z)*ONETHIRD
						
						'collider_tree.tri_centres[triindex].x = collider_tree.tri_centres[triindex].x*ONETHIRD
						'collider_tree.tri_centres[triindex].y = collider_tree.tri_centres[triindex].y*ONETHIRD
						'collider_tree.tri_centres[triindex].z = collider_tree.tri_centres[triindex].z*ONETHIRD
						
						collider_tree.tris[triindex]=triindex 'i
						collider_tree.tri_surface[triindex] = s '& $0000ffff ''lo byte=surface
						'collider_tree.tri_surface[triindex] = collider_tree.tri_surface[triindex] | (i Shl 16) ''hi byte=realtriindex 
						collider_tree.tri_number[triindex] = i
						
						vindex += 3
						triindex += 1
			
					Next
	
										
					total_verts_count += no_verts
				
				Endif
	
			Next	
			
			''add to nodes
			collider_tree.tree = collider_tree.CreateNode( collider_tree.tris, 0, max_tris )
			collider_tree.tree.name = mesh.classname 'debugging

		Endif
		
		
		Return collider_tree
				
	End 	

	
	Method CreateSphereTree:Void ( mesh:TMesh, idiv:Int, sz:Float=1.0, thresh:Int =0 )
		
		'' sz is percentage, so 1.0 is normal size
		
		If idiv<1 Then Return
		If idiv=1 Then mesh.EntityRadius(); Return
		If idiv>24 Then Error "That may be too large for doing this at this time... div > 24 "
		
		If (Not mesh.col_tree.collider_tree) Then mesh.col_tree.CreateMeshTree(mesh)
		mesh.GetBounds()
		''divide up w/h/d
		
		Local width#=(mesh.max_x-mesh.min_x)
		Local height#=(mesh.max_y-mesh.min_y)
		Local depth#=(mesh.max_z-mesh.min_z)
		
		Local total:int =0
		
		'' take the largest dimension and divide it to get cube size
		Local div# = width/Float(idiv)
		Local axis:Int=0 ''0=width, 1=height, 2=depth
		If height>width Then axis=1; div = height/Float(idiv)
		If depth>height Then axis=2; div = depth/Float(idiv)
	
		'' cube is now div x div x div
		'' get positions of each sphere
		'' may need offsets to center spheres ((div*idiv)-height)/2
		'' -- also handle if mesh is not centered! (max+min)/2
		'Local offset:Vector = New Vector( ((div*idiv)-width)/2 + (mesh.max_x+mesh.min_x)/2,
		' 	((div*idiv)-height)/2 + (mesh.max_y+mesh.min_y)/2,
		'  	((div*idiv)-depth)/2 + (mesh.max_z+mesh.min_z)/2 )
		Local offset:Vector = New Vector( mesh.min_x+(div*idiv)*0.5-mesh.center_x, mesh.min_y+(div*idiv)*0.5-mesh.center_y, mesh.min_z+(div*idiv)*0.5+mesh.center_z)

		'Local colobj:CollisionObject = New CollisionObject() ''not really needed
		Local nullvec:Vector = New Vector(0.0,0.0,0.0)
		
		Local usedTriNode:VecStack = New VecStack
		
		
		Local box:Box = New Box()
		For Local z:Int = 0 To idiv-1
			For Local y:Int = 0 To idiv-1
				For Local x:Int = 0 To idiv-1
					
					Local px# = x*Float(div)+mesh.min_x-offset.x
					Local py# = y*Float(div)+mesh.min_y-offset.y
					Local pz# = z*Float(div)+mesh.min_z-offset.z
					
					If px>mesh.max_x Then Continue
					If py>mesh.max_y Then Continue
					If pz>mesh.max_z Then Continue
					
					Const INF:Float = 0.00001
					box.Clear()
					box.Update( New Vector(px+INF, py+INF, pz+INF))
					box.Update( New Vector(px+div-INF, py+div-INF, pz+div-INF))
'If (box.Overlaps(mesh.col_tree.collider_tree.tree.box))
	'CreateTestBox( box.a, box.b, mesh)
'Endif				
					mesh.col_tree.collider_tree.ClearTriNodeStack()

					''do we have triangles in our box
					If (mesh.col_tree.collider_tree.CollideNodeAABB( box, nullvec, Null, mesh.col_tree.collider_tree.tree) And
						thresh < mesh.col_tree.collider_tree.GetTriNodeTotal )
'Print x+" "+y+" "+z+" ... "+px+" "+py+" "+pz+" .. "+total	
						'Local info:Box = mesh.col_tree.collider_tree.GetTriNodeInfo()
						
						''remove duplicates
						''If Not usedTriNode.Contains( pos )
							'' make a sphere here
							Local pos:Vector = New Vector( px+div*0.5, py+div*0.5, pz+div*0.5 )
							
							#rem
							Local maxw:Float = div
							Local maxh:Float = div
							Local maxd:Float = div
							
							
							''get just the overlap, minimum to div
							'' we know it's overlapping
							If (info.a.x > (px))  Then pos.x = (info.a.x-px)*0.5+pos.x; maxw -=(info.a.x-px)'*0.5
							If (info.a.y > (py))  Then pos.y = (info.a.y-py)*0.5+pos.y; maxh -=(info.a.y-py)'*0.5
							If (info.a.z > (pz))  Then pos.z = (info.a.z-pz)*0.5+pos.z; maxd -=(info.a.z-pz)'*0.5 
							
							If (info.b.x < (px+div))  Then pos.x = (info.b.x-(px+div))*0.5+pos.x ; maxw -=(info.b.x-px)'*0.5
							If (info.b.y < (py+div))  Then pos.y = (info.b.y-(py+div))*0.5+pos.y ; maxh -=(info.b.y-py)'*0.5
							If (info.b.z < (pz+div))  Then pos.z = (info.b.z-(pz+div))*0.5+pos.z ; maxd -=(info.b.z-pz)'*0.5
							
							'Local dd:Float = Max( Max(info[0],info[1]), info[2])*0.5
							Local dd:Float = Max( Max(maxw, maxh), maxd)'*0.5
							Local rad# = Sqrt(dd*dd + dd*dd)
							rad = Sqrt(rad*rad + rad*rad)*sz  ''cubic!
							#end
							
							Local halfdiv# = div*0.5
							Local rad# = halfdiv*SQRT2
							rad = Sqrt(rad*rad + halfdiv*halfdiv) * sz ''cubic!
'Print rad							
							
							AddDivSphere( total, rad, pos )
							total +=1
							
							'usedTriNode.Push( pos )
							
						''Endif
						
					Endif
					
				Next
			Next
		next
		
		
		''place a sphere in that div space
		'' question: should the sphere encompass the div? yes for now
		
		
	End

	
	Method AddDivSphere:Void(s%, r#, vec:Vector )
	
		If s >= divSphere_r.Length
			divSphere_r = divSphere_r.Resize( s+1)
			divSphere_p = divSphere_p.Resize( s+1)
		Endif
		
		divSphere_r[s] = r
		divSphere_p[s] = vec.Copy()
		
		'SortDivSphere()
	End
	
	Method SetDivSphere:Void(s%, r#, vec:Vector )
	
		If s > divSphere_r.Length-1 Then return
		
		divSphere_r[s] = r
		divSphere_p[s] = vec.Copy()
		
		'SortDivSphere()
	End
	
	Method SortDivSphere:Void()
		'' bubble sort spheres, largest first for collision priority
		'' collisions exit on first hit with any divSphere
		'' --- no need, must test all spheres anyways
		
		Local t:Int = divSphere_r.Length()
		Local r:Float, v:Vector
		
		For Local i:Int=0 To t-1
			For Local j:Int = 0 To t-1
				If j=i Then Continue
				
				If (divSphere_r[j]>divSphere_r[i]) And (divSphere_p[j]) And (divSphere_p[i])
					''swap
					r = divSphere_r[j]
					v = divSphere_p[j].Copy()
					
					divSphere_r[j] = divSphere_r[i]
					divSphere_p[j] = divSphere_p[i].Copy()
					
					divSphere_r[i] = r
					divSphere_p[i] = v.Copy()
					
				Endif
			Next
		Next
	End
	
	
	Method DebugSphereTree:Void(mesh:TMesh, alpha:Float=0.1)
		''show the spheres for visual debugging
		
		For Local i:Int=0 To divSphere_r.Length()-1
		'If debug_sphere		
			Local sp:TMesh = CreateSphere(6,mesh)
			sp.EntityAlpha(alpha)
			sp.PaintEntity(255,0,0)
			
			Local pos:Vector = divSphere_p[i]
			If Not pos Then Continue
			
			sp.Position(pos.x,pos.y,pos.z)
			Local sc:Float = Max(Max(mesh.gsx, mesh.gsy),mesh.gsz)
			Local rad:Float = divSphere_r[i]*sc
			sp.Scale(rad,rad,rad, true)
			
			Local tt:TText = CreateText3D(""+i)
			tt.NoSmooth()
			tt.EntityAlpha(0.9)
			tt.EntityParent(sp, false)
			tt.PaintEntity(255,50,50)
			tt.EntityFX 1+32+64
			tt.Scale(rad*0.5,rad*0.5,rad*0.5)
			'Print pos
		'Endif
		Next
		
	End
	
	
	Method DebugNodeTree:Void(mesh:TMesh, lev:Int=0)
		
		If (Not collider_tree) Then collider_tree =  CreateMeshTree( mesh )
		Local node:Node = collider_tree.tree
		Local i:Int=0, j:Int=0, k:Int=0, radius:Float, rr:Float
		
		Local searchNode:Node[255]
		
		While (node)
			
			
			
			If (node.left And node.right) And (node.level<=lev) And (i<254)
				
				If node.level>=lev
					Local c:TMesh = CreateCube(mesh)
					c.Scale(node.box.Width()*0.5,node.box.Height()*0.5,node.box.Depth()*0.5)
					c.Position(node.box.Center().x, node.box.Center().y, node.box.Center().z )
					c.EntityAlpha(0.18)
					c.EntityColor(Rnd()*255,Rnd()*255,Rnd()*255)
					c.Wireframe()
				Endif
				
				searchNode[i] = node.left
				searchNode[i+1] = node.right
				i=i+2
			
			Elseif (node.level > lev)
			Endif
			
			node = searchNode[j]
			j=j+1
		Wend
		
	End
	
	
End


Class AxisPair
	Field value:Int
	Field key:Float
End


Class PairList<AxisPair> Extends List<AxisPair>
	Method Compare(lh:AxisPair, rh:AxisPair)
		If lh.key < rh.key Then Return -1
		Return lh.key > rh.key
	End
End


Class Node
	
	Field name:String ''debugging
	Field box:Box
	Field triangles:Int[]
	Field left:Node
	Field right:Node
	Field level:Int ''debugging
	
End


Class MeshCollider
	
	Public
	
	
	''main mesh info
	Field tri_count:Int
	Field vert_count:Int
	Field tris:Int[] ''tri index  '' one to one
	Field tri_surface:Int[]
	Field tri_number:Int[]
	Field tri_vix:Int[] ''vertex index, tris*3
	Field tri_verts:Vector[] ''vert = tri_verts[tri_index[tris]+0]
	Field tri_centres:Vector[]
	
	''mesh info per node
	Field tree:Node ''was global
	Field leaf_list:List<Node> = New List<Node> ''was global
	
	''to allow the ray (or triangles) to inverse entity scale
	''Field tf_scale:Vector = New Vector
	
	
	''fast ray-box test
	Global ray_line:Line = New Line()
	Field r_invx#, r_invy#, r_invz#, r_sign:Int[3]
	
	Global t_tform:TransformMat ''for testing
	Global test_vec:Vector = New Vector ''for testing
	Global test_line:TMesh
	
	Field ee1:TMesh, ee2:TMesh
	
	Private
	
	Field tri_node_stack:Stack<Node> = New Stack<Node>
	Field l_box:Box = New Box
	Global nullVec:Vector = New Vector(0,0,0)
	
	Public
	
	''creates list of triangle, vertices, and triangle centers, and creates tree node	
	Method New(no_verts:Int, no_tris:Int)
	
		tri_count = no_tris
		vert_count = no_verts
		tris = New Int[no_tris]
		tri_surface = New Int[no_tris]
		tri_number = New Int[no_tris]
		tri_vix = New Int[no_tris*3]
		tri_verts = New Vector[no_verts]
		tri_centres = New Vector[no_tris]
		
		For Local i:=0 To no_verts-1
			tri_verts[i] = New Vector
		Next
		
		For Local i:=0 To no_tris-1
			tri_centres[i] = New Vector
		Next

	End

	
	Method ClearTriNodeStack:Void()
		tri_node_stack.Clear()
	End


	Method CreateNodeBox:Box( tris:Int[] )
		If tris.Length<1 Then Return New Box()

'Print tri_verts[tri_vix[ti+0]]+" "+tri_verts[tri_vix[ti+1]]+" "+tri_verts[tri_vix[ti+2]]
		Local box:Box = New Box( )
		
		For Local k:Int = 0 To tris.Length()-1
		
			If tris[k]<>0 'remove null tri values
				Local ti:int = tris[k]*3
				box.Update( tri_verts[ tri_vix[ti+0] ])
				box.Update( tri_verts[ tri_vix[ti+1] ])
				box.Update( tri_verts[ tri_vix[ti+2] ])
			Endif
			
		Next
'Print box.a+"  "+box.b		
		Return box
	End
	
	Method CreateLeaf:Node( tris:Int[] )
		
		Local c:Node = New Node()
		c.box = CreateNodeBox( tris )
		c.triangles = tris
		leaf_list.AddLast( c )
		c.level = 9999
		
		Return c
		
	End

	''recursive
	'' tris = the first vindex for the tri (NOT the tri index)
	''-- this method overlaps because we're testing centers, so some vertexes will be shared.
	Method CreateNode:Node( tris:Int[], level:Int, max_tris:Int = MAX_COLL_TRIS )
		
		If( tris.Length() <=max_tris ) Return CreateLeaf( tris )
				
		Local c:Node = New Node
		c.box = CreateNodeBox( tris )
		c.level = level
		
		''find longest axis
		Local max:Float = c.box.Width()
		Local axis:Int = 0
		If( c.box.Height() >max ) Then max=c.box.Height(); axis = 1
		If( c.box.Depth() >max ) Then max=c.box.Depth(); axis = 2

	
		''sort by axis
		'' list organize from lowest key to highest key, same as c++ multimap
		'' can't use monkey map, as it will overwrite redundancies
		Local k:Int, tri:Int
		
		Local axis_map:PairList<AxisPair> = New PairList<AxisPair>
		Local num:Int = tris.Length()
		
		Local real_total:int
		
		For k = 0 To num-1
			
			tri = tris[k]
			If tri=0 Then Continue '' catches null values
			
			Local ap:AxisPair = New AxisPair
			If axis = 0
				ap.key= tri_centres[tri ].x; ap.value= tri
			Elseif axis = 1
				ap.key= tri_centres[tri ].y; ap.value= tri
			Else
				ap.key= tri_centres[tri ].z; ap.value= tri
			Endif
			axis_map.AddLast( ap )
			
			real_total+=1
			
		Next
	
		axis_map.Sort() ''by float, low to high using key
		
		''left node
		Local index:Int=0
		Local num_left:Int = real_total*0.5
		Local num_right:Int = real_total - num_left
		Local newtris:Int[num_left+1] ''half and round up
		Local newtris2:Int[num_right+1]
		Local leftset:Int=1, lastval:Int=-1
		
		For Local ap:AxisPair = Eachin axis_map
		
			'If lastval = ap.value Then Print "** "+lastval+" "+index ''finds null values

			If index <= num_left
				newtris[index] = ap.value	
				lastval = ap.value					
			Else
				newtris2[index-num_left-1] = ap.value
				lastval=ap.value
			Endif
			
			index +=1
		Next
		
		c.left = CreateNode( newtris, level+1, max_tris  )		
		c.right = CreateNode( newtris2, level+1, max_tris  )
		
		Return c
	End



	Function TrisIntersect:Bool( a:Vector[], b:Vector[] )
		Local r1:Bool=False, r2:Bool=False
		Local p:Plane, p0:Plane,p1:Plane,p2:Plane
		Local  pb0:Bool=False, pb1:Bool=False, pb2:Bool=False
		
		p= New Plane( a[0],a[1],a[2] )
 
		For Local k:Int = 0 To 2 
			Local l:Line = New Line( b[k],b[(k+1)Mod 3]-b[k] )
			Local t:Float=p.T_Intersect( l )
			If( t<0 Or t>1 ) Continue
			Local i:Vector = l.Multiply(t)
			If( Not pb0 ) Then p0=New Plane( a[0]+p.n,a[1],a[0] );pb0=True 
			If( p0.Distance( i )<0 ) Continue
			If( Not pb1 ) Then  p1=New Plane( a[1]+p.n,a[2],a[1] );pb1=True 
			If( p1.Distance( i )<0 ) Continue
			If( Not pb2 ) Then  p2=New Plane( a[2]+p.n,a[0],a[2] );pb2=True
			If( p2.Distance( i )<0 ) Continue
			r1 = True
			Exit
		Next

		
		''swap a,b
		pb0=False; pb1=False; pb2=False
		p = New Plane( b[0],b[1],b[2] )
		p0=Null;p1=Null;p2=Null
		For Local k:Int = 0 To 2 
			Local l:Line = New Line( a[k],a[(k+1)Mod 3]-a[k] )
			Local t:Float=p.T_Intersect( l )
			If( t<0 Or t>1 ) Continue
			Local i:Vector = l.Multiply(t)
			If( Not pb0 ) Then  p0=New Plane( b[0]+p.n,b[1],b[0] );pb0=True
			If( p0.Distance( i )<0 ) Continue
			If( Not pb1 ) Then  p1=New Plane( b[1]+p.n,b[2],b[1] );pb1=True
			If( p1.Distance( i )<0 ) Continue
			If( Not pb2 ) Then  p2=New Plane( b[2]+p.n,b[0],b[2] );pb2=True
			If( p2.Distance( i )<0 ) Continue
			r2=True 
			Exit
		Next

		
		Return r1 | r2
	End

	
	
	Method PrintNodeTree(nn:Node, lev:Int=0)
		If nn=tree
			Print "tree "+lev+" "+nn.triangles.Length()+" "+nn.box.a+" "+nn.box.b
		Else
			Local s$=""
			For Local i:Int=0 To lev
				s+="-"
			Next
			Print s+" "+lev+" "+nn.triangles.Length()+" "+nn.box.a+" "+nn.box.b
		Endif
		
		If nn.left Then PrintNodeTree(nn.left,lev+1)
		If nn.right Then PrintNodeTree(nn.right,lev+1)
		
		Return
	End
	
	
	''gets the trinode stack info 
	'' info is BOX
	Method GetTriNodeInfo:Box()
		Local n:Int=0
		Local info:Float[] = [0.0,0.0,0.0,0.0,0.0,0.0]
		Local v0:Vector, v1:Vector, v2:Vector
		Local box:Box = New Box()
		
		For Local node:Node = Eachin tri_node_stack

			'n +=1
			'If i <> n Then Continue
			
			
			
			For Local k:Int = 0 To node.triangles.Length()-1
			
				Local tri:Int = node.triangles[k]*3

				v0 = tri_verts[tri_vix[tri+0]]
				v1 = tri_verts[tri_vix[tri+1]]
				v2 = tri_verts[tri_vix[tri+2]]
				
				''we could store the triangle's normal here, speed vs. memory.
			
				''tri box
				box.Update(v0)
				box.Update(v1)
				box.Update(v2)
			Next
		Next
		
		''found i
		If box.a.x < box.INFINITY
			'info = [box.Width(), box.Height(), box.Depth(), box.Center().x, box.Center().y, box.Center().z]
		Endif
		
		Return box
	End


	Method GetTriNodeTotal:int()
		Local total:Int=0
		
		For Local node:Node = Eachin tri_node_stack

			total += node.triangles.Length()

		Next
		Return total
	end



	'' -- iterative
	'' -- box should be a sphere.
	'' -- local object space
	Method CollideNodeAABB:Int( line_box:Box, radius:Vector, curr_coll:CollisionObject, node:Node, check_only:Bool = false )
		
		If node = Null Then Return 0
			
		If (node = tree) And (check_only = False)
			'' node = tree
			ClearTriNodeStack() ''clear when checking base node (tree)

		Endif

'Print line_box+" "+node.box		
		If (Not line_box.Overlaps(node.box)) Then Return 0

		''fast ray-box (big speed imporvement for camera picking, but NOT with spheres)
		If (radius.x = 0.0 And Not RayBoxTest(ray_line, node.box)) Then Return 0
		
		Local hit:Int = 0

		If (node.triangles.Length() <1)
			
			If( node.left ) Then hit = hit | CollideNodeAABB( line_box,radius,curr_coll,node.left )
			If( node.right ) Then hit = hit | CollideNodeAABB( line_box,radius,curr_coll,node.right )
		Else

			hit=1
			If (check_only = False) Then tri_node_stack.Push(node)
			
		Endif

		
		
		Return hit
	
	End
	
	
	Method TriNodeCollide:Int( line_box:Box, line:Line, s_radius:Vector, coll_obj:CollisionObject, scalef:Vector=Null )
				
		Local hit:Int=0
		Local tritest:Int=0
		Local str$
		Local v0:Vector, v1:Vector, v2:Vector, tri_box:Box = New Box()
		'Local size_limit:Float = s_radius.x*0.25
		'Local tri_scale:Float = Min(Min(scalef.x,scalef.y),scalef.z)
		
		For Local node:Node = Eachin tri_node_stack
'str+= "NODEBOX "+node.level+"  "
'Print (line.o.Add(line.d).Length())+" ...  "+(scalef.x+radius.x)
			For Local k:Int = 0 To node.triangles.Length()-1
			
				Local tri:Int = node.triangles[k]*3

				v0 = tri_verts[tri_vix[tri+0]]
				v1 = tri_verts[tri_vix[tri+1]]
				v2 = tri_verts[tri_vix[tri+2]]
				
				''we could store the triangle's normal here, speed vs. memory.
			
				''tri box
				'tri_box= New Box(v0,v1,v2)
				tri_box.a.Overwrite(v0)
				tri_box.b.Overwrite(v0)
				tri_box.Update(v1)
				tri_box.Update(v2)
				
				Local miss:Int=0
				
				If (tri_box.Overlaps(line_box)) ''check boxes
				
'str+= "TRIBOX "+k+"  "	
				If s_radius.x > 0.0001
					
					'Local tri_size:Float = Max( Max( tri_box.Height(), tri_box.Width()), tri_box.Depth() )
					'If 0'size_limit > tri_size*tri_scale
						'' *** EXPERIMENTAL SPEEDUP-- treat small tris as spheres ****
						'If Not coll_obj.SphereCollide( line, 0.0, tri_centres[node.triangles[k]], tri_size*0.5, nullVec ) Then hh=1
					'Else
						If Not coll_obj.SphereTriangle( line, s_radius, v0.Multiply(scalef),v1.Multiply(scalef),v2.Multiply(scalef) ) Then miss=1
'Print "tri hit  "					
						''** experimental speedup ** reduce line_box size to current intersect??
						'If miss=0
							'line_box.Clear()
							'line_box.Update(line.o)
							'line_box.Update(s_radius)
							'line_box.Update(tri_box.a)
							'line_box.Update(tri_box.b)
						'Endif					
						
					
#rem
					If src_coll

						tri_box.Expand(scalef)
						tri_box.a = coll_obj.dst_matrix.Multiply(tri_box.a).Add(coll_obj.dst_matrix.grid[3][0],coll_obj.dst_matrix.grid[3][1],coll_obj.dst_matrix.grid[3][2])
						tri_box.b = coll_obj.dst_matrix.Multiply(tri_box.b).Add(coll_obj.dst_matrix.grid[3][0],coll_obj.dst_matrix.grid[3][1],coll_obj.dst_matrix.grid[3][2])
						''check only, dont mess with stack
						If Not CollideNodeAABB( tri_box, New Vector(1.0,1.0,1.0), coll_obj, src_coll.tree, true) Then Continue
					Endif
#end
					'Endif
					
				Else
					If Not coll_obj.RayTriangle( line, v0.Multiply(scalef),v1.Multiply(scalef),v2.Multiply(scalef) ) Then miss=1
'Print "ray hit  "
				Endif

'Print "! TRIHIT "+line.o+"   "+line.o.Add(line.d)
'DrawTriTest(v0,v1,v2, curr_coll)
'CollisionInfo.test_vec = line.Multiply(curr_coll.time)
	
				If Not miss
					coll_obj.surface=tri_surface[ node.triangles[k] ] ''warning: byte packed
					coll_obj.index= tri_number[ node.triangles[k] ] 'node.triangles[k] ''real tri is in hi-bytes of tri_surface
					'coll_obj.box.Update(tri_box)
					'coll_obj.box.Scale( scalef )
												
					hit += 1
					'' no exit early for hit. or check all triangles and check which time is smallest
				Endif
				
				Endif
				
			Next
		
		Next

#If CONFIG="debug"
If (str.Length()>0) Print str+"~n"
#Endif

		Return hit
	
	End
	
	
	'' test Bounding Box to mesh collider nodes
	Method BoxIntersect:Bool ( box:Box, ent:TEntity )
		'' move box to world coords: position and scale box
		
		'' use box center, move point to ent space, rebuild box
		
		''
	End
	
	
	Method DrawTriTest(v0:Vector, v1:Vector, v2:Vector, colobj:CollisionObject)
		If Not ee2 Then Return
		If Not test_line
			test_line = TMesh.CreateLine(v0,v1)
			test_line.EntityFX 65
			test_line.RotateEntity(90,0,0)
			ee2 = TMesh.CreateLine(v0, v1, 255,10,255)
			ee2.EntityFX 65
			ee2.RotateEntity(90,0,0)
		Endif
		
		test_line.GetSurface(1).VertexCoords(0, v0.x,v0.y,v0.z)
		test_line.GetSurface(1).VertexCoords(1, v1.x,v1.y,v1.z)
		test_line.GetSurface(1).VertexCoords(2, v2.x,v2.y,v2.z)
		
		
		
		Local u# = colobj.coll_u
		Local v# = colobj.coll_v
		Local va:Vector = (v0.Multiply(1-u-v)).Add(v1.Multiply(u)).Add(v2.Multiply(v)) 
		ee2.GetSurface(1).VertexCoords(0, va.x-0.1,va.y,va.z+0.1)
		ee2.GetSurface(1).VertexCoords(1, va.x+0.1,va.y,va.z+0.1)
		ee2.GetSurface(1).VertexCoords(2, va.x,va.y,va.z-0.1)
		
	End
	


	
	''Triangle-Triangle intersect
	Method Intersects:Bool( c:MeshCollider, t:Transform)

		Local a:Vector[][] = New Vector[MAX_COLL_TRIS][3]
		Local b:Vector[] = New Vector[3]
		
		If ( Not(t.Multiply(tree.box).Overlaps(c.tree.box) ) ) Then Return False
		
		For Local p:Node = Eachin leaf_list
			Local box:Box = t.Multiply(p.Box)
			Local tformed:Bool = False
			
			For Local q:Node = Eachin c.leaf_list
			
				If( Not box.Overlaps( q.box)) Then Continue
				If( Not tformed)
					For Local n:Int = 0 To p.triangles.Length()-1
						Local tri:Int = p.triangles[n]*3
						a[n][0] = t.Multiply( tri_verts[tri_vix[tri+0]] )
						a[n][1] = t.Multiply( tri_verts[tri_vix[tri+0]] )
						a[n][2] = t.Multiply( tri_verts[tri_vix[tri+0]] )
					Next
					tformed = True
				Endif
				
				For Local n:Int = 0 To q.triangles.Length()-1
					Local tri:Int = c.triangles[q.triangles[n]] *3
					
					b[0] = c.tri_verts[tri_vix[tri+0]]
					b[1] = c.tri_verts[tri_vix[tri+1]]
					b[2] = c.tri_verts[tri_vix[tri+2]]
					For Local t:Int = 0 To p.triangles.Length()-1
						If TrisIntersect(a[t],b) Then Return True
					Next
				Next
				
			Next
		Next
		
	End


	Method RayBoxSetup( line2:Line )
		ray_line = line2
		
		''setup ray for ray-box, once per ray
		Local ln:Float = 1.0/line2.Length()
		Local dir:Vector = New Vector( (line2.o.x-line2.d.x)*ln,(line2.o.y-line2.d.y)*ln,(line2.o.z-line2.d.z)*ln )
		If ln<> 1.0 Then r_invx = 1.0/dir.x; r_invy = 1.0/dir.y; r_invz = 1.0/dir.z
		
		''optimized
		r_sign[0] = (r_invx < 0)
		r_sign[1] = (r_invy < 0)
		r_sign[2] = (r_invz < 0)
		
	End

	''ray testing
	''ray extends forever from origin
	Method RayBoxTest(li:Line,box:Box)
		
		Local tmin#, tmax#, tymin#, tymax#, tzmin#, tzmax#
		Local bounds:Vector[2]
		
		bounds[0] = box.a
		bounds[1] = box.b

		tmin = (bounds[r_sign[0]].x - li.o.x) * r_invx
		tmax = (bounds[1-r_sign[0]].x - li.o.x) * r_invx
		tymin = (bounds[r_sign[1]].y - li.o.y) * r_invy
		tymax = (bounds[1-r_sign[1]].y - li.o.y) * r_invy
		
		If ( (tmin > tymax) Or (tymin > tmax) ) Return False
		If (tymin > tmin) tmin = tymin
		If (tymax < tmax) tmax = tymax
		
		tzmin = (bounds[r_sign[2]].z - li.o.z) * r_invz
		tzmax = (bounds[1-r_sign[2]].z - li.o.z) * r_invz
		
		If ( (tmin > tzmax) Or (tzmin > tmax) ) Return False
		'If (tzmin > tmin) tmin = tzmin
		'If (tzmax < tmax) tmax = tzmax
		
		'Print tmin+" :: "+tmax
		
		Return True
		'Return ( (tmin < li.o.z) And (tmax > -999999) )
			
	End



	
	
End				


Global boxxxxx1:TMesh
Function CreateTestBox(s:Vector,d:Vector, par:TEntity=null)
	'If Not boxxxxx1 Then boxxxxx1=CreateCube();boxxxxx1.EntityAlpha(0.2);boxxxxx1.EntityColor(255,0,0)
	boxxxxx1=CreateCube(par);boxxxxx1.EntityAlpha(0.2);boxxxxx1.EntityColor(200,250,200)
	Local p:Vector = d.Subtract(s)
	boxxxxx1.PositionEntity(s.x+p.x*0.5,s.y+p.y*0.5,s.z+p.z*0.5)
	boxxxxx1.ScaleEntity(Abs(p.x)*0.5,Abs(p.y)*0.5,Abs(p.z)*0.5)
	boxxxxx1.EntityFX 64
End


