from django.urls import path
from .views import add_pack_payment, edit_instructors, edit_location, edit_students, edit_subject, get_group_packs_from_a_lesson, unschedulable_lessons, last_packs, pay_pack_debt, toggle_lesson_completion, upcoming_lessons, last_lessons, schedule_private_lesson, active_packs, pack_details, lesson_details, todays_lessons, available_lesson_times, can_still_reschedule, schedule_multiple_lessons, update_lesson_extras

urlpatterns = [
    path('upcoming_lessons/', upcoming_lessons, name='upcoming_lessons'),
    path('last_lessons/', last_lessons, name='last_lessons'),
    path('schedule_private_lesson/', schedule_private_lesson, name='schedule_private_lesson'),
    path('schedule_multiple_lessons/', schedule_multiple_lessons, name='schedule_multiple_lessons'),
    path('active_packs/', active_packs, name='active_packs'),
    path('last_packs/', last_packs, name='last_packs'),
    path('pack_details/<int:id>/', pack_details, name='pack_details'),
    path('lesson_details/<int:id>/', lesson_details, name='lesson_details'),
    path('todays_lessons/', todays_lessons, name='todays_lessons'),
    path("available_lesson_times/", available_lesson_times, name="available_lesson_times"),
    path("can_still_reschedule/<int:id>/", can_still_reschedule, name="can_still_reschedule"),
    path('update_lesson_extras/', update_lesson_extras, name='update_lesson_extras'),
    path('toggle_lesson_completion/', toggle_lesson_completion, name='toggle_lesson_completion'),
    path('edit_subject/', edit_subject, name='edit_subject'),
    path('edit_students/', edit_students, name='edit_students'),
    path('edit_instructors/', edit_instructors, name='edit_instructors'),
    path('edit_location/', edit_location, name='edit_location'),
    path('add_pack_payment/', add_pack_payment, name='add_pack_payment'),
    path('pay_pack_debt/', pay_pack_debt, name='pay_pack_debt'),
    path('unschedulable_lessons/', unschedulable_lessons, name='unschedulable_lessons'),
    path('get_group_packs_from_a_lesson/', get_group_packs_from_a_lesson, name='get_group_packs_from_a_lesson'),
    path('extras/',
        update_lesson_extras,
        name='update-lesson-extras'
    ),
]
