/* ---------------------------------------------------------------------------------------------------------------------------
<START SCRIPT>
*/ ---------------------------------------------------------------------------------------------------------------------------
global MAX_UniqueFloaterInstance -- Weird naming convention, but the variable's name needs to be truly unique even among other scripts and plugins or else you can break a lot of stuff.
try(closeRolloutFloater MAX_UniqueFloaterInstance) catch()

MAX_UniqueFloaterInstance = newRolloutFloater "MAX Toolbar" 235 144
global MAX_RolloutHeight = 144

global MAX_Functions
(
	struct Functions
	(
		/* ---------------------------------------------------------------------------------------------------------------------------
		<GENERAL UTILITY>
		*/ ---------------------------------------------------------------------------------------------------------------------------
		
		/* ---------------------------------------------------------------------------------------------------------------------------
		<FUNCTION>
		<DOC> Transforms a point3 vector into an array. Note : Only needed in the tri pipeline since polyop already uses arrays rather than vectors.
		Arguments:
			<Point3> vect: A vector.
		Return:
			<Array> Array containing point 3 components. Will always be size 3.
		*/ ---------------------------------------------------------------------------------------------------------------------------	
		public fn VectorToArray vect =	
		(
			#(vect.x as integer, vect.y as integer, vect.z as integer) -- Returns <Point3>.
		),
		
		/* ---------------------------------------------------------------------------------------------------------------------------
		<FUNCTION>
		<DOC>  Gets the tri found under the mouse.
		Arguments:
			<Node> obj : Object where the tri should be located on.
		Return:
			<Int> Returns a face index if one was found. Returns -1 if no face was found.
		*/ ---------------------------------------------------------------------------------------------------------------------------
		public fn GetFaceUnderCursor obj =
		(
			local rmgi = rayMeshGridIntersect()
			rmgi.initialize 100 -- RMGI's precision (how many voxels on width/height/depth).
			rmgi.addnode obj
			rmgi.buildgrid()

			local pRay = mapScreenToWorldRay mouse.pos
			rmgi.intersectray pRay.pos pRay.dir false -- Set to true to enable backfacing.

			local hitIndex = rmgi.getClosestHit()
			local hitFace = rmgi.getHitFace(hitIndex)		
			rmgi.free()
			
			hitFace -- Returns <Int>, -1 if invalid.
		),
		
		/* ---------------------------------------------------------------------------------------------------------------------------
		<FUNCTION>
		<DOC>  Converts the mesh face id to poly face id. Object needs to be an Editable_Poly since function is useless for an Editable_Mesh.
		Arguments:
			<Node> obj : Object that was used to get the meshID.
			<Int> meshID : MeshID that needs to be converted.
		Return:
			<Int> The resulting poly face ID.
		*/ ---------------------------------------------------------------------------------------------------------------------------
		public fn MeshFaceToPolyFace obj meshID =
		(		
			local result = 0
			local index = 0
			for polyID = 1 to polyop.getNumFaces obj while result == 0 do
			(
				index += (polyop.getFaceDeg obj polyID) - 2  -- Mesh ids assume all shapes are tris, so to convert to poly, we have to skip the index values of tris who exist as a part of a poly or ngon.
				
				if (meshID <= index) do
				(
					result = polyID
				)
			)
			
			result -- Return <Int>.
		),
		
		/* ---------------------------------------------------------------------------------------------------------------------------
		<FUNCTION>
		<DOC>  Comparison function for sorting a face array by dot result. Formatted to be used with the qsort function.
		Arguments:
			<Int> face1 : First face to compare.
			<Int> face2 : Second face to compare.
			<Node> obj : Object data is queried from. Is given via qsort declaration.
			<Point3> referenceNormal : Reference normal for the dot function. Is given via qsort declaration.
			<Bool> isPoly : Whether the object being worked on is an Editable_Poly or Editable_Mesh. Is given via qsort declaration.
		Return:
			<Int> -1 if face1 has a smaller dot result than face2. 1 if face2 is smaller or equal than face1.
		*/ ---------------------------------------------------------------------------------------------------------------------------
		public fn CompareFaceNormals face1 face2 obj: referenceNormal: isPoly: = 
		(
			local result = 0
			if (isPoly) then
			(
				local normal1 = polyop.getFaceNormal obj face1
				local normal2 = polyop.getFaceNormal obj face2
				local absdot1 = abs (dot normal1 ReferenceNormal)
				local absdot2 = abs (dot normal2 ReferenceNormal)
				if (absdot1 < absdot2) then
				(
					result = -1
				)
				else
				(
					result = 1
				)
			)
			else
			(
				local normal1 = getFaceNormal obj face1
				local normal2 = getFaceNormal obj face2
				local absdot1 = abs (dot normal1 ReferenceNormal)
				local absdot2 = abs (dot normal2 ReferenceNormal)
				if (absdot1 < absdot2) then
				(
					result = -1
				)
				else
				(
					result = 1  
				)
			)
			result  -- Return <Int>.
		),
		
		
		/* ---------------------------------------------------------------------------------------------------------------------------
		<MATH UTILITY>
		*/ ---------------------------------------------------------------------------------------------------------------------------
		
		/* ---------------------------------------------------------------------------------------------------------------------------
		<FUNCTION>
		<DOC>  Compares two float value to see if they're equal, taking into account an epsilon value for inacuracies.
		Arguments:
			<Float> f1 : First float to compare.
			<Float> f2 : Second float to compare.
			<Float> eps : Defaulted to 0.001f. Margin of error for comparison.
		Return:
			<Float> Value in meters.
		*/ ---------------------------------------------------------------------------------------------------------------------------
		public fn CloseTo f1 f2 eps:0.001 =
		(
			abs(f1 - f2) < eps
		),
		
		/* ---------------------------------------------------------------------------------------------------------------------------
		<FUNCTION>
		<DOC>  Converts 3DS Max's own measurement unit to meters. Function works with multiple variable types.
		Arguments:
			<Float || Point3> unitVal : Value to convert to meters.
		Return:
			<Float || Point3> Value in meters.
		*/ ---------------------------------------------------------------------------------------------------------------------------
		public fn UnitToMeter unitVal =
		(
			unitVal / (units.decodeValue "1m") -- Return <Float || Point3>.
		),
		
		/* ---------------------------------------------------------------------------------------------------------------------------
		<FUNCTION>
		<DOC>  Converts meters to 3DS Max's own measurement unit. Function works with multiple variable types.
		Arguments:
			<Float || Point3> unitVal : Value to convert to unit.
		Return:
			<Float || Point3> Value in unit.
		*/ ---------------------------------------------------------------------------------------------------------------------------
		public fn MeterToUnit meterVal =
		(
			meterVal * (units.decodeValue "1m") -- Returns <Float || Point3>.
		),
		
		/* ---------------------------------------------------------------------------------------------------------------------------
		<FUNCTION>
		<DOC>  Finds a triangle's area using Heron's Formula and the length of all three sides.
		Arguments:
			<Float> side1 : The length of side 1.
			<Float> side2 : The length of side 2.
			<Float> side3 : The length of side 3.
		Return:
			<Float> Area of the triangle.
		*/ ---------------------------------------------------------------------------------------------------------------------------
		public fn TriangleSidesToArea side1 side2 side3 =
		(
			0.25 * sqrt((side1 + side2 + side3) * (-side1 + side2 + side3) * (side1 - side2 + side3) * (side1 + side2 - side3)) -- Returns <Float>
		),
		
		/* ---------------------------------------------------------------------------------------------------------------------------
		<FUNCTION>
		<DOC>  Rotates a 3D value around a central point by a degree value.
		Arguments:
			<Point3> pt : Point to rotate.
			<Point3> center : Central point pt will be rotated around.witha
			<Point3> rot : Values in degree to rotate by.
		Return:
			<Point3> pt after being rotated.
		*/ ---------------------------------------------------------------------------------------------------------------------------
		public fn RotateAroundCenter pt center rot =
		(
			local cosx = cos(rot.x);
			local sinx = sin(rot.x);
			
			local cosy = cos(rot.y);
			local siny = sin(rot.y);
			
			local cosz = cos(rot.z);
			local sinz = sin(rot.z);
			
			local angleX = [cosz * cosx, cosz * sinx * siny - sinz * cosy, cosz * sinx * cosy + sinz * siny]
			local angleY = [sinz * cosx, sinz * sinx * siny + cosz * cosy, sinz * sinx * cosy - cosz * siny]
			local angleZ = [-sinx, cosx * siny, cosx * cosy]
			
			local result = pt - center
			result.x = angleX.x * result.x + angleX.y * result.y + angleX.z * result.z;
			result.y = angleY.x * result.x + angleY.y * result.y + angleY.z * result.z;
			result.z = angleZ.x * result.x + angleZ.y * result.y + angleZ.z * result.z;
			result += center
			
			result -- Returns <Point3>.
		),
		
		/* ---------------------------------------------------------------------------------------------------------------------------
		<FUNCTION>
		<DOC>  Opposite of ComputeBarycentricCoordUsingPoint. Computes a point using barycentric coordinates.
		Arguments:
			<Point3> A B C : Triangle points.
			<Point3> u v : Weights to determine point.
		Return:
			<Point3> Return point with barycentric coordinates.
		*/ ---------------------------------------------------------------------------------------------------------------------------
		public fn ComputePointUsingBarycentricCoord A B C u v =	
		(
			((u * (C - A)) + (v * (B - A))) -- Return <Point3>.
		),
			
		/* ---------------------------------------------------------------------------------------------------------------------------
		<FUNCTION>
		<DOC>  Opposite of ComputePointUsingBarycentricCoord. Uses a point to find the barycentric coordinates.
		Arguments:
			<Point3> A B C : Triangle points.
			<Point3> P : Point used to find coords.
		Return:
			<Point3> Barycentric coordinates in format [u, v, 0].
		*/ ---------------------------------------------------------------------------------------------------------------------------
		public fn ComputeBarycentricCoordUsingPoint A B C P =
		(
			local v0 = C - A
			local v1 = B - A
			local v2 = P - A

			local dot00 = dot v0 v0
			local dot01 = dot v0 v1
			local dot02 = dot v0 v2
			local dot11 = dot v1 v1
			local dot12 = dot v1 v2
			
			local invDenom = 1 / (dot00 * dot11 - dot01 * dot01)
			local u = (dot11 * dot02 - dot01 * dot12) * invDenom
			local v = (dot00 * dot12 - dot01 * dot02) * invDenom
			
			[u,v,0] -- Returns <Point3>.
		),
		
		/* ---------------------------------------------------------------------------------------------------------------------------
		<FUNCTION>
		<DOC>  Returns the dot result between v1 and v2, clamped between -1 and 1.
		Arguments:
			<Point3> v1 : First vector in dot equation.
			<Point3> v2 : Second vector in dot equation.
		Return:
			<Float> Result of the dot equation, clamped. 
		*/ ---------------------------------------------------------------------------------------------------------------------------
		fn GetClampedDot v1 v2 = 
		(
			local dotResult = dot v1 v2
								
			if (dotResult > 1.0) then
			(
				dotResult = 1.0	
			)
			else if (dotResult < -1.0) do
			(
				dotResult = -1.0	
			)
			
			dotResult -- Returns <Float>.
		),
		
		
		/* ---------------------------------------------------------------------------------------------------------------------------
		<GEOMETRY UTILITY>
		*/ ---------------------------------------------------------------------------------------------------------------------------
		
		/* ---------------------------------------------------------------------------------------------------------------------------
		<FUNCTION>
		<DOC>  Get the vertices shared between the two given world-space faces.
		Arguments:
			<Node> obj : Object the vertices are on.
			<Int> f1 : Face index 1.
			<Int> f2 : Face index 2.
			<Bool> isPoly : Whether or not the object is an Editable_Mesh (false) or Editable_Poly (true).
		Return:
			<2D Array> Returns undefined if more or less than 2 values are found. Returns an array containing the vertex indices of both faces, 
			ordered in a way where the shared indices are at the front. Example, return value could be #(#(2, 3, 1, 4),#(4, 3, 1, 2)). 
			This means that, if you get the vertices of the faces from meshop / polyop, f1's 2nd and 3rd vertex in the list are equal to 
			f2's 4th and 3rd value.
		*/ ---------------------------------------------------------------------------------------------------------------------------
		public fn GetCommonGeometryVertices obj f1 f2 isPoly =
		(		
			local result = undefined
			if (f1 != f2) do
			(
				local cEdge1 = #()
				local cEdge2 = #()
				local f1List = undefined
				local f2List = undefined
				if (isPoly) then
				(
					f1List = polyop.getFaceVerts obj f1
					f2List = polyop.getFaceVerts obj f2
				)
				else
				(
					f1List = VectorToArray (getFace obj f1)
					f2List = VectorToArray (getFace obj f2)
				)
				
				for idxf1 = 1 to f1List.count do
				for idxf2 = 1 to f2List.count where f1List[idxf1] == f2List[idxf2] do
				(
					append cEdge1 idxf1
					append cEdge2 idxf2
				)
					
				-- Fill the arrays with the leftover indexes that aren't shared.
				if (cEdge1.count == 2) then
				(
					if (isPoly) then
					(
						-- In poly mode, fill the arrays with any value between 1 and [vert count] that isn't already in it.
						local exists = false
						for idPoly = 1 to f1List.count do
						(
							for idEdge = 1 to cEdge1.count do
							(
								if (cEdge1[idEdge] == idPoly) do
								(
									exists = true
									break
								)
							)
							
							if (not exists) then
							(
								append cEdge1 idPoly
							)
							else
							(
								exists = false
							)
						)
						
						exists = false
						for idPoly = 1 to f2List.count do
						(
							for idEdge = 1 to cEdge2.count do
							(
								if (cEdge2[idEdge] == idPoly) do
								(
									exists = true
									break
								)
							)
							
							if (not exists) then
							(
								append cEdge2 idPoly
							)
							else
							(
								exists = false
							)
						)
					)
					else
					(
						-- In tri mode, doing 6 - both existing values will always give the missing third value.
						append cEdge1 (6 - (cEdge1[1] + cEdge1[2]))
						append cEdge2 (6 - (cEdge2[1] + cEdge2[2]))
					)
					
					result = #(cEdge1, cEdge2)
				)
				else
				(	 
					result = undefined
				)
			)
			result -- Returns <Array>.
		),
		
		
		/* ---------------------------------------------------------------------------------------------------------------------------
		<MAPPING UTILITY>
		*/ ---------------------------------------------------------------------------------------------------------------------------
		
		/* ---------------------------------------------------------------------------------------------------------------------------
		<FUNCTION>
		<DOC> Get all nearby texture vertices. Since one regular vertex doesn't always equal one map vertex, the array will contain every possible related vertices, which can include unwanted vertices. Use the data only if you have ways to check and verify.
		Arguments:
			<Int> vert: Target world-space vertex.
			<Node> obj: Object that contains the vertex (either Editable Mesh or Editable Poly).
			<Int> currentChannel : The map channel where data is queried from.
			<Bool> isPoly : Whether or not the object is an Editable_Mesh (false) or Editable_Poly (true).
		Return:
			<Array> Array containing all related map vertices. Quantity is not certain.
		*/ ---------------------------------------------------------------------------------------------------------------------------	
		public fn GetNearbyTVert vert obj currentChannel isPoly =
		(
			local vertList = #()
			local vertFaceIndexList = #()
			local tVertIndexList = #()
			local tVertFace = #()
			
			if (isPoly) then
			(
				local faceList = polyop.getFacesUsingVert obj vert as array
				for f in faceList do
				(
					vertList = polyop.getFaceVerts obj f
					for indx = 1 to vertList.count where (vertList[indx] == vert) do 
					(
						append vertFaceIndexList indx
					)
				)
				for f = 1 to faceList.count do
				(
					tVertFace = polyop.getMapFace obj currentChannel faceList[f]
					tVert = tVertFace[vertFaceIndexList[f]]
					if((findItem tVertIndexList tVert) == 0) do 
					(
						append tVertIndexList tVert
					)
				)
			)
			else
			(
				local faceList = meshop.getFacesUsingVert obj vert as array
				for f in faceList do
				(
					vertList = VectorToArray (getFace obj f)
					for indx = 1 to vertList.count where(vertList[indx] == vert) do 
					(
						append vertFaceIndexList indx
					)
				)
				for f = 1 to faceList.count do
				(
					tVertFace = VectorToArray (meshop.getMapFace obj currentChannel faceList[f])
					tVert = tVertFace[vertFaceIndexList[f]]
					if((findItem tVertIndexList tVert) == 0) do 
					(
						append tVertIndexList tVert
					)
				)
			)

			tVertIndexList -- Returns <Array>.
		),
		
		/* ---------------------------------------------------------------------------------------------------------------------------
		<FUNCTION>
		<DOC>  Weld two vertices together without moving the attached face. Can cause deformations.
		Arguments:
			<Node> obj : The object the vertices are onto.
			<Int> tv1 : Map vertex 1.
			<Int> tv2 : Map vertex 2.
			<Int> currentChannel : The map channel where data is written to.
		Return:
			<Void> 
		*/ ---------------------------------------------------------------------------------------------------------------------------
		public fn WeldTVerts obj tv1 tv2 currentChannel isPoly =
		(
			if (isPoly == true) then
			(
				local pA = polyop.getMapVert obj currentChannel tv1
				local pB = polyop.getMapVert obj currentChannel tv2
				local vAB = (pB - pA) / 2
				polyop.setMapVert obj currentChannel tv1 (pA + vAB)
			)
			else
			(
				local pA = meshop.getMapVert obj currentChannel tv1
				local pB = meshop.getMapVert obj currentChannel tv2
				local vAB = (pB - pA) / 2
				meshop.setMapVert obj currentChannel tv1 (pA + vAB)
			)
		),
		
		/* ---------------------------------------------------------------------------------------------------------------------------
		<FUNCTION>
		<DOC>  Adds a map onto the object, places the gizmo's position matrix in the center and resizes it based on gives arguments.
		Arguments:
			<Float len : Length of the new UVW map.
			<Float> width : Width of the new UVW map.
			<Float> height : Height of the new UVW map.
			<Int> type : Type of UVW map to add to the object.
			<Node> obj : Selected object to add a map onto.
			<Bool> isPoly : If the selected object is an Editable_Poly or Editable_Mesh.
		Return:
			<Void> 
		*/ ---------------------------------------------------------------------------------------------------------------------------
		fn AddMapAndResize len width height type obj isPoly =
		(
			local sel = obj
			
			if (isPoly != undefined) do
			(
				local faces = #()
				local normal = undefined
				
				local matrix = undefined
				
				if (isPoly) then
				(
					for obj in selection where canConvertTo obj mesh do
					(
						convertTo obj PolyMeshObject
					)
					
					local sol = subObjectLevel
					subObjectLevel = 4 -- Just making sure the faces we obtain are the right one by placing the modifier panel in poly selection mode.
					
					local faceBits = polyop.getFaceSelection sel
					
					if (faceBits != undefined and faceBits.numberSet > 0) then
					(
						faces = faceBits as array
					)
					else
					(
						subObjectLevel = sol
						local faceNum = polyop.getNumFaces sel
						faces = (#{1..faceNum}) as array
					)
					
					normal = [0, 0, 0]
					for face in faces do
					(
						normal += polyop.getFaceNormal sel face
					)
					
					normal = in coordsys sel (normal / faces.count)
					
					local worldup = [0, 0, 1]
					local right = normalize(cross worldup normal)
					local up = normalize(cross right normal)
					
					matrix = matrix3 right up normal [0, 0, 0]
				)
				else
				(
					for obj in selection where canConvertTo obj mesh do
					(
						convertTo obj TriMeshGeometry
					)
					
					subObjectLevel = 4 -- Just making sure the faces we obtain are the right one by placing the modifier panel in poly selection mode.
					
					local faceBits = getFaceSelection sel
					
					if (faceBits != undefined and faceBits.numberSet > 0) then
					(
						faces = faceBits as array
					)
					else
					(
						subObjectLevel = sol
						local faceNum = meshop.getNumFaces sel
						faces = (#{1..faceNum}) as array
					)
					
					normal = [0, 0, 0]
					for face in faces do
					(
						normal += getFaceNormal sel face
					)
					
					normal = in coordsys sel (normal / faces.count)
					
					local worldup = [0, 0, 1]
					local right = normalize(cross worldup normal)
					local up = normalize(cross right normal)
					
					matrix = matrix3 right up normal [0, 0, 0]
				)
				
				modPanel.addModToSelection(UVWMap()) ui:on
				
				local map = undefined
				for m in sel.modifiers where classof m == UVWMap do
				(
					map = m
				)
				
				map.gizmo.transform = matrix
				map.width = MAX_Functions.MeterToUnit width
				map.length = MAX_Functions.MeterToUnit len
				map.height = MAX_Functions.MeterToUnit height
				map.maptype = type
			)
		),
		
		/* ---------------------------------------------------------------------------------------------------------------------------
		<FUNCTION>
		<DOC>  Resize the selection to fit the given pixel ratio. Note : Only supported by Editable_Poly.
		Arguments:
			<Float> uvWidth : How big the UV's width should be for 1 meter.
			<Float> uvHeight : How big the UV's height should be for 1 meter.
			<Node> obj : Object containing the face to resize.
			<Modifier> unwrap : Unwrap UVW modifier used for resizing.
			<Bool> isPoly : If the selected object is an Editable_Poly or Editable_Mesh.
			<Bool> moveToCenter : If the resized face cluster should be moved at the center of the UV map.
		Return:
			<Bool> If the operation had error during it. 
		*/ ---------------------------------------------------------------------------------------------------------------------------	
		fn ResizeToRatio uvWidth uvHeight obj unwrap isPoly moveToCenter =
		(
			undo "Ratio" on
			(
				local result = true
				
				local finalType = undefined -- 1 : Vert, 2 : Edge, 3 : Face.
				if (subObjectLevel <= 3 and subObjectLevel > 0) do
				(
					finalType = subObjectLevel
				)
				
				if (obj != undefined and subObjectLevel == 3 and unwrap != undefined and isPoly == true) then
				(
					local vertices = #()
					local selectedFacesBits = unwrap.getSelectedFaces()
					local selectedFaces = selectedFacesBits as array
					
					for f in selectedFaces do
					(
						vertices = polyop.getFaceVerts obj f
						
						if (vertices.count >= 2 and vertices.count <= 4) then
						(						
							local oldRot = obj.rotation.controller.value
							obj.rotation.controller.value = quat 0 0 0 1
							
							local pA = polyop.getVert obj vertices[1]
							local pB = polyop.getVert obj vertices[2]
							
							local normalVector = normalize(in coordsys obj (polyop.getFaceNormal obj f))
							local upVector = undefined
							
							if (normalVector == [0, 0, 1] or normalVector == [0, 0, -1]) then -- Math breaks when cross returns [0,0,0]
							(
								upVector = cross (cross normalVector ([1,0,0])) normalVector
							)
							else
							(
								upVector = cross (cross normalVector ([0,0,1])) normalVector
							)
							upVector = normalize(upVector)
							local rightVector = normalize(cross upVector normalVector)
							local transVector = pA - (coordsys world obj.pos)
							local faceInvMatrix = inverse (matrix3 rightVector upVector normalVector transVector)
							-- Transform ------------------------------------------------------------------------------------------------------------------------------
							local faceTransformed = #()
							for i = 1 to vertices.count do
							(
								append faceTransformed ((polyop.getVert obj vertices[i]) * faceInvMatrix)
							)
							
							obj.rotation.controller.value = oldRot
							
							-- Find the width and height of the geometry.
							local leftPos = undefined
							local rightPos = undefined
							local upPos = undefined
							local downPos = undefined
								
							for i = 1 to vertices.count do
							(
								local pos = faceTransformed[i]
								
								if (leftPos == undefined or pos.x < leftPos) do
								(
									leftPos = pos.x
								)
								
								if (rightPos == undefined or pos.x > rightPos) do
								(
									rightPos = pos.x
								)
								
								if (upPos == undefined or pos.y > upPos) do
								(
									upPos = pos.y
								)
								
								if (downPos == undefined or pos.y < downPos) do
								(
									downPos = pos.y
								)
							)
							
							-- All math done by Max is done in whatever Unit it uses, but our math requires meters (for the curious, I calculated ~40U = 1m)						
							leftPos = MAX_Functions.UnitToMeter leftPos
							rightPos = MAX_Functions.UnitToMeter rightPos
							upPos = MAX_Functions.UnitToMeter upPos
							downPos = MAX_Functions.UnitToMeter downPos
							
							local width = rightPos - leftPos
							
							if (width == 0.0) do --It shouldn't happen, but in that case, we don't wanna ruin the ratio too much.
							(
								width = 0.01
							)
							
							local height = upPos - downPos
							
							if (height == 0.0) do -- Same here but even worse, if it equals 0, we divide by 0.
							(
								height = 0.01
							)
							
							-- Find the "bounding box" of the map.
							-- Since we have no way of knowing if the map's face is oriented properly, we have to calculate the bounding box in another way.
							-- We're running on a few assumptions. Mainly that, since we ask the artist to pick the face that is as close in map as in geometry in terms of size, we assume they will do so.
							-- By calculating every possible triangles inside of a face, we can find a width and height that has the closest ratio to the geometry ratio (which we know is always right due to projection).
							local oldFlag = unwrap.getTVElementMode()
							unwrap.setTVElementMode false
							unwrap.selectFaces #{f}
							unwrap.faceToVertSelect()
							local selectedVertices = unwrap.getSelectedVertices() as array
							
							local widthUV = 0
							local heightUV = 0
							
							local pos = #()
							for i = 1 to selectedVertices.count do
							(
								append pos (unwrap.getVertexPosition 0 selectedVertices[i])
							)
							
							local i2 = 0
							local i3 = 0
							
							local length1 = 0
							local length2 = 0
							local length3 = 0
							
							local triangleArea = 0
							
							local height1 = 0
							local height2 = 0
							local height3 = 0
							
							local ratioToReach = width / height
							local nearestRatioDiff = 1000000
							
							for i = 1 to selectedVertices.count do
							(
								i2 = i + 1
								if (i2 > selectedVertices.count) do
								(
									i2 = 1
								)
								
								i3 = i2 + 1
								if (i3 > selectedVertices.count) do
								(
									i3 = 1
								)
								
								length1 = distance pos[i] pos[i2]
								length2 = distance pos[i2] pos[i3]
								length3 = distance pos[i3] pos[i]
								
								triangleArea = MAX_Functions.TriangleSidesToArea length1 length2 length3
								
								height1 = 2.0 * triangleArea / length1
								height2 = 2.0 * triangleArea / length2
								height3 = 2.0 * triangleArea / length3
								
								local currentRatioDiff = abs((length1 / height1) - ratioToReach)
								if (currentRatioDiff < nearestRatioDiff) do
								(
									nearestRatioDiff = currentRatioDiff
									widthUV = length1
									heightUV = height1
								)
								
								currentRatioDiff = abs((length2 / height2) - ratioToReach)
								if (currentRatioDiff < nearestRatioDiff) do
								(
									nearestRatioDiff = currentRatioDiff
									widthUV = length2
									heightUV = height2
								)
								
								currentRatioDiff = abs((length3 / height3) - ratioToReach)
								if (currentRatioDiff < nearestRatioDiff) do
								(
									nearestRatioDiff = currentRatioDiff
									widthUV = length3
									heightUV = height3
								)
							)
							
							if (widthUV == 0.0) do --It shouldn't happen, but in that case, we don't wanna ruin the ratio too much.
							(
								widthUV = 0.0001
							)
							
							if (heightUV == 0.0) do -- Same here but even worse, if it equals 0, we divide by 0.
							(
								heightUV = 0.0001
							)
							
							unwrap.setTVElementMode true
							unwrap.selectFaces #{f}
							unwrap.selectElement()
							unwrap.setTVElementMode oldFlag
							
							if (moveToCenter) do
							(
								local center = unwrap.getSelCenter()
								local xOffset = 0.5 - center.x
								local yOffset = 0.5 - center.y
								
								unwrap.moveSelected [xOffset, yOffset, 0]
							)
							
							local scalingU = (width / uvWidth) / widthUV
							local scalingV = (height / uvHeight) / heightUV
							
							unwrap.scaleSelectedCenter scalingU 1
							unwrap.scaleSelectedCenter scalingV 2
						)
						else
						(
							result = false
						)
					)
					
					local oldFlag = unwrap.getTVElementMode()
					unwrap.setTVElementMode false
					unwrap.selectFaces selectedFacesBits
					unwrap.setTVElementMode oldFlag
				)
				else
				(
					resutl = false
				)
			)
			
			result -- Return <Bool>
		),
		
		/* ---------------------------------------------------------------------------------------------------------------------------
		<EDITOR UTILITY>
		*/ ---------------------------------------------------------------------------------------------------------------------------
		
		/* ---------------------------------------------------------------------------------------------------------------------------
		<FUNCTION>
		<DOC>  Converts an image to a base64 string. While unused in the code, it can be used to quickly convert an image offline to hardcode it.
		Arguments:
			<String> filename : The location of the image to convert.
		Return:
			<String> Returns the base64 string for the image.
		*/ ---------------------------------------------------------------------------------------------------------------------------
		fn ConvertImageToBase64String filename =
		(
			local base64String = ""
			if (doesfileexist filename) do
			(
				local memstream = dotnetobject "System.IO.MemoryStream"
				local imgLoaded = (dotNetClass "System.Drawing.Image").fromfile filename
				imgLoaded.save memstream ImgLoaded.rawformat
				base64String = (dotNetClass "System.Convert").ToBase64String (memstream.ToArray())
				memstream.close()
			)
			base64String -- Return <String>
		),
		
		/* ---------------------------------------------------------------------------------------------------------------------------
		<FUNCTION>
		<DOC>  Converts a base64 string to an image.
		Arguments:
			<String> data : The base64 string to decode.
		Return:
			<Image> Returns the encoded image.
		*/ ---------------------------------------------------------------------------------------------------------------------------
		fn ConvertBase64StringToImage data =
		(
			local bytearr = (dotNetClass "System.Convert").FromBase64String data
			local memstream = dotnetobject "System.IO.MemoryStream" bytearr
			local decodedImg = (dotNetClass "System.Drawing.Image").fromstream memstream
			memstream.close()
			return decodedImg
		)
	)
	
	-- Sets itself as an instance of its internal struct, effectively creating a global static function.
	MAX_Functions = Functions()
)

struct ObjectStateListener
(
	/* ---------------------------------------------------------------------------------------------------------------------------
	<VARIABLE MEMBER> 
	*/ ---------------------------------------------------------------------------------------------------------------------------
	public SelectedObject = undefined, -- Undefined = No object selected.
	public SelectedCount = 0,
	
	public SelectedUnwrap = undefined,
	public SelectedObjectIsUnwrap = false, -- Specifically, selected modifier in mod panel.
	
	public IsPoly = undefined, -- Undefined = If SelectedObject is valid, then it is neither Editable_Poly or Editable_Mesh.
	
	/* ----------------------------------------------------------------------------------------------------------------------
	<LOCAL FUNCTIONS>
	*/ ----------------------------------------------------------------------------------------------------------------------			
	
	/* ---------------------------------------------------------------------------------------------------------------------------
	<FUNCTION>
	<DOC>  Updates the internal state of the object, keeping track of the selected object.
	Arguments:
		<Void>
	Return:
		<Void> 
	*/ ---------------------------------------------------------------------------------------------------------------------------
	public fn UpdateState =
	(		
		local sel = getCurrentSelection()
		SelectedCount = sel.count

		if (SelectedCount > 1) then
		(
			SelectedObject = undefined
		)
		else if (SelectedCount <= 0) then
		(
			SelectedObject = undefined
		)
		else
		(
			SelectedObject = sel[1]
		)
		
		IsPoly = undefined
		SelectedUnwrap = undefined
		SelectedObjectIsUnwrap = false
		if (SelectedObject != undefined) do
		(		
			if (classof SelectedObject.baseObject == Editable_poly) then
			(
				IsPoly = true
			)
			else if (classof SelectedObject.baseObject == Editable_mesh) then
			(
				IsPoly = false
			)
			
			for m in SelectedObject.modifiers where classof m == Unwrap_UVW do
			(
				SelectedUnwrap = m
			)
			
			if (SelectedUnwrap != undefined) do
			(
				local SelectedType = modPanel.getCurrentObject()
				if (classof(SelectedType) == Unwrap_UVW) do
				(
					SelectedObjectIsUnwrap = true
				)
			)
		)
	)
)

/* ---------------------------------------------------------------------------------------------------------------------------
<ROLLOUT> Info Box : General options and functions that directly affects the tool rather than the selection.
*/ ---------------------------------------------------------------------------------------------------------------------------
rollout rlt_InfoBox_Main "General" width:220 height:280
(	
	/* ---------------------------------------------------------------------------------------------------------------------------
	<CONSTANT MEMBERS> 
	*/ ---------------------------------------------------------------------------------------------------------------------------
	local GITHUB_URL = "https://github.com/CantyCanadian"
	
	/* ---------------------------------------------------------------------------------------------------------------------------
	<MEMBER VARIABLES> 
	*/ ---------------------------------------------------------------------------------------------------------------------------
	local LogoBase64 = "iVBORw0KGgoAAAANSUhEUgAAASAAAAEKCAIAAAA91h+HAAAACXBIWXMAAC4jAAAuIwF4pT92AAAAIGNIUk0AAHolAACAgwAA+f8AAIDpAAB1MAAA6mAAADqYAAAXb5JfxUYAANt2SURBVHja7L1nXFTX2j68p/eh9w6CBURRUURRsfdeEo29RY0aE0s0xsQac6IxsccSNRpjPfbesWFBQbpK722AYXp9P1x/17vPoKiIpjysD/khGfbsvfa6+3VfN8NsNlP1q37Vr/ezmPVbUL/qV72A1a/6VS9g9at+1a96Aatf9atewOpX/aoXsPpVv+pXvYDVr/pVL2D1q37VC1j9ql/1q17A6lf9qhew+lW/6gWsftWv+lUvYPWrftULWP2qX/UCVr/qV/2qF7D6Vb/qBax+1a96Aatf9at+1QtY/apf9QJWv+pX/aoXsPr1b1xGo5H8bDKZTCYT+ader9dqteSfBoPBYDB8mLti1LNK1a9/zYJcsVgsBoPx0g9AtDgcDovFqhew+lW/3nqZzWZypI1Go9FoZDAYXC6XwWAYDAaI3weTrnoBq1//KheRyWTCdpnNZqPRyGazX/VhuVwulUrrBax+1a+3sF16vZ6iKA6HA3tlNptZLJZer2cw/t8553A4TCYTH36VG1kvYPWrfr0yBjMajRwOh/5PFosFoYJc6XQ6Ho9X7yLWr/r11tLFYDAYDIZer8/Pz8/OztZqtSKRyMrKisFg2NjYODs7UxSl0+n0ej2Px6vBgazDxa5/MfXr37F0Oh2fz6co6uHDh7/++uuRI0eUSqWVlZVAIOBwOC1bthw1alSPHj0kEgmHw/lgdqXegtWvf16s9fKjzGBQFBUbG9uvX7/i4uJ9+/YJBAJra+uKioqrV6/euHEjMTExKCho//797u7uXC73w1iwegGrX/8SAdNoNGazefz48WfPnt2/f3+fPn00Go1QKKQoSqvV6vX67du3r1u3zsnJ6dy5c/b29h/mbuuRHPXrX7IEAkFhYWFUVNTkyZP79evHZDKFQqFWqzUYDDweTywWT506ddeuXVlZWVFRUWq1ul7A6lf9ersY7Pr165WVlZ999hlFUSqVSqFQMJlMjUZDUVRVVZVQKOzSpYujo+OZM2cEAkG9gNWv+vUWi81mP3nyxMHBwdnZ2WQyCYVCvV7P4XDEYjFFUSKRiKKooqKi7t27FxUV6XS6egGrX/XrbY4yk5mZmdmuXTuhUAjgr7W1tU6nA8y3oqKCoignJ6fAwMDMzEw69rdewOpX/Xr9AopXJpMpFAqj0ahSqRgMhk6n43K5FEXhvyaTaf/+/UwmUyKR1AtY/apfb2fBBg0adOHChVOnTvF4PC6Xq9VqxWIx0vcokeXn52dmZk6aNEmpVNYL2Bsti6QtEGh6vV6n09E7gurXv2YxXrHUavXHH388duzYefPmXb9+nc1ml5eXUxSFJIdKpaIoasmSJaWlpe3atftgaKl/MJKjsrISKBi1Wq3T6cRiMYvFQvUQaDS0J+A3Go0GOqx+/VsX0hhLlixhMpnffvut0Wjs2rVrXl4eSl6FhYULFiw4ceJE7969mzVr9mGqzNS/oNBsMpkIlNNoNBoMBqPRiP4fSBc8BOKL169/6yovL2exWFKpNCEhYe7cuQkJCSNHjhw6dGhycnJiYuKJEyeePn06efLkNWvWSKXS8vJyGxubegF7/YYKhUI2m20ymYCShjjBOSSCp9frmUzmh2yzq19/1VKpVEBvbN68eceOHRRFZWVleXh49OjRo3Pnzt26dWMymRUVFdbW1vUW7E2XTqczm83wqjUaDcTMZDIZDAYGg0GMWP36dy+6GtXr9Wq1WqvVgkRAJBKJRCJEEyaTCcEC6Wqpj8FevoxGI8rz8P00Go3RaBSJRGq1WiAQMJlMNP9gH7Va7YfsAqpfH35xOByNRgMBw0uXSqUmk6mkpIQ0LzOZTIRqH6wO9s+2YCBdyM/PP3369MWLFwUCQevWrZs3b+7p6enj40MCWaPRqNFosLP169+6EGabzebCwkJra2sLMFRVVZVAICB8OPWUAW+0ioqKjhw5snXr1uzsbD8/Px6Pl5WVVVFR4e7u/tFHH02fPt3Z2RleQb10/euXRbcyeplBekOicXxMpVJ9sPPwzxAwrVaLxCBdXTGZzBEjRpw6dcrT03Pfvn0tW7bkcDglJSXJyclnz549duyYra3t4cOH3d3dZTKZra1t/RGsXx9+/TMEzGAwwN8jrCYmk+n48eNDhgzx9/ffuHFjx44deTxeaWmpvb19VVUVm81OS0vr2rWrtbV1UlISk8mEPqt/3/XrA69/BpKDTloCO8ZkMq9du0ZR1MyZM7t3745fwkyhJzwoKGjx4sX5+fm7d+8uKSmpl676VW/BXrlINZn8YDAY+vfv7+DgsGPHDrPZjMwhl8sFLgZJpMzMzEGDBtnb2587d64+hVi/6i3Ym5oyg8FQWFiYk5PTv39/JGetrKyqqqooiuLxeKBuValUjo6OgYGBqampPB7vg/X/1K/69c8TMBBHgq6VoiilUllWVqZWq0NCQsxmM+pgdnZ2SqWSwWBwOByDwSCRSCQSSYMGDTgcTnp6er2LWL/qBez1MoafuVwun88XCoWFhYVAUgMbhdwrAfiWlpYmJCT4+fm5urrWC1j9qhewVwZgEC0mkwkXUSAQ2Nvbs1isw4cPAyTFZDIrKyspitJqtUwmU6fTlZeX29vb8/l8gUBQj6OvX/9gATO/5apF3EWyiKQUZmdnFxkZmZCQoNPpwNdlZWWlVCqRzFCpVMBKnzlzpkOHDmDt+mCKgGyL0Wh81fe+tlfNbDYrlUrkbCiKsoghLeZfmc1m/ObvkLIymUwEiER+oA/vot9k3cbGBoNBq9Xi+uDNpl6UdoBLNBqNuCWgw8nHTCYTGsZwEYuNNRqNtb7Pf3DD5ccff5yenr5z504+nw+yf5FIpNFoysrKgJUODw8XCoWdO3fmcrkfANmJ0R7koDMYDBaLxeFwqqqqtFotWmkgFWazGb+xEDMSZOLPRSIRbC/iTODCcHG60oHeIb/BF30AhVJzIgoPwmKxqqqqVCoV3UUnETX1opO/DhfBdhPgL3n1+A2os5GOhnYGeT0w+Gq1Gihh0vqE91j7+zS/8zK95TLX0TKZTOvWrfPz85s3bx70fXp6OvAyRqPx+vXrLi4uSOLLZDJ0On+YhXmKGo1Go9FAob7Js0AqCAwcb1er1apUKrQL6HQ6HA4IKjQrdDZ+bzQazX+D9dKtVigUGH5HnhenvA6/F7thcSzNZnNJSYnBYFAqlSqVCnYMm4k3hQ+TjbW456qqKvxcUVFRu7uqgzrY216hrppHAO7cvn37nj17KIoaPnx4q1atDAZDSUnJjh07zp8/P2jQoB07dtja2hJt+l41t8FgsDAsxGUi7TMYAEcIWOiOJX0ICHGrQJpZw87jgm/1Xt538w7pbYUdBnca2SKz2UyMzPubIQTtQzfs5LuUSiUBIpaUlNjb24MbBxsuEAgAwGez2XZ2dvhDjUZTax7Ff7CAURRVVVUlkUjUavXMmTOTkpJKS0ufP39uNpudnJzGjBmzatUqNptdUFBgb2//AVxE7AN5Opx+nKdXHQILicIVdDodZBWuL/m/KpWKyWTidJJF4jF6KqiGGaofQMAoitJoNHq9Hq9m27Zt3t7ePXv2tIDhkkeu8/uBJSeiBQAd/hek3WQyKRQKqVSq0WhQ16FoaCH6UiqVTCbzXVhK/8ECRlq8TCYT4LxRUVEFBQVSqZTD4XTv3l2hUKBD4a+NFdVqNYIoevsMFpvNhitSUlJSUFBQVlamVCoDAwOzs7MNBoOXlxfMr7W1tZOTE/2acAjZbPZLpZfEaX+VgEFszGbzzZs3Bw8eLJFIevbs+e233zo4OJCGyPek8l5q1VUqVUZGRmJiok6na9Cggbe3t7OzMzFlZWVlCQkJFy9eTE9PLy8v79KlS/v27Zs3bw47jEsBKvR/zoKVlpba2NhY7CaOF4vFIrwLSDO+b7ZkVAjg6SHGgFsvl8tLS0sLCwtLSkry8vKePXuWmZlZXl7esGFD2Kvy8vKioqKioiK5XI6eUZCKsVgsiUQiEons7OwcHR2Li4vt7OxcXV0dHR3t7OxcXFy8vb2dnJxcXFw4HA6fz8eRRWhhMBheVZx4leDV1SorK4NzpdFobt++3a1bN7PZzOFwpk6dOnDgwC5dulDvk8TBQsAUCkVcXNy333577949kUhkNBpLS0vt7OymTJmycOFCkUj0n//858qVKwUFBampqc7Ozjwez2QyVVVVtWvXbv78+eHh4QaDQafTIQXyf07ASCKYxWLhLYKtjc/nk466D9yrgjRmZmZmUlLS06dPCwsLL126VF5eDi8f9CGIvnAI6K6dVCoVi8WVlZUNGjQQCoX5+flAganV6qysLPwJ6P7IFaytrSMiIhwdHf39/Rs3btygQQMXFxeJREKK7x9ewKgXzebW1taVlZXdunUrLi52c3O7c+fO3Llzv/nmGzQaAw9Q5y4iXcDkcnlZWVnr1q1dXV379evXrFkze3v7rKysrVu33rt3b86cOfb29j/99JOHh8fcuXMDAwObNm1aVlaWl5d37Nix33//vby8fMiQIZ999lnz5s3J8LG/QMBwlKGzQZwGtcHn86VSqY2NjVgsxthcbCX+Cx8Jo9AI9oLkqYnn8yHZoOhlOtytVqvFjHpIArhjGQyGSqXicDgkWFer1ffv39fpdDKZLDo6OiUl5caNG5jfwWazDQaDlZWVRqOxtrYODQ2VSCQIADw8PHBxoVBoY2NjZ2dnY2OD1LxIJGIymSqVCtl2lUpVUVGBvpuqqqq8vDyZTKZWq6uqqioqKhISEog4OTg4BAYGoqfby8vLysrKx8fH29sbDTsI+rHzhK3k/yW7GAw8HcwLAaCR5ITJZKKnLmpO9uD1GQyGvLy8jh07SiSSH3/8cdu2bceOHTty5MiQIUOIc/EuAoa0JIPBQKSAkKG4uNjR0REsfampqT169GAwGCdOnAgICCAedWZm5sCBA589e6ZSqdavXz9q1ChbW1udTsdms8E0wWAwkpOTDx8+vHnzZrPZvH79+hEjRiB0BKkOgn/6w75HAbOQtAsXLsyaNUupVPr4+OTn5wuFwp49e3788cchISHIKeEBOBxOWVlZcXGxg4ODvb19eXk5UBf0BIbJZLKysvpgxocuXfS9QyHLzs4Ox5HURkwmU0ZGRnx8/MOHDxMSEq5du8blcuVyOSZ6WFlZOTg4eHl5RUZGent7W1lZubi4BAcHs1gsmUwmFAp5PB7Ji9CdJfK9RBmjCMHlclENUygUer0eoqtSqZRKpVwuz8zMTEhIiI+PT01NTUtL0+v1+LyLi0vjxo0DAgJ8fX0bNmzo4+Pj5eVFSlV6vR6KGUER5oWTbyciZ+GBv4kZBGvl1atXu3Tp0rhx40uXLt27d2/WrFl+fn4bNmxo2rQp7rB2WUqouepmE4x9+GdBQcHYsWPv3bv3xx9/9O3bV6PRcDgcbKbJZDp06NDIkSNbtmx54MCBBg0aEGsPR4PP55tMJqVSGR0dPX/+/IKCgjVr1gwZMgTnkwSQ9O16j3Uws9lcVFSkUqkg67a2tqNGjTp+/PiBAweSkpLOnTs3ZMiQyMjIPXv2KBQKPN6dO3fGjRvn7u6OirBAIIiIiFi3bh0GN+HZSE3pLyzpKJVKpCjIPxUKRUVFxaVLl+bOndujR4+WLVti8i+Wi4tLixYtRowYMXPmzN27d8fExACXbHFZFGFQ6UIuXqfTqdVqhUIhl8tJNQbFGfJXiCQtfm80GsG7itSZwWCQyWSxsbFnz56dPHly7969mzZt6ubmJpVKuVyuQCCwtbX19fUdMWLEr7/++uDBg9LSUnJN3Az5p0qlwj8tqlX0ctaranpms1kul5vN5nXr1rFYrGHDhmH3Pv30U4qifvzxR3QY0R+qFlVQUjnUarW4Gm64pKREqVTu3LmToqg1a9bg8zhX5DOlpaXOzs4zZ87EucV/sSxKl3/++aeNjY2Xl9eNGzfwf8mRIHX/mnBL734KyR49evTI1dV13Lhx5DFwDtRq9YYNG0JCQiZPnlxUVNS/f39nZ+dWrVotX778t99+27Rp06xZs0JCQqytrX18fL744gtSL66srKzbWmQNB+KltVGy41qtVqlU3rhxY8mSJXZ2dgh14FGIRKKQkJAZM2asXLny8OHDT58+fVX5tbKyEkOroD6Qjq/hflCqJseC/B4HC58kp4FeZTYYDKWlpTqdDuqguLj44cOHGzZsGDZsWHBwcMOGDZE9c3R0bNOmzaRJk44dO6ZQKCD2kARy4CorKyFR5PqvRQvQS95Tpkzh8/nr1q3DP+/cuePp6dm9e/eKigo8AvnSWkgX/a7MZjMpCuMDQ4cOZTAYKNvAxaWXlauqqs6cOfPkyRP6ZclT45PFxcV4U3v27OFyuWPGjAGjDl7NG955HQgY7kYmk3Xq1GnkyJH4Z1FREYAI+IxcLt+7d++QIUMaN248aNCgmzdvkjOh1WpxlBMTEz///HMGg2FnZ7dz586XqpMPJmD4ZUVFBdRHfHz82LFjnZyc7Ozs+Hx+kyZNwsPDBw4c+J///OfatWtZWVn0Nw23DdiFGoywsdqq+ewSIwO1jQ/TsRGAgFh8BQGCGI1GuVxeWFj4+PHjW7dunTt37tdffx0+fLijo6NYLG7YsOGKFSvu3r37qs3Bl9KvXMOWwminpaU1atSIoqgLFy6Qvxo7diyPxzt69CgBVdTuvNG3BRqQmC/8fsCAAQAekF0CFKb61cgFid9EthEW3mQyzZo1y9ra+sCBA8RTeEPfqm5cRLVavXfvXgcHh8ePH8vlcmgC6IzKykp4C2azOSMjY/v27cXFxTKZDL8pLCzEjZaXl+M3z549Gz16tEAg+Prrrz+YgNHfNPE9oBfu3r27aNEif39/iqLEYnFISMjs2bMvXryIZ8TbxZ/TkTV0f4OoW7pTVwP0BpaN3BKBRNXw+Zc+iFqtBjiIfjPYeZg4PEJFRcX27dt79uzJYDCaN2++cuVKYoQt0EP0i7/J8frqq68oimrVqhXqe7jUxo0bKYpav379u+CP6BqK/puKigo8b2Fh4cCBAyMiIiAz9Lsl8lZZWWk0GisrKxUKBdQoHUWFzyAdCmXh5eUVHBxMN3TkYL9fAcMNTZ06tXXr1sRS5+fnk6dSq9VlZWX0vSD3jUXkDeonNze3S5cubm5uxI59SAsGdJ9arS4tLV2zZk2zZs1AFezj47N8+fLi4mK6b0xCJmwCLoWXSj/ZEDALAdC/WHRxehO4HeQfcEcAEWsABBIYHnkdBQUF1eVEoVBcvHhx4sSJLi4unp6eCNJSUlLwdqqLUw0WDE906tQpHx8fiqIOHTqE68OAnDlzhsPhrFy5EhtVO4wopudYqPi8vLxHjx6RAGnBggXjxo0jIEN6eInf0L8aAoYEEq6gUqmQZiOf+e677yiKunXrFvHb38QI140FU6lULVu2HDRoEN59ZWUlXRlXD83hpqNlgK6qoVfwz379+llbW587d+5DChhuCfmGvn37Ojg4UBTVuHHjX375JScnB1k7eniGz5NXDqHCb+jZEfJ2IRIwYq+1pa/S0686c3QXkTRu1CwG1b89JSXl66+/xoO3bNny22+/TUhIIHma12Y4sKKioiIiIsRi8eDBg3U6Hd1SXb16laKo8ePH1wk0WavVPnr06KeffhozZgzKXA4ODuPHj9+3b1///v3nz59PQi+40EQs1Wo13GycN+IcWpgmvA4Yg6dPn0qlUkRidPtRZwJGzw4RoSdHrWHDhq1bt8b5I0JSC0uI4BJ+fGhoqKura3p6ukVSsXZ+o1wuf5W+gYOKiAWexsyZM62trf38/GbOnJmQkICzRc81/VsXUrhxcXE//vhjaGgoRVHW1tZDhgzZu3dvcnIyERX68SI5TKzt27c3adKEoqhu3bpFR0fTE24KhQKIipEjR2LPa5HkoOd7Tp482apVK2TPO3bsOHny5B49ejRr1gxsESdPnqzD7hCz2dyjRw9HR0eZTFZZWYlD+Fo1Qb3Vg7005YJs1bJlyzgcTlRUFL74TdzTl1pC0u5hNpuPHDlib2+/Zs0akqike8nv4tMiC0QPcOHDGAyGu3fv9u3bl6KowMDAbdu2KRQKdONZpBb/fcsijaHT6Z49e3bjxo3AwMCgoCBfX19XV9dmzZpNnTp1z549UVFRiYmJycnJGRkZRUVF2dnZ58+fX7BgQffu3X18fLhcbs+ePZOTk6Ft8/PzyWWvX78uFArHjBlDgtjaJTnUavW1a9ecnZ2DgoJOnDhRVlYGO6NQKMrLyxMTE6Oioizs0rsL2Jw5c7y8vPLz81FZeZP7p2onAxChyspKNKjp9XqVShUQELBx48ZaVzbox5e86aFDhzZu3PjZs2fklwj6a62eoW6rO2MQ6bt3744aNYrJZHp6ev7xxx+kTAQx+zBJl792WRTfsPLz87ds2dK9e3cnJydMKgFrg1gsFgqFVlZWUqmUx+PxeDypVNqoUaO1a9fCDSFvirisf/zxB4vFmjRp0pt7v9XLQlqtVi6X9+/f39ra+sGDByQdTffMcQ5roehraGXcvXu3h4fHw4cPyRO91lF8i+kqABTzeDzgUMgYaZ1Od+nSpZycnIqKilu3bk2ZMgUoobcF16IlGYAXNpsNsPP8+fMjIiLOnTs3c+ZMQBxeCi94Q6CGwWAgbVfYSiaTqVAoMB3z8uXLM2fOTElJGThw4PTp07t16wZbx2az+Xw+oDT/+il+DAYDCggN2ni/Li4un3766aefflpaWhofH3/z5s24uLjs7GytVstisUQiEYfDEQqF3t7e/v7+Xbp0adSoEd4RmXTDYrHUajWXy01OTjYajcDOGgyGWuwn3uCVK1dOnjw5Z86cVq1aIfq1wOMCYFGHw851Op2bm1tFRUVaWlrLli2xUa+//3cpRFy6dGnevHktW7Z0cHBo0qRJmzZtZsyYUWvzgj8kGgiep9ls7ty5c9euXUniCB94xwI00gyYeITvunjxIuDtYWFhd+/eNRqNxMGgl5s+ZGf03ycqMxgMGo2GlNTgCMhksqysrOzsbDg1Go2msrISm6ZUKkmWGDuJP1EqlUOHDqUoatWqVRZ5oLdaFRUVXl5eLVq0KCwszMjIoMfwOBh6vb6qqkqv19fCn3qV+TIYDFeuXGEymVu3biWZktde7e3mgwGjyWazHz9+vH///suXLysUiuHDhwcFBUVGRorFYuxv7TQEk8nUarWAxgECj10bP378/Pnz09PTAwICCFCwhk7e1y4gaOng6MOHD//www+pqalffvnliBEjWrZsSW+moGMF3+V7/1mL+G9oPAP8DyoGe2JjYyORSIgWZ7PZAN0SIC+BSguFQjgmWVlZ6enpTCYTuqzWuP5z585lZWWtXLnSyckJ5w3jQUinEpvNFovFdNT4uy+ASAE3M5vNBLxelxYMJuXevXudO3du3LjxokWLUCqhq5B3SXKQvyI/lJeX5+Xl2djYbN26lRTRa2dG8FdI19J14YYNG/z8/CiKmjRpEgpxRO1pNJry8nLyve+YXPn7R19vwu1B/q9CoSA/Iwiv/l4A+ScfO336tJ2dnZWVFRKzb4Lle6mF+fLLL8PCwlJTU2G+6GUAg8FAyhUvhW68S5Jj9erVXl5esbGxFnnvuklyYPuKi4sHDBhgZ2d37NgxlAjgaNVOol5aCYB3Qcp8Go0GFABEMGqXaaDXQHDl/Pz8S5cueXh4UBQ1fPjw8vJyOiTPAiv45uXgf5NzCGQWeXYQmNG3BfVu+iZXL6kD+6fRaNavXw8MJMke1S6gGD16dNu2bUnFnBRvSPCCb6+dIn6VgMnl8unTp6NnrHqt4i0ErAYJVqvV27dvpyjqv//9r5mG+6qTBfkhwAitVkvwU926dRs2bBgBfJDf16ALLDQxfcfB2WQ2m0tLSyMjIymKGjRoEKnY/H3omf6hy2L3SNGloqKibdu2FEXt3bsXR7N2NQ+9Xt+lS5dOnToh9kNU8tJXVjO287XEZ8Qw4rxVVla6u7tPmTLFYDBAxt6kLvp2TnBpaenOnTsnTJiArAPhEqmThaBIqVSi55LL5ZKRDmlpaQqFwsbGBvtibW1NaCJfGjzAC0fzHIlQKYoCeJfL5aLAcOfOndu3b8+bN2/SpEnBwcF0xgGqftV2Ee5HsKaCipCiqNTU1JSUlI8//njQoEEIjTBQ+22vz2azHR0d3dzccGCQPHzpK3vTMKnaXwErB9IelNopioqOji4vL584cSISp3q9XiAQvJZ/kv1WG/fs2bPo6Og1a9ZIJJL3NK8Eff4VFRU2NjZMJhP9v8CwIz+BHEMNHAkglISUorMTiV21Wm1nZ1dcXHzlypXjx48/e/YsOzu7f//+n3/+uYODA9LKyOPXE9m/y2Kz2VqtFrUNKDixWKzVahcuXFheXt6jRw+RSAQXQyAQ1IIopaCgoLS01MrKSiaT2dnZ4VLgkKor9gEmk0koovGzXC5fvXp1y5YtW7duTVEUilXox68zAaMoKicnx8HBoXHjxqgdoX26Dt+NXC4XCoWEkg7FByTu3NzcioqKHB0dX9tnjsZ40vSKFDOHwxEIBMeOHVu8eHFSUhKbzW7cuHGvXr02bdpEWMRIqzL1Pin7/i8s6EQcUJFIVF5evnHjxqtXr44bN65Hjx6oKHI4HMIL9lZLLBZXVVVJpVKBQEC8leqMD+/C8oK7MhqN0PImk2nnzp137ty5dOkSoKRCoRAavzZ1sBoc061bt4aFhWm1WtTp67zdGGklFKnQ46DX6+/duyeVSg8cOECPLN8kgUNiXK1Wm5mZOX36dLBWfPrpp1FRUejXqqqqqh4Km0ymd8Gj/B9f5FRAteXl5S1fvpzNZnft2jUjI4OO3qg1uW+rVq369OlDz10RdM6bM0nX8HmtVkvgvAqFYtWqVWKxePr06chv0/OodZzk2Lhxo5eXF2I7RK51eBDp+VzcRnFxcUZGRtu2bSMiIuh5rZqTENgXvV5fXl6O6OvYsWMDBw5kMBjh4eF3796lbzq+1OI1vAsaq37hxJNC87x587hcbkhICBBG+D3J6ddCR+v1+jZt2gQEBOTk5JBTThIShFSctPa8rYBdvXp18eLFy5YtM5vNubm5GzZscHJyatu2LQjY6bwDbwJqfwsBM5lMv/zyC5/PB3azOplBnSyVSoXdX758ubu7O4vFatmy5dWrV81ms0wmw8urGcRJT+JnZGSsXbsWqPBRo0aRCgZmZJK8JXCur+0prl9vBbaA/gVyesSIETExMaT0olQq8YHqLapv4phMmzZNKBQeOXKk5upCzXWwVx3yr7/+GmFY+/btnZ2dPTw8PvroIxyq0tJSOu7xTdbbWbANGzY4OjomJibiaNati0iModFovH37doMGDZo0aXLp0qWioiKL1PxrLYxarTYajbm5ubNnz2az2e3bt7916xbuGbl+8l1EVumcExZkD/WrdhUXs9lcVFS0efNmKDgOhzNr1qz8/Hx6y3DtSlXbtm2jKOrzzz9HF5yFG4U3iEpPDR7Wq875jBkzunTp8uDBg2XLlq1evRpcN3K5HOcQGoHc9msB+28hYEqlMioqiqKoEydO4Iy+lKQBZH3VxY/UQ2p27XC48/LyWrVqFR4eXlhYSOersDAv9M5Oul4xGo0pKSkjR46kKKp37950uEn9qkVM8laLvAViPXJzc8+ePYsmMW9v76ysLJ1Oh1ISPYwh3/UqOiCyQLfI4XBQj4UA4E9IbbaoqKhDhw4rVqx4abXWwruTy+XQ4CqVasKECaGhoXgK8rFa25K3qIMJhUKj0ejg4HD58mW5XA7Mu1wuB7cu+hGR5AHPJspQaBAGng1osRrSuwCFYO6Bp6dnfn5+aWlpDWUD4M2oFzOgCHdFUlLSF198sX///qlTp27btq1hw4YKhaI+uffB8PgWv3Fzc2vTps3169c/++wzuVzeunXr6OhogUCAxghS74HZwdusoVKiVqsdHBw++eQTJyen9PR0UrPC8bO3ty8rK6Mo6uzZsykpKYsXL46OjsZfkSukp6ejGkSAqRKJxNraGlNUMjIyOnfujMykQCDAZUFmXns62zfUZGlpaaCwTElJIcaRDu0j2ovw3hB8TfUPvzTPQfIzP/30k7W19b17915lwSx8DHLlhw8fBgUFMRiMJUuW1C3WpN6CvRWSw8LTxhk4c+aMl5cXRVFbt259KXaRnkWoYZWUlLRo0YLP5+/bt48cPGIPHz582KZNmzFjxkRGRg4aNIiQ/5BcCJ3Jgn7ZlJQULy8vpOPpqcJaw1DfQsAQNc6fP5+iqO3bt5v/F/dJECv0rhNyW6TfroaNo2dvNRrN5cuXRSIR2ule5SKS5weFIJyHZs2aiUSiFStW4FIASda6M6JewGohYPS3DE410hVuMBiSk5OdnZ0lEsmff/5pcdxfmqmqnqXEu3748GGTJk0cHByuXLlifsE0YTAYdu/ebWdn5+fnl5qaWlxc7O7ujnQIPY6wyJZptVogG7/66qsuXbpgKoCF4/reBQx2CbMzWrZsaaYR34IBy/xirDBdIdE98prvlfSQ47EPHz4sEAiSkpJqEDAki8jfGo3GefPmURS1bt06tVpN7+v+axmC/08JGJTpS/neQNVkNptjYmJYLJa/v/+1a9dwTt4cl0jXladPn3Z3d6coKiAgYNy4cfAbbW1tJ06c+PTpU4PBUFFR8Z///MfX15dQPqpUKhJZEYQ6rhkfHx8cHEwqrkQC36WL4q0FzGw2b9myRSqVTpo0qTr7MW5Fo9GkpqYSjUVkrOZTDhElGz1r1qymTZvWkOQglyUNkWfOnBGJRKNGjcrNzTW/YI1EkF0vPx9MwMz/C7onVyDHurS0VKPRrFmzhs1md+zYkWC46S7May0kndV49erVw4YNCwsLCwgI6NWr19q1a3FNyE9lZWXXrl3DwsLoPL6AvOIOCQ3bxIkTu3btSk8MwqX8cAJmMpnKysr0ev28efMEAsHWrVuzsrJI+ATlZDQa9+7d27Nnz82bN1twYlkkHmsoU6alpTVr1mz16tVIkLxUwCxymOfPn+/bt2/Dhg2joqLwv+hf96/n0vhbCRh5lXBhCJ2OUqkkLHdGo7FPnz4URa1evRqhMnlHr0UvYOwyyRkSB4owVRE1DQ4cmUzWpUuXLl26PH78GKMz6DE8svlXr17t1KkTMV+4mXd3fN5OwPCtuKfJkydTFNW3b9+bN2+iRADl9Ouvv7Zt2xaDi6KioqAGqnNx1lwH+/3334VC4bNnzwD9epWLCFZN/O0nn3xCyP4VCgU93VJfO/6QAkZ39qq3rtBf9Llz5xwdHfl8Ptgvyaz6mo81pIjef4j7JNEKXQ7xA6AR7du39/X13b9/P7Q20go4J0VFRUFBQVOmTCHuIqE5qs5y+a4C9toqB56/oqJi/fr1IL719vYeMGDA6NGjmzRpIhKJJkyYkJGRwePx5s2bBzwLnYyaeOd0KBrh4sRIyJEjR7Zv3x4PX/OLx4bu3LlTIBCMHDnyHdmY/2UCY/7fbt+aoT2EcgNDN82vo7Z+W4EkckUkMDc3988//3RwcPDx8TG/QLe9Sba5dqU5pVK5dOlSJycnDAeDSBcXF69Zs8bBwWHMmDHv4/C8dUczmsPJLwsKCnbv3j1z5syWLVs2aNBg0KBBO3fuhN+4evVqiqKmTp2KV0UiIvobQh6CJCGg8GJiYiiK2rVr12tfJF5DcnJyYGBgQEAAEFX1ix4/4Hi9IRXs3r17d+zYYZEAqFuLBwQw+SdI5K2trUGiCIxO7fgMa9YdiF80Gs3FixdHjRplb2/fr18/zGvu2rXr999/Dy+sThrz38mCkRdGxAyDpJRKZUFBAX3kT3Fx8bfffktR1JAhQ1C2NxqNdG53iwWxrKqq6tWrV6tWrfCoyD2+qmyAz48fP56iqC+//LIWwLZ/9yoqKiIphOqHu/pCu/qSJUuIM1aDJamFgBGydEI5bjabV65cyWQyUc4yv+AAr8NNIKeC3NvTp09//fXXDRs27Nu379SpUyAIeU/r7Zh96dtnNBpBAUnfO0z0QHYBHz59+jSLxXJ2dr5//z5xVOCNkKtptVqibtesWUNR1M2bNwmT+KteJF7Dzp07JRJJ06ZNz58/Xw8gpK+jR482bdo0LCwsPj7eIm/+0lVYWKjT6dzd3dls9unTp+kOW10JGJ3XRC6Xw1KtXbuWoqhvvvnGglq4rhYdimDBd0T/mEwmozMQ19V6C6gUk8lEUEjv+uRyueCg02q1mHUPclLM/zUajSEhIXfu3PH19W3duvXkyZOjoqLQKod+O7PZjK41BoNx9+7dTz/99Keffpo5c2b79u05HE4NuCpQDGg0mnPnzimVytDQUB8fH9xhPVgJq2/fvsOHD5fJZDt37kxLS2OxWEjiverz1tbWHA5nzJgxBoNhyZIlubm51tbW5rpjTwCDAAFSSSQSoVBoNpsBSsKMNTA7WCCb3p1uDexgaLLGnVRVVVlZWYGNB99lY2Pj4uJS9/3db/VpMrMcyobFYnFeLGDJlEol+vzR9m9tbe3q6spisbZs2XL27Nkff/zx9OnTzZs39/Hx8ff3d3JyEgqFCoUiPj7+yZMn6MYbN27cjBkzsC9oia2hqzwtLe3ixYsURfXp0wfUa/WLvr7++uuEhISff/5ZpVJt3boVTBKv+jCPxysvL2/cuLGTk1NycnJJSYm3t3dJSQm6yN99EYQhTg5IEQ0GQ8OGDSUSSU5ODuluBiawbuleIFowofin2WxmMBg4q+Xl5RwORyQSVVZWgoGjztabGzvU5qr/HsJmMVSTeBd0pz8xMfGbb75p0KCBg4MDHlIqlTo6OjZs2LBNmzZfffUVshRAjpEY71WuSEVFxcKFCymK6tWrF2I/klqtXyRZd+XKlSZNmkgkkr1799bsJWLDb9y40bBhQ0C6ay6r1C7JgW5x4vxrNJqMjAw/Pz8fHx9Ch1a3MVj1p8Z0YvoE1ho+/KGTHBZzlqoHzYSP2kybGGRx36mpqVevXr18+fKZM2eOHTuGPkj69DozDTP2qhdZUFDAZrNdXFzi4uLqS8kvXcDXXb9+naKo0NDQnJycGoIcvKMtW7bAX0LoX0P6sXYxWPUTjBoUh8O5c+cOadOs22CMzN19afGA1L7rPHtprqsBfO+7oEmSp2RIl9Fo3L9/P2CH1UuZf8miF8pJ3U+j0cCSYHg2HgG/sRgt+9Lr0N0HenqADK01v+CQrA71pAPtVq5cSVEU6cy1UOcg4cLnly1bxmazw8PDnzx5AktCnxZgfsFwTHBGFlgZMhOZlJ7M/4uyJVl4hO5ms/nZs2eNGzd2c3NDayOdYv5Nkm0WxS5yqxZT4ckQZ/MLNPmHORXsf0QsQbirWCwWomS1Wr1x40Yej+fh4QFPA/1mfyHjGkKIqqoqMLaz2WydTvfdd9/l5uYuWLAgKCgItFlisVgkEoGQ66V3S0IR6B3kAEDvjmwQmRiCbak+a8ZkMpGPyeVyqVQaEhIiEomePn1aVVVla2tLTzbgHvB5lUrVsWNHg8GQmZkJ4sGqqiqBQACZ4XA4GHnDYrGAjyksLDxw4ACDwVAqlfn5+R06dODxeMHBwcXFxd7e3h4eHkKhEKE4oYk3mUy4YTabja9WKpVKpZLcMDJbNdBC0RntkYNBNMXlciHzJClA9pDJZNLpn9hsdh1y1tdlkuMvWYRWDYcS+xsXFxcdHT127NiOHTsymUwigX851xryYIjjGQzG8ePHU1JSGAzGhg0b2Gy2SCTC/QuFQmK7yJECsx+bzSYDhKCMQaLK4/HIVhCPTq1WC4VCMhDD/GL0AekmBD9kSEhIy5YtY2Ji4uPjO3bsSIQQX0r2WSaT5eTkCASC/Pz8AQMG9OvXr0OHDj4+PgqFoqKiwmAw3Lhxg81mZ2VlpaamKpXKxMRE8JzhQfbs2SORSKBiPDw8goKCwDEBdkGkGYjKIKusrEwmkzk4ONjZ2UFUzG/GmUdPMuNPmEwmIhQUjTB3gjwgGdDD5XIJq1+9gFH0ySbI6et0ukOHDplMpgEDBtjb20Pw4DxotVqRSPSX3CfeMbQ1xIzD4XTq1CklJeX27dvZ2dlNmzbF/yorK3NwcCDWGM9FzgGEhyj4qqoqpVLJ5/O5XC5Oqkgk0mg0LBaLy+XSFTNOOQ4oOB45HI61tbXJZLK1te3QoUNUVNTVq1c7duxYfUINfnZycjp48KBarR49enRGRsaCBQskEgmHw3FwcODxeCaTKSEhwd7eHnA5Dw+P4ODgdu3alZWVicVif3//mJiY/Px8V1fX6OjolJQUmUx2/PjxKVOmMBgMSBcMDr4d+UyTyZSbm6tQKHx9fXGrKPC8oXTRuXtRKCKqtjpjJ4vFIsrow9Gw/iNcRL1eD+ZQnLzCwsKTJ09aWVk1bNgQnRFCoRA7/ldJF1427pN6QQOu1WrnzJlz586dJ0+erFixIjQ01M7ObsyYMRRFPX/+/NGjRwwGQ6PRkJm/ULGoz2CEJIvFQqAlFoulUqmdnZ23t3fjxo3BuQlXGSoZ55KcHmhxgUAA/43P5wcGBlIUhQZWcoiJrUBkKBKJbGxshELhsGHDOnbs2Llz50ePHg0dOpTD4ezfv9/a2vqHH354+vTpzp07d+3aFRkZefDgwSdPnuzevZvJZE6bNq1du3Zjx46Ni4s7ceKEp6enUqn86quv7OzshgwZQu6KFEjhDDMYjOfPn1MU5enpiVF9uB9iq2vecLq0YOcRjrLZbCT6SfhgQf37Jtf/PydgLBYLau/WrVs5OTk9evQArxspXHwwx7oGbxb1cdyJXC4PCAgYNmzYkydPDh06dO3atZKSkr179+bm5mZkZMCzZTKZKpVKr9fjEBgMBgcHh8rKSp1Ox+FwCE0FCc/c3Ny6du3asGFDDw+PHj16SKVSnCfqBQsyZJvH45EaMZ/PZzKZDg4OFEUVFBSAbReVKGLEzGazra3t5cuXDxw4EBAQwOFwuFzuxo0bY2NjP/30U5lM1rNnT3t7+169euXl5bm6ukZGRrq5ubVo0YLH42Gwm4eHBypmDg4Os2fPbtWq1YoVK27evHnw4MEBAwaQm4GhJpGYUqmMj4+nKKpZs2bEpFOvm8P2/0AStGCMuMewtOXl5aWlpVKp1MrKipgytKhxOBwmk1kvYP+zEGdjQ9PT0/fu3SuRSAYPHiwWi7FTSMfh5788z0FuFa9Wo9EIhcKxY8f27dv35MmTWVlZXl5e/v7+rq6ujo6OdnZ2IpHI2tra2dnZysoKoxLKyspKSkoqKyvLy8sLCwtLSkrUanV5eTmDwXjw4MFvv/2Gr+jXr1/jxo179uzp6+vr5uYG55lYUQaDodPpmEwm5u46OTm5urqWl5dXVVUhG0RX/9i09PR0nU43bNiw9PT0X375BUTOn3zyiVAo3LZtW3x8fMuWLZcvX75s2bI1a9YcO3Zs3759Xbt2HTdunNFo3LNnT05OTteuXSdPnjxs2LCSkpLy8nKKok6dOhUbG9uqVSuDwUC+EfJmMpnS0tISEhJEIlGLFi1IlRkaoWZv3EL/arVasVh848aNEydO3L17NyUlRS6X+/j4BAcHjxs3DkPckSKCbH+wQ/LPEDC4UgKBAFnd8+fP+/v79+7dGz4SxIx4ZX+VgBFOc+QPkdJQqVSAdLm4uPTu3bt3797IAcjlcji91UMLMhSGPAiaWZOTkxs0aJCenq5QKGJiYnbt2nXu3Lljx46tWrVq4MCBU6dObdeuHUkwwpeGXwTl7ejo6O3tnZSUpFKppFIpPSiCgMGY2Nrauri4dO7cmcFgiMXi9PT0MWPGVFVVyeVyLpe7aNEiFxeX1NTUnj17opUrNzd32LBhDAajsLCQx+ONHj0ak5ozMzO/+uqr8+fP//HHHzk5OSEhIcS/QGaPoqjKysrnz5/n5uZKJBJfX1+IH6acvslLhH+LfIZGo/niiy/OnDlTUFDQoUOHqVOnKhSKrKysqqqqAQMGjBw5cu7cuSEhISCxIjroA4XmdVXaqpNK/6v6mgjIeujQoQwGY86cOXXegVu9QGSm0TmiaKNUKktKSnJyckgVSKfTEdgoKRmRHludTjd8+HCKojZu3Ej/AHhg3nZNnDhx2LBharVaLpd7eXlNmTJl//79HTp0gLWcO3funTt3cGP4dtIICxRiaGiotbX1/fv3TSYT/hchqDAYDFlZWUjD3Lt3D5mVL7/8snPnzhi+3KBBA7BJ37lzRyKRXL161Wg0zp49OywsDPIfFhY2e/Zso9H4888/Ozs7//HHH2azedOmTRRF/fTTTyiXkWIgaX5v2rQph8P56KOPkKy3gAHVgDihv6a0tLQmTZowGIzx48ffvXuXAHqMRmNFRcVvv/1GUdSgQYPA3W0ymT4k1xj1nurI5rpuQceJefLkiZ2dHYvF2rVr1/sWMPL+iFQYDIbff//d09PTysrKz89v1apVpMyK+Ie8e9QxgXrp378/RVErVqygX8pcI0X5S1d+fv69e/fkcvm9e/ceP3785MmT/Pz8x48fx8bGbt26FXM6Q0NDt23bptVqS0tLcV5B8WA2mzMyMtzd3a2srJ4+fWrRviGXy3U63aZNm1gsVo8ePQh6IyYmJi0tLS8vTy6XP3r0SCaTnTp1Kjs7Oz4+XiaTxcfHFxcXJyYmgtIrMTGxuLg4Pj7ex8fn66+/LigoePjwYUpKyvr162/evEkHsGOX5HJ5VFSUu7u7ra3t8ePHsWkQvDfhwMB5AP59+fLl1tbWUVFRdIUC1iO9Xl9aWnru3Dl3d/cuXbrk5OS8O83GhxYwxI5Ao2CvCdtJXQkA+StwJnfq1CkvL+99Cxi9m4bo3SlTpnA4nOXLl/fs2VMgEKA9EZrypTZcpVLNmDGDwWAQsge0+dRCwMDZYjKZevfuPXPmTLlcHh0d3bp162vXrpWWlq5duxb8Sm5ubpcvXyanmZiFBw8eODk5tWnTxvxiPK9MJgMPIZpZUB/bunUraerD3z579qyoqAhQoz/++CMtLQ0XBzEGfZ61wWAoKSkJDw//888/Dx06FBERARAcmnRxWUBSKisr9Xr92LFjWSzWkCFD6NbptT1H9E5+o9H44MEDiqIWL15M51aCdNH/avHixQKBYM6cOYCPfTAkx3uEStWVABBlU1ZWNnbsWIqifvjhh9fO/3z3RZ/5i4HfJpNp1qxZFEXt3bv33r17YWFhIpHoxIkTABlVPxlAJLdv357P59+4cYNMx8Vl31bA8OcVFRXZ2dlZWVmHDx9+9OhRbm5uXFzcn3/+WVBQkJycDBqZiIgIsFxgOBMO3M6dO9lsdo8ePejHi/DDrFixgsfjDRw4sLKy0oJ4j1jvV83IBvMh+WdQUNAvv/xiNpvT09MttoWgtFUq1c6dO11cXNhs9qVLl8w0HgECuXqt+YIsjRgxws7ODvtjMQ8JeC6lUomrTZs2jcfjXbt2TS6X/4MFjHRe1iHPHjYuJSWlcePGFEXt378feLz37SLSdTlePHq0GzVqBDQDctPg3CPEPijF4KWmpqYKhcIWLVoUFBSQqKwW0kWeC2GMXq//+OOPN2zYUFVVFR0dHRoaeuPGDaVSuX//fqTjOnfuTJrH8Y0jR44Ui8WLFy8mjEBKpRIP+Pz5c5CQHz58uPohJjZQJpPRf0mfA0bnWZk7d+6gQYOIWoQhhQ7KzMzEL2/cuNGgQQOKokaPHg1FQK72JnNFSND7559/Nm7c+OLFi686NnRPJD09naKo2bNnm99gaMPfSMCg6UncReYy1aEA4BwkJCTY2to6ODjAp/8AAkYfWYaLL1iwwMnJad68eVeuXDl06NCBAwcoiho7diyJeZC9IMfrwIEDLBZr6dKlFga5FkkOhEYANMGbKi0tjY+PLykpSUxMjI+PX7p0qUwme/LkCQqDgwYNKisr02g0FRUVCQkJFEX5+vqC+gL3gIilrKxs4MCB+Hx2djbhzSWQdnIWq+8tJhOQYwAp+u6773r16mUBv6bTGN6/f79Zs2YSiWTIkCGJiYlEawAH/FoGaEIVYTabZ86c6e3tDbEErlqhUBCuOPpfIXHSrFmz0NDQWg/+q8VivnseksAIUJHA2Ie6zZUjm1xcXKxUKsPCwpo1a/bB6lqkdIOMMEVRRUVF3t7e2dnZR48e7dWr17hx4y5fvpycnIzENx3gJ5PJ/vvf/zIYjBYtWqADn75ptdhnFGrxRQKBQCqVuru7Z2ZmNmnSJCEhAV5oYGDgkiVLgoKCrl69eu3aNR6PZ2Vlhdto0KCBj48PgfCx2ez09PSNGzceP348NDSURHHIp6OCbDKZUM3T6/XAf6lUKvIgEomEy+Ui8OZyuSgSODs7Aw6GeW4ETIzvffr06bx581JSUjp27LhmzRqMXMEfoj6BBHoNdTD01BOYL4JJPp/P4/FEIpFIJAKsjM1mk+STWq2G0sG8nuTk5A8HmHp3GQWwGpnfR48eRUVFPXr0KCMjow4tDPJOGzdupChq4cKFyIN/mDQ9ieChEf/zn/9wudzg4GDQ0ZnNZky4hatD9D1u+PHjx0KhsHPnzoRXHJoe/6ydi0jPuJBwXy6X5+TkqNXqM2fOfPbZZ2az+fLly46OjsHBwZmZmQ8fPsQRFwgEM2bMwLjh3bt3T5s2DfCOiIgI5EUIcSc94qJ/Kebuml8wh6LlntwPmkQuXrzYqlWr7Oxseq8NIk+VSjVmzJjAwEBvb29wZpJHo6fma07Tk+3V6/VTpkxp2bIlEjDEh6ITkND5Q3U63fr16yUSSV5e3gejb2G/lSgCZQP3DwoVGB+DwZCWlrZgwYKTJ09aW1tLpVKVSuXh4TFjxowJEyYoFAqoKJlMhl6Jt8Ufcblco9F47do1IHGMRiMZP/P+FvgRgJ0FCICiqNzcXJ1OJxKJ7O3tAU1wcnLq3r37gwcPFAqFQCDAkCf4TlOnTtXpdFOnTgUDBChDsG902CvgC+BfoEPD8OyoApOKMDF9ZHSTWq2WSqWoz+IeNBpNx44dPT094+Pj79y5s2fPHoqiVq5cKZfLV69ejUHvgBq5ubkNGjRo7Nix4eHhFEVBzeOriQ9CrAod6gnIPxpDYNlwPyaTydPTMyEhITo62sPDA/VujDyvqKjYunXr77//zuVyd+zYERERQSAv5Kur//xyeASbjc0RCARsNpucRurFCCty//g9Po9OBW9v75ot5F9vwUjrMSn7rFq1iqIoW1vbOXPmrFmzZtWqVV9++WVISIiTk9OoUaOQ2CUk22+7iDPds2dPiqI2bNjw5oMC3nGR8RGkvfzTTz9FV8W6detat24NRfjFF1/weLzHjx9D++KTR48epShq3Lhx5Cno1ND4Q41GQydi0Ol0iEboQzNwG3T2teoLO5yXl1daWmoymVauXDl9+vTly5cjH0NR1IABA5DTS05Onjhx4qRJk+bPn79nzx7M1njDbPBLGx9xoOn/V6PR9OrV65NPPiGbVl5efuPGDciwVCpdu3YtwrzaUTzQGz2HDx/esmVLxF0ATNPjQ/qUY9jP2bNnR0ZGfkh2Wupt5cpcbUrDwoULuVzuqFGj7ty5Ay+IuA1Lly4VCAQ9evTIzMx82+G2Fk2+aWlpDRo0YDKZt27dIqSIH6D5mjRQgylk6NChfD4/JSXl8ePHmJBkNpvnzJnDZrOBD8ChOXXqVGhoqEQiAXqAROH0yjX9ESxq0CQtrlAoXlsSJdeBEOp0uq1bt+7Zs+enn35CNCIWi8+dO4cginhfYNcj31UD4WbNvnf1tLhWq/3yyy8jIiKwdcXFxatXr/by8uLxeL6+vps2baIPhajdeyQe4KZNm+zs7O7cuUPfyYqKCvqjkSRNVVWVm5sbOkr/pkgOi7SS2Ww+deoUm80ODg6G6iWHjHxm7dq1HA7n888/pyN3apFFvHz5Mp/Pt7W1BUPwB6jE08mDUUkvLCxEa3BAQAC6g3Eb33//PUVR0dHRUCInT55E9L98+XKk6Wo4KBA8CFhVVVVlZSVhBKB/7LVZtdzcXCiv58+fQ1oCAwN79+69bt26/fv30yWhrKyMXt167WmrIb6lj84x05r5V65c6eHh0bt377CwsAYNGkgkEkdHx02bNhFIR0FBAb63dgoX4R9Kas2bN8egH/pDEbmFkOPMXLx4kclkfvfdd28S5v01AobbVSgU+CEhISE4ONjPzy87O5uMwIP50uv1WVlZ2MRRo0ZRFHX37t3aaQ781cmTJ9GsUVpa+mHMF3EOySG+e/eujY1NeHj4iRMngBWCBMJWpKSkGAyGZcuWMRgMHo+3du3a4uJiuiIgHbUmkwm+XA0bQgdevXaYN52Eq7KyEmWlY8eO0ec24VC+1LtWq9U1eE2vSrrodDqVSlV9tobJZAJzTkRExIwZM9atW3f69Glgmsg8t+rVtreSLnpm/8iRI02bNv3hhx8sSt5ktwmOZMiQIR4eHg8ePDB/QIok6m0tCV1rbtiwgaKor776iiBlzLSpXOSl3r17VyAQjB49unauHaarrFixgqKodu3avQ/AYc1+CCF42bp1q1AoxACXH374wdXVFcHP4sWL3d3df/755ylTplAUZWVlRRje8bxQSfAzLbJzqampZ86c2bx58+bNm69cuVJUVPT8+XOLCtJr6dbINYEqJIVdnU6XlZWFKcbETSJ/9Sa4JAsZM9LWq7SSwWBISEjg8/mAaBCTRVKpZG5Q7cwI/auhF2bPnu3i4nLq1CmC4rUABMPVQl37fXDf142AWcyJlMvlw4cPDwkJoXvSULTwfPBS8UZHjx5tZWVV6zyHUqkEZJZkwz9MmpWYL9RSPv30U09Pz927d1+6dEkmk124cAHb0rFjRxaL5eDgYGNjM378+EePHlnwilfXlwqFAkDYyMhIGxsbDocjFos9PT2bN2/ep0+fn3/++erVq5gAQoBaNd9qeXk5ne0MtgJzeswvph8QGg+L+NZC7GsWMMOLRfIuWq2WkF6pVCqlUvn8+XN3d/dz585hPBcxrXQXDniXd3EuCCQlOTm5f//+Pj4+JAFWXl4O0wpZOn78eJs2bfz9/WG+6IHZ3w7JgSKD0Wh8/Pixv7//woULIUIIISxeCXmFX331lZWVVa2HMxiNxh49erBYrEmTJqEJ/MPEqXhbpPWjZ8+erVq12rdvX8OGDRFY42wdP378m2++uXjxYlJSEtE+9FNFEl/4ITExcdGiRf7+/jY2NuCoIb1SSIg7Ozt7eHgMGDDg6tWrZADNm3gW2G3SFYKXRU42ileQE5C9vQlnPXmbMFyQLr1ef+XKladPnxYVFWVlZeXl5dFTF2fOnAkMDCSMevQJjHRUlPkdJiDDWJEtzc7O7tKli5eXV+vWrbdu3VpYWFhVVSWTyTQazbZt29AADv7MWmv5DyRgxP5euHDBy8vr0KFDsLmkeErX2eSX06ZN8/LyqjnX/CpfH9YAWO9vvvnG/GaY67daarUah4/8s3qN9cKFC56enoGBgXhPJ0+e/O233+gfq6FAjCOFg/7w4cOIiAgej0da2f38/Hx9fTt37ty6detu3br5+/uz2ewGDRrw+XwPD4/Dhw8j80GOKYrsdX4UyFNjVht9hzGsA6SUOp0uLi7u22+/tbGxCQgI8PLy8vDwmDVrFlDqyODl5+c3adLkiy++IC7MB0hKFRYWfv31146OjhwOx8/Pr0WLFoGBgWhknjhxIknnEk3xtys0E7Ik9OGC5EgqlSqVStJIS7glOBxOZWWllZWVTCYTi8Vyudze3r52hONAHoFnC18EFE9dVQJBSmUwGMg1+Xw+dLxAICAVzEOHDmVnZ7ds2bKqqgq4LT6fL5PJ0OfP5XLNr5iTAP4w0APGxMSMHz8+Pj6ez+erVCo7O7tevXr17NlTJBJ5enqaTCZHR0cbG5sdO3Zcu3YtLy8vJydn+fLld+/enTZtmre3N7iiSJFdrVbXIYc7n89HFAC0EV43mHwEAkFZWdmVK1cuXbp07969p0+fAq8EV4LH4+Xk5CQkJDg4OFhZWeFssFissrIyUoD+AB3ETk5O8+fPHzp0aGJi4oMHD54/fw4NNXTo0IYNG9rb2wNmZTQaeTzeh2t7f6ugn8BYDQbD06dPvby8Fi9eTIJ4pE3JlETivWg0moCAgEmTJtGD7De3YGq1uqysLDw8nMFgrFu3DhTHdajCSfBNr0uSBUx6cXFxw4YNIyMjU1NTY2NjFyxYkJqaCrQUYi3Eaa+yYLBdxcXFsMMsFsvFxWXFihW//fYbAq3qPRpPnz5dvHhx9+7d3dzckJFLSkoinmdFRcX7y4PBCScluGvXrv3555+DBw8GRxWbzba2tm7duvXGjRsPHDhw5cqVBw8ePHv2TCaTkTaC3Nzchg0bBgcHwx97T3OJqpcrXoripXfZvGq+wt/CRaSfPDjiY8eOdXFxefDgAT2JTIQQhGRms/nXX3+lKOr8+fNvXm+xOKDl5eVhYWFSqRT9FHXuIOH+IQYWYytwD4sWLSJdyVFRUZ07d7aQwxowhDhb2dnZn3/+uUgkcnV1HTZs2L179+ixExoEcU06ziM2NhazpymK8vf3Hz9+/M2bN4GQIHMP6zbgNNO6xYqLiy9evNihQwdQvoFcbcyYMYcOHZLL5Rbd2WQ0HOS/R48ednZ2t2/fNr+HiQo1F9yJLGGuKrz3V0nd30jA6A+AE3Dnzh1PT89FixbhlyR8hNbHcUlPTw8ICIiMjDS/gBrUQsDS09N9fHxEIhEZElu378xixAFsNTlwRUVFTZs29ff3P3DgwPjx41NTU7VaLUwxvXReM0h34cKFvr6+FEVh0jYd4UrKAHRdRk55XFzczJkzg4KCPD09uVzu8OHDSVdV3Spj4psQeVuzZo2npycSMHZ2dlOmTDl79iwenGwO6nUWZTqNRvPll18yGIydO3eaP1T7MF3XvFSo6L/5YDMM3i7JgQDRTBtGunXrVj6fP3LkSCRAjUYj8A1I79y8ebNdu3YNGza8cuUK3koND1aDixgVFYUAiUABqhc63l3zGQyGQ4cOlZWVWcxEvH//vlQq7dy589WrV+fOnZuamkq+ndRnSUtB9VVWVnb58mWxWGxtbT1v3rzc3FyTyQRnj1wHIR/2lnjRUMOQ/40bN86aNQvRV79+/a5evYqWx/eRbi4pKTl48OBHH32EgXRNmjQZNmzYhQsX9Ho9UH/0R6bLucFgKC4uxl3t2rWLoqi5c+eCM+fDnGa9Xi+Xy+k5VbxBjUaDH+gjIP6OAkZgnaQkbzQa9+3b5+fn5+rq+umnn/78888xMTHl5eUXL1787rvvwES5YcMGosNqIWBms/nmzZsgZ38f43TxFRqNRi6Xf/7559988w09r11RUbFkyRLk+o4ePSqXyw8fPjxt2jQSZJL5TDXcf8eOHSUSyZkzZyA85PoQMGTh6TEVsQn04bqHDh2aMWOGra0th8OZN28eRKtuXR2tVpuUlLRq1aqAgABQ6Hz77bfx8fE5OTkWw0osSjLVtzQuLo7D4UydOtX8F61XVSCIkfjbCRg5AeRswVeRy+XFxcVbtmzp2LFjUFAQxrc5ODhIpdJmzZr9/vvvdO1SOxfxxo0byE09efIEB6tuXUQi/ytWrLCzs8vMzCTA3BMnTkil0uDg4M2bNz98+FCj0SQkJNy+fZsOjX+tBX7y5AlozDAqnuwhXES6FaJzyNB1GX6flJQ0aNAgiqK8vb137dpV54C6+/fvT5kyxcbGhsvl9u/f/9y5c6QTGXSodImywD0plUrcJKBJmZmZLBZr+PDh5lcPHHofQkWHStG5T+j197+pgNVg1sgPycnJhw4d2rRp05YtW06fPv306VN6/bHWSQ7MiW3ZsiVKqO+JeMNgMBw7dszDwwMFLqPRmJKSgsm0a9asUalU0dHR/v7+CQkJ5GS/SfM5GZlFrwWRQhP6LOhVRLTNI41kAXeQy+VFRUUBAQFsNrtJkyZHjhyBfSM0gxbUMa+tehFMg0KhuHXrFjyOUaNGrV+/vvqMRfrRhBThS4lBhiARoxoUFNS0adOSkpI69Off3Cuhvxe8L7I5RDUQ9AndYNBNyLuLIlUn6p9e+SV0CHQUOXk3tXMR7927x+Vyvb294+LiiDNWt68Et3fr1q2AgID169dDL0yePJmiqJkzZ1ZVVT148KCsrOzgwYM5OTnkzL00mK55r0iGvfpWYCD3q9IwxcXFuMmjR4+irOTr63vjxg2LXCLKxK/V9KTnCPf/4MEDMFINGjQoJSUF16wuGFqtFnUX+m/Ix+huhdFo7NChg6+vL1pUzX+DhW2HG4XNB8+c+UU7Eg6tRbZcp9NZgLbfY6G5BkJ2DCtAtywadUnzMiY2vEtpGNWV0tJSmUyGGRkYb1UnlUD01arVapFIhPE2oK3WarWnTp3q16/ft99+K5fL+/XrN23atCVLlqjVajwy2o3pNM6v6sg2m81gsebxeJhOQIgxZDJZbGzs7du379+/j3kF9vb2/v7+7du3b9GiBWY78Hg8qVSK+ywsLOzevfuiRYv+85//mEymNWvWCASCli1b0ikrXrszuBQqyAwG486dOxs3brx06dLo0aM3btyIVAoI4oFxefbsWXJyMgZHSKXSpk2bBgcHY/Qrl8tFIhHVdvor8/HxiYuLKy0tdXZ2/gDDFmp4BZhCyOVylUolziGDwQBqwt7eHlGZQCBAkR2vpqqqisfjoWIOYoW/kpseRw2Ph+E0qP8QYSOF/FpIBXIAeD3kgkajsa7AHLgUdryoqCgtLS0rK0uv1y9fvrywsLBr167x8fHBwcFxcXEAJRDwBMSm+qyt6i8emW61Wo1TyGQyAVS9e/fu7t27r1y5gglM8AWgO9hstr+//+jRo1FsLC0ttbOzy8nJAYPv5MmT7ezsvvjii8zMTIy6A1MAl8sFzMVc4ww7csiYTGZJScmmTZv+/PPPiIiIYcOGSaXS8vJyLpcrEomePXu2b9++X375BehTOLp4Ukh1nz59hgwZ4uvrKxQKQUeF+QFYjRo1qqyszMzMDAwMNBgMH0DA8NTVH5yAbDAhiQwfxCeVSiW4D+RyuZ2dndFoRAs2RrF06NBBKpViBMJfQ3oDKEN1b/WleYjauYj37993dHS0tbUFUwq9/b6usoj4b1RUlIODw6JFi0pKSnx8fDp16nTmzJlRo0Z99tlnBNNM/or+gDXfD71PJy0tbevWrWBQJfxNgwcP3rt376VLl44fP37y5Mm1a9eOHDkSdTOxWPzdd9+RJhTC+lZSUtKlSxdMzbt+/bqZhuWt+X7oDGqVlZWLFi3icDiNGjW6efMmblKlUh08eHDgwIGwSP7+/v3791+4cOHPP/+8YcOGb7/9tn///mC2YDAYPXr0QFcBeUw4kEaj8dixYxRFrVu3zqIv8z0togUsEoZw+SoqKkjmkzBGksCMvMpz58599NFHmPcLM7506dJ3KZpRdRvGoMsdfoXF8XptPqAGAUtMTPT39+dyuYcOHTK/h14Vwh4RHR3duHHjL7744o8//rC2tt6+fTuSY/RKDp340QK88qqL45MVFRX79u3r1KkTPMwGDRp899130dHRz58/R/8lUUAwZQqF4ujRo5GRkXZ2dg0bNjx27Jj5BVkvicpatWpFUdTUqVNRh4QKqHmfSarNZDLt2LFDKBQ6ODhcvXo1IyPDbDbHxsYuWrQI2joyMvKPP/7IyMiwCOqUSmVcXNyqVasiIiKYTKaTk9M333yD2Iaex7t79y5FUYD8foAsYnXpQgRFb1PMycmJjo6mJ2/IsZTL5Rs2bAgMDHRzc5s2bdqlS5fOnTsXFhYmFot37979txCw6vtIWi1qbnqvWcC0Wm1BQUGXLl0oilq7du37wN0Q8NHvv//O4/EiIiLatm3bvHnzlJQUUpjC95LUmYWA1fB0OHApKSmff/453KSIiIitW7fGxMTIZLLqCRvShgzZLi8v37x5c0BAgI2NDUAzULpAVC1fvtzOzs7FxWXNmjUEoVazuSC67+7du+3atWOz2RibglM4cuRIUHctXbqUdA0TZU8kDfeQmJj4+eefCwQCiUSyZs0a9K2RbNa9e/coivrkk08+WObQ4uyh05R0haGjb9KkSbGxsaWlpSSZgdvGWI+hQ4eWlpYSb2XHjh02Njbz58+vda28bph9LTJ7BGFQvS+gFi4izs1nn33G5XKXLVtG+mHrNn+ItXv3bkdHx1GjRvXq1evRo0c4qWSSAN1M0btpXqueY2NjUb+ys7PbsmUL3SAQnBS97xgJdyInFRUVmZmZzs7Ojo6OmHxFWLjj4+MBFJw6dWp+fj49jf7a4sSaNWuYTGaHDh2Ki4uRQ/rss88oimrRokVMTAwuZVFqoz8pSfT/9ttv6LjZvn07Pe1548YNBoPRr18/84eCI1oIGByBvLw87Mb3338vEAjATwosqFarBXzv7t27QUFBY8aMIbuHp8NwwHfREW8hYMSkErNLLOybGKhaL8T9GzZs4PF4mMSBh4dHSvc86WwFdIhGzRqddAno9fqzZ8/6+vpGRERUVFRAO7wVnyleJIFcArttNBpBJWBnZ/ff//63uqy+4Tp79myLFi2YTObEiRPVajUholq3bh2aRC5evAi9RrL25MHpLY/44c6dO3Z2djY2NteuXcMDTp482d7evm/fvqmpqaRSV/ODkyNx48YN8MNdunQJiCqTyRQbG8tisRo1agT0WV0RxWJLLVixSJ2DBKvPnz/fvn27r69v8+bNy8vL9Xp98+bNBw8ePG/ePCaTuXDhQroOmj17NhqXyPVxzg8ePAhP/gNZMItJGdWBcNVxq3VlYc6dO+fo6NihQ4eX1kyJLJlfsPBaCHwNmD36O/7111/5fH6vXr1IW95bnQM6HxsxR0uXLqUoKiAgYNeuXeY3IDmsYR/u3r3bqlUrNpv9448/ml/Qwefk5LRt25aiqDFjxhQUFECocCCqg2+wRU+fPv34448pitq8eTPM1PTp0wUCwezZs5OSkujqsoa3Sa+/lZeXL126VCgUTpo0ifxtSkoKj8cLDAwsKioCMKVOBIyuLkEsiZskN5Obm/uf//wH/ayRkZEHDhyoqKhISkpyd3dfsWLF7du3mUzmqFGjcB34X3hH58+ft5h7tHPnThaL9emnn36gGAxlOJKNgR61sAbvyRlQKpU9e/Zs1qwZDi74oklL/0vJksgkLnON4GC6Sfnuu+8IW2gtBIy8Y4PBgFsqKChwdXVlMBjbtm0jO1M7dYg7jImJGTx4sI2NDSJvnOYjR46IRCIHB4c9e/aQJJ75fwnMSHd9SUkJFPaoUaOQ2FizZo1YLB4+fDihPHjtptEtNklE+fr6SqVSGECz2Zyeni6RSEDpV7fjpkhHD/1dk1Zrf39/JpPZpk2b33//nVCS/PLLLy4uLrdv3zYYDG5ubqgc4FIajea///0vn89fsmQJ0Rco7n388ceBgYHHjx+vdZLmLQSMIAlNJhPJZdFDFLpNqMPiPfo4zWbziBEjbGxs0BSDjSNAWDpju8U9v7ZXgt45smDBAi6Xu3jxYrzCtxUwC0NRVVW1evVqBEj4TQ0ciW9ycSiXp0+f9ujRIyAggL4VH330EebQmf+3iYYOOsEP58+fd3R0FIvFSDyePHnSxsZmxIgRhJgeBtZkMtWMdSR7Aup5g8EwYMAAFosFRi29Xp+Xl+fk5OTv7w9S4TqfJUBoYFQqVXx8/Pfff48ioYODw5IlSwDRII8watSo1q1by+VyvV4/cOBAsVh8/vx54meWl5cHBASEh4eTk1xUVAS+6unTp5vfoXvjLWq1aNfX6XQYj42Ct1qtxsx27KDFIJK6moBOZoGXl5ejzltZWZmcnPzHH3/88MMPv/7667Vr10pKSlA1QkMuat8gAEWUWPP1kd8rLS1lMplWVla1mH6C8fVAruBqDx48WL9+vVQq7dOnD1LzQqEQjAO148rn8/lms9nX13fVqlUSiQT2Ft37CPNycnL0er2NjQ1EvXpxuaqqavv27aDXBmT+hx9+EIvFS5cuJcT04A5gMBjW1tY1vEecRWyg2WxmsVghISESiSQmJgYlPmtra2dn54qKCsyzrKvzQAA0fD5fLBYXFRVt3Lhx8ODBCxcudHNz+/XXX2/durV06VJ7e/uSkhJra2u1Wo1d8vDwEAqFJpMpKChIr9djajuIDyQSiYuLS35+Pnrzs7Oz58yZ8+233wYFBY0bN65203Bqg+TA+G0nJydIGpvNJrAGBoMBvAWKp7W+oZcuBPE4vvHx8QC53759Oz4+Hh/w8PDo0qVL3759e/ToIRaLCb0En88HRKMGGAEmLfD5fI1Gk5qaCrceh6Z2igDTKiiKOnPmTH5+ft++fcPCwjAGAfdDwEpvdX2tVkvGKQUGBk6YMGHp0qVXrlzp0qWL2WwOCwvr2rXrnj17JkyY0KFDB3KgCfAFQxIuXbp09OjRnj17Tp48WSAQfP7550lJSZs2bWrYsCFaZiQSiUAgIPrIYDC86lViPhCDweBwOHjprq6uFRUVT548AVmIUChs2LBhZmYmKFXedj9r2GetVsvhcJhMZnR09OrVqy9cuCAWi+fMmXP//n2NRiMSiYCNcnBwMJvNIBRhMBiASkmlUmdnZ6Q0AF4DbYyHh8ezZ8/u3r178+bNCxcuPH78uG/fvvPnzw8NDYUFI8Qz7wvJQWAESUlJ69ev//nnn/fu3VtRUUEGH76ngj0Z7ztnzhyKorp16+bj40OQL56entbW1iwWSywWBwYGTp06lTCVk1xCzeBXQg1QVlYWEhJCUdSCBQtqF4MRF9FgMMTExAQGBlpZWZ08eZL4VOROaudCK5VKwkdSUVExefLkkJAQ9L8gDyQUCk+ePEnP6NApUnJycnr27CkWi9EucOXKFTabjZYtvEE6EQDQOW/y4NhAuVx+9epVDIkmpby5c+fyeDzwcNWti5iWlrZ69eqmTZtSFNW+ffvk5GRMLRs5ciT9pcOHTEpKCgsLmz59On55+fJlLpfbs2dPeui+ePFiiqKCg4MlEolEIlm1ahX+9h0nRbxdkkMmk1VVVfXu3ZuiqKCgIJFIFB4eHhMTQ/Lj9NprHcoYNuLAgQPop6AoqmnTpr169Vq0aNGBAwd+//33devWjR071snJicfjdevWDfPC6XWkN9Qg3bt3b9CgAYLdWggYyV7odDoMDerRowepYldPMNYu8CB4n8ePH1tZWe3fvx8SZTKZjhw5ArJhIsB0AcOgsLlz56rVavAgREZG5uTk0EnCza9uVXyVNkFwXlVVpVAoAgICHB0d09PT8cjoVY2Kiqqh47t2O7Bu3Tp0we7cuTMzMxPN1Pb29hMmTMCGEwYEnU6XmJhob2+/evVq84uBfQKBoFOnTjhXuP9ffvnFzs6Ox+ONHDkSzXv0RE6tY7C3Jr35/fffvb29FyxYUFVVNXfuXHhue/bsIS/yXUSLJHbolRwSpvfu3ZvP5/P5/NGjR9+9exeZX8IVYzab//jjjwYNGrBYrMGDBxcWFpJRLzUfF4PBAAksLS318vJiMpnbt2+vtQzgD/Pz8319fW1tbdetW1e3w+DxXzLLb/LkyShdkGwhSVvT3xr2sF27dm5ubg8ePICvSFHU7t27gW2trhPpTYpE11TXevT8ZGFhob+/v1gszs/Ph6755ZdfWCzW77//jiYX+jWrZwLfStvGxMT88ssvd+7cAR2A2WzOyMhgMBgTJ04k1pLUG3bv3u3u7o5+WexJaGgol8t9/vw59qeqqmrLli1WVlaLFy+uW0v7FmEAn88vKCj47bff4ImJxeIff/zx/Pnz/v7+M2fOTExMxEQ20jv4LjNpUcQwm80IVHQ63bhx465evarRaL755pvdu3eHhYVhKB7w9Qj0u3XrtmHDhj59+sTExGCoEj3t8aqvY7FYiPFKS0t5PJ6Tk1OTJk1ADFiL4Bt5iAcPHuTl5fn5+bVv376uAlGEkfgWROdcLrdDhw5paWmnT59Gnhp5FHwStXIEyTweT6vVOjs7u7u7N2nShMFgREVFubu7h4SEMJlMjNUjx9EipGS+WGS8PTxVkUgkk8kQjKlUKlTS1Wq1m5sbwmAoXxSFRSIRfR4vgh+SoXnbZA98uSFDhrRt25bH4+G70tPTmUymWCyGlsHZAA4hKysLVCg8Hs9sNmOsLobfMplMpVIpFovFYrGdnV1YWFjdYvzfLs4+f/789evXR48e7ePjA1hnjx49tmzZotfr09PT8V6hn2rRS4I+CHBr4jparZbNZvN4vG+//RYVnn79+mH+g1KpJJ1m6FwyGAwODg49e/ZcvHgxh8M5evTosmXLUNrncDivFXilUhkVFVVWVubu7o70Wu0EAFmphw8farXali1bAoxbN6+KycQu4bugMrp06eLh4XHu3Dkej8fhcCBjSEchNEVgjATJqlWrjh8/LhQKS0tLL1682LVr1+DgYPrBhbYiRoYwyJMuFS6XKxAIMAoZ0/RAJoMEwLNnz0QiUcOGDZG8JVdOSkqCBAJDB2AnXcxqMbCbwWC4urpC4yBYsrW1tbGxQRMK/bJ6vZ7H4/n7+6M7ASZLJBJpNJqYmBgejwedBYtXC4GvSwF78uSJh4cHWl95PB6oW9u1axcYGHj58mVMDcZ7evckLLQL5h7t3LlTIpEsW7Zs+/btHTt2xAah8QyfR0YLQydCQ0OXLl0qEol27dq1atUqpOkJT/VL+81A0nb06NGysrJGjRpZWVnVkNavYUHgGQxGXl4ei8XChO+6nQRP9hbf5eLiMmTIkMTERJLIJdJIxs+ScxwQEODs7IxSWEVFxYgRI6BZ6A9rftFShZG2kFsIHo4gpA6t2Ugjw0iq1eq7d++mpqay2WwwXoFtF7N2iUFDVyu5vdo1+OKGkR9GExqDwfDx8cEoY5VKBZVqNpvRIJeTk1NVVbVv376oqCiFQsFisYKDg00m04MHD6AmqqqqGAyGWq3Ozs7+KwVMqVS2atUKg6GQlsU8ecQ5yJzC7tc6J0vcS+hLg8Hw6aefIkYaPXo0mm2JqsakYAD2kSzG+Rs2bNjXX3+t1Wp3796dnJyMCLsGy4PS+c2bN5GSIqMYamGEcbhzc3MZDIazs3Md1n9wKewJzhnOaPv27XNzc4FeJY4DfEIoLPhUKAeXl5czGIxLly41atSoU6dOuCBphyWGCwuJe9KbyGQyMW0Zy9raWi6XUxSlUCiQJ/D09BQKheHh4aQIwePx5HJ5QkICSLuIUDGZTLyp2ikyomjYbLZIJEIFAuewqKiooqICehPKorKy8tq1awqFYsWKFd27dx87duyKFSvkcjmeGq/MZDLZ29trtVoEC3W42G9lW+zs7A4fPszn89VqNWwCWmLLy8sHDhxIJzSHvNWus5jMHaco6s6dO7m5uVZWVlOnTnV2dsY1cXEiVNhNuoOu1+tnzJhx48aNw4cPb9q0ae3atTW094IdIDExUaVSOTk5tW7dGmXTWkgXbsZgMGRnZxsMhtcO836XsjvY8I1Go4+Pj7W19fXr19u0aSMUCs0vepnxgsAagg5l8lfPnz8fPHgwn8+nT1uHmaquXFB0Jr3beFJskVgsBvLD2dmZMEmZTKZr165JpVJvb+/CwkKoY+JBwPqRwKl2ioYQRoAZHzcpk8lcXFzc3d3JyURnd2ZmZl5e3pgxY1gs1pUrV2JjY2/cuMHlcuE2azQaBoNhZWXl6OhoNBpr2bZcJwLGZDIjIyORumnevDl52s2bN/v5+TVp0gRPXjvHmugSCBjKsvn5+Zs3b8ZGTJ8+XaVSgedDoVBYW1tDIHEgoMOYTKZWq+Xz+RjmsHDhwsuXL1+/fj0uLq5169Y12EytVnv+/HmKojp37uzl5UU3BbUQMDQ78Hg8e3v7OuyTh+0ipXySBLK3tw8LC4uLi6P7eNhAk8kEuYJDAb8D2bauXbsiAUgEDH+CMJhYSyaTCU0H9iuZTCaTyVAuc3R0LC4uPn369KlTp/z9/XU6XXp6ulqtnj9/PgJjUq4sKCg4ceJEt27dhEIhWEmI4UIFvBZJDjp0Bl9nZWVlb28PF5QcJ9y5yWTq2rVr37599Xp9cnLyvn37Ll26lJiYmJycDB4OAKwGDBgAsNVfJmCdOnUaNmxYt27d9u7dy2AwGjZseOTIkd9//33z5s0wL8Q3gFTUIsYgAAKKotLS0g4ePEhR1Mcff4yItrCw0NnZ2draGp434gGcPGhZDEbBKQwICPj000+///77tLS0Zs2avep+4JTeu3dPLBa3adPGysqqdmwfOCgg2AIHvY2NTS0OUM1gDnh0pBUNDByNGjU6cOAAfRuJqOOpkShjsVh8Pv/Ro0c2NjbNmjVDpR7bBSnS6/UymSwrK+v58+e5ubkoBpSXl2u12srKypKSkqKiosLCQiAqgX1BAHP//n0Is1gs9vX11Wq1GRkZycnJODZ5eXnTp09v0aJFr169+vfv7+7uTvakFroYioBkfVDpEgqFEomkrKzs+fPnCoXC1tZWrVYj2/Hs2TM+n4/zyeFwWrZs6ePj06dPn+HDh9+7dw8vSKVSubi4LFu2zM/Pr64QJ7VxEblc7pdffsnn8+fOnYt3RlHUzp0727Vrh/S0VqtFyFuLEBbaiMPhICZWqVQ//PADn893c3MDhoOiKBSa4fOgriIUChHU4s/VajXOClLDQUFBbDYbNcTIyEhE/LC0YHeCI/H1118nJiYSX4jY0pqdtOquFAoMOLKZmZl4HIx0gmnVaDTEMSPdqCR0RB4c3gv4jAgZE26VzWbDMUZVisfjqVQqHo/XqFGj0tJSZFZFIhGuT9wnYlr5fL5SqezRowcAEAqFAlKHIxsdHX327Nnjx4/D59dqtWBiKi0tpeM5BQIBPEORSOTn59e5c+fg4GAbGxt3d/cFCxY0btx45cqVMpmsrKyssLDw4cOHBw8efPbsWVlZ2enTp+/evRsfH48JznjSWkDGAHyl/xNMO87Ozk2bNi0oKJDL5cgowmLn5+cTriQskUgUEhISFBSUnJyMM6zX64VCoZeXF1UrXqa6ETBgWIODg1evXj1r1iy9Xo9DYGNjg3OP1BO2rBZzq+guPkVRz58/f/r0qUajCQ4OhuEmBQDIAJz458+f+/j4sFistLQ0Jycn4kPjbIWHh/ft2/f48eNPnz7t3r07ggciihhl9uDBg/v37+t0usmTJw8YMADvvhaalcvlIkNVUVGRm5sbGBhIaLYIgZEF3xZ0ASnToYxOEhgqlUoul7PZbKlUir0FkRg9zcNisVgslpeXF7pC/Pz8AMMzv6CyQu+jVCpFfyqfz6+oqAgJCdFqtXCNMLhs//79CxYsQEWxcePGISEhtra2er0+IyPD29sbhMSlpaVWVlbNmzcPDg52cnJydXUVCASYu4W3A+SalZWVra0tXkrXrl0zMzNzcnJWrlz54MGDM2fOHDt2bMKECaGhoUCu1uGcN6VS6e3tfffuXdS4wbEFeBpmd+AzXC6Xy+VKpVKtVouKhaOjI7a9Dn2N2ggYlDGHw7GxsbGxsUHxnjjB0IJsNhufqcXGwZ8h8U9GRkZ+fj5FUe7u7hBXuIX0iEKv1zdo0AC+k5+fH0kfQfIrKioAOjlx4sSBAwcmTpzIZrMBqOHxeEiIGQyGO3fu5OTkiESiUaNGeXh4YBJfLcC+BoMB4m1nZxceHv7s2bOKigovLy8S29CjGiaT+fTpU4VCUVlZCdSfTqdTKBRKpTI5Obm4uLi0tBRGycXFJTAw0MnJCWk6uHOQN39/f+BrAwIC9uzZQ2rKkOrS0lJ7e3uxWHzu3LmYmJjk5OTU1FS5XF5ZWdm/f38WixUREdGjRw8rK6uCgoJFixZVVVUtWrSoT58+rq6u8EfotQ20V5IZiNBQeFMoOhcVFaWkpAwcOBBJI+QJYU41Gk27du0GDhxYVFR07dq1lJSU0NBQkUhEap51skQiUZcuXTZv3lxRUUFyngaD4eTJk87Ozng1gB3jMHft2lWhUKCICtGCBq9bMWO/lWlGzIN7QhyM21WpVEhAYVtrYfeJBYNhpCgqJydHqVSC80iv1xN9jykkBO2xcePGBw8e2NnZOTk5BQQE9O/fH2JD4oqwsLA+ffqcPXv27NmzQ4YMwTw7koZ68ODBunXrioqKBgwY0LRpUxxcZP/f9hHgChqNRqFQ2KNHjzNnzsB9xX2Cvub+/fvp6ekPHz4sKSmxsbHJzs5++vQpkt3YQOgsUhzX6XTPnj27desWrLpUKsWHpVIpk8mEI+Tq6hoZGTlu3DiBQFBVVSWRSCorK7lcrq2t7ePHjw8cOPDHH3/k5eUhr2gwGKysrI4dO6bX63///fdBgwaNGzfu4cOHWVlZixcvHj9+PCHZJDhMuAwsFgvkpwTVDUeRZMwLCwux2xRFyWQyOzs7k8mUmZmJbpHc3Nw2bdqEhYVFR0fDeX5pxvIdF15uenp6eHg4Xp9Go9HpdCR1QRwrk8k0adIkjUZDp8fFAf7LLBjiWvJPcq84UvRYH/r4bTtW8HkSvKWnp+NbQkJCgLKBSCgUColEAjEeN27cmTNnPDw8NBrN8+fPmzdvvnbt2k2bNjVt2lSj0eCuqqqqunXrdu3atRMnTtjY2AiFQqFQ6OvrKxaLFQrFoUOHCgoKrKysJkyYYGVlhXCOy+XqdLq3zSMLBAKFQsFgMEQikY+Pj42NzfPnz8+dOwfynGfPnpWWlmZlZQG6xefzGzVqFBAQMGDAADc3N4RVOKw5OTkcDsfFxcXFxQXTXBkMhkKhwMjJR48eyeVyHo+XlpYWExMTExPz+PHjU6dO3b17F4PVocvhSixfvvzYsWP+/v4TJ06MiIho2rQpi8WqqqpKTk7Oz8/fvXv3kSNHMjIy0tLSnJ2dBw8e7ODggA5foEBglumcqviBRLyQQNjMmzdvWllZubu7Q5LxNqVSKWoVIHHgcDhqtToxMRF+LFJTdZVoVSqVNjY2ERERyDDDCIvF4hUrVri4uCB1SSrmTCaTJDmRkCNspHXsI745bJHASQlBOaqHBLROb2SuNQcOGdsD0ojmzZuTvl1cHFhPtVq9fft2iqI+//zzzMxMmUwWHR29dOlSUNYATU8uePv2bU9PT4qivL29UTpr2bLl+PHjhwwZQlGUp6dn27ZtCfG/mTa7/a1An6RHQyaTnT9/vnXr1hKJhMFgeHh4NGnSBBNoR40atXfv3tjY2IqKCoVCQe8Kl8vldIp/IGjpQ5IIrBt/pdfrCwoK7ty5s2LFCiAex4wZAyYFs9l87NixNm3aMJnMli1b7tu3Lzs7m/ACEch/YmLi1KlTIR6RkZFPnjwhsF3C2AN4sQUXCxlcRiDRarV6woQJc+fOJb0LhJh1/PjxFEVh1OXy5csB70Lq/KVED2/S4V7De7l9+zZ5QAvENv21kn8SMq/3RHVRG9o2ICfoJCRIiNFJJ2u3CEVUfn5+p06dBAJB7969Cdab3ua0Y8cOKKctW7aQqXxyufzKlSu2traTJk2qqKggA2zKy8uRvUCjYWhoKJQLwnGKovz8/FasWHHp0iV0BGPHa4GqLigo+O6779zc3EQikZWVVVhY2NKlS/fs2XPr1i0MDqczZBA+1upkY6T1jpwMCCT9FZBhrWaz+datW7AD6FW5cOECEAmfffYZSGyqa0l0GKWkpIBwctKkSS89Z+SMIpR6VRtbcnJyy5YtL1y4QGhaMB+dCNiePXsMBsP69esBPSFzZOpcwMj+6PX6qqoqHEjC70vfh+rMdu9jstFbT7i0OAp080U/ELWD95O3++jRI1jwbt26gYGE3t+VlJTk7+/v6Oi4d+9ekNpNmTIlNjYW73XFihUURYFNmvRc7tq1i8/nr127FvJ2+PDhVatWTZ8+ffTo0Y0bN0baWiQSde7c+bfffktKSgIA4q0ELCkpqW3btqilcjgc8AFa8OxCHoBJp/fOAd9AHp/8LyRy6BtLPygajSYqKio3N1elUk2cONHBwWH//v1ZWVkdOnSwtbWdMmUKJqwTfUEIKn777bdJkybdunXLbDZv375dLBaPGzeOnEXipLz0LBJNSoRNq9VGR0cHBQXRDQW+tLKycsyYMdQLrsX//Oc/GLyEfahzASOEP0QvEH5Y3C2xqxZEg3VOtkkWuxZ5COKO071n+v+qXaRIzykxGAxwV4SFhSEIIdkCrVZ79erVkpISMh2cHEeKooqLi3v27Llz587du3d37NhRKBQixxUaGtq4ceOFCxdGRkaGhIQMGDAApQ+FQiGTyTBu/Pz589euXVu6dKlCoejYsaOTk1N4eHh4eDipURJIEQ4HsLAkg2pra9u8efP79+/7+/t7e3u3bt2a4JVJQpIk0NlsNv1hLeJV8r8sqh2of6Ahn6KotWvXfv3117/++usnn3zSuXPnnTt35ufnb926NTY2tmvXrps3b6ZHzuDYoCgqMzPz1KlT7u7uK1euPHv2LJR948aN0dWP9Cmel16zpt8D/W5xMw8ePOjatSs0hUAgQAQLQDCyMl5eXnPmzCkpKeHxeIWFhaT1hlSNa3cIq+OAcYckfiZHFK+PhHwWgd9Lf/mhY7APsIgqys/Pb968OZvN/uabb+jcVVVVVRqNZsaMGZGRkUql8unTpz179rx06RL4Zfv37w/VGB4eLhaLHz9+THdypk+fbm9vf+HCBaKoCE8T1HBOTs69e/e2b9/erl07Pz8/d3d3W1tbf3//kSNHrl279vjx44mJiaS9j+5EgWpXo9G0atVKJBJt3bq1T58+c+fOhbKvwwY+oNRh2Y4ePTpu3LjmzZt3794dz9KoUSOEmpGRkQBDvtSV2LJly6hRo548edKiRYu4uLhp06ZRFHXixIm3vU/QNlVWVioUik8//TQvL8/8vzO4sIYOHWpvbx8VFZWSkjJp0iRgoMF3/8Emkf+Fq+4ra++CFkcRDP3wcrncysqqcePGlZWVVlZW0EmoZsjl8sjISDAENWzYMDg4mMViubm5tWrVCk81fPhwYAiaN2/O5/PLysrs7OwiIiI2b948Z86cHj16NGjQIDw83NbWFicSOUxXV1d3d/fWrVsPGDDAZDJduHAhOjr67t27ly5dOnbsGOpOTZs2nTJliqurq7OzM8wIUZbJycmPHz8eNmzY1KlT09LSMMqsbnE3dLD8jRs3JBLJhAkTVq5cmZGR4ePj4+rqGh0dTVHUoEGDwOvyUn1aUlLi4ODQsGFDg8Hw7NmzrKwsdLK87c2gxMzn87lc7vTp0/GNMG4SiQSqh8PhaDSa0tLS9PT0iIiIwMBAqVTq7u6u0+lQfSLW+N+6/kYCRm+agN/C5XLt7OzIC0CSAIAmZCx69uz5448/HjlyZPPmzVu2bFm0aNHcuXPFYjGQ0ZcvX543b56trS0yGW3btm3atGl8fHxJSUlJSYmzs3NkZOTQoUODgoL4fL6Hhwdm8Gk0Gnt7ewaDMWbMmDFjxmi12vv379+5cyc2NvbJkycHDhxITk52c3Nr165dZGRkQECARCJBQuzEiRNGoxGOa5s2bTZu3IghbnW4RUg9Q9IUCkWLFi3atGnD4XAKCws9PDxAC9upU6eBAweijGbhTeFvgbiXy+XomdfpdA0aNKgdCxiKMRqNJigoqKioyNnZGbx68OpRKsBmlpeXV1VVqVQqFNYBp6hzXFK9gL2Rv0qYCXNycu7fv9+9e3eC38V5xQThJk2aODk5yeXyJk2azJkzRyQSJSQkDBw4ED3hbm5uiNTFYrHBYBAKhR4eHp06dYqPj/f395dKpWlpaf/973+PHTvm5+dnY2MTFhbWokWLrl27IreuUqnKy8vd3Nx4PF54eHhERARFUWVlZXFxcV999dWVK1fOnDnj6enZqFGjDh069O7dOzAw8NatW2KxGF1S4eHhP/30065du2bNmlVXRozgEuF2goqM5EhQ4KIoasSIEcCj4MPkBOM2EAGmp6fjGVEItrGxqV3YDIABuCREIlF+fj4w2QqFQiAQcLlcQAKAgZRIJPAXFAoFsGDg1asXsA+00CCIY6FWq4HUBMCUAF6RRrO2to6JiRkwYEBUVBTQMYMHD16xYsWJEycuX75sZWWVk5NjNpvj4+MTEhJsbGzwFtFuk5mZOXr0aAcHh7S0tLKysujo6MePH2dlZUVHR7u6urZu3bpdu3Z9+vQhrHo42Sjz29jYdOjQ4f79+1euXLly5crdu3evXr168eLFvXv3Ojo6JiUlMZlMjIEF2eiFCxdmzZpVV/tDKtHA+NInAEql0uLiYpVK5eXl1bdvX4qiysvLYTqq66/w8PAdO3Y8fvxYq9U6OTndu3cP4zNrYb6QNfnmm28eP3586NAhwvnF4/GAt2Qymc7Ozmq1+ueffwaI2cnJCUNPSJ7jfU++rBew/0kBkWADuTU3NzegctHBTrx8e3v76OjokJCQhQsXWllZ3b59e+TIkV27ds3NzVUoFPb29hEREcePH+dwOMDOAcY+aNAg2Ch4cXA+MzIycnJyrl27lpCQcOXKlWPHjm3cuJHBYLRp08bPz69Tp06kVwBeq0ajCQ8PR/koKirqzp07N27cQDuZm5sbQpGzZ89269bt0aNHcXFxdN6Ld3ShSZ8rh8MJCAhAq4hQKAwMDIyOji4sLPTy8kJSroaxwqGhoeHh4b/++itUGElP1wLcnJ2dzeFwPvnkk8GDBycnJ/v5+TEYDNguAvLA1BWz2bxp0yZ4AaQPFXCcf7cF+3tlEUmpOiUlBaCbKVOm0CueaFFBKdbDw2Pp0qVms3nfvn0BAQFxcXEmkwn6e8KECUFBQUwm88qVK4SukHDog6cFAkMKTSqVSqlUbtu2bcKECV27dsW346T26tVr5cqVly5dys/PtyjXEtzJiRMnmExm27ZtFQrF9evXYRnmzp27Zs2aOswikoqWXC7fvHnz/v37169f7+/vbzabv//+e4qihg8fTqdqtcjQYjSHSqUqKiqys7PjcrmdOnUKCQkJCwtLSkqqxX2eOHFi8ODBRUVFBQUFU6ZMAeaGTK9DEvWbb76hKGrx4sX37t1DvRE94waDobKy8v1Nvfr3ZxFhNOg/AAOGU05YGQikDb/BLwUCAak7oa+BXAFddKWlpTdv3uTz+bt27WrXrt3jx49nz5599uzZ/Px8KyurgwcPKpXKRo0aubi4QN+T9hZ63g/1KJw8dC5Onjx5woQJJSUlMpnsyZMn8fHxhw8fPnfuHOIrHx+fzp07N23aVCQSgfmHw+EgzAOdAzIr7dq1S0hIKCgo8PT0BKcFyp1Er9cOgIdDibAK3YSxsbH29vaenp46nQ4BGIzSS/Ny5EtBU3Po0KEtW7acOXNGrVb7+vo+ePCgcePGAO9yuVyVSqVSqUBTYZGnIVVaPp8fHBz8xx9/YIj7r7/+Cvw3iNM4HA6+EX2D4GKIjIyMj4/v3bs3+DlsbGyI5cQBwLuAm8Dn8wlqnPAgAE2GLCVBh+PkoKSGein+L1KUCoWCVCxJvvpt+Sz+ji4i2SDEuDqdDk0u9MIiYXcgQTaS8p6enqGhodnZ2SkpKfCLCCccrqDT6Xx8fGJiYrZu3dqoUSNnZ+ekpKT8/PxVq1YNHTr0xIkT27Zty8jIePbsWePGjUmfy6ty35AB3AmLxbKzsxOJRE2aNPnoo49GjRp1/fr1x48fX79+/c6dO9HR0YBmX716tX379qBnRNsiIv74+HitVtu3b9+0tLRff/319u3bpLOQekEUgdp3LboNRCIRttTe3j40NPTp06fbtm0bO3asRqNJS0sTCAQdOnSARquB2wvf3rlz5yZNmnzyySe7du06ffr02LFj9+7du3jx4nbt2qEETwDcxMggMQgyeg6Hk5GRAfT61atX5XJ5z549BQJBRUWFWCyGSw/VI5VKFQqFVCpF/yVFUdbW1qRtT6FQoG+InApsFFoKsG+4YdT0cFfoYUOoaWNjgzODpCVJh0LS1Gp1WVnZ/v37Y2NjHRwcQkND27VrR3qI/vEuImiJamCups8To3MDG41GYNiaNGmSk5NDZ4SFe1ZYWLhq1apr166VlZWlp6fDM5w6derBgwc3btxogTF9Q5SWBVKG8IHL5XK5XJ6amnrs2DHMmIURYDAYgwYN2r9/f3l5+dmzZymKioiIeP78uUajWbdu3b1793Jzc69cuXL27Nm8vDw6lgf0crXGkWGjtFrt2bNnP/3005SUlKqqKkR6GJRe88XpBWiTyfTkyZM1a9aMHDmSxWK5uLj85z//ARpLpVIR2K6Fq0mYwB88eJCcnAy6fDI3GC2eRqMRI56BXLt582Z8fDzEg9wkEV24/RaYrOoDLPH2oazp5WylUgkUGPkN+qrMZvPOnTsh5DY2Njjwc+bMeZchUh8C7Pu2bM/YFxT+wQRa3bMHnpX8s7y8fNSoUSiAgpDMAhOt0Wh69uyJIXRXrlxhsVi2trb79u1bvXr1yJEjdTrdgAED7O3t6QPFX3WT1cMAeuwByCWd8BkMOXPnzm3RogU08YQJEzB71tra+t69e3l5eW3btsXEg6+//nratGlk3jGiQYtRt28uYNXPOg56Tk4O8uP37t17E0AdOiFQbMRvcnJyfv75ZwaD4eLismXLFkSb+L81U9WDKY1sb3FxscUHwL746NGjGzduUBTl4uKCuWQEE4OLY4vw37KyMsSQBH1KEJgxMTEnTpwgF4+NjR0xYsR3332H78XnCSj52LFjISEhc+bMefToUXl5+Zo1a3g8nlgsXr9+fa1Hwv69BAxChddAZg1WV8n0tAGxYMuWLYNDv2vXLtJpb6bNBVYoFM+fPx8zZsycOXPQehgWFoaLfP/9946Ojj4+PniXNR9oC8AOodcELgmWDcNa8dVoPVYoFMXFxUeOHAGOBPAFkUiETpnKysqYmJiePXuWlJQolcpjx44dP368+tiE2nkEFthrk8m0Y8cOLpcbEhLyJhM96UaJAKmhOH7//feWLVtSFDVu3DhMRqcrFww3RYUAOoveoERGH+Kl4wYePnwYGBjo4OCwdetWDNoaM2YMyRXRTQ1eMUllkefNyck5efLkt99+O2LECHS72draYkyRTCYbOXKkg4ODs7Nzly5diGyTOwFBE7FXVVVVX3zxBUVRQ4cOrdvhJH9NksNoNMKG6HQ6sBaTQiQWVDLCTTjEQH8iPm7WrBl6ImNiYkaOHEl8a4TFBoMBbYXA/jIYjBEjRjg4OKSnp7u7uzs7OwuFQrQt4ZWQmPglYej/+uIkGUD/PQC+hNObcAwOGTKke/fuMTExf/zxx549e7y8vBDsSSSSnJwcPp8PPFFGRoZEIkHgjgesRQxAqCYhIUgJoJ1p165dOp2uTZs2COXpoUjNl0KpGsEVi8X66KOPxGLx/Pnzd+/erdFo5s2b16JFC/DqgFuGfhESpAH3BL0jFovxyHAdr1+/npubK5fLp0+fbjKZWrduPWfOHBcXF4KQIu36gNEg/3TgwAGFQoFZbZcuXcrMzOTxeEKh0MXFZfbs2T4+PshG/vTTT0ePHr1///7Vq1cXLFgQFxcXGRlJmOqSkpISExM3b95sa2urUqlQtWvWrBkyXnVODfAXJDlARDN79uyEhAQ+n8/j8VxcXNasWePq6mplZYW6Fp18CoQk5C2iiwQD0SorK0lhB6dfr9d36NBh5syZP/74IzC+ffr06dOnz/Lly/Pz85cvX75jx47U1FT0vNDB+DXEoji1dDmEEwUECQHOIyMCyjRYvw4dOjRv3vzAgQOg+sBxGTBgwIABA1asWPHkyZNDhw5RFLVhw4ZRo0bZ2tqin/dt95PIJOyGQCBgsVhCoTA2NvbOnTsikQgZDnppvoZXQzricMHKykqooUGDBgUEBEyaNOnAgQPOzs4MBuPUqVN2dnZubm729vbgb4Iz4uXlhdcnFos5HE5KSsr169flcnlcXJzBYEhKSuLxeEqlEu9OIpHY2trOmjULjJroKAF1CiScZPnKysq2bdt2//59Ozu7oqIiiUQybdq0iIgIkUiEaRUMBkOv11dWVt64caNnz55NmjR58uSJTqc7c+ZM+/btyRs8f/68QqFo164d2G+EQqFer799+7ZYLI6IiMBr/WcLWEVFxYwZMx4+fPjll19mZ2czmczHjx+3bNny5s2bPj4+Dg4OSKmR00MSa0gf+fv7N2vWLCYmJi4urqioyNraGjM1YcG0Wu3gwYPR5BcbG9u2bdvw8PCSkpIGDRqA/aakpITJZAJbUFxcTEAGb3Ls4BYSJCtFUeC6wL1BUAknPgib4uLiwAsLillCkNqxY0cfH5+nT5+CJAMxm1QqJaWLt8rKIpolagh9ro8ePTKbzd27dweX6BsWAEA6gsMNeg/YH7PZHBAQMHv27JKSkvXr1+/Zs4dABzEMAE8NlnmxWGw0GnNyclDkyMnJwcXJ8AdwKHTv3n3JkiU2NjagJNDpdNAvKpWKPvITZUk7O7vJkycvWrSouLh41qxZXbt2XbNmjVAoxKlQqVQ4A3l5eTdv3rx48SK6tps3bx4VFUUaf7Ra7aNHj3Q6XWZmZoMGDVAsiY+Pv3nzpq2tba9evT4cwriuekyqr4cPHzo6Ol68eJEkte7fvy8QCCIiIki2B7kjegMsvZEEM+woilqzZg0JKnA1RNVPnjyBz3ngwIFdu3Z5e3sjeEWTX7t27YqKihAuv3YUeq0XDr1OpwsNDXV0dExLSyMd3wgwlErl6dOnd+zYQcrENbRp0GkCqrcAkv5RkocEzyGXy925cyfJ49VuuBmJrDQaTWFhYUhICJvNnjdv3syZMydMmDBo0KCOHTs2b948ICDA19fX29u7ffv2vr6+EC1HR8fQ0NC+ffuOGDFixYoVW7du3bx584ULF0iVuYZz8qqVlpZmZ2fXuXNn3F5lZSWZ7oWeUTs7u3v37mGa3IABA8Ri8Y4dO8j4eQBHoqOjsZ83btwA7eFXX31FtvGfHYPl5+cHBQXZ29sTpRIaGjp16tTff/+9uLgYpS3wtJHgh5gvVFrCwsI6dOjw6NGj4uJiFouFOTowIEKhMCYmxtHR8aOPPjpw4EB8fPzYsWPnz5/PYDCQtT906FBCQgIULVUrBtm3qlChdFNcXJyTk+Pj44PYhoyr7tatm1wu5/P5qNuiTQPkdkR/k6k8iNBgKMA9CtNNBnnB7PD5fIVCcerUqQsXLqAHBOVBqrb8fkAMY3sLCwtLSkpat2795ZdfYiQ3gj00MsNFxHTjsrIyo9FoZWXl4OAAiDYcP0RZRUVFAoEAseLbAvbBcIroDsVGUKMjeszPz0eRHW/W19f3xIkTcXFxw4YN4/F4YH2mKCoxMdHb2/vo0aPbtm2rqqoaNWrUgAEDSMr+H19oTk1NFYlEpLSq1+ubN2++bds2oBkIlJbA5ImAodYOuHpUVNThw4cHDhzYvHlzRKiAZm/ZsqVRo0YLFy7ctm3bL7/80qlTp2nTpvXt2xdqD8klUAiVlZXVgM2rq4UZwTBBCoUC8NnKykpg8xD6Y+4Bnpp4R9SLRi/yT8gVUj4mk4n4M0jrJSYmFhUVZWVlPXjwYNeuXUwms1u3bsiwUbVieyfvC1SHLBZLJpOVl5e7uLgA2An1gcERxBbxeDxHR0fkAMGSQM9CkcdE1oGuSd9w5eXlgfKN4EuoFyyu1AvCWTabDTJJIB5v3ryZk5MTGBgIbkaKogoKCrp27ZqQkMBgMObMmTN//nwwTFZWVr6P0RwfVMCCgoIwtSQgIAA5IvDF29rawvtHwIBMoIWFQRTEZrNxTDMyMh49etS2bVs6LHjZsmVarfbJkycLFiyA33Ljxo3Vq1fb29uDvga0OUwmE7j499R6RC47b968CRMmnDx5MiIiws7ODpGYlZUVcv1VVVXW1tagFkTnP7FdpOyLcAhd9xAS5ABKSkowEffKlStxcXGxsbEwHVKplMPhLFy4sHv37gCFEY7o2qGBcC6FQqFYLHZ1dRWLxfBmGbQFdQC8BbBmFhchPjCAHTCMtQATl5SUYCvQcATNC+VbXFx8//79Ll26QPjFYnGXLl28vb2fPn2ampoaGBgIfQGAiLu7e1BQULt27QYMGABrbDQaP4x0vV8B43A4o0eP3rt3b//+/e3t7VUqlVarBeIT+UPiMxBuBtLFBEgOm81u0aIF8EH3798fN26cXq+3trYGVs3V1fXq1avffPPNjBkzevfuff78+YULF96+fdvR0RGUwB07dsR8GvBD1FVc+ypZhfzv2LGjS5cu/fv3x/wBjUYDh4TQaIM5GB4vSRjQNYtYLEZVis1my+Xy+/fvHz9+/Pbt2wKBAJwFcJ9EIlG7du1atGgxbdo0QPjpeqoWWEecYIBFlUplWVkZaomE9fb/L56+wJpCwMgcZ+oFvwj5dpCQW1tb14KL1sXFBRS32CUgPyDbVVVVz549AyzD2dk5ODgYSSz4Dkif+Pn5CYXCysrKP//8k/A0krEE/wYX0d7efsSIEd27d//oo4+GDh0qEAhOnjx58eLFLVu2eHp6EhtloQgJXTt2ITQ0NDQ09Pr165cuXcKQcrxLfD4wMHDfvn0sFuvPP//s0KHD8ePHExISIiMjbWxs7OzsMHET16nbrBFdxsgPUql04MCBZ8+eXbdundFo7Nu3LxBViEasra0hAKhB0UtVyJ4VFxdnZ2cXFRWpVKqcnByZTKbVatPT02NiYioqKsCF6unp2atXr0aNGgUGBgoEAn9/fycnJ9T6SMhXa/5n3A/+sLy8XCaToehvkQ+DmaXLMFQh/RvRys3lcisqKgQCgYuLSy2MmLW1tcFgKC0theTDowYLKjjSnz9/npSURFEU6NOzsrLImASDweDt7c3j8ZB/RiKKzlxEH330TxUwmUzWpk2b48ePb9++fdmyZUwm08XFZceOHd27dyeeOsix6eqWDK7GyXN3d58wYcL169eLi4uvXr06duxYgrivqKjA8UpPTz9w4EBERESDBg2QLB45cmSHDh3gl6vVakKj/V4tmLOzc8+ePS9evHj9+vXExMSgoKA+ffoMHToUMTc9s4+7io+Pl8lkeXl5OTk5OTk5WVlZOTk5ZWVlaMlBOoGiKCcnp5EjR7Zr1y4kJMTb25tUaUGvDVsHT5ikSZAUqcWj4crl5eXPnj3z9PTs3bs3XTER0SJ+B5mWSFxclOkReIMornaTNJBoQQkbvZuk6ZbNZt++fdvW1nbu3LlQWCkpKadOnaIoCkNekAODliHjeIh44y38G9D0qAWFhYWFhYWxWKz8/Hxvb2/0I3G5XLVajRCCog32JuU/vBKVSmVlZdW9e/emTZtmZWUtWbJEJBINGzaMwWCAxwao6kaNGp08eRJ/5efnB1kCdgStCmScYR3KGPW/fBKYSzJ16tTS0tItW7bI5fKbN2/GxMQcPnzY398fUQSglWlpaWq1WiaTpaamVlVVwVDglUulUqFQ2LRpUy8vLzTCNGzYcNCgQYGBgSSRSMQA4RYq4LgTVHvQxVi7mBOb//Dhw7179yoUipCQEFJbp5fgSfxMnp0+KwMOP4/HA5IdnTW12OSioiKxWOzt7S0SiWBLORwOPOfExERPT89Zs2bBsHO53F9++aVx48aIHmHMi4qKGAwG5siQV48+qQ9JBFIHAvaq28WOk3IqJkeSRDAdykAQQGgcJq4OWAStra1XrFgxfPjw4uLiEydOoKcQswWgqIjpJz4nKpgATJDYgHwdQXVUVVVB19YAngBig35eyVQ7jKRAuEj09IwZM0JDQ0+fPn3jxo2srKwnT54kJSWhWYt+jqVSKZ/Pd3V1bdOmjb29vY2NjaenZ9OmTX19fUmvJz1tgG/BlqKNim6y8DFSqa95DirZJZggutByOJzMzMwtW7YkJCSMHTu2RYsWL036V+dwt/hNZWUlCiTl5eVgpKzFuXJyckJvGDkkBAZ1+/bt8PBw0hmAlGxoaOiVK1fS0tKgx5HKJxCcms/qm2vVGpwacnGiYkwm09+L9Oali8fjtWvXzsrKCs7A8+fPGzRoANgBdh9jdlFf0uv1mPgEPAEMI94T2qX5fD78KzabTSbxvKouRKBPZLoXkS4LN4OcA2tr6w4dOvj6+o4YMQLKOyUlBbVRoVCIPxEIBFKp1NHR0d7e3sXFxeI23ncXPYwt4IXYPUBDioqK1Gr1999/f+zYscDAQAxzqsX1TSaTra2t0WhMTk5OTk6GW0vqE2++Hj9+XFpaCv0IXBXcxXv37kkkEm9vb6SgCXxMLpf7+PiEhYWhUhcWFrZ8+XIyPOW9LjJrkwzxgjvG4XDeI5r+bVvQa/i8wWCYN28eh8OxtbWdN28eAO9yuRxABxC1o/qJ3xDYBxDWjx8/Ro8DfX4FMNc1tKzTqaGrA/At0BJAgr+qE0epVCoUClCfk8+A05/eECWXy2Uy2dsiHt4diSKTyZ49e7ZixYoePXpQFOXh4bFnz55aY1+AJjEajceOHaMoqm/fvqRJ7K3WiRMnbG1tJ06cSH9NgO1eunQJzWYE3KPX66dOndqxY0e0Plh0lL3X84wWBzo6x2AwKBQKkH/9AwQMUNSsrCzgRL28vA4dOlS9Wat6byJkIDs7u1evXkeOHCFdDPTex9fSoyPzW51/HxKlUCjIuJOXtpBW58YAropcCrJKFEQtIEW1g0RptdqioiI05uzatatJkyYwpA0aNDh16hQZ6FEL8l3CAr9x40YOh4ORK2Ta2JuvBw8eWFtbd+zYEXtY/UkRz0M3YTbAL7/8Qv5v9c60932e6SXND9EPVlcCRhTSH3/8AYscGBhIuu4wsIfYE2hK0ocWGxvbr1+/Nm3axMTELFmyJCYmBk1QxJrV3J5osX1QnwAHvRQr+Cp4IX0sENkEi0ZGHGjT26/aWS30/27fvh0BEpvN5vP57du3P3jwIH3iRO3YraE1Jk+eLBQKjxw5gou87XOp1erRo0fPmDEDPBzESoC6FMU6OjyVsBuByZx0i77v84xCAp24CduL3rl/gIARc1RQUAAiAIqi/P39N23aBP5D7KzFWdfpdFevXgW+8/r166dOnZJKpd9++y15Hyh816yJyZsDDJL8r6ysrOPHj+/cufP06dMZGRnYX7iIhheLCOEbzpp5qf57l/2sYUVFRY0bNw7xCZvNdnBwcHFx+e6775KSkuDQvrn6eNVKTEz09/cXiUTJycmkMfRtFQeGA9J34KUCD8VHfBk6M/4HO8/owSWfrKqqqqysvH379j8jBsN/KyoqEhMThw0bhi6moKCgZcuWPXv2DDgaaA74k2azecOGDcHBwb6+vt99953JZDpz5gzw9USo6JwQr1oklgOdgdFovHr1au/evUn0b2dnN2zYsDNnzpirDXCqPmwKIoQUE2ncRsyAJo6apaWuBKyqqgrdBm5ubuHh4W3btl2wYAHI9C0+Wbu+etzSli1bGAyGv79/ZmYmApW3FTCcVzJOqbqFhHNI/18WgwLJfLD3ep7VarVSqSTKKDU1de3atYMHD/bw8LC1tf1nCBi9AT49Pb1jx44NGzZEh1KLFi02btyYnJyclJR07dq1c+fO/fHHHzNmzJBIJBwOZ+rUqbA/J0+exERwTLKkN6W/Nl4nn79z506rVq3AlPjzzz9v3769V69eqLktWbIE5ovu5r3Wdawu4TUYjTq0YDKZLC0tLTs7m2wstH5lZSWxxu8y+kSv10+YMIHBYPTq1SsxMRHOQu0EDGyWhLuSHj+bX8wwgAQikUhn+/hg51kmk924ceO7777DZDZSFheJRH8v4tGaOTOINnr69OmBAwd8fHy8vb2RJPX09LSxsfHw8ADpGnIhq1evBhuH0WgsLS2NiIjgcrn//e9/39CRoM8WBOHRokWLRCLRgQMHyBBHs9l84cKFNm3aMBiM0aNHx8bGKpVKvF18xoKppjp31YdfrxVUUOJYRKGwyfSbr+E6RqNx8ODBFEUtWrSITpLxd1swrXTfwaIfj+60k9lRdHqYhISEVatW9e3bl9QeHR0d/f39AwMDv/7669OnT/8D6mCEEZEAFHx9fUUi0Z9//nnt2rUNGzag4At/RiQScTic+fPnT5w4MSAggPCoYH7KnTt3kpKS+vTpQ4pgNYzPIW1sALCmp6ffuHEjNDS0W7duhBdEq9V2797dyspq9uzZe/fuzcvL+/777728vECIUFhY6OzsjPeHMs7fmZCdbAW9YIXGIuaLRUrteKJXXQo2BHhUjHr4G54rnCVSzES0D4JaMgYAlTdQ32KYI1rac3Jyjh49euXKlezsbOAhhUJhy5YtIyIiIiIiGjdubGdnJxaLGQzGP0DA6LBaYGRZLJarq6urq2vDhg2RxmAymQUFBe7u7vb29hqNpnnz5s7Ozig64dBA+5K6qgWIpObXAHHKyMi4ffv2L7/8Ymtri/5rgpxo0qTJgQMH1qxZc+DAgTZt2kyfPn3+/PleXl70kVmkxk+4KP5u+0wUDaEfxpkDVoaM5CSHsgZkQ2pqanx8vEgkatWqFZPJ5HA4hHPh77MANiAQR/rkTrTtoOGD4IS0Wm1xcfGjR49OnDhx6tQpAI4BcGvbtm2/fv06d+5MMCtVVVXFxcX79+//BwgYUTYWACWFQmFtbT1ixAhoVjrLBUw/OqbxeQ6HY29vz2az8/LyiJZFb0jNSA7wQFEv2v5cXV0JLy8+gHGp3t7eGzdu/OijjyZOnLhjx4779++PGjVq1KhRDg4OUIfmF2zhNeOY/vJFuJYBa6wdKDY1NTU3N7dnz57gHfiQ4Nq38oyImkOTDplMb2VlBRgxDl5ZWVlWVlZqaurBgwcvXLiAycABAQGhoaEBAQEBAQFNmzZFExpFUenp6Xfu3Hn06NGuXbsqKir+ATEYqsnVQxdSKaYn01HjUqlU5JdAUZjN5osXLzo7Ozs5OUVFRSG7UL0KbOGgk6HaGo0mLi7O3t5+7NixJAmJdhj8s6ysDD8XFhbOmDEDCcaePXsmJCTQk3KEXPUvDEtqqDeivkQAChgiRVhKLQLUGmKwlStXcjgcUCz/bQMwUtt8abJRJpPFxMTs2LFj/PjxQUFBEomE+M89evRYv359QkICPQ/06NGjtWvXfvLJJ23btkUWAOjEf0wMhkYgC4wiRZt4jQ+gU1UgEEDG+Hw+cL1ms7l169YNGjS4devWjRs3wsLC4LrU7JoCFgiAmbe3d0RExMGDB6dNm9ayZUtYNnhN4DxDfdbGxmbt2rUURe3cufP8+fMVFRVjx47t0KFDkyZNpFIpSKf5fP7f0I7BQUJYj42l7w8KDOQVgD7gpdfBfBnS0IAnfX8d5XXlGKN5SqVS7d69OyYmBr0OBQUFKpWKyWSiS7hXr179+/f38vISCoWAMj98+PDq1at5eXnx8fGpqak4crCNEOB/gAWjpxNRXEJGy4LKXCaTAcBBYBzmFzS9wAFoNJopU6YwGIw+ffpkZGSY34BhF9cnyfojR454eXkFBwffv38fxgppbsJNi4+VlJT07du3d+/ekydPhoLo2rXrzp07s7Oz/yZqu4bsH73ODvMF5ITFn9dwncuXL/P5/LCwsMTERDqG8O92nGCEzS9omDdv3jx27Nj27duDswgleMxk/OKLL0DMLJPJcCSKiop+/vnniIgIqVRK+B2qA/b5fP4/QMBeVUkkP9M9PbpnWP2lfvfdd3jskydPymSymgvN5LLEydHpdHPnzuVwOE2bNt27dy+9koabLCwsNBgMu3btoihq165dkMlevXohZmvTps2uXbuys7NrTZ39vkGrxOPNyck5dOjQl19+OXz48H79+i1evPjKlSsWlehXXWfp0qUw4HDjX4v2/AtXfn7+vn37Ro0aRZgRYKIbNGgwfvz4zZs33717F9lpg8FQUVERFRW1Zs2aYcOGoWGPPhXIoq+HMGpSdfvmECkiZYdJoRb10xrO1ktrpoA71IAtIhC+N4nlSktL27RpQ1FU+/btS0tLaxj78qpQUKVSDR8+HAnor776iqCuwJWPn5s2berg4FBcXAxW9MzMzF27dg0ZMgTOUrNmzQ4ePAihpSNFLEqo9DgT2uSlW0ewIIidyD6DOB6HmyCJUfoj0TzRC0QrlZSUHD16dOzYsX5+foT0ivTvrV27lkzeMP/viAyikvLz80GWGB0dDTp78+uoIGthaekoNvJ2iCQjsU7OG1HQcrkc91NZWXn+/PlJkyb17t2bcLm3atVq6tSpS5YsOXHiRFpaGh3pduvWrSVLlgQHByMtTCIUOtHVq1YdCNhLEQkW66W4pJdiEegiavFhbByK9xbY2TcENKhUqqlTp6JAcfbs2ZrBoNVvDNyA5eXlmLlOUdQ333yD90rmyCQkJNjb2/fq1YvoSGIAz5w5Ex4eDlUnFouHDh26evXqAwcOZGVl0TcHAzjp9U0LU0yfimJR+bWADpHBJfiB3qGDDxM2z+Li4vPnzw8bNgynp3379suWLQNTQ0pKyuXLl9u0aTN27FiIKKFVpStN7MOlS5cEAkGrVq0AZsd31Q4UUnNB3Gg0KhSK0tJSuicCgwmFUlpain0DpVdFRcX169d/+umnL7/8slOnTkRU7O3tx40bd/Lkyfz8fPrdmkymW7duLVy4MCIiAqBNiURC5xTCBIUPIWDVTyFGmGo0GoVCgVdL35eXmqAaRBSRQF2Nwzh+/HinTp0oivrss8/MNZLgWhhG2AccJoVCgbm1FEVNnjwZaUmFQlFVVXXlyhVHR8cff/yRjhSBfSstLX369Ckmo0NxikQiFosVFBQ0ZcqUTZs2Xb16lZxF0P29Cj9FNoQEosR80bEIyHMSqFF1TJbJZLp48eIPP/zg7e3NZrOtra379u177Ngxoi9glq9everg4DBu3DgLAAQ0FD4DV2revHkURU2bNo0ohVq/uFcJGGGDpr8piBndXccPSUlJZ86c+eqrr3r06EH4RkUikYeHx/jx47/77ruLFy+SWAB/XlFRsWvXrk6dOr00EYVpFXTPsGYBq4MsIiE/QeWEnusjhTxCa04YXklaCRwJmM9ARwyQDaUPbTDT2jpeisCoIVuF/xUREVFQUHDnzp2rV68+e/bM398fSbPqbfDm/6UcJrwUKpVKIBCMGjWqY8eO06dP3759+6lTp1avXj127FiKouLi4hQKRfv27SUSCXpagZBgs9kikcjW1tbT07NNmzYLFiw4cOAAOFjT0tISExNBtOrr69uxY8d27do1atSIPDjBf5CfifokG0WIbjBrE9xVuGHC6ARGwQsXLqhUqoyMDEx/j4uL0+v1QUFBn3322cCBAzt27EhRlFwu12q1YrFYJBJlZGT88MMPWq22Z8+eSBJi2gP2zWw2I9kolUrLysouXLjAZrM7deoEHQFnoc7bh/GkUC4oBEN4oMWuXbsmlUqfPn2ak5Nz4cKFiooKmUyGqbOOjo6tW7fu1q1bx44dnZ2d7ezscKmKiornz5/fvn37wYMH9+7dKywsVCgUfD7f1tZWp9NB01G0Yah0oAL9n69EKrz7IhTtBPNKMPx0n/jNVRdd/cOTRmMi3Tl8w0CO3CHuKj09HQMdv/76a3QZvXS2XQ3RHXHbnj179ssvv3h7ezMYjDZt2ty4caO4uDgqKgq2kU4lj6CIaEqNRnPo0CF/f/+4uLj09PQTJ07MmjUrLCwMb9HGxiYgIKBnz56LFi3at2/f6dOnz549W1BQAJImvHLS12jhW5J+JLLncrn83r17W7dunThxYrNmzZydnZs1a9auXbvRo0dv3Ljxt99+8/Lymjp1KrE5xHJWVlaePXt2wIABPB5vzpw5FmEh3RLiu3bs2IFRDJh7SObr0ceIvbsFg02m94PLZLKUlJR58+b16tUrLCxMIBBgti1m1WLce7NmzT7//PM7d+5YIFHT09N//PHH8PBwtGgQw2AB7wI58UsnXdVswRjmt6dcffNF55eFnIBwhsQzwFmDRMHV1RXuJaFKFgqFoEySSqWEipX4mbh/C7ajmolNUMnR6/VHjhyZPn26tbX1wYMHmzdvboG1q/lSZDaXXC7HXZ0/f37btm3Hjh1zcHD46KOPPvvsM3iPwH+AEQR2nsxBZ7PZq1atWrNmTVJSkrOzM/pEBQLBkydPCgsLDx8+fPHixeLiYtC5MJlMDIB2c3PDmD8XFxc7OzsrKytHR0cMFDeZTDKZrKqqytXV1cvLi8lkVlVVcbnc+/fvP378WKVSicViDw8PiUQyceLETp06YVoNvImgoKBWrVrt3r0bkg/X6MGDB7/99tuxY8dKSkoGDBiwbds2R0dHwg+Ls0WuAFkaMmTI+fPnR4wYsWvXLuJfgI2jFnbsVSeTfqmcnJwbN26cPXs2NjY2OTlZIpEEBgbq9XpMG23Tpo2dnZ1Wq/Xy8oLyQpknJyenoKAgLy/v4sWLZ8+eLS4uJldms9mkCAFJE4lEiGyr12ar8ym95G7fXcAIWxjhgsYqKSmBCmcwGAUFBRkZGfn5+aWlpdnZ2SQjh3IwBEwikeAFEwFDrtPFxcXd3b1Ro0Z+fn5ubm6urq4eHh4g6wX4iO6UvragCXbYzMzMBQsWHD58eMmSJYsWLcJ1iIBBt72KbQrmiCg8hENCofDKlStff/31/fv3GzRo0Lhx4zZt2gwbNszf35/OdQXGbDSD9O7d28HBYe/evXRfHyogPz9foVAAXlxUVFRWVvbgwQMej+fr6wuQGwZNyOVy0B6r1Wqce7QRSKXS+Ph4iqK6desmFosdHBzatm3r6+vbsGFDcEfjKQoLC8FgNXDgQJ1Od+jQIdxJXl7e+vXrN2/erFAofH19x44dO3nyZBcXl6qqKoPBYGNjQ+SKPJpOp7t9+/bAgQOFQuGiRYumTJmCOjVOau2AlzUIWFlZ2bNnz27cuHH8+PHo6GjAAEaMGBEZGdmyZUuU8ul0N6BDTkhIuHv3bkJCws2bN5OTk8EJizQpg8EAfyu2EZ1QRKhwtokrCF0MRf9aAauDGAzGtLKyEty0WVlZeXl5lZWVCQkJOTk50M1yuZyEktVdatiikpKSl1oPkCSDQsjGxqZJkybh4eFBQUEYfG5hxGoGdxKUrbe3d7du3Q4fPnz37t2X3tVLXzapPyKFWFBQ4OzsDBxJZWVlp06dMCp26dKlJ0+ePHXq1OHDh0NDQzt16tSrVy8bGxuCl4XTHxsb++uvvxLEMDIKkFt7e3tXV9eAgIBOnTrx+fzY2NgJEybMnz8fM3LVarWLi0tBQUF6erqrq2tubm5WVhaMPJvN9vX1TUtL+/HHHzt16jR16lSEfwDa4sQgey6RSCBdlZWVIpFILpeLxeKYmJjTp09fvHjx3r17XC53xowZs2fPdnZ2lkgkSqWSzpgPg4x/AgUaGxsrl8sbNGgAl1IulyNQpKNp68QtysjI2LVr144dOwoKCqRSaY8ePfr169exY0d/f38cRbqzYzKZYmJibty48fDhw/v37+fm5oKTE1YXDFAqlYoYJZC3Q8XjXCFSgPdBT3eR01vz4WFbQDyJeiP9CDqdjgCo4Rsg+/zkyZOnT59CcmJiYvLy8srLy0tLS6VSKY/Hw/w7aK//RxDHZtvY2Dg7Ozdq1Cg4ODg3N7dx48Y8Hq+qqqpXr15arfbAgQOhoaF+fn75+fnR0dEZGRnQLikpKUwm02g0VlZWlpSU3Llz5/r16wwGY/DgwZ6enp988kmjRo00Gg22FQaKKBicAKByCUkl6EpHjBhx7ty5Bw8e7Nu3b9KkSZWVlVZWVvBgsa0WmaL/2TU2m6IozFvAsrKyqqysdHFxmTZtWp8+fa5fv3716tWbN29u374dvBcfffRReHi4p6dnQECAQCB49uyZXq9H8IbNV6vVkC4kRXAn0JF2dnbp6elFRUVoeAPa2MbGxt/fn8PhBAcH45aI9cZsSGdnZ+QqUUGGl0j46kCaC2b8Vq1a/fzzz3379o2Pj8/OzgYV1Pjx47t27QpqSrPZTBBnhKUMWwRCSIPBcP/+fYqipkyZ4uHhYTabkVR4E0JCmEGUYcjEJpIAgzliMpmpqalPnjyJjY397bffCgsLHR0dv/zyy1GjRgUEBHC5XMKXTG41Nzf35s2bjx492rhxIx3/hdkA+AoiPIQtD6+DzAo2/y8fZvXHea1qZuNF4kQizOXz+SSYU6lUFRUVFRUVCoWCxWLFx8ffuXPn8ePHz549q6ysxMHicrklJSVgTZFIJMAXo0+EwWCIRCL0xggEAkdHR2dn54iICDI/iqKo0tJSzMho2rQpvjckJKRPnz5QjTKZLDMz08rKysbGhslkFhYWPnny5PHjxxkZGY8fP7548eLGjRvbtGnz9ddfR0ZGggmYRGjYTQSsIJomlUGTySQWiyMjI8+fP79x48aQkJCWLVsibq61ukXa0GAwuLi4jBkzZvTo0YmJiXFxcRcvXoyNjf3xxx81Gk2DBg1GjBgRHBycnZ29cOHCVq1a4TERbVIUBcZiaAQ08wKgDd1EZ+Ejd4s4DScASq2kpEShUGBeFGnowt5WVVVJpdLnz5+DcjAzM/PixYs3b94EJ36zZs2mT58eGRkZHByMa1ZUVNCj/+qxEIpsZ8+ePXHihFAopM/grp0rRFxKk8mUl5dnZ2f36NGjLVu2xMbGFhUV5eXlubq6fvLJJ8OHDw8PD7e2tja/YKol4X1SUtKlS5fOnj177949UKAiZUXPu34wrCMb4o6eDvwMWEBeXt7du3fv3r2blJT0/PnzvLw8sVgM+BZJ0eKpXFxc/Pz8WrRoERAQYGVl1aRJk6CgIPBakkFydH8dVONE9GF5IABQY2h6w4w5W1tb+jtzdnZu2rRpv379FArF06dPN23aVFBQkJOTM2zYsBkzZmCGPNJcZF6bhUHTaDRWVlbwasaMGXPx4sXz588vWbLkt99+c3JyohOg1yJ9TNxdnL+goCBnZ+ehQ4fm5+cnJib+97//PXLkyPLlyzEsD73lQqHQ398/IiICiWYAsSFgmB1hNpujoqJUKhUUEyJeelsk/kkfzcpisTw9PTHwG1pWoVDcv38/JSUlISGhqKjo1q1bxcXFbDYbfKx+fn4ff/xxv379GjRo0KhRI/q8+RqauLCr0JJxcXFqtbpXr16ka6MWDbXEk8ekMnSvXrt2raCgAH2AwcHBmzZtghNEF3swIFy7dq2kpCQ1NTUuLg52GJAllMVIeuxDdzMiD85isUCnfuXKFTDRFhYW5uTkIDqkXoyEYjAYtra2/v7+TZs2bdasWXBwMPodJRIJzgcS9HBzySxj/C00Lo6UhYkgaXH6QCPzCxpx9FnCUyXzbLDkcnlOTs5vv/22adMmUMOvXr2aPvoJ/gAZRkwcMHhNfD7/9u3bGzduPHDgwKxZs3744Qd0s9Zu9AZpSAMxExSWRQRSUlISFRW1d+/eEydOoL28uLhYLBb7+/tLpVI/Pz93d/fmzZuXlJQ0a9YMhLtqtfrXX3+NiYlZtmyZs7Ozvb29u7s7gnI42Nj5oqIiELMWFxefOXPmhx9+6NGjB4xVWVlZVVVVenp6eXm5Xq/n8/lSqdTT07NJkybBwcEhISEhISH0oY+wnJivVXOyoaKiQiwWP3v2bOzYsU+ePNmyZcv48ePfJPtXPcQl/jzypefOnVuyZAl0TcOGDceMGdOkSRMWi9WoUSMIGwJ7BoMhk8kOHz68Z88edBZDYiUSCZPJVCgUiKbe9n7qUsDgISDmAfAC5LJ4/Z6ens7Ozp6enm5ubh999BEZfU3SzfQsBUrpBMOGXSNhbvV8AxnWhLNCwidCmE5vSaZnySHG2EoulyuXy48cObJmzZqMjIxBgwYtWbIEc1UqKyulUinxsOliptfrNRoN1PO1a9f69eunVCq3bt360UcfQTW+S1e/RSYTOVJgQ5VKJUyQ2Ww+evSoRqOJj4/PycnJy8tLTEw0m80oTlRWVmJgrEQiMRgMgB2RzKpUKiVjMfz9/fPz89PT0+/du6dSqUhOFW6nUCjU6/USicTBwUEqlTo4OAgEgsDAwMjISPTeKhQKTGapqqqC8rJ4X2Qcx0vLFWBgX7t27bfffjt48OCVK1ciAKvFgQZbCRRcRUXFjBkzDh48OHDgwCFDhqCntrS01MnJCRVRDofz9OnT/fv3Hzp0CLE6RkUTD4iEyhi0+1dJF0VRDJRokDnhcDiOjo7h4eFGo9HLy6t9+/aBgYFisVgikdBnNbw0kQ3HksQ51ScsEvARxn8gh1s9G06E1uI39D/HlYnFgFG6devWxP+Pve8Oi+ra3j4wA0MZGNoAUqSDiBpUQMEGRgRB5Yoa0KtRsberxq7EFjHqJZYYGyY2ROxYMIpYEGkWQAQB6QjShhmYoQwDDOf3x/u5n/OhYmISvebe84cPDsPMOfucvdfaa71l5sy8vDxXV9eVK1eOGzeO2bNiYjXIH6JaIBQKz549u2jRIisrq127do0ZM+YPMoIphlg5JBzenHWdxkckEqWnpz9//hx4q6ampuLiYtwUiURiaGjIZrOhCSGRSJSVlaurq1++fIkZK5FIeDyekZFRz549cReUlZURoHR1dU1MTIyMjLS1tbHTpigKSiHMle7NBYI4qnRRZEckqaio8Pf3T0tLi4iImDhxIloRHxDBgGzC39bV1Q0cOBATu7i4eMmSJf7+/qWlpSoqKqWlpVlZWXl5eVlZWSKRCOUNIFcItALn/9aEllSDyVPxlx8cDsfExKR///6BgYGHDx9+/vx5WVlZSUnJmyp54A6jL0x4r2D7vlWs5014xFuxi+g1Mz8EeDOiL/vm56MfTdN0ZWUlJh4USHNzc8eOHauoqAhfMgJHILA9wA46sZvgf7ds2TI2m+3n53fu3LnfhbJnjk8nQSKC28AoMdGxuDomHKGTBBUusLGxEZB8grLLy8urrKysr68vLi7Ozs6Oj4+/dOnS3bt3IUcnFoubm5vfZIgQyCX5fOZXt7a21tfXM8eZKerYBegWVmxoVaekpHywvBxGBv9iTTEzM9u3b19hYeG//vUvJqiCrEqobJOFmGl4jcAFsximCzZT3AUtk49wUKGhoRcuXECzn0mgwKP/pvb6mwh3cifQP30rvAgPN6qinSgSnVBRhAaH/xLSPn7VSc2TrAIENyQSiZYsWUJR1JAhQwDYIV4EzKmFS2OeYWZmJowSXVxc0tPTP9g3oBOcB+sRk3ZAZhF5va2tDerf0IhmUtHIKIHZzkSmMwkKGBz6tSo4ViVyjVhB3kUXeivLgYncf9eEaWhoOH78OCrJt27dwiICRNjvnWDM0a6trZVIJHZ2dqdPn8YroaGhVlZW8HxisVg8Hq+LElSnONnJxIz5+keaYJ1G/M8CrX9aZu6ePXvYbPbUqVNphpgmWSYIkBwPK0IEqBZ9+/bV1NS0t7ePjY0l/C48AXiCmQSn95J0Ps71/ommEO8C/jHBjWTOP3r0CHvd9evXYwyZRgIfTK6VSqVisdjCwiI0NBRXUVFRgeIki8VCpPqMDqoToeiTy2L+KeItCQkJgCkkJiZikcadIzrVnRbv2tpaxIdHjx4NHTqUoigvL6+oqCg8THj/W0eGaJJ+hMn2qSYYmVQikQiLTkNDw/Pnz2HPN3bsWCTqTAbn76U4ET1WUN1qa2tNTU137doFvZ3s7GwLC4vfSA/5j5tgnfDjf4MJht8eOnSIoqhJkyYhUewCX08iGJLJR48eTZs2jc/nczicDRs2EB4eYldtbe2buPuPE/Y/1QR7czeek5MzZMgQQAJu3ryJwWFKoXzAVxNWGzjgfD4fogPgdFlZWTF5Q5/fBPsTDd0++QQjGSCsWKZPn46iBZbDN9VdyFFdXY0fMjIypk6dqqmpqa6uvnz5ctz7mpoazMBPNUSfMIJhAFHFefHiBXA2GhoaR48eZXJh/0gYJxRPmqYfPnyopKR06tQp/Kq0tLRXr17ADZKe0OdyKDKRrG+SDj/Hg8ViVVZWKigoLFq0yNra+ty5c6mpqaiXErgtwjWRKK2rq0Pfr6Wl5eHDh1lZWbW1tWgi/fDDD9OnT4+IiODz+Si4E4gQASuhIk/9TQ+5XM7j8SorK9XU1LKyssaOHXv9+nUjI6OQkJCJEydyOBxo3P4WYF4XvQ0g/cha1tbWhsyC+v8NWj8myunPOT6vqPUbV1xSp969ezdFUbAhZb5OapWkvCaXy8PDwz08PACbhC5SVFQUdhoWFhbPnj0rLS3ttHlgcij/rhGMVDUuXbrk4eEB9iExGcVRU1PzZib527+XbPMwwS5evKioqBgSEgJboOLiYiJJrfC5HYofs6v9cQ4CI5ZKpb6+vr179z5z5kxMTAxWE1A2CHtNJBIdP378+++/nzhxYnBw8JMnT0DXu3//vp+fX3l5OaxbiouL58yZc/LkSeBxsY6SD6H+I6Wh/6wDcL6QkJDVq1ffu3dv5MiRt2/fnjhxYlNTE9Eh5/P5AFsxIee/FevwmgTExL4oKSnp6uoiZUDOD7zyf6Cm/3vAvkzgPY7P7hreTBEBbGtubraxsZk8efLatWt//fVXJyenx48fV1dXNzY2vnz5UiwWl5eXp6SktLS0GBoa1tXV9ezZE1jSa9eu9e3bV0NDo76+fsGCBXw+f/HixSkpKS9fvjx16lRkZCRN03p6eghcn+Nd/11HU1PThg0b4GLTv3///fv3W1tbi8ViFRUVY2Nj0O8BSQOc/wNyKPBH2Gy2VCrFsMtkMrCB8LFMnYjPbPg+fkpDxgskpU5tTVLnJaLzSBuIogbTLPRNXAJRfUpISLh3796yZcv8/PyINgP1Wi4Gy0qPHj0cHR15PB4gqufPn+/du3dNTU11dfWWLVu8vb3Rt502bZq/v//cuXMBU7SwsNi6dWt1dTXp6kLmgHSHiepgpwb6J+k0MoeIKcbUSXCS+Suio9jY2Jibmztp0iRMm5kzZxYXF8tksvdaq5FUvJNeGFOnnnwjzpAp7TRv3jwulxsXF4e3CQQCpKaATX5eKeIn0KYnyYCCgoKqqipxSwEilkDgSXqA9xP5EJKMoQGKyhIAdc3NzS9evEhPT79//354eDh4X7a2tpqampqamqAnduvWjc/nm5mZ6enpNTQ02NjYFBQUeHh4FBUV2drarl27FjwAHx8fLS0tTU3N4uJiLy8va2trQ0NDFxeX7du35+fnBwcHP3z4cOXKlaampubm5oBWEoSkXC7vdPLM/KdrPYI/90DChhNjkoyo1zpfgBoSbjJkhZDslZeXHz169Ny5c8+fP3d1dQ0MDIScIFDLXcN2cflQdwSnEzGKy+VCsRCwXXJnkYgCE8tms1++fKmjo4MCEgAcWlpaTHms/0WwriIYsFdEWA/APKa0KFNUFbBDopUJWYg3tSwrKirOnz8/depUkMeUlJT4fP6CBQsOHjyYnZ2dm5tbUVHRCaFXXl4+c+bM5cuXd3R0pKWl9e3b9+LFizRNb9iwwd3dHd7b7u7uCxYsQJg1Nzfftm1bR0eHo6Ojrq6ulpaWkpLSwoULsbknOQxzwSaCu2/2VT9O+Hqr4CTxue0knkVirFAoPHTo0KBBg9TU1CB3ceLEiXeBG988EN+YoAXc6E42K1VVVZ1eIYHRycnJwcHh7t275CqgiPpblHT/446/bkl41yeDVEt16S7J/AScJNY5QnTHKxCKqK+vDwsL279/v1gs7tmzp7e3t729fc+ePXv37k2Q/gCMYlEEyYKiqJs3b2ppacHNWSgUcrncxsZGKyurvLw8bW1tmUxWW1trZGTEZrMrKip0dXXBvqmtrV28ePGLFy/gzsbj8QICAlatWqWmpgZ2iVQqBW0EakpEGgVR673SVx9nVWWeACaDsrJyTk7O7du379y5c//+/fr6ejs7uy+//HLatGm9evUi+gUII4DSd13cxyWjYIsbjfRSUVFRR0eHcJoIYJ88D56enkVFRZCQwPyfNGnSpUuXCCnxfxHsPWXlNxf7trY2EmGY1ltY/AjUlamUiEW0tLR0ypQpbDZ7wIAB4eHh+fn5CBr4Leq8ZM8GvWEETPLJbm5u33//PU3TFy5c0NbWzszMpGl6+fLlQ4cOhQ6zs7Pzjz/+SNN0SkqKmZlZTk7O4cOHlZWVLS0tHRwc9PX1KYrq06fP3r17nz171mmZJ22ATl4wHwFaxSwMdHIiBlsRg0PQhnv37h0zZgyyOxaLNWTIkPDwcGY2QdBM78VDEVw84SVIJJKEhAQyPvDORgv7TSTanDlzNDU109LSyEdNmTLlM41gn2CCYVhJWsjsICGn6sSYwO1kbtaJomVMTIyfnx+Xyx0+fPjDhw/f9eAS7Vsmgh4litLS0uzs7Pz8/OPHj+fm5tbW1j5+/Dg8PFwikSQmJubl5Z06daquri4+Pv7YsWOJiYnV1dVZWVnffPNNt27dLCwsNmzY4Onp2bNnT6xWPj4+x44dy8zMfKvrXCfewF89wTqVNJiZGHPMY2Ji5s2bN2DAAJRwFBUVfXx8IiMjy8vLMScJU4HJcngvBYl5I27duhUYGAhRlt27d+MmEisG3F/829bWJpVKFy9erK6unpiYSO71nDlzYGP7vwn2myYYWdcJDhDs7k5iulCSwsPa0dFBlj1Ibd64cQMqfxs2bMAtxzslEgmTecXkv5AaV6eiWXV1tZOTE+79oUOHBg8enJqaKpfLfX19x48fj8+xs7Pbt28fTdORkZGOjo4BAQF6enrdunWbMmVKXFxcUFAQSgVqamq2traTJ08ODQ29f/++RCIhplJdk0Q+zpYMIUUoFN65c2fXrl2TJ0+GRjebzTY2Np4xY8aNGzeEQiHiLeHR4W/Jvuu3YFaJA8vhw4f79evXvXv3CxcujB49Wk9PLzY2Fr9i7oqJsH5tbe2YMWMsLCwePXoEewOapufOnUu6jv+bYO+ZYET+uqio6Ndff8W0uXz5ckREBPi54eHhFy5c6OjoqKmp2bx5s0AgaG5uvnnz5rFjxxB2njx5Eh4ebm1t7ejouHnz5qqqqk6sp045Ev3atIVMZvwKlQzoBEokkpqamo0bN8L0NTo6GvONpukffvgB7JWqqqrg4OCCggKapvft26ekpGRqaioUCq9cufL48eOkpKSVK1cCxY9DS0vLzc0tKyuLrCMfs8JBqkQko6upqcnIyDhw4MDcuXN79eqFnY+GhsbIkSPXrVv34sULArZk+ie8aR7bdYrI9GEqKiry8fEZOXIkFr7o6GgFBYV169aRJgEmLf4EI1NeXm5nZ+fm5gbcDL5r1qxZqCJ+dmX6P22CYWlsb29HLQhPM/NOgI5J0/TLly/xZN+5c8fFxaWoqIim6W+//Xbx4sXgRHh6ekZERMjl8lu3bg0ePLiwsFAqlR44cGDMmDG4ZyNGjICE6C+//EKqYe9ilPxGGhJN0+fOnRs8eHBlZaVEItm/fz8siBoaGqZNm7Z169b29vakpKQRI0bcv3+fpukTJ07w+Xw9Pb2jR49u3LgRwa2trS0nJwdeiZhpSkpKBgYGs2bNOnjwoFAoxFNFGFaEzEqWamYyRiKtTCZjWlEzF36mzxhZuVBoIfhm4JjPnDmzbNkyPp+vqKjI4XC0tbUdHR2XLVt2584doVBIarNkv8p0aSG5A5MSziTOknPD3Qd9u6OjY9euXTY2NiSnyMjIsLW1Xb9+fae2GMn5pVJpVlaWgoKCu7s76PO4NPCmP2+6yh85SBbHbF/iiamqqnr16hVeWb9+fVhYmFwuf/78+ZQpU0Ayj46OXr58uUQiEQgEGzZs2LNnT0tLS0VFxcyZM+Pi4trb2+Pi4hYsWFBTUyOTyfbv3+/v729iYqKlpfXtt98ScOAHk5GwrpOfxWJxVFTU0qVLEXNWrFixdetWbNi++uqrpKSkhoaG5OTkwMBANAYoipo/fz6m/ZgxY2JjYyFJfeHChbS0tCNHjkAVFFBjPT09Ly+vM2fOoIUqEAjwNDN3hgKBoNPDysyomaUgdLdJBCbLHFY6Eh9iYmLOnj0bHBwMKWl9ff3x48fv2bMnIyOjrq6usbGRCcvswuuw0w+dkl5gczH+eBjw87Bhw3bs2CEQCPDfp0+fGhgYzJ8/vxOfnclofvDggaampp+fH9po+CKYHhKnnv+uRjMR3EL9HYkyBHCgrFZdXY1SW2lpqY2NDTSMIEDd1tZWWloKbSkNDQ2oxHE4HEhNQce4vr6+qampoaGBz+dnZGRcvny5o6Nj+PDh06dP7969O8q7ELFBGff39nD5fD5AiTo6OpqamlKpFLJNampqPB4PV6GsrAwZMEROfX39hoaGYcOGmZmZHTx4EI7MkIurra2F/LCzs/OsWbMGDRqUlpZ29OhRJGAxMTGpqaksFsvKykpbW9vX19fFxYXFYjk6OkJrWk9PD1mZsrIyiv4wfKqsrFRUVNTS0iLalahoC4VCWL9XVFQYGRnxeDyJRJKVlSUWi9esWcPlcgsLC9FxoijK39//m2++MTExMTAwwIhBN5K0ekkvBEp+xMkb74GeDKR8IUfF4XCSkpKeP38+c+ZMHR2d8vJyExMTCNyzWKwbN26YmpouXbqUSERDEd7W1lZFRYUp+0P04RQUFDIyMsAfh8gUzgFi10Aj/Jc2msmSVlVVhZ/Pnj07cuRI7Jhnzpy5du1agUAgFAq//PLLs2fP0jQdFRX1xRdfQK9mxYoVM2fOFIvFUqnUx8cnNDS0tbX1yZMnvXv3LiwsrKuri4iICAgIcHJy4nA4vr6+yBvp1952f3yHg+QWNf26uroff/xxxIgRiF2BgYHbt2+naTo1NdXDw+PGjRs0TYeGho4dO3bu3Lna2trm5uY//vijSCTKysqaOHFiVFQUTdNHjhzp1asX2tCrVq3y9/ePiopauHChiooKcWDAYWRk5ObmNmbMmHXr1p0+ffrp06ctLS01NTVVVVWdygmkA5GTkxMfH5+UlPTw4cO7d++eO3du3bp169evDwwMnDBhgo2NDfVaw5TP53t5ea1evTouLo7pQ9vU1FRXV0ciCX6A9kkX97eyshJ+YqTPsX37dg0NDehnMG2rcnNze/XqhWwQgyCRSMaNG+fg4AAPIWIBxZQkaG9vnz9/PkVRHh4eyEtxvZ6enp9pmf5PiGCg4mNBbW5uNjAwwMAZGBgMGTIEbZbhw4ezWCw9PT2BQODs7Ax3HyMjI19fX7R0R40alZOTgyZs//79XV1dgaf29PRUUlLS0tKCczl8D6ZMmUJcF8DDI4vFB0CQoEqP9IM0iG1sbCZOnNjQ0FBXV+fh4WFhYYGa9aBBg/r06SMSiYYPH15VVeXk5HTixAmZTCYQCLS1tUUiUc+ePRGuraysfHx8ENgHDBhgZWU1atSoYcOGubi4GBoaVlRUnD59uqWlpbS0VCwWJyUlqampXbt2DQHc0NDQ0tLSwMAA8DFjY2NVVVVEIZlMVlFRUVBQUFNTQ1Z6SNm1tbVxuVwej1dcXOzm5gaqqKOjo7W1NYwOIDuJ7jxUE5mqZp2AbHjcYSCIAI4i0C+//LJy5crvv/9eSUlJIBDw+fyGhoY1a9Y0NzfPnDkTOaeurq5AIKipqXn27BnpraelpV29enXEiBFA8ULmmnrtt4BzY7FYLS0tiN70b5O2/6+IYMihz549C0xNRETEiBEj0FVctWoVKt2NjY0BAQHwcbt58+bgwYMTExOlUuny5cu9vb2x3ffx8YFPaU1NjYuLy88//0zT9N69e//5z3/+85//BEc9PDz8Ta7+H1ETIRbD2L0gouI4c+bMgQMHANUdOnTo4cOHgQnu06dPWVlZe3v7vn37AEJ9+vSpk5PTpk2bOjo6nj9/7uzsfO/ePZqmN23a5OXlhU8bPnz4kiVLUHJwdXWNjIysr69fsWKFoqKit7e3v78/EF48Hk9FRQWJFsSMyc3icrlMmSSsQZaWlmZmZvPmzVu+fHloaCgQkh4eHhkZGUyhHrLZI4OGcP3mxhXKxPX19SSa5ebmoo6nqqq6YcOGyspKBCWRSHTs2DE2m83n83v37o3QRGj/np6eTk5ORGXA3d1dSUnp9OnTzE0jujJMmjmsj3x9fVExxq/+8Y9/KCgoAH/zeUUw1qZNm/74LMW+AmJACgoKFhYWioqKtra28PiwtLQEaobP5zs4OLBYLHV1dS0tLWdnZ4qiTE1Ne/bsidKWhoZGv379DA0Nof7l6+srk8l69OgRHx9/+/ZtTU3Nb7/9NiAgABLtBBYM76bfaGL0VnoLdlx4lFVVVaGqD3F5W1tbrPQikcjNzQ3cFjs7O1NT05KSEhaLZWRkFB8fz2Kx/Pz8fH196+vrFRUVeTyeg4NDdXV19+7dTU1NdXV1RSIRn8/38PCAo4WVldWQIUPU1NTMzMz69++/bds2V1dXX19fHx8fe3v7VatWGRsbx8XFWVhYjB8/XllZeeTIkWpqav369YN96+DBg0ePHu3t7R0QEDB79mw7O7u5c+e6uLh4eHh4enryeLyIiAgYKzs4OABoC+dBOF9Rr6WLCdcG2TWBQamqqmJLVlpaumLFinXr1uXk5Hz11Vdbt24dP368tra2urp6U1OTpqbmqVOnHj16tGjRolu3brW1tY0dO1ZBQQF6zHfv3s3JybG0tBSLxbt3775y5UpQUNDatWtxp7C1w5cS8LFcLr9//35ycrKJiQlQ/MhKrl27lp2djfn2XweVKi8vnzFjRnBwsEAgKCoq4vF46CQeO3bM0tIS8n1TpkyZO3duQ0PDq1evrK2tL1y4QNP0wYMHDQ0Nc3Jy2tvbly1bhpVeIpHY29vv2bOHpul79+5paWmlpKQsWrQI9TqC+n0TDdSp4PanUDxIcRJblAcPHlhZWV27do2m6e+++87c3Jym6bt377JYLDc3N5qmMzMz7e3tIyIiEOhMTU3RowsKCvLy8mptbRUKhQMHDjx48GBbW9uZM2f09fXz8/OBzPriiy8QTidMmLB69WqxWDxr1iyKoqKjo2ma3rVrl7W1dWtrq1gsHjFiBBzcnz171q9fv+PHj2O09fX1EVigUqypqenm5gbILGkPENAWGUkCRybxCvlIc3Pzvn37zMzMFBQURowYkZCQQPZvzM7Y9OnTzczMbt68yeVyvby8mO2E9evXUxQ1atQo7Aj69u376NEjJrqAfCnZTre1tYWEhOCv4OmDG/r111+TJPazB/u+F6SLTQtiyMuXLxsaGmQymYWFRX5+PpfLraur09XVhWFXaWmphYVFdXW1hoaGgoICPCnFYrG5ublIJFJTU3v16pW5uTk8ZiDazuPxRCKRgYFBaWkpvOTOnTt3+PBhZ2fnbdu2OTs7A9HzJxq6vVdPARgCmUwmEonq6ur09fVTUlKsrKwkEomBgcHFixevXr36+PHjHTt2ICYbGxu/ePHC0NCwubmZOCeh062rqwsLtaamJi0traKiIlilaWhoQPRCSUlJU1Ozo6MjMzPz559/jo2N3bBhw4QJE5qbm4VCYY8ePeD2VF5ejl5WfX29qqpqdXW1jY1NUVGRiYnJy5cvbWxsCgsLExMTg4ODzc3NY2Njra2t4YrW9bhBSxwbMJhcent7Z2dnC4XCqKgoa2trApuGwblUKl26dOnNmzezs7O3bNmyd+/elJQUR0dHmDBdunRp/PjxsJ7icDgXLlwwNTXF7SNEHjLOYPrK5fLvvvtu8+bNM2bMOHr0KPXaBmThwoVhYWFg3HxmnMvfBXEqKipipvXNzc2jR48eO3YsUBSWlpZ79+5Fx7Z///5YO6dPn/7ll1/ik62trVesWEHTdGxsrJ2d3dWrV2maXrlypZubG0pGzs7OX331FU3TcXFx9vb2ly9fTkxMhIP1lStXSL3rU2nLyWQyLKu//vqrSCSSSCSBgYGzZs2aP3++vb29oqLijh07WltbHzx4YGNjg8izZcuWfv36yeXyhoaGoUOHLliwoLW1tbS01MDAALIWGzduHDZsWElJiVwunzBhQlBQkFgsLisrc3JyQmpqbm5uaWkJfMnUqVOHDRuG3ZS1tfW3335L0/Tt27cdHR2vXr3a0dHx3XffjRo16sWLFzRNu7i4WFpaKisrjx49WiqVQlata4iWRCIh91ooFKJft3DhQg6Hc+jQIWZPH4GutbXV3d3d1dW1o6MjLCyMoqiNGzeitYB9l46OTp8+fcLCwmJiYiC10ClHIOeDak1zc/Pu3btVVFQWLlyI6iLC2pw5c6iPKMf71zaa3yt+giM+Pv7cuXO1tbWNjY3w42lubq6srNy2bVtBQYFEIklPT9+3bx8ao6dOnTp//jxshU+ePJmZmdna2pqRkREWFiaRSPLz8zMzM48cOYJ7ExkZ+fTpUyBxUZHbvn070c3rQgb0L2UEvxW5AtTV7NmzuVyujo7OgwcPbt68GR0dDVWCHTt2FBcXy+XyK1eu3Lt3DyIWZ86cycrKqqmpycnJOXTo0KtXr0QiUXR09Pnz52HhGRsbe//+/aKiIjxVgYGBTU1NL168OHjwIHKzX375JTExsaWlpbi4+OTJk2VlZXV1dU+fPj19+nR1dTU81O/cudPS0iIQCAYMGMDlcm/fvo1ssGtxHowqOrzkGvfv309R1KpVq5gJJDK66upqExOTNWvWIF81Njb29vYm7W+RSNS9e3cXF5dOkonMSU5ogeQEDh48qKCgMHr0aFCwmRMMsffzE735jQcuD1b2crk8Li7uwIEDmpqaysrK165dy8jIUFVVzcjIiIyMRL24pKTk8OHDjY2N9fX16enp9+7d4/P59fX1W7duTU9PV1JSSk9PDwkJQXp58uTJtLQ0LN67du3KzMxsamrauXOnTCbz9PT08/Njs9nIRdGU/Hj2MwoKTFYi6UzANkldXZ3FYnl4eBgaGopEon//+9+HDx9ubW1VV1e/fv36tWvXDA0NFRUVIyMjT58+Dfvz8PDwmJgYPp//4sULhAVtbe2YmJhDhw6Burt58+anT5+am5tXVFQAPaympnb58uX9+/fjHO7duxcREcHhcMrKyk6dOhUTE8PlcjMzM7dv397e3m5gYJCQkLBz507YiPbq1auxsXHPnj319fUNDQ1diPOQ7AvOUmg9w2KbmOYA9kG9NjguKSkRCoX9+vWTyWSmpqZeXl5lZWV4A1rVHA4HNDkihkN2fczhZRacCLaDvAEV/L9Pmf69MmCPHj3avHkzVrtDhw6FhYUJhcLW1tY1a9Y8ePCgtbU1NjZ21apVeXl5LS0tV69ePXjwIJTuNm3aFBYWRtN0QUFBQEAA6vjHjh3bsmWLWCymaTo4ODgmJgY8oi1btiAlgMIrWTs/AtHjvQdZkuvr65HcxsbGmpubjxo1KjU19fnz58HBwcjTwsPD161bhz9Zu3bt9evX29vbi4qKFi1adOfOHZqmjx8/vmbNGqlUKpVKt2zZcuDAAdSNli5d6u7urqWlNWLEiNDQ0JSUFIlEcuXKlY0bN6KasnLlyidPntTW1paXly9atKiiooKm6evXr+/atQvAl9DQ0OvXr8tkMh8fH1NT0y1btshksrfyaDppaSBVIw/DTz/9BO42IdSRexEfH09RFLopLS0ta9as4XA46Gfi05ydnQMDA7H/JFx1Js+aPFcEGLVnzx4lJaU5c+bg/XjDggULiHHZ3zaC4WhsbIQYU2lpaUNDQ0lJSWpqqo6OTltbW1paGkyrlJSUcnJyxGIxh8O5fft2cnKyrq4um82+f/8+SiPATAD/AtQCFMkLCwuBk3j+/PnOnTvlcvm8efNGjx5N2pEIpPjDj1DheOvr9fX1enp6eNR4PJ6urm5jY2Pfvn29vLxu3boVHx/fo0ePYcOGoRqkqKgIO1MOh1NbW1tcXIy1vLi4GKtyW1tbZWVlQ0NDdXW1goKCQCBoamoyNjYuKCioqqpqamoqKSl58OBB9+7dNTQ0UlNTBQIBRVF2dnbp6ek5OTloABQXFxcUFAgEgvz8/Pj4eIRQqK8qKyujMh4aGpqbm9s1hRz9CXTbm5ubQRgdOHCgpqZmYWFhW1uburo6Thves3w+X0FBITk5maZpDocD0Bl2g1i72Wy2UCgUiUSkzU299trFzCG85v+He3jthi6VSknfBTPwc203/y6ayY0bN6ZOnVpcXNze3n7+/Pm5c+cC3LR169Zt27YBKe/t7U1QvJMnT8Ziv3Tp0o0bN6KGO2HCBJh33bhxY8yYMUCv79q1a8GCBehdbty40d3dnWK4TkG3A80xpuzRX80IxvHW7yLhlHhbrVmzhqKoRYsWwTkeb0PdHJv+9vb2uro6FKmlUmlVVdWRI0cAuYyMjMROprGxMSQk5Pz58w0NDUeOHKEoavjw4e3t7SdOnBg3bhzgv0uWLAkNDZVIJAUFBUFBQXFxcc3NzfHx8T/99BOpoRN4Pv5duXIlRVHgK3RRwnmrpVt7e7uDg4OTkxOuhRhQtbS0FBUV6erq2tvb//zzz01NTUlJSXZ2dijDYDvt7e1tZGSUmpr6VioNE6JNvvfAgQMURQ0bNgxvQPTDHuyjmXp9mggGqz745RE7Vg0NDbKYYT3W19fHSgOhJXRvdXR0DA0N1dTUKioqDA0NUYnW1dVFUVhDQ4PFYhkbG6Msm5SU9ODBAz09PSsrq169ehG1BjU1NdiBAlnzEfQVkaOSFZR67f5IdqRsNhsRCW5J6urqt27dSkhI4PF4SAuh0ITlCahcDAgaEqNGjYKAh5mZmZubG3xc+/fvr6Ojo6SklJ+fD3UnmGLp6OhoaGhIpVI7Ozt0clEBAk5NRUXFzs6OaFArKyujnq6uri6RSBYuXGhiYpKcnNxF8AeOGXhFwPbxUSjNy2QysVhM4g+eB4lEoqWllZeXt2LFiuTk5C+++AJALWQ6ysrK1tbWjY2NZAOGKgvTgJuMJOzFQKJTV1dHpGXK8lB/QJr7P67RzNQYxL8FBQUDBgyIiYlpaGiIjo729/cHCWXOnDkLFy5saWmpr68fNGjQlStX0Iz38PB48uQJtlXgcYG88MMPP9A0/fjxY2dn55iYGJqmd+7c6e/vj7XZw8MjJCRk165dFEWZmZmdPXv207q9MIkkBJnahd7jnDlz1NTUUJvBmX9Y4xv04cjISIA2iIzkB0hk45murq4eM2YMh8PppBrCjK5dfIifn5+joyN2lUwpy/j4eB0dndDQ0NWrV3O53GvXrm3cuNHKyqqiogJrytWrV/X09BISEt57kmRrHRERQVHUgAEDCgoKCPh44cKFWMU+u0o9+627LC6Xi74k8fBlsVgTJ07U0dHBJsrV1VUikWhoaLi7u2OFEwqFAQEBMpmsurpaW1s7ICBAR0cnMzPT1dXVwcEhOztbR0dnxowZampqAK0uWbLEzs6uqqpq8ODBampqLBartrZ2/vz5N2/ejI2NVVVVnTVr1ujRoz+taC7pupIddhfSfGw2e/jw4UePHt26daunp6exsbGenl7Xe553gaeB8QUaEGxLFRWVD1DnxqmCGWRnZxcTE5OUlARGCZICInTRxTi3t7cPHDiwoKAAMAOAlbDyqqio1NfXDxs2zMnJqbi4ePv27QAS5OXldevWjcPhuLq6rlmzxsLCopOO1ZvJAmaXgoKCSCRSVFSEXThAXuDvdI2C+CyhUtjmohQGCkZMTIyFhQX4yGvXrh0xYgREUaZOnfqvf/0LqFArK6uEhAS5XB4VFWVvb4892IIFC2bNmoVuSe/evX/++WeZTHby5EkjIyOsqUFBQbNnz66rqxszZoySkpKjoyOwnu8Vkf3rjjel/wi86F171NzcXDs7Ox6Pt3jxYvA4OxnV/q7m2/bt21VUVIYPH97193bNISKh6fLlyzo6OqNHj35rK+xNW2fmONy5c0dfXz8nJwcsYyLvkZycrKend+vWLbzz4sWL/fr1CwoKgiAUkbLsesPcST5x/fr1KioqgwYNwi4Xholz584lSP+/A9gXCXRLSwuWcAMDAx6PV11dbWxsrK6u7uzsXF5e7uzszOfzVVVV6+rq9PT03N3dYXevra09bNiw3NxcfX397t27m5ub19XVGRkZ2dvb0zTN5XKtra1dXV0rKir69etna2urr6+vr6+vo6MDlG1ISEhzc/PXX389cuRINpvNNMD+yAchkqKlQ6iHXfQJNTU1U1NTMzMzMzMzR44caWZm9gHbRVRW2Gz2kSNHUlNTbWxsAgICfrsr8VvFCbHRvXPnTn5+/sCBA7t166aoqIjrIuH3XZ+DSsPp06ddXV1NTEzwSNA0raqqeufOHblcvnr16sbGxqampr59+06aNMne3v6LL75AfRha80xly7deL04DmLKoqKi0tDQejzd27Fjs1Tkczt27d1NSUtAl+zuAfYEJwkJVXFxM03RaWpqjo+P+/ftpmv7+++979+6NapiPjw+hY1haWm7YsIGm6Z9++mnAgAHga8yYMcPd3R2YVwcHB0ClUlJSbG1toaS7atWqPn36YEc3cuRIiqLc3d2JnkQXCrIf4QCLHleKTh3dpeY+ODsURWlqas6ZM0cgEHxAtZOI72M0Zs2axRRO+70RjJwYhrpbt27//ve/YTUIyO9v6StWV1cvXLjw+vXruB04HwwLhEaYiQaCISlmvilA9K5NIP5w0aJFioqK1tbWGRkZ0KVEFfozjWBU13p6JPRnZWWVlZVlZWWdOnWqoKCgqanp119/jYmJKS4urq2tvXbtWnp6ellZWV5e3tmzZ589e1ZeXp6ZmXnjxo3c3Nzi4uKEhITc3Ny0tLTc3NwLFy5UV1eXl5cnJyefP39eKBRmZ2dnZmZevnyZy+UaGhpGRkYSlZVPezBLFITG24UkOKTI5s6dC0X1s2fP/pG2uKenJ5/PRxv3wyYYUdTBf2/cuNG7d+9p06Yxjc6Ib0bXR3Z2NtFW6cQrI+h4sVgMPVOizMHkUHd9kkRvZ+3atRRFWVtb5+bmQnWvvb193rx5zLru5z3BGhoa8FgUFBQ0NjYKBAIXF5d9+/Z1dHTk5uaqqamBV7dq1Sp3d/eamhqpVPrll1+uXLkSII9u3boVFBSIxeLDhw8bGhpiDxYUFOTv79/R0VFeXu7o6Lh3797Gxsbo6Gh7e3t0utatW4eIOmfOHJqmcS+bmpr+oGv9H9Q8I88QpK/wDHXxoONJLSoqgsLMjBkzPsyYr62trayszNbWlsPhADTcxcTuYiPHVG5tbW0VCATu7u6ampqXL18mrvC/t05LCqRtbW0IXOhSdsKIEM2p944AE/grk8l27txJUZSTkxO81dEzwASD78Rn3wfjcrko2lhZWamrqzc2NsbGxnp5eR0+fLiwsLCmpkZVVTU4ODg4ODgqKurBgwcRERExMTHffPPNtm3b5HJ5Xl5eSUnJiRMnvLy88vPz7927d/DgwZCQkGPHju3YsSM/P//q1auBgYFhYWHm5ubx8fESieT48eNQkkAuLhaLjYyM6uvr1dTUuhZA/whAxLq6urq6uitXrqD4yeQXv7UASFGUhYXF7t27lZWVL168CDDRB2z/KisrX716JZPJmL61HyZAjz1Yc3MzqppNTU1AeHA4HKJs00V1Dr+SSCTYVoFX0tbWRnbISkpKqqqqcE5BL6upqQk3DtYqqIR1Mcj0a6tYmUyGPZ62tjYBnbLZbFVVVWwmPzvRm/fsv9GeR3320qVLYB+lp6cnJiaijh8REQE+b1tbW3R0dFZWFihh0dHRVVVVXC734cOH0dHRhoaGGhoaFy9eTE5O1tLSKisru3HjRmFhoY6OTlJSUnR0dExMTH5+vqmp6YoVKyCNBOIQugKfpI4KvI+2tvaBAwdOnTqloaFRU1MDRvDbkwGKgk5WR0dHQEDA119/LZFIDhw4AEoleYKbmpqo1zYUb32s5XI5h8O5du1aU1OTr68v2IpdgBi6rnDAJQioLqlU6uDgIJfLHz9+TCYtKo1dfA5+hWdARUWFTCqapvEvOUBLp2laTU0Nr2D2Qt3gXZ8P/ypsuTU0NEpKSiiKAoyY7LtKSkpomv60q+2f/Hhhqw3EzfLly+Pi4mQyWV5eXlBQUHl5uVwuP3fu3ObNm9FlDwkJuXjxolwuLysrmz17NhB3Dx48WLBgATb6+/fvB89XIBBs2rTp3r17Uqk0NTU1KCiopaVFIpH06NGDoqjZs2cz69ofp8v8rtQL315WVtanT5+lS5cy1Ta7SHUgi9vR0XHr1q2hQ4cqKiqOHz8eFSOSRGFr18n7gugckp47j8cbPHgwNjkfkCojzycS1nhx3759XC536dKlBBXFdDn8U8bt96ayBGuGy9+zZw9FUT169ABHDvi4cePGIbf6O4B9kQwoKSlBn1Amk1VWVgK2U1tbW1ZWBg+h8vLykpISYKYKCgog3Aedw5qaGuRLRUVFXC5XUVExNTU1Ozsb6d/Dhw87OjqUlZVFIlFlZWVLS8vDhw9fvHihqqrq7++vrq4OLBK6BZ82P6Qo6ubNm4WFhaNHj0ZA6zqi4omBiaanp+esWbM6OjoePnxYVlaG/IrJ0cBwNTY2Yk1B2xf19OTk5OLiYrFYPGrUKADNPmDxZlb2SYCytrZuaWlJTU3Ny8vDtZA49smSqNegMzab3d7e3rNnT/Q2IGWFjACXTx6Mzz6CgXkFzWREHpFINHHiRGBejhw5EhgYiEbw8uXLQWRoaGiYPHnykSNHaJpOTEycMGECaAtbtmz5+uuv8bHjxo07dOgQBAb/8Y9/oLwBZjiPx/P09MRnkm0x8Wj9JBEM5enBgwd7e3ujzUC/zwCW0AfxtsrKSj8/PxaLNXny5PT0dGbzmpAaO9XTUESZNGmSsrIyWF5oDzC1b3/XpZG+MALF06dPIQ4VFhbG5IN8QDHmz4pgzEgO9gDESZFaI9rPmDGD+jyVfRXfBV0hTUYMvUAg6NGjB4pOFhYWNjY2GDJjY2PIXLa2tpqZmZmZmeFBwYstLS1mZmYODg4I9A4ODt26dQNb0cnJSVVVFTK0FEXp6upOmzZNS0sLEQBbFGjlfsLj6tWrCQkJfn5+qAo2Nzd3sVchsQv7n/b2dkNDw9WrV3fr1u306dP79u0TiUQqKipYhlEPIOQAmMuwWCxNTc3IyMjr16+z2Wzg+lDk6KLR3PXqSVz/kBPq6+vb2tpKpdLk5GQi2QtK5Sdc4gkzqKOjg8/nczic5uZm+EET/1tiZfh5Hf83AFVjslBm9h8KAAAAAElFTkSuQmCC"
	
	/* ----------------------------------------------------------------------------------------------------------------------
	<MAIN ROLLOUT CONTROLS>
	*/ ----------------------------------------------------------------------------------------------------------------------	
	dotnetcontrol ic_Logo "Label" pos:[5,5] width:210 height:195
	
	GroupBox gb_Infos "Info" pos:[5,205] width:210 height:45
	button bt_Github "Github" pos:[64,223] width:92 height:20
	
	/* ----------------------------------------------------------------------------------------------------------------------
	<MAIN ROLLOUT EVENTS>
	*/ ----------------------------------------------------------------------------------------------------------------------	
	on rlt_InfoBox_Main rolledUp bState do
	(
		if (bState) then
		(
			MAX_RolloutHeight += rlt_InfoBox_Main.height + 2
		)
		else
		(
			MAX_RolloutHeight -= rlt_InfoBox_Main.height + 2
		)
		
		MAX_UniqueFloaterInstance.size.y = MAX_RolloutHeight
	)
	
	on rlt_InfoBox_Main open do	
	(
		bt_Github.tooltip = "Opens my Github page!"
		
		ic_Logo.image = (MAX_Functions.ConvertBase64StringToImage LogoBase64)
	)
	
	on bt_Github pressed do
	(
		ShellLaunch GITHUB_URL ""
	)
		
	on rlt_InfoBox_Main close do ( )
)

/* ---------------------------------------------------------------------------------------------------------------------------
<ROLLOUT> Checker Tex : Tool that allows the use of a temporary checker texture for quick edits.
*/ ---------------------------------------------------------------------------------------------------------------------------
rollout rlt_CheckerTex_Main "Checker Texture" width:220 height:0
(	
	/* ---------------------------------------------------------------------------------------------------------------------------
	<UI MEMBERS> 
	*/ ---------------------------------------------------------------------------------------------------------------------------
	local uiApplyChecker = false
	
	local uiCheckerUTiling = 10.0
	local uiCheckerVTiling = 10.0
	
	/* ---------------------------------------------------------------------------------------------------------------------------
	<MEMBER VARIABLES> 
	*/ ---------------------------------------------------------------------------------------------------------------------------
	local ObjectStateListenerObj = ObjectStateListener()
	local SelectedObject = undefined
	
	local CheckerMat = multimaterial numsubs:12
	local ObjMat = undefined

	/* ----------------------------------------------------------------------------------------------------------------------
	<MAIN ROLLOUT CONTROLS>
	*/ ----------------------------------------------------------------------------------------------------------------------	
	GroupBox gb_CheckerOP "Checker Options" pos:[5, 5] width:210 height:50
	spinner sp_UTiling "U Tiling: " pos:[72, 27] width:30 height:20 range:[0.05, 100.0, 10.0] type:#float scale:0.05 fieldwidth:36
	spinner sp_VTiling "V Tiling: " pos:[175, 27] width:30 height:20 range:[0.05, 100.0, 10.0] type:#float scale:0.05 fieldwidth:36
		
	checkbutton ck_ApplyChecker "Apply Checker" pos:[135,65] width:80 height:25
	
	/* ----------------------------------------------------------------------------------------------------------------------
	<LOCAL FUNCTIONS>
	*/ ----------------------------------------------------------------------------------------------------------------------	
	
	/* ---------------------------------------------------------------------------------------------------------------------------
	<FUNCTION>
	<DOC>  Sets the right material onto the selected object, depending on the flag.
	Arguments:
		<Bool> flag : If either the checker material or the old stored material has to be set.
		<Bool> obj : The object whose material should change.
	Return:
		<Void> 
	*/ ---------------------------------------------------------------------------------------------------------------------------
	fn SetCheckerMaterial flag obj =
	(
		if (flag and ObjMat == undefined) then
		(
			ObjMat = obj.material
			obj.material = CheckerMat
		)
		else if (not flag and ObjMat != undefined) do
		(
			obj.material = ObjMat
			ObjMat = undefined
		)
	)
	
	/* ---------------------------------------------------------------------------------------------------------------------------
	<FUNCTION>
	<DOC>  Callback function, called whenever the modifier panel updates. Updates the ObjectStateListener object and sets its own state accordingly.
	Arguments:
		<Bool> initial : If this call is done manually in the start method.
	Return:
		<Void> 
	*/ ---------------------------------------------------------------------------------------------------------------------------
	fn OnModPanelSelChanged =
	(
		ObjectStateListenerObj.UpdateState()
		
		local obj = ObjectStateListenerObj.SelectedObject
		if (obj != undefined) then
		(
			if (obj != SelectedObject) do
			(
				if (SelectedObject != undefined and uiApplyChecker) do
				(
					SetCheckerMaterial false SelectedObject
				)
				
				SelectedObject = obj
				
				if (SelectedObject != undefined and uiApplyChecker) do
				(
					SetCheckerMaterial true SelectedObject
				)	
			)
		)
		else
		(
			if (SelectedObject != undefined) do
			(
				if (uiApplyChecker) do
				(
					SetCheckerMaterial false SelectedObject
				)
				
				SelectedObject = undefined
			)
		)
	)
	
	/* ----------------------------------------------------------------------------------------------------------------------
	<MAIN ROLLOUT EVENTS>
	*/ ----------------------------------------------------------------------------------------------------------------------	
	on rlt_CheckerTex_Main rolledUp bState do
	(
		if (bState) then
		(
			MAX_RolloutHeight += rlt_CheckerTex_Main.height + 2
		)
		else
		(
			MAX_RolloutHeight -= rlt_CheckerTex_Main.height + 2
		)
		
		MAX_UniqueFloaterInstance.size.y = MAX_RolloutHeight
	)
	
	on rlt_CheckerTex_Main open do
	(
		sp_UTiling.tooltip = "Sets the horizontal tiling of the material."
		sp_VTiling.tooltip = "Sets the vertical tiling of the material."
		ck_ApplyChecker.tooltip = "Enables the tool, placing the material onto the selected object."
		
		-- Making each material ID a different color.
		local diff = checker()
		diff.color1 = (color 255 255 255)
		diff.color2 = (color 0 0 0)
		CheckerMat.materialList[1] = standard diffuseMap:diff showInViewport:true
		
		diff = checker()
		diff.color1 = (color 192 192 192)
		diff.color2 = (color 96 96 96)
		CheckerMat.materialList[2] = standard diffuseMap:diff showInViewport:true
		
		diff = checker()
		diff.color1 = (color 251 191 128)
		diff.color2 = (color 232 58 73)
		CheckerMat.materialList[3] = standard diffuseMap:diff showInViewport:true
		
		diff = checker()
		diff.color1 = (color 96 192 128)
		diff.color2 = (color 64 128 120)
		CheckerMat.materialList[4] = standard diffuseMap:diff showInViewport:true
		
		diff = checker()
		diff.color1 = (color 96 112 192)
		diff.color2 = (color 64 74 128)
		CheckerMat.materialList[5] = standard diffuseMap:diff showInViewport:true
		
		diff = checker()
		diff.color1 = (color 255 246 128)
		diff.color2 = (color 96 93 48)
		CheckerMat.materialList[6] = standard diffuseMap:diff showInViewport:true

		diff = checker()
		diff.color1 = (color 192 96 192)
		diff.color2 = (color 128 64 128)
		CheckerMat.materialList[7] = standard diffuseMap:diff showInViewport:true
		
		diff = checker()
		diff.color1 = (color 102 204 192)
		diff.color2 = (color 64 128 111)
		CheckerMat.materialList[8] = standard diffuseMap:diff showInViewport:true
		
		diff = checker()
		diff.color1 = (color 121 192 242)
		diff.color2 = (color 64 102 128)
		CheckerMat.materialList[9] = standard diffuseMap:diff showInViewport:true
		
		diff = checker()
		diff.color1 = (color 255 196 127)
		diff.color2 = (color 96 74 48)
		CheckerMat.materialList[10] = standard diffuseMap:diff showInViewport:true
		
		diff = checker()
		diff.color1 = (color 192 217 108)
		diff.color2 = (color 114 128 64)
		CheckerMat.materialList[11] = standard diffuseMap:diff showInViewport:true
		
		diff = checker()
		diff.color1 = (color 237 118 192)
		diff.color2 = (color 128 64 103)
		CheckerMat.materialList[12] = standard diffuseMap:diff showInViewport:true
		
		for m in CheckerMat.materialList do
		(
			m.diffuseMap.coordinates.U_Tiling =  uiCheckerUTiling
			m.diffuseMap.coordinates.V_Tiling =  uiCheckerVTiling
		)
		
		callbacks.addScript #modPanelObjPostChange "rlt_CheckerTex_Main.OnModPanelSelChanged()" id:#checkertex_callback
		OnModPanelSelChanged()
	)
	
	on sp_UTiling changed val do
	(
		uiCheckerUTiling = val
		
		for m in CheckerMat.materialList do
		(
			m.diffuseMap.coordinates.U_Tiling =  val -- UVGenClass : https://help.autodesk.com/view/3DSMAX/2016/ENU/?guid=__files_GUID_BD6C5537_7314_4A1B_940C_32E471045621_htm
		)
	)
	
	on sp_VTiling changed val do
	(
		uiCheckerVTiling = val
		
		for m in CheckerMat.materialList do
		(
			m.diffuseMap.coordinates.V_Tiling =  val -- UVGenClass : https://help.autodesk.com/view/3DSMAX/2016/ENU/?guid=__files_GUID_BD6C5537_7314_4A1B_940C_32E471045621_htm
		)
	)
	
	on ck_ApplyChecker changed val do
	(
		uiApplyChecker = val
		
		if (val) then
		(
			if (SelectedObject != undefined) do
			(
				SetCheckerMaterial true SelectedObject
			)
		)
		else
		(
			if (SelectedObject != undefined) do
			(
				SetCheckerMaterial false SelectedObject
			)
		)
	)
		
	on rlt_CheckerTex_Main close do
	(
		if (uiApplyChecker and SelectedObject != undefined) do
		(
			SetCheckerMaterial false SelectedObject
		)
		
		callbacks.removeScripts id:#checkertex_callback
	)
)

/* ---------------------------------------------------------------------------------------------------------------------------
<ROLLOUT> UV Painter : Tool that allows painting UVs directly from Max's viewport.
*/ ---------------------------------------------------------------------------------------------------------------------------
rollout rlt_UVPainter_Main "UV Painter" width:220 height:0
(	
	/* ---------------------------------------------------------------------------------------------------------------------------
	<UI MEMBERS> 
	*/ ---------------------------------------------------------------------------------------------------------------------------
	local uiUvMapChannel = 1
	
	local uiPropagateSmoothingGroups = false
	local uiPropagateMaterialID = false
	
	local uiAutoWeld = false
	local uiWeldThreshold = 0.05
	local uiWeldAverage = false
	
	local uiPaintByPoly = true
	local uiUseOnlySelection = false
	
	local uiFillPaintThreshold = 100.0
	local uiFillVsOrigin = true
	
	/* ---------------------------------------------------------------------------------------------------------------------------
	<MEMBER VARIABLES> 
	*/ ---------------------------------------------------------------------------------------------------------------------------
	local ObjectStateListenerObj = ObjectStateListener()
	
	local CanUseTool = false
	local CanFill = true
		
	local RefFaceNum = undefined
	local RawRefFaceNum = undefined
	
	local IsPainting = false
	local IsFillPainting = false
	local IsPerfectPreparing = false
	
	local SelectedObject = undefined
	local IsDisplayDirty = false
	
	local PolyTriRecursion = false
	local OriginNeighborRecursion = false
	
	local StartedWithEdges = false
	
	local Error09 = false
	local DisplayError09 = false
	
	/* ----------------------------------------------------------------------------------------------------------------------
	<MAIN ROLLOUT CONTROLS>
	*/ ----------------------------------------------------------------------------------------------------------------------
	dotnetcontrol lb_Messages "Label" text:"" width:195
	
	GroupBox gb_WeldOP "Weld Options" pos:[5,30] width:100 height:70
	checkbutton ck_Autoweld "Weld" pos:[10,48] wiWdth:40 height:20
	checkbutton ck_AverageWeld "Average" pos:[50,48] width:50 height:20
	spinner sp_weldThreshold "Thres:" pos:[17,75] width:82 height:16 enabled:false range:[0,99,0.05] type:#float scale:0.05 fieldwidth:40

	GroupBox gb_Propagate "Propagate Opt." pos:[115, 30] width:100 height:70
	checkbutton ck_PropagSmoothGroup "SmoothGr" pos:[124, 48] width:82 height:20
	checkbutton ck_PropagMaterial "MatID" pos:[124,73] width:82 height:20
	
	GroupBox gb_ChannelOp "Channel" pos:[5,156] width:60 height:45
	spinner sp_CurrentMapChannel "" pos:[23,176] width:34 height:16 range:[1,99,1] type:#integer fieldwidth:34

	GroupBox gb_PaintOP "Object Options" pos:[5, 105] width:210 height:45
	checkbutton ck_PaintByPoly "By Poly" pos:[14, 123] width:50 height:20
	checkbutton ck_PaintByTri "By Tri" pos:[71,123] width:45 height:20
	checkbutton ck_DisplayTri "EO" pos:[116, 123] width:20 height:20
	checkbutton ck_UseSelection "Selection" pos:[145, 123] width:62 height:20
	
	GroupBox gb_FillPaint "Filling Options" pos:[75,156] width:140 height:70
	checkbutton ck_FillVSOrigin "VS Origin" pos:[84, 175] width:59 height:20
	checkbutton ck_FillVSNeighbor "VS Neigh." pos:[148, 175] width:59 height:20
	spinner sp_FillPaintThreshold "Limit:" pos:[185,203] width:0 height:16 enabled:true range:[0,360,100] type:#float scale:0.5 fieldwidth:40

	checkbutton ck_PerfectPrepare "Prepare" pos:[5, 209] width:60 height:20
	checkbutton ck_StartPaintUV "Start Painting" pos:[5,237] width:100 height:25
	checkbutton ck_FillPaint "Start Filling" pos:[115,237] width:100 height:25

	/* ----------------------------------------------------------------------------------------------------------------------
	<LOCAL FUNCTIONS>
	*/ ----------------------------------------------------------------------------------------------------------------------
	
	/* ---------------------------------------------------------------------------------------------------------------------------
	<FUNCTION>
	<DOC>  Get the UV channel requested by the artist to draw on.
	Arguments:
		<Void>
	Return:
		<Float> The map the tool can use to paint with. Is undefined if no functional map is selected.
	*/ ---------------------------------------------------------------------------------------------------------------------------
	fn GetMapChannel =
	(
		local mapChannelsList = undefined
		
		if (SelectedObject != undefined and ObjectStateListenerObj.IsPoly != undefined) do
		(
			mapChannelsList = uiUvMapChannel	
			
			-- Clear the array if the selected UV channel index is unsupported.
			if (ObjectStateListenerObj.IsPoly) then
			(
				if (not polyop.getMapSupport SelectedObject mapChannelsList) do
				(
					mapChannelsList = undefined
				)
			)
			else if (not ObjectStateListenerObj.IsPoly) then
			(
				if (not meshop.getMapSupport SelectedObject mapChannelsList) do
				(
					mapChannelsList = undefined
				)
			)
		)
		
		mapChannelsList -- Returns <Array>.
	)
	
	/* ---------------------------------------------------------------------------------------------------------------------------
	<FUNCTION>
	<DOC>  Updates every variable related to viewport rendering, forcing a refresh by next frame.
	Arguments:
		<Void> 
	Return:
		<Void> 
	*/ ---------------------------------------------------------------------------------------------------------------------------
	fn UpdateViewport =
	(
		update SelectedObject
		redrawViews()
		-- IsDisplayDirty allows UpdateViewportRendering to work.
		IsDisplayDirty = true
	)
	
	/* ---------------------------------------------------------------------------------------------------------------------------
	<FUNCTION>
	<DOC>  Called via a registered callback when the views are redrawn. If UpdateViewport was called, it will display the markers shown during the painting process.
	Arguments:
		<Void> 
	Return:
		<Void> 
	*/ ---------------------------------------------------------------------------------------------------------------------------
	fn UpdateViewportRendering = 
	(
		if (IsDisplayDirty) do
		(
			if(RefFaceNum != undefined and RefFaceNum > 0) then
			(			
				if (uiPaintByPoly) then
				(
					gw.setTransform(Matrix3 1)
					local faceCoords = polyop.getFaceVerts SelectedObject RefFaceNum
					local lineArray = #()
					local colorArray = #()
					
					for faceVert = 1 to faceCoords.count do
					(
						local pt = gw.hTransPoint (polyop.getVert SelectedObject faceCoords[faceVert])
						gw.hMarker pt #smallCircle color:[255,255,0]
						append lineArray pt
						append colorArray [255, 255, 255]
					)
					
					gw.hMarker [0.0, 0.0, 0.0] #smallCircle color:[255,255,0]
					gw.hPolyline lineArray true rgb:colorArray
					gw.enlargeUpdateRect #whole
					gw.updateScreen()
				)
				else -- Tri mode, no matter what, always have 3 vertex in every face, unlike poly mode.
				(
					gw.setTransform(Matrix3 1)
					local faceCoords = for f in (MAX_Functions.VectorToArray (getFace SelectedObject RefFaceNum)) collect getVert SelectedObject f
					local pt1 = gw.hTransPoint faceCoords[1]
					local pt2 = gw.hTransPoint faceCoords[2]
					local pt3 = gw.hTransPoint faceCoords[3]
					gw.hMarker [0.0, 0.0, 0.0] #smallCircle color:[255,255,0]
					gw.hMarker pt1 #smallCircle color:[255,255,0]
					gw.hMarker pt2 #smallCircle color:[255,255,0]
					gw.hMarker pt3 #smallCircle color:[255,255,0]
					gw.hPolyline #(pt1, pt2, pt3) true rgb:#([255,255,255],[255,255,255],[255,255,255])
					gw.enlargeUpdateRect #whole
					gw.updateScreen()
				)
			)
			IsDisplayDirty = false
		)
	)
	
	/* ---------------------------------------------------------------------------------------------------------------------------
	<FUNCTION>
	<DOC>  Resets the selected object to a state where you can use the tool on it (collapsed + UnwrapUVW).
	Arguments:
		<Void> 
	Return:
		<Void>
	*/ ---------------------------------------------------------------------------------------------------------------------------
	fn ResetModifierState =
	(
		if (uiPaintByPoly) then
		(
			for obj in selection where canConvertTo obj mesh do
			(
				convertTo obj PolyMeshObject
			)
		)
		else
		(
			for obj in selection where canConvertTo obj editable_poly do
			(
				convertTo obj TriMeshGeometry
			)
		)
		
		for obj in selection where validModifier obj Unwrap_UVW do
		(
			addmodifier obj (Unwrap_UVW())
		)
	)
	
	/* ---------------------------------------------------------------------------------------------------------------------------
	<FUNCTION>
	<DOC>  Sets the tool and the selected object to the state needed by the tool.
	Arguments:
		<Bool> flag : If true, the object will be collapsed to be painted upon and painting will start. If false, an UnwrapUVW will be added and options unavailable during painting will re-enable.
	Return:
		<Void>
	*/ ---------------------------------------------------------------------------------------------------------------------------
	fn SetModifierState flag =
	(
		ck_PaintByPoly.enabled = not flag
		ck_PaintByTri.enabled = not flag
		sp_CurrentMapChannel.enabled = not flag
		
		ck_FillPaint.enabled = not flag
		ck_StartPaintUV.enabled = not flag
		ck_PerfectPrepare.enabled = not flag
		
		if (flag) then
		(			
			if (uiPaintByPoly) then
			(
				for obj in selection where canConvertTo obj mesh do
				(
					convertTo obj PolyMeshObject
				)
			)
			else
			(
				for obj in selection where canConvertTo obj editable_poly do
				(
					convertTo obj TriMeshGeometry
				)
			)
		)
		else
		(			
			for obj in selection where validModifier obj Unwrap_UVW do
			(
				addmodifier obj (Unwrap_UVW())
			)
		)
	)	
	
	/* ---------------------------------------------------------------------------------------------------------------------------
	<FUNCTION>
	<DOC>  Weld the painted vertices directly without moving them. Called when painting while control is pressed.
	Arguments:
		<Int>  faceNum : The painted-on face index.
		<Int>  currentChannel : The UV channel where data is queried and written to.
	Return:
		<Bool> If the process was done successfully.
	*/ ---------------------------------------------------------------------------------------------------------------------------
	fn WeldPaint faceNum currentChannel =
	(
		local SharedInfos = MAX_Functions.GetCommonGeometryVertices SelectedObject RefFaceNum faceNum uiPaintByPoly
		local done = false
		if (SharedInfos != undefined) do -- 2 vertices in common is needed to perform the smart weld.
		(
			if (uiPaintByPoly) then
			(
				local refTFace = polyop.getMapFace SelectedObject currentChannel RefFaceNum
				local TFace = polyop.getMapFace SelectedObject currentChannel faceNum

				if(refTFace[SharedInfos[1][1]] != TFace[SharedInfos[2][1]]) do -- testing 1st common Tvert
				(
					MAX_Functions.WeldTVerts SelectedObject refTFace[SharedInfos[1][1]] TFace[SharedInfos[2][1]] currentChannel true
					TFace[SharedInfos[2][1]] = refTFace[SharedInfos[1][1]]
					polyop.setMapFace SelectedObject currentChannel faceNum TFace
				)
				
				if(refTFace[SharedInfos[1][2]] != TFace[SharedInfos[2][2]]) do -- testing 2nd common Tvert
				(
					MAX_Functions.WeldTVerts SelectedObject refTFace[SharedInfos[1][2]] TFace[SharedInfos[2][2]] currentChannel true
					TFace[SharedInfos[2][2]] = refTFace[SharedInfos[1][2]]
					polyop.setMapFace SelectedObject currentChannel faceNum TFace
				)
				
				-- Propagate stuff
				if (uiPropagateMaterialID) do 
				(
					polyop.setFaceMatID SelectedObject faceNum (polyop.getFaceMatID SelectedObject RefFaceNum)
				)
				
				if (uiPropagateSmoothingGroups) do 
				(
					polyop.setFaceSmoothGroup SelectedObject faceNum (polyop.getFaceSmoothGroup SelectedObject RefFaceNum)
				)
				done = true
			)
			else
			(
				local refTFace = MAX_Functions.VectorToArray(meshop.getMapFace SelectedObject currentChannel RefFaceNum)
				local TFace = MAX_Functions.VectorToArray(meshop.getMapFace SelectedObject currentChannel faceNum)

				if(refTFace[SharedInfos[1][1]] != TFace[SharedInfos[2][1]]) do -- testing 1st common Tvert
				(
					MAX_Functions.WeldTVerts SelectedObject refTFace[SharedInfos[1][1]] TFace[SharedInfos[2][1]] currentChannel false
					TFace[SharedInfos[2][1]] = refTFace[SharedInfos[1][1]]
					meshop.setMapFace SelectedObject currentChannel faceNum [TFace[1], TFace[2], TFace[3]]
				)
				
				if(refTFace[SharedInfos[1][2]] != TFace[SharedInfos[2][2]]) do -- testing 2nd common Tvert
				(
					MAX_Functions.WeldTVerts SelectedObject refTFace[SharedInfos[1][2]] TFace[SharedInfos[2][2]] currentChannel false
					TFace[SharedInfos[2][2]] = refTFace[SharedInfos[1][2]]
					meshop.setMapFace SelectedObject currentChannel faceNum [TFace[1], TFace[2], TFace[3]]
				)	
				-- Clean unused mapvert
				meshop.deleteIsoMapVertsAll SelectedObject
				
				-- Propagate stuff
				if (uiPropagateMaterialID) do 
				(
					setFaceMatID SelectedObject faceNum (getFaceMatID SelectedObject RefFaceNum)
				)
				
				if (uiPropagateSmoothingGroups) do 
				(
					setFaceSmoothGroup SelectedObject faceNum (getFaceSmoothGroup SelectedObject RefFaceNum)
				)
				done = true
			)
		)
		done -- Returns <Bool>.
	)
	
	/* ---------------------------------------------------------------------------------------------------------------------------
	<FUNCTION>
	<DOC>  Computes the position of 2 new map vertices using barycentric coordinates. Called when painting in poly mode.
	Arguments:
		<Int> faceNum : The painted-on face index.
		<Int> currentChannel : The UV channel where data is queried and written to.
	Return:
		<Bool> If the process was done successfully. 
	*/ ---------------------------------------------------------------------------------------------------------------------------
	fn ComputeNewUVs faceNum currentChannel =
	(
		local isPoly = ObjectStateListenerObj.IsPoly
		local SharedInfos = MAX_Functions.GetCommonGeometryVertices SelectedObject RefFaceNum faceNum isPoly
		local done = false
		if (SharedInfos != undefined) do -- 2 vertices in common is needed to perform the smart weld.
		(			
			-- Compute clicked face informations ------------------------------------------------------------------------------------------------------------------------------
			-- Transform the clicked face into a 2D plan.
			local faceVertList = undefined
			local pA = undefined
			local pB = undefined
			
			local normalVector = undefined
			if (isPoly) then
			(
				faceVertList = polyop.getFaceVerts SelectedObject faceNum
				pA = polyop.getVert SelectedObject faceVertList[SharedInfos[2][1]]
				pB = polyop.getVert SelectedObject faceVertList[SharedInfos[2][2]]
				
				normalVector = normalize(polyop.getFaceNormal SelectedObject faceNum)
			)
			else
			(
				faceVertList = MAX_Functions.VectorToArray (getFace SelectedObject faceNum)
				pA = getVert SelectedObject faceVertList[SharedInfos[2][1]]
				pB = getVert SelectedObject faceVertList[SharedInfos[2][2]]
				
				normalVector = normalize(getFaceNormal SelectedObject faceNum)
			)
			
			local upVector = normalize(pB - pA)
			
			local rightVector = normalize(cross upVector normalVector)
			local transVector = pA - ([0,0,0])
			local faceInvMatrix = inverse (matrix3 rightVector upVector normalVector transVector)
			-- Transform ------------------------------------------------------------------------------------------------------------------------------
			local faceTransformed = undefined
			
			-- Transform the ref face into a 2D plan also.
			local refFaceVertList = undefined
			
			if (isPoly) then
			(
				faceTransformed = for v in faceVertList collect ((polyop.getVert SelectedObject v) * faceInvMatrix)
				
				refFaceVertList = polyop.getFaceVerts SelectedObject RefFaceNum
				pA = polyop.getVert SelectedObject refFaceVertList[SharedInfos[1][1]]
				pB = polyop.getVert SelectedObject refFaceVertList[SharedInfos[1][2]]
				
				normalVector = normalize(polyop.getFaceNormal SelectedObject RefFaceNum)
			)
			else
			(
				faceTransformed = for v in faceVertList collect ((getVert SelectedObject v) * faceInvMatrix)
				
				refFaceVertList = MAX_Functions.VectorToArray (getFace SelectedObject RefFaceNum)
				pA = getVert SelectedObject refFaceVertList[SharedInfos[1][1]]
				pB = getVert SelectedObject refFaceVertList[SharedInfos[1][2]]
				
				normalVector = normalize(getFaceNormal SelectedObject RefFaceNum)
			)
			
			upVector = normalize(pB - pA)
			rightVector = normalize(cross upVector normalVector)
			transVector = pA - ([0,0,0])
			local refFaceInvMatrix = inverse (matrix3 rightVector upVector normalVector transVector)
			-- Transform ------------------------------------------------------------------------------------------------------------------------------
			local refFaceTransformed = undefined
			if (isPoly) then
			(
				refFaceTransformed = for v in refFaceVertList collect ((polyop.getVert SelectedObject v) * refFaceInvMatrix)
			)
			else
			(
				refFaceTransformed = for v in refFaceVertList collect ((getVert SelectedObject v) * refFaceInvMatrix)
			)
			
			-- Compute the new points.
			local computed = #()
			local current = #()
			
			local computedVal = undefined
			local currentVal = undefined
			local refTFace = undefined
			
			local currentVerts = undefined
			
			if (isPoly) then
			(
				refTFace = polyop.getMapFace SelectedObject currentChannel RefFaceNum
				
				for i = 1 to SharedInfos[1].count do
				(
					computedVal = refFaceTransformed[SharedInfos[1][i]]
					append computed computedVal
					currentVal = polyop.getMapVert SelectedObject currentChannel refTFace[SharedInfos[1][i]]
					append current currentVal
				)
				
				currentVerts = polyop.getNumMapVerts SelectedObject currentChannel
			)
			else
			(
				refTFace = MAX_Functions.VectorToArray (meshop.getMapFace SelectedObject currentChannel RefFaceNum)
				
				for i = 1 to SharedInfos[1].count do
				(
					computedVal = refFaceTransformed[SharedInfos[1][i]]
					append computed computedVal
					currentVal = meshop.getMapVert SelectedObject currentChannel refTFace[SharedInfos[1][i]]
					append current currentVal
				)
				
				currentVerts = meshop.getNumMapVerts SelectedObject currentChannel
			)
			
			local Pcoord = undefined
			local currentNewPos = undefined
			local newPos = #()
			
			local newVerts = #()
			
			local currentAssociated = undefined
			local associatedTVert = #()
			local currentToWeld = undefined
			local toWeldTVertList = #()
			
			local canWeld = true
			
			for i = 3 to SharedInfos[2].count do
			(
				Pcoord = MAX_Functions.ComputeBarycentricCoordUsingPoint computed[1] computed[2] computed[3] faceTransformed[SharedInfos[2][i]]
				currentNewPos = (MAX_Functions.ComputePointUsingBarycentricCoord current[1] current[2] current[3] Pcoord.x Pcoord.y) + current[1]
				append newPos currentNewPos
				
				currentVerts += 1
				append newVerts currentVerts
				
				currentAssociated = MAX_Functions.GetNearbyTVert faceVertList[SharedInfos[2][i]] SelectedObject currentChannel isPoly
				append associatedTVert currentAssociated
				
				if (isPoly) then
				(
					currentToWeld = for tV in currentAssociated where((distance (polyop.getMapVert SelectedObject currentChannel tV) currentNewPos) <= uiWeldThreshold) collect tV
				)
				else
				(
					currentToWeld = for tV in currentAssociated where((distance (meshop.getMapVert SelectedObject currentChannel tV) currentNewPos) <= uiWeldThreshold) collect tV
				)
				
				append toWeldTVertList currentToWeld
				
				if (currentToWeld.count == 0) do
				(
					canWeld = false
				)
			)
			
			if(uiAutoWeld and canWeld) then
			(
				if(uiWeldAverage) then
				(
					local sP = undefined
					local vect = undefined
					
					if (isPoly) then
					(
						for w = 1 to toWeldTVertList.count do
						(
							sP = polyop.getMapVert SelectedObject currentChannel toWeldTVertList[w][1]
							vect = (newPos[w] - sP) / 2
							polyop.setMapVert SelectedObject currentChannel toWeldTVertList[w][1] (sP + vect)
							newVerts[w] = toWeldTVertList[w][1]
						)
					)
					else
					(
						for w = 1 to toWeldTVertList.count do
						(
							sP = meshop.getMapVert SelectedObject currentChannel toWeldTVertList[w][1]
							vect = (newPos[w] - sP) / 2
							meshop.setMapVert SelectedObject currentChannel toWeldTVertList[w][1] (sP + vect)
							newVerts[w] = toWeldTVertList[w][1]
						)
					)
				)
				else
				(
					for w = 1 to toWeldTVertList.count do
					(
						newVerts[w] = toWeldTVertList[w][1]
					)
				)
			)
			else
			(
				if (isPoly) then
				(
					polyop.setNumMapVerts SelectedObject currentChannel newVerts[newVerts.count] keep:true -- adding more TVert
				
					for v = 1 to newVerts.count do
					(
						polyop.setMapVert SelectedObject currentChannel newVerts[v] newPos[v]
					)
				)
				else
				(
					meshop.setNumMapVerts SelectedObject currentChannel newVerts[newVerts.count] keep:true -- adding more TVert
				
					for v = 1 to newVerts.count do
					(
						meshop.setMapVert SelectedObject currentChannel newVerts[v] newPos[v]
					)
				)
			)
			
			faceTransformed[SharedInfos[2][1]] = refTFace[SharedInfos[1][1]]
			faceTransformed[SharedInfos[2][2]] = refTFace[SharedInfos[1][2]]
			
			for i = 3 to SharedInfos[2].count do
			(
				faceTransformed[SharedInfos[2][i]] = newVerts[i - 2]	
			)
			
			-- Create the new UVs for the face to modify.
			if (isPoly) then
			(
				polyop.setMapFace SelectedObject currentChannel faceNum faceTransformed
				
				if (uiPropagateMaterialID) do 
				(
					polyop.setFaceMatID SelectedObject faceNum (polyop.getFaceMatID SelectedObject RefFaceNum)
				)
				
				if (uiPropagateSmoothingGroups) do 
				(
					polyop.setFaceSmoothGroup SelectedObject faceNum (polyop.getFaceSmoothGroup SelectedObject RefFaceNum)
				)
			)
			else
			(
				meshop.setMapFace SelectedObject currentChannel faceNum [faceTransformed[1], faceTransformed[2], faceTransformed[3]]
				
				if (uiPropagateMaterialID) do 
				(
					setFaceMatID SelectedObject faceNum (getFaceMatID SelectedObject RefFaceNum)
				)
				
				if (uiPropagateSmoothingGroups) do 
				(
					setFaceSmoothGroup SelectedObject faceNum (getFaceSmoothGroup SelectedObject RefFaceNum)
				)
				
				meshop.deleteIsoMapVertsAll SelectedObject
			)			
			
			update SelectedObject
			done = true
		)
		
		done -- Returns <Bool>.
	)
	
	/* ---------------------------------------------------------------------------------------------------------------------------
	<FUNCTION>
	<DOC>  Main prepare loop, called whenever the mousetrack event sends a message. Prepares a face turning its UV into a 1:1 UV Planar, centering its UV and turning it to the right pixel ratio.
	Arguments:
		<String> msg : The message name sent by the mousetrack event.
		<Ray> ir : Unused, but needed as argument. The grid or surface intersection normal Ray at the current mouse position.
		<Node> obj : Object that is being painted on. Value is overwritten because the object is lost whenever your mouse isn't over it, causing issues.
		<Int> faceNum : Only used in tri mode and fill painting. The index of the face under the mouse.
		<Bool> shift : Unused, but needed as argument. If the shift key is down.
		<Bool> ctrl : If the control key is down.
		<Bool> alt : Unused, but needed as argument. If the alt key is down.
	Return:
		<Bool> If the operation was done successfully.
	*/ ---------------------------------------------------------------------------------------------------------------------------
	fn DoPerfectPrepare msg ir obj faceNum shift ctrl alt =
	(
		obj = SelectedObject -- MouseTrack sets obj to undefined if the mouse leaves it, which can cause issues with our math. To remedy this, we are manually setting the object.
		local success = true
		if (IsPerfectPreparing and msg == #mousePoint and uiPaintByPoly) then
		(
			faceNum = MAX_Functions.GetFaceUnderCursor obj
			faceNum = MAX_Functions.MeshFaceToPolyFace obj faceNum
			
			local sol = subObjectLevel
			subObjectLevel = 4
			
			polyop.setFaceSelection obj #{faceNum}
			
			MAX_Functions.AddMapAndResize 1 1 1 0 obj uiPaintByPoly
			
			for obj in selection where validModifier obj Unwrap_UVW do
			(
				addmodifier obj (Unwrap_UVW())
			)
			
			Error09 = MAX_Functions.ResizeToRatio 1 1 obj obj.modifiers[obj.modifiers.count] uiPaintByPoly true
			
			if (uiPaintByPoly) then
			(
				for obj in selection where canConvertTo obj mesh do
				(
					convertTo obj PolyMeshObject
				)
			)
			else
			(
				for obj in selection where canConvertTo obj editable_poly do
				(
					convertTo obj TriMeshGeometry
				)
			)
			
			subObjectLevel = sol
			
			ck_PerfectPrepare.state = false
			IsPerfectPreparing = false
		)
		else if (msg == #mouseAbort) then
		(
			ck_PerfectPrepare.state = false
			IsPerfectPreparing = false
		)
		else
		(
			#continue -- Continue the paint loop.
		)
	)
	
	/* ---------------------------------------------------------------------------------------------------------------------------
	<FUNCTION>
	<DOC>  Main tool loop, called whenever the mousetrack event sends a message. Handles input while painting.
	Arguments:
		<String> msg : The message name sent by the mousetrack event.
		<Ray> ir : Unused, but needed as argument. The grid or surface intersection normal Ray at the current mouse position.
		<Node> obj : Object that is being painted on. Value is overwritten because the object is lost whenever your mouse isn't over it, causing issues.
		<Int> faceNum : Only used in tri mode and fill painting. The index of the face under the mouse.
		<Bool> shift : Unused, but needed as argument. If the shift key is down.
		<Bool> ctrl : If the control key is down.
		<Bool> alt : Unused, but needed as argument. If the alt key is down.
		<Bool> forceObj : If called via fill painting in poly mode, prevents getting the face under the mouse multiple times by using the passed-in value.
	Return:
		<Void> 
	Messages:
		#freeMove - Mouse was moved while left click is up.
		#mouseMove - Mouse was moved while left click is down.
		#mouseAbort - Right click is down.
	*/ ---------------------------------------------------------------------------------------------------------------------------
	fn UVPaint msg ir obj faceNum shift ctrl alt disableAnim:false forceObj:false =
	(
		obj = SelectedObject  -- MouseTrack sets obj to undefined if the mouse leaves it, which can cause issues with our math. To remedy this, we are manually setting the object.
		if (IsPainting or IsFillPainting) do
		(					
			if (msg == #freeMove) do
			(
				if (obj.modifiers.count > 0 and classof obj.modifier[obj.modifiers.count] != Editable_Mesh and classof obj.modifier[obj.modifiers.count] != Editable_Poly) do
				(
					IsPainting = false
				)
				
				RefFaceNum = undefined
				RawRefFaceNum = undefined
			)
			
			if (msg ==  #mouseMove) do
			(
				local faceID = undefined
				
				if (uiPaintByPoly and not forceObj) then
				(
					faceID = MAX_Functions.GetFaceUnderCursor obj
				)
				else
				(
					faceID = faceNum
				)
				
				if (RefFaceNum != undefined) then
				(
					if (faceID != undefined and faceID > 0) do
					(
						if (RefFaceNum != faceID) do
						(
							if (uiPaintByPoly and not forceObj) do
							(
								RawRefFaceNum = faceID
								faceID = MAX_Functions.MeshFaceToPolyFace obj faceID
							)
							
							local canPaint = true
							if (uiUseOnlySelection) do
							(
								local faces = undefined
								if (uiPaintByPoly) then
								(
									faces = polyop.getFaceSelection obj
								)
								else
								(
									faces = getFaceSelection obj
								)
								
								if (not faces[faceID] or not faces[RefFaceNum]) do
								(
									canPaint = false
								)
							)
							
							local map = GetMapChannel()
							
							if (canPaint and map != undefined) do
							(								
								if (ctrl) then
								(
									if (WeldPaint faceID map) do
									(
										RefFaceNum = faceID
										
										lb_Messages.Forecolor = (dotnetclass "System.Drawing.Color").White
										lb_Messages.text = "Weld success"
									)
								)
								else
								(
									if (ComputeNewUVs faceID map) do
									(
										RefFaceNum = faceID
										
										lb_Messages.Forecolor = (dotnetclass "System.Drawing.Color").White
										lb_Messages.text = "Stitch success"
									)
								)
							)
						)
					)
				)
				else
				(
					if (uiPaintByPoly and not forceObj) then
					(
						RawRefFaceNum = faceID
						faceID = MAX_Functions.MeshFaceToPolyFace obj faceID
						RefFaceNum = faceID
					)
					else
					(
						RefFaceNum = faceNum
					)
				)
				
				if (not disableAnim) do
				(
					UpdateViewport()
				)
			)
			
			if (msg == #mouseAbort) then
			(
				RefFaceNum = undefined
				RawRefFaceNum = undefined
			)
			else
			(
				#continue -- Continue the paint loop.
			)
		)
	)
	
	/* ---------------------------------------------------------------------------------------------------------------------------
	<FUNCTION>
	<DOC>  Poly version of the fill painting code. Gets all the faces connected to the selected face (under restriction) and paints them together.
	Arguments:
		<Int> faceNum : Selected face to start the chain from.
		<Node> obj : Object data is queried from.
	Return:
		<Void>
	*/ ---------------------------------------------------------------------------------------------------------------------------
	fn DoFillPropagate faceNum obj =
	(
		local map = GetMapChannel()
		if (map != undefined) then
		(
			lb_Messages.Forecolor = (dotnetclass "System.Drawing.Color").White
			lb_Messages.text = "Please wait. May freeze."	
			
			undo "UVPaintAction" on
			(				
				local isPoly = ObjectStateListenerObj.isPoly
				
				local numFaces = undefined
				if (isPoly) then
				(
					numFaces = polyop.getNumFaces obj
				)
				else
				(
					numFaces = meshop.getNumFaces obj
				)
				
				local allowedFaces = #{}
				
				if (uiUseOnlySelection) then
				(
					local faces = undefined
					if (isPoly) then
					(
						faces = polyop.getFaceSelection obj
					)
					else
					(
						faces = getFaceSelection obj
					)
					
					allowedFaces = faces as bitarray
				)
				else
				(
					allowedFaces = #{1..numFaces}
				)
				
				if (allowedFaces[faceNum]) do	-- Making sure where we start the filling is allowed to be selected.
				(
					local start = timeStamp()
					
					local firstFaceNormal = undefined
					if (isPoly) then
					(
						firstFaceNormal = polyop.getFaceNormal obj faceNum
					)
					else
					(
						firstFaceNormal = getFaceNormal obj faceNum
					)
					
					local angleThreshold = uiFillPaintThreshold
					
					local neighborFacesBitArray = #()
					for f = 1 to numFaces do
					(
						if (allowedFaces[f]) then
						(
							append neighborFacesBitArray -#{1..numFaces}
						)
						else
						(
							append neighborFacesBitArray #{}
						)
					)
					
					-- For every face, find each vertices and get the faces tied to those vertices. Considering neighboring faces have 2 vertices in common,
					-- we can assume that any duplicate faces found between the vertices are the neighbors.
					local faces = #{}
					for face in allowedFaces do
					(
						if (isPoly) then
						(
							for vert in polyop.getFaceVerts obj face do
							(
								for faceFromVert in polyop.getFacesUsingVert obj vert do
								(
									if (faces[faceFromVert]) then
									(
										neighborFacesBitArray[face][faceFromVert] = true
									)
									else
									(
										faces[faceFromVert] = true
									)
								)
							)
						)
						else
						(
							for vert in ((meshop.getVertsUsingFace obj #(face)) as array) do
							(
								for faceFromVert in ((meshop.getFacesUsingVert obj #(vert)) as array) do
								(
									if (faces[faceFromVert]) then
									(
										neighborFacesBitArray[face][faceFromVert] = true
									)
									else
									(
										faces[faceFromVert] = true
									)
								)
							)
						)
						
						faces = #{}
					)
					
					local end = timeStamp()
					format "Time to link : %     \n"  ((end - start) / 1000.0)
					start = timeStamp()
					
					UVPaint #mouseMove dummyRay obj faceNum false false false disableAnim:true forceObj:true
					
					-- BitArray with 1 for all faces. Used to not visit the same face twice
					local toVisit = #{}
					local visitedFaces = #{}

					toVisit[faceNum] = true
					
					-- While faces remain unvisited
					while toVisit.numberset != 0 do
					(
						for f in toVisit do
						(
							local neighborFaces = neighborFacesBitArray[f]
							
							local normalf = undefined
							if (isPoly) then
							(
								normalf = polyop.getFaceNormal obj f
							)
							else
							(
								normalf = getFaceNormal obj f
							)
							
							-- Always visit the ones with similar normals first
							local neighborFacesToVisit = for ff in neighborFaces where ( (visitedFaces * #{ff}).numberset == 0 ) collect ff
							local neighborFacesToVisitSorted = deepcopy neighborFacesToVisit
							qsort neighborFacesToVisitSorted MAX_Functions.CompareFaceNormals obj:obj referenceNormal:normalf isPoly:isPoly
							
							for ff in neighborFacesToVisitSorted do
							(
								local normalff = undefined
								if (isPoly) then
								(
									normalff = polyop.getFaceNormal obj ff
								)
								else
								(
									normalff = getFaceNormal obj ff
								)
								
								local proj = undefined
								if (uiFillVsOrigin) then
								(
									proj = MAX_Functions.GetClampedDot normalff firstFaceNormal
								)
								else
								(
									proj = MAX_Functions.GetClampedDot normalff normalf
								)
								
								local angleBetweenPlanes = acos ( proj )
								if ( angleBetweenPlanes < angleThreshold) do
								(
									RefFaceNum = f
									UVPaint #mouseMove dummyRay obj ff false false false disableAnim:true forceObj:true
									toVisit[ff] = true
								)
							)
							
							visitedFaces[f] = true
							toVisit[f] = false
						)
					)
					
					end = timeStamp()
					format "Time to paint : %     \n"  ((end - start) / 1000.0)
				)
			)
			
			UVPaint #mouseAbort dummyRay obj faceNum false false false disableAnim:true
			UpdateViewport()
		)
		else
		(
			messagebox (obj.name+" don't have this UV Channel you need to create it first." title:"Info Message")
		)
	)
	
	/* ---------------------------------------------------------------------------------------------------------------------------
	<FUNCTION>
	<DOC>  Main tool loop when Fill Painting is enabled, called whenever the mousetrack event sends a message. Handles input while fill painting.
	Arguments:
		<String> msg : The message name sent by the mousetrack event.
		<Ray> ir : Unused, but needed as argument. The grid or surface intersection normal Ray at the current mouse position.
		<Node> obj : Object that is being painted on. Value is overwritten because the object is lost whenever your mouse isn't over it, causing issues.
		<Int> faceNum : Only used in tri mode. The index of the face under the mouse.
		<Bool> shift : Unused, but needed as argument. If the shift key is down.
		<Bool> ctrl : If the control key is down.
		<Bool> alt : Unused, but needed as argument. If the alt key is down.
	Return:
		<Void> 
	Messages:
		#freeMove - Mouse was moved while left click is up.
		#mousePoint - Left click is down.
		#mouseAbort - Right click is down.
	*/ ---------------------------------------------------------------------------------------------------------------------------
	fn FillPropagate msg ir obj faceNum shift ctrl alt =
	(			
		obj = SelectedObject  -- MouseTrack sets obj to undefined if the mouse leaves it, which can cause issues with our math. To remedy this, we are manually setting the object.
		if (msg == #freeMove) do
		(
			RefFaceNum = undefined
		)
		
		if (msg == #mousePoint and (faceNum != undefined or uiPaintByPoly)) then
		(
			if (uiPaintByPoly) do
			(
				faceNum = MAX_Functions.GetFaceUnderCursor obj
				RawRefFaceNum = faceNum
				faceNum = MAX_Functions.MeshFaceToPolyFace obj faceNum
			)
			
			IsFillPainting = true
			DoFillPropagate faceNum obj
		)
		else if (msg == #mouseAbort) then
		(
			RefFaceNum = undefined
			RawRefFaceNum = undefined
		)
		else
		(
			#continue -- Continue the paint loop.
		)
	)
	
	/* ---------------------------------------------------------------------------------------------------------------------------
	<FUNCTION>
	<DOC>  Sets if the tool is working in poly or tri mode, changing the selected accordingly if possible.
	Arguments:
		<Bool> isPoly : If the new mode is poly mode. False if new mode is tri mode.
		<Bool> button : If this function is currently called from the UI button, to prevent recursion. Default value set to false.
	Return:
		<Void> 
	*/ ---------------------------------------------------------------------------------------------------------------------------
	fn SetPolyTriState isPoly button:false =
	(
		if (PolyTriRecursion == false) do
		(
			PolyTriRecursion = true
			uiPaintByPoly = isPoly
			
			ck_DisplayTri.enabled = not isPoly
			
			if (isPoly) then
			(				
				ck_PaintByPoly.state = true
				ck_PaintByTri.state = false
				
				if (SelectedObject != undefined) do
				(
					SelectedObject.alledges = false
				)
			)
			else
			(				
				ck_PaintByPoly.state = false
				ck_PaintByTri.state = true
				
				if (SelectedObject != undefined) do
				(
					SelectedObject.alledges = not ck_DisplayTri.state
				)
			)
			
			if (button) do
			(
				if (ObjectStateListenerObj.IsPoly and not isPoly) then
				(
					ResetModifierState()
				)
				else if (not ObjectStateListenerObj.IsPoly and isPoly) then
				(
					ResetModifierState()
				)
			)

			PolyTriRecursion = false
		)
	)
	
	/* ---------------------------------------------------------------------------------------------------------------------------
	<FUNCTION>
	<DOC>  Sets if the limit while fill painting uses the origin face as its limit calculation reference point or the last neighboring face.
	Arguments:
		<Bool> isOrigin : If the tool uses the origin face or not.
	Return:
		<Void> 
	*/ ---------------------------------------------------------------------------------------------------------------------------
	fn SetOriginNeighborState isOrigin =
	(
		if (OriginNeighborRecursion == false) do
		(
			OriginNeighborRecursion = true
			uiFillVsOrigin = isOrigin
			
			if (isOrigin) then
			(				
				ck_FillVSOrigin.state = true
				ck_FillVSNeighbor.state = false
			)
			else
			(				
				ck_FillVSOrigin.state = false
				ck_FillVSNeighbor.state = true
			)

			OriginNeighborRecursion = false
		)
	)
	
	/* ---------------------------------------------------------------------------------------------------------------------------
	<FUNCTION>
	<DOC>  Sets if the tool is ready to be used.
	Arguments:
		<Bool> flag : If the tool is ready.
		<Bool> check : If false, the tool will bypass checks to set the new value. Default value set to true.
	Return:
		<Void> 
	*/ ---------------------------------------------------------------------------------------------------------------------------
	fn OnEnabledFlagChanged flag check:true =
	(
		if (CanUseTool != flag or not check) do
		(
			CanUseTool = flag
			ck_StartPaintUV.enabled = flag
			ck_FillPaint.enabled = flag
			ck_PerfectPrepare.enabled = flag
			
			if (not flag and not IsPainting) do
			(
				ck_StartPaintUV.state = false
			)
		)
	)
	
	/* ---------------------------------------------------------------------------------------------------------------------------
	<FUNCTION>
	<DOC>  Sets if an object is selected in the world.
	Arguments:
		<Bool> flag : If the an object is selected.
		<Bool> check : If false, the tool will bypass checks to set the new value. Default value set to true.
	Return:
		<Void> 
	*/ ---------------------------------------------------------------------------------------------------------------------------
	fn OnSelectedFlagChanged flag check:true =
	(
		if (check or SelectedObject != ObjectStateListenerObj.SelectedObject) do
		(			
			if (flag) do
			(
				if (ObjectStateListenerObj.IsPoly == undefined) then
				(
					SelectedObject = undefined
					lb_Messages.Forecolor = (dotnetclass "System.Drawing.Color").Red
					lb_Messages.text = "05 Unsupported type"
				)
				else if (ObjectStateListenerObj.IsPoly == false) then
				(
					ck_PerfectPrepare.enabled = false
				)
				else
				(
					ck_PerfectPrepare.enabled = true
					
					if (SelectedObject != ObjectStateListenerObj.SelectedObject) do
					(						
						if (flag) then
						(
							SelectedObject = ObjectStateListenerObj.SelectedObject
							StartedWithEdges = SelectedObject.alledges
							ck_DisplayTri.state = StartedWithEdges
						
							if (not uiPaintByPoly) do
							(
								SelectedObject.alledges =  not ck_DisplayTri.state
							)
							
							SetPolyTriState ObjectStateListenerObj.IsPoly
						)
						else if (SelectedObject != undefined) then
						(
							SelectedObject.alledges = StartedWithEdges
							SelectedObject = undefined
						)
					)
				)
			)
		)
	)
	
	/* ---------------------------------------------------------------------------------------------------------------------------
	<FUNCTION>
	<DOC>  Callback function, called whenever the modifier panel updates. Handles recording the state of the world to update the tool accordingly.
	Arguments:
		<Bool> initial : If this call is done manually in the start method.
	Return:
		<Void> 
	*/ ---------------------------------------------------------------------------------------------------------------------------
	fn OnModPanelSelChanged initial =
	(
		if (DisplayError09) then
		(
			lb_Messages.Forecolor = (dotnetclass "System.Drawing.Color").Yellow
			lb_Messages.text = "09 Issues during resize"
			DisplayError09 = false
		)
		else
		(
			ObjectStateListenerObj.UpdateState()
		
			-- Make sure the flag is properly set to false when opening the tool to prevent edge cases.
			if (initial) do 
			(
				OnSelectedFlagChanged false check:false
				OnEnabledFlagChanged false check:false
			)
			
			if (ObjectStateListenerObj.SelectedCount > 1) then
			(
				OnSelectedFlagChanged false
				OnEnabledFlagChanged false
				
				lb_Messages.Forecolor = (dotnetclass "System.Drawing.Color").Red
				lb_Messages.text = "01 Only one mesh"
			)
			else if (ObjectStateListenerObj.SelectedCount <= 0) then
			(
				OnSelectedFlagChanged false
				OnEnabledFlagChanged false
				
				lb_Messages.Forecolor = (dotnetclass "System.Drawing.Color").Red
				lb_Messages.text = "00 Select mesh"
			)
			else
			(
				OnSelectedFlagChanged true
			)
			
			SelectedObject = ObjectStateListenerObj.SelectedObject
			if (SelectedObject != undefined) then
			(
				if (ObjectStateListenerObj.IsPoly == undefined) then
				(
					lb_Messages.Forecolor = (dotnetclass "System.Drawing.Color").Red
					lb_Messages.text = "05 Unsupported type."
					
					OnSelectedFlagChanged false
					OnEnabledFlagChanged false
				)
				else if (GetMapChannel() == undefined) then
				(
					lb_Messages.Forecolor = (dotnetclass "System.Drawing.Color").Red
					lb_Messages.text = "04 Channel unsupported."
					
					OnEnabledFlagChanged false
				)
				else
				(
					local faceCount = 0
					
					if (ObjectStateListenerObj.IsPoly) then
					(
						if (uiUseOnlySelection) then
						(
							local arr = undefined
							
							if (ObjectStateListenerObj.SelectedUnwrap != undefined) then
							(
								arr = ObjectStateListenerObj.SelectedUnwrap
								arr = arr.getSelectedFaces() as array
							)
							else
							(
								arr = (polyop.getFaceSelection ObjectStateListenerObj.SelectedObject) as array
							)
							
							faceCount = arr.count
						)
						else
						(
							faceCount = polyop.getNumFaces ObjectStateListenerObj.SelectedObject
						)
					)
					else
					(
						if (uiUseOnlySelection) then
						(
							local arr = undefined
							
							if (ObjectStateListenerObj.SelectedUnwrap != undefined) then
							(
								arr = ObjectStateListenerObj.SelectedUnwrap
								arr = arr.getSelectedFaces() as array
							)
							else
							(
								arr = (getFaceSelection ObjectStateListenerObj.SelectedObject) as array
							)
							
							faceCount = arr.count
						)
						else
						(
							faceCount = meshop.getNumFaces ObjectStateListenerObj.SelectedObject
						)
					)
					
					OnEnabledFlagChanged true
					
					CanFill = true
					if (faceCount > 7350) then
					(
						lb_Messages.Forecolor = (dotnetclass "System.Drawing.Color").Yellow
						lb_Messages.text = "07 Tool ready, cannot fill."
						
						CanFill = false
					)
					else if (faceCount >= 1350) then
					(
						lb_Messages.Forecolor = (dotnetclass "System.Drawing.Color").Yellow
						lb_Messages.text = "06 Tool ready, long fill, see docu."
					)
					else
					(
						lb_Messages.Forecolor = (dotnetclass "System.Drawing.Color").Green
						lb_Messages.text = "Tool ready!"
					)
					
					SelectedObject = ObjectStateListenerObj.SelectedObject
				)
			)
			else
			(
				OnEnabledFlagChanged false
			)
		)
	)
	
	/* ----------------------------------------------------------------------------------------------------------------------
	<MAIN ROLLOUT EVENTS>
	*/ ----------------------------------------------------------------------------------------------------------------------
	on rlt_UVPainter_Main rolledUp bState do
	(
		if (bState) then
		(
			MAX_RolloutHeight += rlt_UVPainter_Main.height + 2
		)
		else
		(
			MAX_RolloutHeight -= rlt_UVPainter_Main.height + 2
		)
		
		MAX_UniqueFloaterInstance.size.y = MAX_RolloutHeight
	)
	
	on rlt_UVPainter_Main open do
	(		
		ck_AverageWeld.enabled = uiAutoWeld	
		ck_DisplayTri.enabled = not uiPaintByPoly
		SetPolyTriState uiPaintByPoly
		SetOriginNeighborState uiFillVsOrigin
		
		lb_Messages.Backcolor = (dotnetclass "System.Drawing.Color").fromARGB 68 68 68
		lb_Messages.Forecolor = (dotnetclass "System.Drawing.Color").Green
		lb_Messages.TextAlign = (dotNetClass "System.Drawing.ContentAlignment").TopCenter
		lb_Messages.font = dotnetobject "System.Drawing.Font" "" 9 (dotNetClass "System.Drawing.FontStyle").bold
		
		ck_Autoweld.tooltip = "Automatically weld neighboring faces as it stitches, creating one large flat map, but can cause deformations."
		ck_AverageWeld.tooltip = "Changes the welding type of the welding from Source To Target to Average."
		sp_weldThreshold.tooltip = "Threshold (in distance between vertices in map space) under which welding is allowed to be done."
		
		ck_PropagSmoothGroup.tooltip = "Propagates the smoothing group from the origin face to the target face while painting or filling."
		ck_PropagMaterial.tooltip = "Propagates the material ID from the origin face to the target face while painting or filling."
		
		sp_CurrentMapChannel.tooltip = "The map channel onto which the painting and filling is done."
		
		ck_PaintByPoly.tooltip = "Changes the item to an Editable_Poly and does the Painting and Filling using the polygons rather than tris."
		ck_PaintByTri.tooltip = "Changes the item to an Editable_Mesh and does the Painting and Filling using the tris rather than polygons."
		ck_DisplayTri.tooltip = "Show Edges Only (same as the option inside the object itself, just temporary)."
		ck_UseSelection.tooltip = "Paint or fill only what is selected."
		
		ck_FillVSOrigin.tooltip = "Fill against Origin. Compares each faces that are filled to the original clicked face when limit is checked."
		ck_FillVSNeighbor.tooltip = "Fill against Neighbor. Compares each faces that are filled to the neighboring face when limit is checked."
		sp_FillPaintThreshold.tooltip = "Limits the angle (degree) in which the fill function propagates."
		
		ck_PerfectPrepare.tooltip = "Allows you to select a face. It will be mapped to planar, set to the pixel ratio and centered."
		ck_StartPaintUV.tooltip = "Allows you to start painting. When active, drag your mouse from one face to its neighbor to stitch them together. You may press 'control' while painting to weld the faces rather than stitch."
		ck_FillPaint.tooltip = "Allows you to start filling. When active, select a face then all neighboring faces, following the chosen limits, will be painting according to the origin face."
		
		registerRedrawViewsCallback UpdateViewportRendering
		callbacks.addScript #modPanelObjPostChange "rlt_UVPainter_Main.OnModPanelSelChanged false" id:#uvpaint_callback
		OnModPanelSelChanged true
		
		if (SelectedObject != undefined) do
		(
			ck_DisplayTri.state = not SelectedObject.alledges
		)
	)

	on ck_AutoWeld changed val do
	(
		ck_AverageWeld.enabled = val
		sp_WeldThreshold.enabled = val
		uiAutoweld = val
	)
	
	on ck_AverageWeld changed val do
	(
		uiWeldAverage = val
	)
	
	on sp_WeldThreshold changed val do
	(
		uiWeldThreshold = val
	)
	
	on ck_PropagSmoothGroup changed val do
	(
		uiPropagateSmoothingGroups = val
	)
	
	on ck_PropagMaterial changed val do
	(
		uiPropagateMaterialID = val
	)
	
	on sp_CurrentMapChannel changed val do 
	(
		uiUvMapChannel = val
		OnModPanelSelChanged false
	)
	
	on ck_PaintByPoly changed val do
	(
		SetPolyTriState true button:true
	)
	
	on ck_PaintByTri changed val do
	(
		SetPolyTriState false button:true
	)
	
	on ck_DisplayTri changed val do
	(
		if (SelectedObject != undefined) do
		(
			SelectedObject.alledges = not val
		)
	)
	
	on sp_FillPaintThreshold changed val do
	(
		uiFillPaintThreshold = val
	)
	
	on ck_FillVSOrigin changed val do
	(
		SetOriginNeighborState true
	)
	
	on ck_FillVSNeighbor changed val do
	(
		SetOriginNeighborState false
	)
	
	on ck_UseSelection changed val do
	(
		uiUseOnlySelection = val
		OnModPanelSelChanged false
	)
		
	on ck_StartPaintUV changed val do
	(
		OnModPanelSelChanged false
		
		IsPainting = val
		
		if (val) then
		(
			if (CanUseTool) do
			(
				if (SelectedObject != undefined and GetMapChannel() != undefined) then
				(
					SetModifierState true
					
					undo "UVPaintAction" on
					(					
						lb_Messages.Forecolor = (dotnetclass "System.Drawing.Color").Green
						lb_Messages.text = "LClick-Paint/RClick-Cancel"			
						mousetrack on:SelectedObject trackCallback:UVPaint()
					)
				)
				else
				(
					lb_Messages.Forecolor = (dotnetclass "System.Drawing.Color").Red
					lb_Messages.text = "04 Channel missing"
				)
			)
			
			SetModifierState false
			IsPainting = false
			ck_StartPaintUV.state = false -- Release the button when painting is cancelled.
		)
	)
	
	on ck_FillPaint changed val do
	(
		OnModPanelSelChanged false
		
		local stateChanged = false
		if (not IsPainting and not IsFillPainting and val) do
		(
			if (CanFill) then
			(
				if (CanUseTool) do
				(
					SetModifierState true
					stateChanged = true
					
					lb_Messages.Forecolor = (dotnetclass "System.Drawing.Color").Green
					lb_Messages.text = "LClick-Pick/RClick-Cancel"
					mousetrack on:SelectedObject trackCallback:FillPropagate()
				)
			)
		)
		
		if (stateChanged) do
		(
			SetModifierState false
		)

		IsFillPainting = false
		ck_FillPaint.state = false -- Release the button when painting is cancelled.
	)
	
	on ck_PerfectPrepare changed val do
	(
		local stateChanged = false
		if (not IsPainting and not IsFillPainting and val) do
		(
			if (CanUseTool) do
			(
				SetModifierState true
				stateChanged = true
				
				IsPerfectPreparing = true
				
				lb_Messages.Forecolor = (dotnetclass "System.Drawing.Color").Green
				lb_Messages.text = "LClick-Pick/RClick-Cancel"
				
				mousetrack on:SelectedObject trackCallback:DoPerfectPrepare()
			)
		)
		
		if (stateChanged) do
		(
			SetModifierState false
			
			-- Small little sleight of hand to get the warning on the screen.
			DisplayError09 = Error09
			Error09 = false
			
			OnModPanelSelChanged false
		)
	)
		
	on rlt_UVPainter_Main close do
	(
		if (SelectedObject != undefined) do
		(
			SelectedObject.alledges = StartedWithEdges 
		)
		
		callbacks.removeScripts id:#uvpaint_callback
		unregisterRedrawViewsCallback UpdateViewportRendering
	)
)

/* ---------------------------------------------------------------------------------------------------------------------------
<ROLLOUT> Pixel Ratio : Tool that allows quick resizing of UV elements to fit a given pixel ratio.
*/ ---------------------------------------------------------------------------------------------------------------------------
rollout rlt_PixelRatio_Main "Pixel Ratio" width:220 height:0
(	
	/* ---------------------------------------------------------------------------------------------------------------------------
	<UI MEMBERS> 
	*/ ---------------------------------------------------------------------------------------------------------------------------
	local uiWidth = 1
	local uiHeight = 1
	
	local uiMoveToCenter = true
	
	/* ---------------------------------------------------------------------------------------------------------------------------
	<MEMBER VARIABLES> 
	*/ ---------------------------------------------------------------------------------------------------------------------------
	local ObjectStateListenerObj = ObjectStateListener()
	
	local SelectedObject = undefined
	local CanUseTool = undefined
	
	local Error09 = false
	
	/* ----------------------------------------------------------------------------------------------------------------------
	<MAIN ROLLOUT CONTROLS>
	*/ ----------------------------------------------------------------------------------------------------------------------	
	dotnetcontrol lb_Messages "Label" text:"" width:190
	
	GroupBox gb_RatioOP "Ratio Options for 1 UV" pos:[5,30] width:210 height:45
	spinner sp_Width "W: " pos:[32,52] width:42 height:16 enabled:true range:[0,100,1] type:#float scale:0.01 fieldwidth:30
	spinner sp_Height "H: " pos:[97,52] width:42 height:16 enabled:true range:[0,100,1] type:#float scale:0.01 fieldwidth:30
	label lb_To "in meters." pos:[148,52] width:60 height:16
	
	checkButton ck_ToCenter "Move to Center" pos:[5,85] width:85 height:25	
	button bt_Resize "Resize" pos:[100,85] width:110 height:25
	
	/* ----------------------------------------------------------------------------------------------------------------------
	<LOCAL FUNCTIONS>
	*/ ----------------------------------------------------------------------------------------------------------------------	
	
	/* ---------------------------------------------------------------------------------------------------------------------------
	<FUNCTION>
	<DOC>  Callback function, called whenever the modifier panel updates. Handles recording the state of the world to update the tool accordingly.
	Arguments:
		<Bool> initial : If this call is done manually in the start method.
	Return:
		<Void> 
	*/ ---------------------------------------------------------------------------------------------------------------------------
	fn OnModPanelSelChanged =
	(	
		if (Error09) then
		(
			lb_Messages.Forecolor = (dotnetclass "System.Drawing.Color").Yellow
			lb_Messages.text = "09 Issues during resize"
			Error09 = false
		)
		else
		(
			ObjectStateListenerObj.UpdateState()
			SelectedObject = ObjectStateListenerObj.SelectedObject
			
			local objCount = ObjectStateListenerObj.SelectedCount

			if (objCount > 1) then
			(			
				lb_Messages.Forecolor = (dotnetclass "System.Drawing.Color").Red
				lb_Messages.text = "01 Only one mesh"
			)
			else if (objCount <= 0) then
			(			
				lb_Messages.Forecolor = (dotnetclass "System.Drawing.Color").Red
				lb_Messages.text = "00 Select mesh"
			)
			
			if (SelectedObject != undefined) then
			(
				if (ObjectStateListenerObj.IsPoly == undefined or not ObjectStateListenerObj.IsPoly) then
				(
					SelectedObject = undefined
					lb_Messages.Forecolor = (dotnetclass "System.Drawing.Color").Red
					lb_Messages.text = "08 Editable Poly only"
					
					CanUseTool = false
				)
				else if (ObjectStateListenerObj.SelectedObjectIsUnwrap) then
				(				
					lb_Messages.Forecolor = (dotnetclass "System.Drawing.Color").Green
					lb_Messages.text = "Tool ready!"
					CanUseTool = true
				)
				else
				(
					CanUseTool = false				
					if (ObjectStateListenerObj.SelectedUnwrap != undefined) then
					(
						lb_Messages.Forecolor = (dotnetclass "System.Drawing.Color").Red
						lb_Messages.text = "03 Unwrap unselected."
					)
					else
					(
						lb_Messages.Forecolor = (dotnetclass "System.Drawing.Color").Red
						lb_Messages.text = "02 Unwrap required."
					)
				)
			)
			else
			(
				CanUseTool = false
			)
		)
	)
	
	/* ----------------------------------------------------------------------------------------------------------------------
	<MAIN ROLLOUT EVENTS>
	*/ ----------------------------------------------------------------------------------------------------------------------
	on rlt_PixelRatio_Main rolledUp bState do
	(
		if (bState) then
		(
			MAX_RolloutHeight += rlt_PixelRatio_Main.height + 2
		)
		else
		(
			MAX_RolloutHeight -= rlt_PixelRatio_Main.height + 2
		)
		
		MAX_UniqueFloaterInstance.size.y = MAX_RolloutHeight
	)
	
	on rlt_PixelRatio_Main open do
	(		
		lb_Messages.Backcolor = (dotnetclass "System.Drawing.Color").fromARGB 68 68 68
		lb_Messages.Forecolor = (dotnetclass "System.Drawing.Color").Green
		lb_Messages.TextAlign = (dotNetClass "System.Drawing.ContentAlignment").TopCenter
		lb_Messages.font = dotnetobject "System.Drawing.Font" "" 9 (dotNetClass "System.Drawing.FontStyle").bold
		
		sp_Width.tooltip = "Specifies the width (in meters) of what 1 map width represents."
		sp_Height.tooltip = "Specifies the height (in meters) of what 1 map height represents."
		ck_ToCenter.tooltip = "Sets if the resized cluster should be centered after."
		bt_Resize.tooltip = "Resize the selected faces (as well as their clusters) using given parameters."
		
		ck_ToCenter.state = uiMoveToCenter
		
		callbacks.addScript #modPanelObjPostChange "rlt_PixelRatio_Main.OnModPanelSelChanged()" id:#pixelratio_callback
		OnModPanelSelChanged()
	)
	
	on sp_Width changed val do
	(
		uiWidth = val
	)
	
	on sp_Height changed val do
	(
		uiHeight = val
	)
	
	on ck_ToCenter changed val do
	(
		uiMoveToCenter = val
	)
	
	on bt_Resize pressed do
	(
		OnModPanelSelChanged()
		
		if (CanUseTool and ObjectStateListenerObj.IsPoly) do
		(
			Error09 = not MAX_Functions.ResizeToRatio uiWidth uiHeight SelectedObject ObjectStateListenerObj.SelectedUnwrap ObjectStateListenerObj.IsPoly uiMoveToCenter
		)
		
		OnModPanelSelChanged()
	)
		
	on rlt_PixelRatio_Main close do
	(		
		callbacks.removeScripts id:#pixelratio_callback
	)
)

/* ---------------------------------------------------------------------------------------------------------------------------
<ROLLOUT> Strip Flattener : Tool that allows quick flattening and straightening of strips.
*/ ---------------------------------------------------------------------------------------------------------------------------
rollout rlt_StripFlattener_Main "Strip Flattener" width:220 height:0
(
	/* ---------------------------------------------------------------------------------------------------------------------------
	<UI MEMBERS> 
	*/ ---------------------------------------------------------------------------------------------------------------------------
	local uiAngleTypes = 0 -- 0: None, 1: Average, 2: Min, 3: Max
	
	/* ---------------------------------------------------------------------------------------------------------------------------
	<MEMBER VARIABLES> 
	*/ ---------------------------------------------------------------------------------------------------------------------------
	local ObjectStateListenerObj = ObjectStateListener()
	
	local SelectedObject = undefined
	
	/* ----------------------------------------------------------------------------------------------------------------------
	<MAIN ROLLOUT CONTROLS>
	*/ ----------------------------------------------------------------------------------------------------------------------	
	dotnetcontrol lb_Messages "Label" text:"" width:190
	
	GroupBox gb_Options "Edge Angles" pos:[5,30] width:210 height:45
	checkbutton ck_Unchanged "Unch." pos:[10, 50] width:40 height:20
	checkbutton ck_Vertical "Vert." pos:[50, 50] width:40 height:20
	checkbutton ck_Average "Avg." pos:[90, 50] width:40 height:20
	checkbutton ck_Min "Min" pos:[130, 50] width:40 height:20
	checkbutton ck_Max "Max" pos:[170, 50] width:40 height:20
	
	button bt_Flatten "Flatten" pos:[80,80] width:60 height:25
	
	/* ---------------------------------------------------------------------------------------------------------------------------
	<LOCAL FUNCTIONS>
	*/ ---------------------------------------------------------------------------------------------------------------------------
	
	/* ---------------------------------------------------------------------------------------------------------------------------
	<FUNCTION>
	<DOC>  Changes the states of the various angle buttons depending on which is clicked.
	Arguments:
		<Int> type : Which button was clicked.
	Return:
		<Void> 
	*/ ---------------------------------------------------------------------------------------------------------------------------
	fn SetEdgeAngle type =
	(
		case uiAngleTypes of
		(
			0:
			(
				ck_Unchanged.state = false
			)
			
			1:
			(
				ck_Vertical.state = false
			)
			
			2:
			(
				ck_Average.state = false
			)
			
			3:
			(
				ck_Min.state = false
			)
			
			4:
			(
				ck_Max.state = false
			)
		)
		
		uiAngleTypes = type
	)
	
	/* ---------------------------------------------------------------------------------------------------------------------------
	<FUNCTION>
	<DOC>  Main flatten function. Takes the selected strip and makes it perfectly horizontal.
	Arguments:
		<Void>
	Return:
		<Void> 
	*/ ---------------------------------------------------------------------------------------------------------------------------
	fn Flatten =
	(
		-- Why try-catching? Well, if the code somehow breaks and theHold is not properly stopped, then the entirety of the undo system breaks and you can't undo anymore.
		-- This is just a safeguard so that, if the tool breaks, the user doesn't have to reset 3DS Max to regain the ability to undo.
		try
		(
			-- Weird undo stack hack. Due to a known glitch in how the undo stack works, I must make sure that an entry is entered before I start recording the tool's actions
			-- for future undoing. Thus, I enter a simple "Strip Selected" entry before I start the main tool's entry. Another glitch is that, despite the tool undoing properly,
			-- the first action, which is moving the first edge, isn't entered. Thus, I must create a dummy action that can be skipped by the undo stack instead, being the moveSelected.
			theHold.Begin()
			local unwrap = ObjectStateListenerObj.SelectedUnwrap
			local selectedEdgesBits = unwrap.getSelectedEdges()
			local selectedEdges = selectedEdgesBits as array
			
			unwrap.selectEdges (selectedEdges as bitarray)
			theHold.Accept "Strip Selected"
			
			theHold.Begin()	
			unwrap.moveSelected [0, 0, 0]
			
			if (selectedEdges.count > 0) do
			(
				unwrap.edgeToFaceSelect()
				local selectedFacesBits = unwrap.getSelectedFaces()
				local selectedFaces = selectedFacesBits as array
				
				local maxFace = amax selectedFaces
				local maxEdge = amax selectedEdges
				
				local faceToEdgeNeighbors = #() -- Using a face ID, return the three or four edge IDs related to it. Any unused face ID will be an empty bitfield.
				
				for i = 1 to maxFace do
				(
					append faceToEdgeNeighbors -#{1..maxEdge}
				)
				
				local edgeToFaceNeighbors = #() -- Using an edge ID from the strip, return the one or two face IDs adjacent to it.
				
				for i = 1 to maxEdge do
				(
					append edgeToFaceNeighbors -#{1..maxFace}
				)
				
				local triangleEdges = -#{1..maxEdge} -- Any edges in this bitfield is related to a triangle in the strip.
				
				for face in selectedFaces do
				(				
					unwrap.selectFaces #{face}
					unwrap.faceToEdgeSelect()
					
					local faceEdges = (unwrap.getSelectedEdges()) as array
					
					for faceEdge in faceEdges do
					(
						faceToEdgeNeighbors[face][faceEdge] = true
						if (faceEdges.count == 3) then
						(
							triangleEdges[faceEdge] = true
						)
					)
				)
				
				for stripEdge in selectedEdges do
				(				
					for stripFace in selectedFaces do
					(
						local faceToEdgeArray = (faceToEdgeNeighbors[stripFace]) as array
						
						for arrayEdge in faceToEdgeArray do
						(
							if (arrayEdge == stripEdge) do
							(
								edgeToFaceNeighbors[stripEdge][stripFace] = true
							)
						)
					)
				)
				
				-- Step 1 : Have an ordered list of edges and prepare our data.
				local orderedSelectedEdgesBits = -#{1..maxEdge}
				local orderedSelectedEdges = #()
				
				-- Cache some data that is quite annoying to obtain.
				local positions = #()
				local vertices = #()
				local lengths = #()
				
				for i = 1 to maxEdge do
				(
					unwrap.selectEdges #{i}
					append positions (unwrap.getSelCenter())
						
					unwrap.edgeToVertSelect()
					local verts = (unwrap.getSelectedVertices()) as array
					
					append vertices verts
					append lengths (abs(distance (unwrap.getVertexPosition 0 verts[1]) (unwrap.getVertexPosition 0 verts[2])))
				)
				
				-- We need to find the edge closest to left on X and 0 on Y to start the strip from.
				local currentEdge = 0
				for stripEdge in selectedEdges do
				(
					if (edgeToFaceNeighbors[stripEdge].numberSet < 2) do
					(
						if (currentEdge == 0) then
						(
							currentEdge = stripEdge
						)
						else
						(					
							if ((distance [0, 0, 0] positions[currentEdge]) > (distance [0, 0, 0] positions[stripEdge])) do
							(
								currentEdge = stripEdge
							)
						)
					)
				)
				
				append orderedSelectedEdges currentEdge
				orderedSelectedEdgesBits[currentEdge] = true
				
				local facesVisited = -#{1..maxFace}
				
				-- We jump from edge to face to edge in order to construct an array where the strip edges are in the right order.
				local escape = false
				while(not escape) do
				(
					local faceToVisit = 0
					local neighboringFaces = (edgeToFaceNeighbors[currentEdge]) as array
					for face in neighboringFaces do
					(					
						if (not facesVisited[face]) do
						(
							faceToVisit = face
							facesVisited[face] = true
						)
					)
					
					local oldCurrentEdge = currentEdge
					if (faceToVisit != 0) then
					(					
						local faceEdges = (faceToEdgeNeighbors[faceToVisit]) as array
						
						for faceEdge in faceEdges do
						(
							-- We don't wanna select a new edge if one was already found, we wanna make sure the edge we're calculating has been selected by the user and we wanna make sure we haven't been to that edge already.
							if (currentEdge == oldCurrentEdge and selectedEdgesBits[faceEdge] and not orderedSelectedEdgesBits[faceEdge]) do
							(							
								currentEdge = faceEdge
								append orderedSelectedEdges faceEdge
								orderedSelectedEdgesBits[faceEdge] = true
							)
						)
						
						if (currentEdge == oldCurrentEdge) do
						(
							escape = true
						)
					)
					else
					(
						escape = true
					)
				)
				
				local lastNewPosition = [0, 0, 0]
				
				local useTriangleEdgeCalculation = false
				local lastCalculatedEdgeID = 0
				
				local vertsToChange = #() -- All verts in this will be moved between the equivalent vertex in First and Second.
				local vertsToChangeFirst = #()
				local vertsToChangeSecond = #()
				
				for i = 1 to orderedSelectedEdges.count do
				(
					local edgeID = orderedSelectedEdges[i]
					
					if (not useTriangleEdgeCalculation) then
					(
						local center = positions[edgeID]
						local dist = 0
						
						-- We want the edges to remain at an equal distance from each other, even when straightened.
						if (lastCalculatedEdgeID > 0) then
						(
							dist = abs(distance positions[edgeID] positions[lastCalculatedEdgeID])
						)
						
						local angleBetweenCenters = 0
						local nextEdgeID = orderedSelectedEdges[i + 1]
						
						-- While the artist will do touch-ups of the result, we at least try to get them a result close to the real deal to lighten the load.
						-- Here, we try to average the angle of the edge by using the two adjacent edges as source.
						if (uiAngleTypes >= 2 and positions.count > 1) do
						(
							if (i == orderedSelectedEdges.count) then
							(
								angleBetweenCenters = acos ((positions[edgeID].x - positions[lastCalculatedEdgeID].x) / (abs (distance positions[edgeID] positions[lastCalculatedEdgeID])))
							)
							else if (lastCalculatedEdgeID > 0) then
							(							
								case uiAngleTypes of
								(
									2:
									(
										angleBetweenCenters = acos ((positions[nextEdgeID].x - positions[edgeID].x) / (abs (distance positions[edgeID] positions[nextEdgeID])))
										angleBetweenCenters -= acos ((positions[edgeID].x - positions[lastCalculatedEdgeID].x) / (abs (distance positions[edgeID] positions[lastCalculatedEdgeID])))
										angleBetweenCenters /= 2.0
									)
									
									3:
									(
										local angles = #(acos ((positions[nextEdgeID].x - positions[edgeID].x) / (abs (distance positions[edgeID] positions[nextEdgeID]))), acos ((positions[edgeID].x - positions[lastCalculatedEdgeID].x) / (abs (distance positions[edgeID] positions[lastCalculatedEdgeID]))))
										if (abs(angles[1]) < abs(angles[2])) then
										(
											angleBetweenCenters = angles[1] 
										)
										else
										(
											angleBetweenCenters = angles[2] 
										)
									)
									
									4:
									(
										local angles = #(acos ((positions[nextEdgeID].x - positions[edgeID].x) / (abs (distance positions[edgeID] positions[nextEdgeID]))), acos ((positions[edgeID].x - positions[lastCalculatedEdgeID].x) / (abs (distance positions[edgeID] positions[lastCalculatedEdgeID]))))
										if (abs(angles[1]) > abs(angles[2])) then
										(
											angleBetweenCenters = angles[1] 
										)
										else
										(
											angleBetweenCenters = angles[2] 
										)
									)
								)
							)
							else
							(
								angleBetweenCenters -= acos ((positions[nextEdgeID].x - positions[edgeID].x) / (abs (distance positions[edgeID] positions[nextEdgeID])))
							)	
						)
						
						-- Step 2 : Move all edges in a straight line.
						local newY = #()
						
						for i = 1 to maxEdge do
						(
							append newY #()
						)
						
						local newX = positions[edgeID].x 
						if (lastCalculatedEdgeID > 0) do
						(
							newX = lastNewPosition.x + dist
						)
						
						local flat = false
						for v in vertices[edgeID] do
						(
							unwrap.selectVertices #{v}
							
							local pos = unwrap.getVertexPosition 0 v
							local y = 0
							
							if (MAX_Functions.CloseTo pos.y positions[edgeID].y) then
							(
								-- If the strip is going up, we want to orient the edges differently than if the strip is going down to prevent the side edges from going criss-cross.
								if (lastCalculatedEdgeID > 0 and positions[edgeID].y < positions[lastCalculatedEdgeID].y) then
								(
									if (flat) then
									(
										y = -lengths[edgeID] / 2.0
										flat = false
									)
									else
									(
										y = lengths[edgeID] / 2.0
										flat = true
									)
								)
								else
								(
									if (flat) then
									(
										y = lengths[edgeID] / 2.0
										flat = false
									)
									else
									(
										y = -lengths[edgeID] / 2.0
										flat = true
									)
								)
							)
							else if (lastCalculatedEdgeID > 0 and positions[edgeID].x < positions[lastCalculatedEdgeID].x) then
							(
								if (pos.y < positions[edgeID].y) then
								(
									y = lengths[edgeID] / 2.0
								)
								else
								(
									y = -lengths[edgeID] / 2.0
								)
							)
							else
							(
								if (pos.y > positions[edgeID].y) then
								(
									y = lengths[edgeID] / 2.0
								)
								else
								(
									y = -lengths[edgeID] / 2.0
								)
							)
							unwrap.moveY y
							append newY[edgeID] y
							
							-- Step 3 : Move the edges in a way where they keep the same distance they had before the move.
							-- We have to re-obtain the position due to us having moved the vertices beforehand.
							if (uiAngleTypes == 0) then
							(
								local pos = unwrap.getVertexPosition 0 v
								local diffs = #(abs(pos.x - positions[edgeID].x),  abs(pos.y - positions[edgeID].y))
								unwrap.moveX (newX + (amin diffs))
							)
							else
							(
								unwrap.moveX newX
							)
						)
						
						-- Step 4 : Re-apply the rotation the edges would theoritically have after being straightened.
						unwrap.selectEdges #{orderedSelectedEdges[i]}
						unwrap.rotateSelectedCenter angleBetweenCenters 
					
						for i = 1 to vertices[edgeID].count do
						(
							unwrap.selectVertices #{vertices[edgeID][i]}
							unwrap.moveY newY[edgeID][i]
						)
						
						lastNewPosition = unwrap.getSelCenter()
						lastCalculatedEdgeID = edgeID
					)
					else
					(						
						local nextEdgeID = orderedSelectedEdges[i + 1]
						if (i + 1 <= selectedEdges.count) then
						(
							unwrap.selectEdges #{lastCalculatedEdgeID, edgeID, nextEdgeID}
						)
						else
						(
							unwrap.selectEdges #{lastCalculatedEdgeID, edgeID}
						)
						
						unwrap.edgeToFaceSelect()
						local relatedFaces = (unwrap.getSelectedFaces()) as array
						
						if (relatedFaces.count == 1) do
						(
							append relatedFaces relatedFaces[1]
						)

						local edges1 = faceToEdgeNeighbors[relatedFaces[1]]
						local edges2 = faceToEdgeNeighbors[relatedFaces[2]]
						
						local currentVertices = vertices[edgeID]
						local lastVerticesBits = (vertices[lastCalculatedEdgeID]) as bitarray
						
						local vertToChange = 0
						for v in currentVertices do
						(
							if (vertToChange == 0 and not lastVerticesBits[v]) do
							(
								vertToChange = v
							)
						)
						
						if (vertToChange != 0) do
						(
							append vertsToChange vertToChange

							-- We know the neighboring vertex we wanna use as references for the new position are, well, neighbors to our vertex. So, we can use some unwrap manipulation to get a selection of all neighboring vertices.
							unwrap.setTVSubObjectMode 1
							
							unwrap.selectVertices #{vertToChange}
							unwrap.expandSelection()
							unwrap.vertToEdgeSelect()
							
							unwrap.setTVSubObjectMode 2
							
							local relatedEdges = (unwrap.getSelectedEdges()) as array
							local step = 0
							for relatedEdge in relatedEdges do
							(
								if (relatedEdge != edgeID) do
								(
									local relatedVertices = vertices[relatedEdge]
									
									if (relatedVertices.count != 0) do
									(
										local vStorage = 0
										local foundFirst = false
										for v in relatedVertices do -- We have to make sure we can find the right neighboring vertices no matter the order of them in each edges.
										(
											if (v == vertToChange) then
											(
												if (vStorage  != 0) then
												(
													if (step == 0) then
													(
														append vertsToChangeFirst vStorage
														step += 1
													)
													else if (step == 1) then
													(
														if (vertsToChangeFirst[vertsToChangeFirst.count] != vStorage) do
														(
															append vertsToChangeSecond vStorage
															step += 1
														)
													)
												)
												else
												(
													foundFirst = true
												)
											)
											else if (foundFirst) then
											(
												if (step == 0) then
												(
													append vertsToChangeFirst v
													step += 1
												)
												else if (step == 1) then
												(
													if (vertsToChangeFirst[vertsToChangeFirst.count] != v) do
													(
														append vertsToChangeSecond v
														step += 1
													)
												)
											)
											else
											(
												vStorage = v
											)
										)
									)
								)
							)
						)
					)
					
					if (i + 1 <= selectedEdges.count and triangleEdges[orderedSelectedEdges[i]] and triangleEdges[orderedSelectedEdges[i + 1]] and not useTriangleEdgeCalculation) then
					(
						useTriangleEdgeCalculation = true
					)
					else
					(
						useTriangleEdgeCalculation = false
					)
					
					skippedFirst = true
				)
				
				if (vertsToChangeFirst.count == vertsToChange.count and vertsToChangeSecond.count == vertsToChange.count) do
				(
					for i = 1 to vertsToChange.count do
					(
						local newPos = ((unwrap.getVertexPosition 0 vertsToChangeFirst[i]) + (unwrap.getVertexPosition 0 vertsToChangeSecond[i])) / 2.0
						unwrap.setVertexPosition 0 vertsToChange[i] newPos
					)
				)
				
				unwrap.selectEdges (selectedEdges as bitarray)
			)
			
			theHold.Accept "Flatten"
		)
		catch
		(
			if (theHold.Holding()) do
			(
				theHold.Cancel()
			)
		)
	)
	
	/* ---------------------------------------------------------------------------------------------------------------------------
	<FUNCTION>
	<DOC>  Callback function, called whenever the modifier panel updates. Handles recording the state of the world to update the tool accordingly.
	Arguments:
		<Bool> initial : If this call is done manually in the start method.
	Return:
		<Void> 
	*/ ---------------------------------------------------------------------------------------------------------------------------
	fn OnModPanelSelChanged =
	(		
		ObjectStateListenerObj.UpdateState()
		SelectedObject = ObjectStateListenerObj.SelectedObject
		
		bt_Flatten.enabled = false
		if (ObjectStateListenerObj.SelectedCount > 1) then
		(			
			lb_Messages.Forecolor = (dotnetclass "System.Drawing.Color").Red
			lb_Messages.text = "01 Only one mesh"
		)
		else if (ObjectStateListenerObj.SelectedCount <= 0) then
		(			
			lb_Messages.Forecolor = (dotnetclass "System.Drawing.Color").Red
			lb_Messages.text = "00 Select mesh"
		)
		
		if (SelectedObject != undefined) then
		(
			if (ObjectStateListenerObj.SelectedObjectIsUnwrap) then
			(				
				lb_Messages.Forecolor = (dotnetclass "System.Drawing.Color").Green
				lb_Messages.text = "Tool ready!"
			
				bt_Flatten.enabled = true
			)
			else
			(		
				if (ObjectStateListenerObj.SelectedUnwrap != undefined) then
				(
					lb_Messages.Forecolor = (dotnetclass "System.Drawing.Color").Red
					lb_Messages.text = "03 Unwrap unselected."
				)
				else
				(
					lb_Messages.Forecolor = (dotnetclass "System.Drawing.Color").Red
					lb_Messages.text = "02 Unwrap required."
				)
			)
		)
	)
	
	/* ----------------------------------------------------------------------------------------------------------------------
	<MAIN ROLLOUT EVENTS>
	*/ ----------------------------------------------------------------------------------------------------------------------	
	on rlt_StripFlattener_Main rolledUp bState do
	(
		if (bState) then
		(
			MAX_RolloutHeight += rlt_StripFlattener_Main.height + 2
		)
		else
		(
			MAX_RolloutHeight -= rlt_StripFlattener_Main.height + 2
		)
		
		MAX_UniqueFloaterInstance.size.y = MAX_RolloutHeight
	)
	
	on rlt_StripFlattener_Main open do
	(
		uiAngleTypes = 0
		ck_Unchanged.state = true
		
		lb_Messages.Backcolor = (dotnetclass "System.Drawing.Color").fromARGB 68 68 68
		lb_Messages.Forecolor = (dotnetclass "System.Drawing.Color").Green
		lb_Messages.TextAlign = (dotNetClass "System.Drawing.ContentAlignment").TopCenter
		lb_Messages.font = dotnetobject "System.Drawing.Font" "" 9 (dotNetClass "System.Drawing.FontStyle").bold
		
		callbacks.addScript #modPanelObjPostChange "rlt_StripFlattener_Main.OnModPanelSelChanged()" id:#stripflat_callback
		OnModPanelSelChanged()
	)
	
	on ck_Unchanged changed val do
	(
		if (val) then
		(
			SetEdgeAngle 0
		)
		else
		(
			ck_Unchanged.state = true
		)
	)
	
	on ck_Vertical changed val do
	(
		if (val) then
		(
			SetEdgeAngle 1
		)
		else
		(
			ck_Vertical.state = true
		)
	)
	
	on ck_Average changed val do
	(
		if (val) then
		(
			SetEdgeAngle 2
		)
		else
		(
			ck_Average.state = true
		)
	)
	
	on ck_Min changed val do
	(
		if (val) then
		(
			SetEdgeAngle 3
		)
		else
		(
			ck_Min.state = true
		)
	)
	
	on ck_Max changed val do
	(
		if (val) then
		(
			SetEdgeAngle 4
		)
		else
		(
			ck_Max.state = true
		)
	)
	
	on bt_Flatten pressed do
	(
		Flatten()
	)
	
	on rlt_StripFlattener_Main close do
	(		
		callbacks.removeScripts id:#stripflat_callback
	)
)

/* ---------------------------------------------------------------------------------------------------------------------------
<ROLLOUT> Map Options : Group of quick shortcuts to create the perfect UVW Map in seconds.
*/ ---------------------------------------------------------------------------------------------------------------------------
rollout rlt_MapOP_Main "UVW Map Shortcuts" width:220 height:0
(	
	/* ---------------------------------------------------------------------------------------------------------------------------
	<UI MEMBERS> 
	*/ ---------------------------------------------------------------------------------------------------------------------------
	local uiUnitLength = 1
	local uiUnitWidth = 1
	local uiUnitHeight = 1
	
	/* ---------------------------------------------------------------------------------------------------------------------------
	<MEMBER VARIABLES> 
	*/ ---------------------------------------------------------------------------------------------------------------------------
	local ObjectStateListenerObj = ObjectStateListener()
	
	local SelectedObject = undefined
	
	/* ---------------------------------------------------------------------------------------------------------------------------
	<MAIN ROLLOUT CONTROLS>
	*/ ---------------------------------------------------------------------------------------------------------------------------
	button bt_PlanarFit "Fit Planar" pos:[42,10] width:65 height:20
	button bt_BoxFit "Fit Box" pos:[114,10] width:65 height:20
	
	spinner sp_UnitLength "Len:" pos:[44, 43] width:30 height:20 range:[0, 100, 1] type:#float scale:0.05 fieldwidth:36
	spinner sp_UnitWidth "Wid:" pos:[120, 43] width:30 height:20 range:[0, 100, 1] type:#float scale:0.05 fieldwidth:36
	button bt_ToPlanar "To Planar" pos:[155,40] width:60 height:20
	
	spinner sp_UnitHeight "Hei:" pos:[120, 68] width:30 height:20 range:[0, 100, 1] type:#float scale:0.05 fieldwidth:36
	button bt_ToBox "To Box" pos:[155,65] width:60 height:20
	
	/* ---------------------------------------------------------------------------------------------------------------------------
	<LOCAL FUNCTIONS>
	*/ ---------------------------------------------------------------------------------------------------------------------------
	
	/* ---------------------------------------------------------------------------------------------------------------------------
	<FUNCTION>
	<DOC>  Callback function, called whenever the modifier panel updates. Handles recording the state of the world to update the tool accordingly.
	Arguments:
		<Bool> initial : If this call is done manually in the start method.
	Return:
		<Void> 
	*/ ---------------------------------------------------------------------------------------------------------------------------
	fn OnModPanelSelChanged =
	(		
		ObjectStateListenerObj.UpdateState()
		SelectedObject = ObjectStateListenerObj.SelectedObject
		
		local flag = SelectedObject != undefined
		bt_PlanarFit.enabled = flag
		bt_ToPlanar.enabled = flag
		bt_ToBox.enabled = flag
	)
	
	/* ---------------------------------------------------------------------------------------------------------------------------
	<FUNCTION>
	<DOC>  Replicates the functionality of the Fit function on the UVW Map modifier, fits the object's map inside the UVW boundaries.
	Arguments:
		<Int> type : Type of UVW map to calculate fit with. Given as an int representing the order in which they appear in the tool. 0:Planar, 1:Cylindrical, 2:Spherical, 3:Shrink Wrap, 4:Box, 5:Face
	Return:
		<Void> 
	*/ ---------------------------------------------------------------------------------------------------------------------------
	fn AddMapAndFit type =
	(
		-- This function is necessary because the Fit option isn't available in the API and must be replicated.
		local sel = SelectedObject
		local isPoly = ObjectStateListenerObj.IsPoly
		
		if (isPoly != undefined) do
		(
			local faces = #()
			local verts = #()
			
			local normal = undefined
			local matrix = undefined
			
			local sol = subObjectLevel
			
			if (isPoly) then
			(
				for obj in selection where canConvertTo obj mesh do
				(
					convertTo obj PolyMeshObject
				)
				
				-- Just making sure the faces we obtain are the right one by placing the modifier panel in poly selection mode.
				-- Setting it there since we've just converted the object and thus we know SOL 4 exists.
				subObjectLevel = 4
				
				faces = polyop.getFaceSelection sel
				verts = polyop.getVertsUsingFace sel faces
				
				if (verts.numberSet == 0) do
				(
					local num = polyop.getNumVerts sel
					verts = #{1..num}
					
					local faceNum = polyop.getNumFaces sel
					faces = (#{1..faceNum}) as array
				)
				
				normal = [0, 0, 0]
				for face in faces do
				(
					normal += polyop.getFaceNormal sel face
				)
				
				normal = in coordsys sel (normal / faces.count)
				
				local worldup = [0, 0, 1]
				local right = normalize(cross worldup normal)
				local up = normalize(cross right normal)
				
				matrix = matrix3 right up normal [0, 0, 0]
			)
			else
			(
				for obj in selection where canConvertTo obj mesh do
				(
					convertTo obj TriMeshGeometry
				)
				
				subObjectLevel = 4
				
				faces = getFaceSelection sel
				verts = meshop.getVertsUsingFace sel faces
				
				if (verts.numberSet == 0) do
				(
					local num = meshop.getNumVerts sel
					verts = #{1..num}
					
					local faceNum = meshop.getNumFaces sel
					faces = (#{1..faceNum}) as array
				)
				
				normal = [0, 0, 0]
				for face in faces do
				(
					normal += getFaceNormal sel face
				)
				
				normal = in coordsys sel (normal / faces.count)
				
				local worldup = [0, 0, 1]
				local right = normalize(cross worldup normal)
				local up = normalize(cross right normal)
				
				matrix = matrix3 right up normal [0, 0, 0]
			)
			
			subObjectLevel = sol
			
			modPanel.addModToSelection (UVWMap()) ui:on
			
			local map = undefined
			for m in sel.modifiers where classof m == UVWMap do
			(
				map = m
			)
			
			map.gizmo.transform *= inverse(scaleMatrix map.gizmo.transform.scalepart) -- Reset scale to [1, 1, 1]
			
			local minVal = [1000000, 1000000, 1000000]
			local maxVal = [-1000000, -1000000, -1000000]
			
			local mapTransform = matrix
			local invMapTransform = inverse(mapTransform)
			
			for v in verts do
			(
				local vert = undefined
				if (isPoly) then -- Get the vertex position in gizmo space.
				(
					vert = (polyop.getVert sel v) * invMapTransform 
				)
				else
				(
					vert = (meshop.getVert sel v) * invMapTransform
				)
			  
				if vert.x > maxVal.x do 
				(
					maxVal.x = vert.x
				)
				
				if vert.y > maxVal.y do 
				(
					maxVal.y = vert.y
				)
				
				if vert.z > maxVal.z do 
				(
					maxVal.z = vert.z
				)
				
				if vert.x < minVal.x do 
				(
					minVal.x = vert.x
				)
				
				if vert.y < minVal.y do 
				(
					minVal.y = vert.y
				)
				
				if vert.z < minVal.z do 
				(
					minVal.z = vert.z
				)
			)
			
			local pos = [0, 0, 0]
			case map.axis of -- Take into account axis orientation (X=0, Y=1, Z=2).
			(
				0: 
				(
					pos.x = maxVal.z - minVal.z  -- Gizmo's Z axis is aligned to the object's local X axis.
					pos.y = maxVal.y - minVal.y
					pos.z = maxVal.x - minVal.x
				)
				
				1: 
				(
					pos.x = maxVal.x - minVal.x
					pos.y = maxVal.z - minVal.z -- Gizmo's Z axis is aligned to the object's local Y axis.
					pos.z = maxVal.y - minVal.y
				)
				
				2: 
				(
					pos.x = maxVal.x - minVal.x
					pos.y = maxVal.y - minVal.y
					pos.z = maxVal.z - minVal.z -- Gizmo's Z axis is aligned to the object's local Z axis.
				)
			)
			
			if (verts.numberset == 0) then
			(
				pos = [10, 10, 10]
			)
			else
			(
				-- If we have to process vertices, add 0.1% for padding (that's how UVW Map handles the math).
				pos += pos * 0.001
			)
			
			map.gizmo.transform = matrix
			map.width = pos.x
			map.length = pos.y
			map.height = pos.z
			map.maptype = type
			
			case map.maptype of --Take into account map type.
			(
				default:
				(
					map.width = amax #(pos.x, pos.y)
					map.length = map.width
				)
				
				0: () 	-- Planar : Keep data as-is.
				
				1:		-- Cylinder : Do some math based on the map orientation.
				(
					case map.axis of
					(
						0: 
						(
							map.width = amax #(pos.x, pos.z)
							map.length = map.width
							map.height = pos.y
						)
						
						1: 
						(
							map.width = amax #(pos.y, pos.z)
							map.length = map.width
							map.height = pos.x
						)
						
						2:
						(
							map.width = amax #(pos.x, pos.y)
							map.length = map.width
							map.height = pos.z
						)
					)
				)
				
				2:		-- Spherical : Radius becomes the largest of the 3 values.
				(
					map.width = amax #(pos.x, pos.y, pos.z)
					map.length = map.width
					map.height = map.width
				)
				
				3:		-- Shrink Wrap : Radius becomes the largest of the 3 values.
				(
					map.width = amax #(pos.x, pos.y, pos.z)
					map.length = map.width
					map.height = map.width
				)
				
				4: ()	-- Box : Keep data as-is.
			)
		)
	)
	
	/* ----------------------------------------------------------------------------------------------------------------------
	<MAIN ROLLOUT EVENTS>
	*/ ----------------------------------------------------------------------------------------------------------------------	
	on rlt_MapOP_Main rolledUp bState do
	(
		if (bState) then
		(
			MAX_RolloutHeight += rlt_MapOP_Main.height + 2
		)
		else
		(
			MAX_RolloutHeight -= rlt_MapOP_Main.height + 2
		)
		
		MAX_UniqueFloaterInstance.size.y = MAX_RolloutHeight
	)
	
	on rlt_MapOP_Main open do
	(		
		bt_PlanarFit.tooltip = "Applies a planar UVW Map onto the selection and sets it to fit the content."
		bt_BoxFit.tooltip = "Applies a box UVW Map onto the selection and sets it to fit the content."
		
		sp_UnitLength.tooltip = "Sets the length of the UVW Map that would be applied with To Planar and To Box."
		sp_UnitWidth.tooltip = "Sets the width of the UVW Map that would be applied with To Planar and To Box."
		bt_ToPlanar.tooltip = "Applies a planar UVW Map onto the selection and sets its size to the given values."
		
		sp_UnitHeight.tooltip = "Sets the height of the UVW Map that would be applied with To Box."
		bt_ToBox.tooltip = "Applies a box UVW Map onto the selection and sets its size to the given values."
		
		callbacks.addScript #modPanelObjPostChange "rlt_MapOP_Main.OnModPanelSelChanged()" id:#mapop_callback
		OnModPanelSelChanged()
	)
	
	on bt_PlanarFit pressed do
	(
		AddMapAndFit 0
	)
	
	on bt_BoxFit pressed do
	(
		AddMapAndFit 4
	)
	
	on sp_UnitLength changed val do
	(
		uiUnitLength = val
	)
	
	on sp_UnitWidth changed val do
	(
		uiUnitWidth = val
	)
	
	on bt_ToPlanar pressed do
	(
		MAX_Functions.AddMapAndResize uiUnitLength uiUnitWidth 0 0 SelectedObject ObjectStateListenerObj.IsPoly
	)
	
	on sp_UnitHeight changed val do
	(
		uiUnitHeight = val
	)
	
	on bt_ToBox pressed do
	(
		MAX_Functions.AddMapAndResize uiUnitLength uiUnitWidth uiUnitHeight 4 SelectedObject ObjectStateListenerObj.IsPoly
	)
		
	on rlt_MapOP_Main close do
	(		
		callbacks.removeScripts id:#mapop_callback
	)
)

/* ----------------------------------------------------------------------------------------------------------------------
<END OF SCRIPT> Start the tool then free memory
*/ ----------------------------------------------------------------------------------------------------------------------
addRollout rlt_InfoBox_Main MAX_UniqueFloaterInstance rolledUp:true
addRollout rlt_CheckerTex_Main MAX_UniqueFloaterInstance rolledUp:true
addRollout rlt_UVPainter_Main MAX_UniqueFloaterInstance rolledUp:true
addRollout rlt_PixelRatio_Main MAX_UniqueFloaterInstance rolledUp:true
addRollout rlt_StripFlattener_Main MAX_UniqueFloaterInstance rolledUp:true
addRollout rlt_MapOP_Main MAX_UniqueFloaterInstance rolledUp:true
