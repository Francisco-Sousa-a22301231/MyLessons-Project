from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from .serializers import EquipmentSerializer

class CreateEquipmentView(APIView):
    """
    POST payload must include *all* fields:
    {
      "name": "Basketball",
      "school": 3,
      "location": 5,
      "state": "new",
      "is_being_used": false,
      "nothing_missing": true,
      "usages": ["dribbling", "shooting"],
      "sports": [1,2],
      "size": "standard",
      "is_for_kids": false,
      "description": "Leather ball",
      "brand": "Spalding"
    }
    """
    def post(self, request, *args, **kwargs):
        serializer = EquipmentSerializer(data=request.data, context={'request': request})
        if serializer.is_valid():
            equipment = serializer.save()
            return Response(
                EquipmentSerializer(equipment).data,
                status=status.HTTP_201_CREATED
            )
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
