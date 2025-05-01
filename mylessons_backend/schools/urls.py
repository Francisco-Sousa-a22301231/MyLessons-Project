from django.urls import path

from equipment.views import CreateEquipmentView
from .views import add_instructor, add_staff_view, check_user_view, create_location, create_review, create_subject, get_all_locations, get_all_subjects, get_equipments, get_school_time_limit, remove_instructor,delete_payment_type_entry_view ,number_of_bookings_in_timeframe, school_revenue_in_timeframe, number_of_students_in_timeframe, number_of_instructors_in_timeframe, update_pack_price_view, school_details_view, update_payment_type_view, all_schools, get_services, add_edit_service, create_school, update_school_locations, update_school_subjects

urlpatterns = [
    path('add_instructor/', add_instructor, name='add_instructor'),
    path('remove_instructor/', remove_instructor, name='remove_instructor'),
    path('number_of_booked_lessons/<int:school_id>/<str:start_date>/<str:end_date>/', number_of_bookings_in_timeframe, name='number_of_booked_lessons_in_timeframe'),
    path('number_of_students/<int:school_id>/<str:start_date>/<str:end_date>/', number_of_students_in_timeframe, name='number_of_students_in_timeframe'),
    path('number_of_instructors/<int:school_id>/<str:start_date>/<str:end_date>/', number_of_instructors_in_timeframe, name='number_of_instructors_in_timeframe'),
    path('school-revenue/<int:school_id>/<str:start_date>/<str:end_date>/', school_revenue_in_timeframe, name='school_revenue_in_timeframe'),
    path('update_pack_price/', update_pack_price_view, name='update_pack_price'),
    path('update_payment_type/', update_payment_type_view, name='update_payment_type'),
    path('delete_payment_type_entry/', delete_payment_type_entry_view, name='delete_payment_type_entry'),
    path('details/', school_details_view, name='school_details'),
    path('all_schools/', all_schools, name='all_schools'),
    path('<int:school_id>/services/', get_services, name='get-services'),
    path('<int:school_id>/equipments/<int:subject_id>/', get_equipments, name='get-equipments'),
    path('<int:school_id>/services/add_edit/', add_edit_service, name='add-edit-service'),
    path('create/', create_school, name='create_school'),
    path('add_staff/', add_staff_view, name='add_staff'),
    path('check_user/', check_user_view, name='check_user'),
    path('subjects/', get_all_subjects, name='get_all_subjects'),
    path('locations/', get_all_locations, name='get_all_sports'),
    path('update_subjects/', update_school_subjects, name='update_school_subjects'),
    path('update_locations/', update_school_locations, name='update_school_locations'),
    path('create_subject/', create_subject, name='create_subject'),
    path('create_location/', create_location, name='create_location'),
    path('get_school_time_limit/', get_school_time_limit, name='get_school_time_limit'),
    path('add_review/', create_review, name='add_review'),
    path(
        'create_equipment/',
        CreateEquipmentView.as_view(),
        name='create_equipment'
    ),
]   