from datetime import datetime, timedelta
import json
from locations.models import Location
from payments.models import Payment
from sports.models import Sport
from users.models import Instructor, Student, UserAccount
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from .models import Lesson, Pack
from django.utils.timezone import now
from rest_framework import status
from django.shortcuts import get_object_or_404


# TODO change all views to work on specific roles (user.current_role)
# TODO refactor packs data
# on instructor or admin schedule private lesson if the time is unavailable because of his unavailability or pecause its in the past there should be an alert message and an option to override


def get_lessons_data(user, is_done_flag):
    """
    Helper function to get lessons data.
    
    :param user: The current authenticated user.
    :param date_lookup: A dict with the lookup to apply on dates 
                        (e.g. {'date__gte': today} for upcoming lessons)
    :param is_done_flag: Boolean indicating if lessons are completed.
                          Used in the filter for Lesson.
    :return: Combined list of private and group lessons data.
    """
    today = now().date()
    
    if user.current_role == "Parent":
        student_ids = user.students.values_list('id', flat=True)
        lessons = Lesson.objects.filter(
            students__id__in=student_ids,
            is_done=is_done_flag,
            date__isnull=False,
            start_time__isnull=False,
        ).order_by('date', 'start_time').distinct()

    elif user.current_role == "Instructor":
        lessons = Lesson.objects.filter(
            instructors__id__in=[user.instructor_profile.id],
            is_done=is_done_flag,
            date__isnull=False,
            start_time__isnull=False,
        ).order_by('date', 'start_time').distinct()

    elif user.current_role == "Admin":
        if not user.current_school_id:
            lessons = []
        else:
            lessons = Lesson.objects.filter(
                school_id=user.current_school_id,
                is_done=is_done_flag,
                date__isnull=False,
                start_time__isnull=False,
            ).order_by('date', 'start_time').distinct()


    # Process lessons data.
    lessons_data = [
        {
            "lesson_id": lesson.id,
            "date": lesson.date.strftime("%d %b %Y") if lesson.date else "None",
            "start_time": lesson.start_time.strftime("%H:%M") if lesson.start_time else "None",
            "lesson_number": lesson.class_number if lesson.class_number else "None",  # TODO: fix for group lessons
            "number_of_lessons": lesson.packs.all()[0].number_of_classes if lesson.packs.exists() else "None",  # TODO: fix for group lessons
            "students_name": lesson.get_students_name(),
            "type": lesson.type,
            "duration_in_minutes": lesson.duration_in_minutes,
            "expiration_date": lesson.packs.all()[0].expiration_date if lesson.packs.exists() and lesson.packs.all()[0].expiration_date else "None",
            "school": str(lesson.school) if lesson.school else "",
            "subject_id": lesson.sport.id if lesson.sport else "Unknown",
            "subject_name": lesson.sport.name if lesson.sport else "",
            "is_done": lesson.is_done,
            # Added status flag: "Today", "Upcoming", or "Need Reschedule" based on lesson.date.
            "status": (
                "Today" if lesson.date == today else 
                ("Upcoming" if lesson.date > today else "Need Reschedule")
            ) if lesson.date else "Unknown",
        }
        for lesson in lessons
    ]
    return lessons_data


def get_packs_data(user, is_done_flag):
    """
    Helper function to get packs data.
    
    :param user: The current authenticated user.
    :param date_lookup: A dict with the lookup to apply on dates 
                        (e.g. {'date__gte': today} for active lessons)
    :param is_done_flag: Boolean indicating if lessons are completed.
                          Used in the filter for Pack.
    :return: Combined list of private and group packs data.
    """
    
    today = now().date()
    user = user  # Get authenticated user
    current_role = user.current_role

    if current_role == "Parent":
        # Fetch active packs
        student_ids = user.students.values_list('id', flat=True)
        packs = Pack.objects.filter(students__id__in=student_ids,
                                    is_done=is_done_flag,
                                    ).order_by("-date_time").distinct()
    elif current_role == "Instructor":
        packs = Pack.objects.filter(lessons_many__instructors__in=[user.instructor_profile],
                                    is_done=is_done_flag,
                                    ).order_by("-date_time").distinct() # TODO combine those filters with pack.instructors__in=[user.instructor_profile]
    elif current_role == "Admin":
        packs = Pack.objects.filter(school__in=user.school_admins.all(),
                                    is_done=is_done_flag,
                                    ).order_by("-date_time").distinct()
    else:
        packs = []

    packs_data = [
        {
            "pack_id": pack.id,
            "lessons": [
                            {
                                "lesson_id" : str(lesson.id),
                                "lesson_str": str(lesson),
                                "school": str(lesson.school) if lesson.school else "",
                            }
                            for lesson in pack.lessons_many.all()
                        ],
            "lessons_remaining": pack.number_of_classes_left,
            "unscheduled_lessons": pack.get_number_of_unscheduled_lessons(),
            "days_until_expiration": pack.handle_expiration_date(),
            "students_name": pack.get_students_name(),
            "students": [{
                "id" : str(student.id),
                "name": str(student),
            }
            for student in pack.students.all()
            ],
            "type": pack.type,
            "expiration_date": str(pack.expiration_date),
        }
        for pack in packs
    ]
    return packs_data

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def upcoming_lessons(request):
    """
    Return lessons that are upcoming (date >= today) and not completed.
    """
    # For upcoming lessons, filter for date >= today and is_done False.
    lessons_data = get_lessons_data(
        user=request.user,
        is_done_flag=False
    )
    return Response(lessons_data)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def last_lessons(request):
    """
    Return lessons that have already occurred (date <= today) and are completed.
    """
    # For past lessons, filter for date <= today and is_done True.
    lessons_data = get_lessons_data(
        user=request.user,
        is_done_flag=True
    )
    return Response(lessons_data)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def active_packs(request):
    # For upcoming lessons, filter for date >= today and is_done False.
    packs_data = get_packs_data(
        user=request.user,
        is_done_flag=False
    )
    return Response(packs_data)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def last_packs(request):
    # For upcoming lessons, filter for date >= today and is_done False.
    packs_data = get_packs_data(
        user=request.user,
        is_done_flag=True
    )
    return Response(packs_data)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def pack_details(request, id):
    today = now().date()
    user = request.user
    pack = get_object_or_404(Pack, id=id)

    # TODO      students : {
    #               student_id : {
    #                   student_first_name,
    #                   student_last_name,
    #                   parents?
    #               } 
    #           }
    # TODO add parents
    # TODO structure students and instructors better

    data = {
        "pack_id": pack.id,
        "date": pack.date,
        "type": pack.type,
        "number_of_classes": pack.number_of_classes,
        "lessons_remaining": pack.number_of_classes_left,
        "unscheduled_lessons": pack.get_number_of_unscheduled_lessons(),
        "days_until_expiration": (pack.expiration_date - today).days if pack.expiration_date else None,
        "expiration_date": pack.expiration_date,
        "duration_in_minutes": pack.duration_in_minutes,
        "price": str(pack.price),
        "is_done": pack.is_done,
        "is_paid": pack.is_paid,
        "is_suspended": pack.is_suspended,
        "debt": str(pack.debt),
        "lessons": [{
          "lesson_id": lesson.id,
            "date": lesson.date.strftime("%d %b %Y") if lesson.date else "None",
            "start_time": lesson.start_time.strftime("%H:%M") if lesson.start_time else "None",
            "lesson_number": lesson.class_number if lesson.class_number else "None",  # TODO: fix for group lessons
            "number_of_lessons": lesson.packs.all()[0].number_of_classes if lesson.packs.exists() else "None",  # TODO: fix for group lessons
            "students_name": lesson.get_students_name(),
            "type": lesson.type,
            "duration_in_minutes": lesson.duration_in_minutes,
            "expiration_date": lesson.packs.all()[0].expiration_date if lesson.packs.exists() and lesson.packs.all()[0].expiration_date else "None",
            "school": str(lesson.school) if lesson.school else "",
            "subject_id": lesson.sport.id if lesson.sport else "Unknown",  
            "is_done": lesson.is_done,
        } for lesson in pack.lessons_many.all()],
        "students": [{
                        "id" : str(student.id),
                        "name": str(student),
                    }
                    for student in pack.students.all()
                ],
        "parents": [
                        {
                            "id" : str(parent.id),
                            "name": str(parent),
                            "email": parent.email,
                            "country_code" : parent.country_code,
                            "phone" : parent.phone,
                            "students": [{
                                    "id" : str(student.id),
                                    "name": str(student),
                                }
                                for student in parent.students.all()
                            ],
                        }
                        for parent in pack.parents.all()
                    ],
        "students_name": pack.get_students_name(),
        "students_ids": pack.get_students_ids(),
        "instructors_name": pack.get_instructors_name() if pack.instructors.exists() else "",
        "instructors_ids": pack.get_instructors_ids() if pack.instructors.exists() else "",
        "finished_date": pack.finished_date,
        "school_name": str(pack.school) if pack.school else "",
        "school_id": pack.school.id if pack.school else "",
        "subject": pack.sport.name if pack.sport else None,
    }
    return Response(data)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def lesson_details(request, id):
    today = now().date()
    user = request.user
    lesson = get_object_or_404(Lesson, id=id)

    # TODO      students : {
    #               student_id : {
    #                   student_first_name,
    #                   student_last_name,
    #                   parents?
    #               } 
    #           }
    # TODO add parents
    # TODO structure students and instructors better

    data = {
            "lesson_id": lesson.id,
            "date": lesson.date.strftime("%d %b %Y") if lesson.date else "None",
            "start_time": lesson.start_time.strftime("%H:%M") if lesson.start_time else "None",
            "end_time": lesson.end_time.strftime("%H:%M") if lesson.end_time else "None",
            "duration_in_minutes": lesson.duration_in_minutes,
            "lesson_number": lesson.class_number,
            "number_of_lessons": lesson.packs.all()[0].number_of_classes if lesson.packs.exists() else "None",
            "price": lesson.price,
            "is_done": lesson.is_done,
            "extras": lesson.extras,
            "students_name": lesson.get_students_name(),
            "students_ids": lesson.get_students_ids(),
            "type": lesson.type,
            "instructors_name": lesson.get_instructors_name() if lesson.instructors.exists() else "Unknown",
            "instructors_ids": lesson.get_instructors_ids() if lesson.instructors.exists() else "Unknown",
            "location_name": lesson.location.name if lesson.location else "Unknown",
            "location_address": lesson.location.address if lesson.location else "Unknown",
            "location_link": lesson.location.link if lesson.location else "Unknown",
            "minimum_age": lesson.minimum_age,
            "maximum_age": lesson.maximum_age,
            "maximum_number_of_students": lesson.maximum_number_of_students,
            "school_name": str(lesson.school) if lesson.school else "Unknown",
            "school_id": lesson.school.id if lesson.school else "Unknown",
            "pack_id": lesson.packs.all()[0].id if lesson.packs.exists() else "Unknown",
            "subject": lesson.sport.name if lesson.sport else "Unknown",
            "subject_id": lesson.sport.id if lesson.sport else "Unknown",
            "is_done": lesson.is_done,
            "packs" :
                [
                    {
                        "pack_id": pack.id,
                        "lessons": [
                                        {
                                            "lesson_id" : str(lesson.id),
                                            "lesson_str": str(lesson),
                                            "school": str(lesson.school) if lesson.school else "",
                                        }
                                        for lesson in pack.lessons_many.all()
                                    ],
                        "lessons_remaining": pack.number_of_classes_left,
                        "unscheduled_lessons": pack.get_number_of_unscheduled_lessons(),
                        "days_until_expiration": pack.handle_expiration_date(),
                        "students_name": pack.get_students_name(),
                        "parents": [
                            {
                                "id" : str(parent.id),
                                "name": str(parent),
                                "email": parent.email,
                                "country_code" : parent.country_code,
                                "phone" : parent.phone,
                                "students": [{
                                        "id" : str(student.id),
                                        "name": str(student),
                                    }
                                    for student in parent.students.all()
                                ],
                            }
                            for parent in pack.parents.all()
                        ],
                        "students": [{
                            "id" : str(student.id),
                            "name": str(student),
                        }
                        for student in pack.students.all()
                        ],
                        "type": pack.type,
                        "expiration_date": str(pack.expiration_date),
                    }
                    for pack in lesson.packs.all()
                ]    
        }
    return Response(data)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def update_lesson_extras(request):
    # 1) grab lesson_id from the JSON payload
    lesson_id = request.data.get('lesson_id')
    if lesson_id is None:
        return Response(
            {'detail': 'Lesson ID not provided in request body.'},
            status=status.HTTP_400_BAD_REQUEST
        )

    # 2) load your Lesson
    try:
        lesson = Lesson.objects.get(pk=lesson_id)
    except Lesson.DoesNotExist:
        return Response(
            {'detail': f'Lesson with id={lesson_id} not found.'},
            status=status.HTTP_404_NOT_FOUND
        )

    # 3) merge the rest of request.data into the JSONField
    #    remove 'lesson_id' so we only merge the extras
    payload = dict(request.data)
    payload.pop('lesson_id', None)

    current = lesson.extras or {}
    current.update(payload)
    lesson.extras = current
    lesson.save(update_fields=['extras'])

    return Response({'extras': lesson.extras}, status=status.HTTP_200_OK)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def todays_lessons(request):
    """
    Return lessons that have already occurred today
    """

    user = request.user
    current_role = user.current_role
    today = now().date()

    if current_role == "Instructor":

        lessons = list(set(Lesson.objects.filter(
            instructors__in=[user.instructor_profile],
            date=today
        ).order_by('date', 'start_time')))

        # Process private lessons data.
        lessons_data = [
            {
                "lesson_id": lesson.id,
                "start_time": lesson.start_time.strftime("%I:%M %p") if lesson.start_time else "None",
                "lesson_number": lesson.class_number,
                "number_of_lessons": lesson.packs.all()[0].number_of_classes if lesson.packs.exists() else "None",
                "students_name": lesson.get_students_name(),
                "location_name": lesson.location.name if lesson.location else "None",
            }
            for lesson in lessons
        ]
    elif current_role == "Admin":

        lessons = list(set(Lesson.objects.filter(
            school__in=[user.school_admins],
            date=today
        ).order_by('date', 'start_time')))

        # Process private lessons data.
        lessons_data = [
            {
                "lesson_id": lesson.id,
                "start_time": lesson.start_time.strftime("%I:%M %p") if lesson.start_time else "None",
                "instructors_name": lesson.get_instructors_name() if lesson.instructors.exists() else "Unknown",
                "location_name": lesson.location.name if lesson.location else "None",
            }
            for lesson in lessons
        ]
    
    return Response(lessons_data)

def process_lesson_status(request, mark_as_done=True):
    """
    Função auxiliar para marcar uma aula como feita ou não feita.
    """
    user = request.user
    current_role = user.current_role
    lesson_id = request.data.get("lesson_id")
    
    if not lesson_id:
        return Response({"error": "É necessário fornecer lesson_id"}, status=status.HTTP_400_BAD_REQUEST)
    
    try:
        lesson = Lesson.objects.get(id=lesson_id)
    except Lesson.DoesNotExist:
        return Response({"error": "Aula não encontrada."}, status=status.HTTP_404_NOT_FOUND)
    
    if current_role == "Parent":
        return Response({"error": "Não tem permissão para alterar esta aula."}, status=status.HTTP_403_FORBIDDEN)
    
    success = lesson.mark_as_given() if mark_as_done else lesson.mark_as_not_given()
    
    if success:
        return Response({"message": "Aula alterada com sucesso!"}, status=status.HTTP_200_OK)
    else:
        return Response({"error": "Não foi possível alterar a aula."}, status=status.HTTP_400_BAD_REQUEST)



@api_view(['POST'])
@permission_classes([IsAuthenticated])
def available_lesson_times(request):
    """
    Receives a lesson_id and a date (YYYY-MM-DD) and returns a list of available times for the lesson.
    Only works for lessons of type "private".
    """
    lesson_id = request.data.get("lesson_id")
    date_str = request.data.get("date")
    increment = request.data.get("increment")
    
    # Validate required parameters.
    if not lesson_id or not date_str or not increment:
        return Response({"error": "Missing lesson_id or date parameter."}, status=400)
    
    try:
        # Convert the date string to a date object.
        date_obj = datetime.strptime(date_str, "%Y-%m-%d").date()
    except ValueError:
        return Response({"error": "Invalid date format. Expected YYYY-MM-DD."}, status=400)
    
    try:
        lesson = Lesson.objects.get(pk=lesson_id)
    except Lesson.DoesNotExist:
        return Response({"error": "Lesson not found."}, status=404)
    
    # Get available times from the lesson method.
    available_times = lesson.list_available_lesson_times(date_obj, increment)
    
    return Response({"available_times": available_times})

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def can_still_reschedule(request, id):
    try:
        lesson = Lesson.objects.get(pk=id)
    except Lesson.DoesNotExist:
        return Response({"error": "Lesson not found."}, status=404)
    
    # Call the lesson's method which returns a boolean.
    result = lesson.can_still_reschedule(role=request.user.current_role)
    
    # Return the boolean value directly.
    return Response(result, status=200)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def schedule_private_lesson(request):
    """
    Permite aos pais/instrutores reagendarem uma aula privada.
    """
    user = request.user
    current_role = user.current_role
    lesson_id = request.data.get("lesson_id")
    new_date = request.data.get("new_date")  # Formato esperado: 'YYYY-MM-DD'
    new_time = request.data.get("new_time")  # Formato esperado: 'HH:MM'
    """
    {
    "lesson_id": 1,
    "new_date": "2025-02-21",
    "new_time": "16:00"
}

    """
    

    # Validação inicial
    if not lesson_id or not new_date or not new_time:
        return Response({"error": "É necessário fornecer lesson_id, date e time."},
                        status=status.HTTP_400_BAD_REQUEST)

    try:
        lesson = Lesson.objects.get(id=lesson_id)
    except Lesson.DoesNotExist:
        return Response({"error": "Aula não encontrada."}, status=status.HTTP_404_NOT_FOUND)

    # Verifica se o utilizador pode reagendar esta aula (somente pais da pack ou instrutores ou admins)
    if not lesson.packs.all()[0].parents.filter(id=user.id).exists() and not lesson.instructors.filter(user=user).exists():
        return Response({"error": "Não tem permissão para agendar esta aula."},
                        status=status.HTTP_403_FORBIDDEN)

    # Converte strings para objetos `datetime`
    try:
        new_date_obj = datetime.strptime(new_date, "%Y-%m-%d").date()
        new_time_obj = datetime.strptime(new_time, "%H:%M").time()
    except ValueError:
        return Response({"error": "Formato de data ou hora inválido."}, status=status.HTTP_400_BAD_REQUEST)


    # Verifica se ainda é possível reagendar esta aula

    # TODO make aware

    if new_date_obj < now().date():
        return Response({"error": "Não é possível agendar para uma data no passado."},
                        status=status.HTTP_400_BAD_REQUEST)
    
    if current_role == "Parent" and not lesson.can_still_reschedule(current_role):
        return Response({"error": "O período permitido para agendamento já passou."},
                        status=status.HTTP_400_BAD_REQUEST)

    # Tenta reagendar a aula
    reschedule_success = lesson.schedule_lesson(new_date_obj, new_time_obj)

    if reschedule_success:
        return Response({"message": "Aula agendada com sucesso!"}, status=status.HTTP_200_OK)
    else:
        return Response({"error": "Não foi possível agendar. Data e horário não disponíveis."},
                        status=status.HTTP_400_BAD_REQUEST)
        

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def schedule_multiple_lessons(request):
    """
    Simula o agendamento múltiplo de aulas utilizando vários blocos de Data.
    
    Se o campo schedule_flag for verdadeiro, para cada aula o método
    lesson.schedule_lesson(date_obj, time_obj) é chamado para agendar a aula.
    Caso contrário, utiliza-se lesson.is_available para simular a disponibilidade.
    
    O payload de resposta para cada aula inclui:
      - "new_date", "new_time", "weekday"
      - "instructor_ids": lista dos IDs dos instrutores disponíveis (ou o utilizado no agendamento)
      - "instructors_str": lista dos respectivos valores de string
    """
    schedule_flag = request.data.get("schedule_flag", False)
    if isinstance(schedule_flag, str):
        schedule_flag = schedule_flag.lower() in ["true", "1"]

    # Obter os IDs das aulas
    lesson_ids = request.data.get("lesson_ids")
    if not lesson_ids:
        return Response({"error": "É necessário fornecer lesson_ids"}, status=400)
    if isinstance(lesson_ids, str):
        try:
            lesson_ids = json.loads(lesson_ids)
        except Exception:
            return Response({"error": "Formato inválido para lesson_ids"}, status=400)

    # Obter os dados de agendamento (blocos)
    schedule_data = request.data.get("Data")
    if not schedule_data or not isinstance(schedule_data, list) or len(schedule_data) == 0:
        return Response({"error": "É necessário fornecer a chave 'Data' com uma lista de opções."}, status=400)
    
    # Ordena os blocos por from_date (assumindo formato "YYYY-MM-DD")
    try:
        sorted_blocks = sorted(schedule_data, key=lambda b: datetime.strptime(b.get("from_date", ""), "%Y-%m-%d").date())
    except Exception:
        return Response({"error": "Erro ao ordenar os blocos de Data."}, status=400)
    
    # Mapeamento de nomes de dias para números (Monday=0, ..., Sunday=6)
    weekday_map = {
        "monday": 0, "tuesday": 1, "wednesday": 2,
        "thursday": 3, "friday": 4, "saturday": 5, "sunday": 6
    }
    
    def get_date_for_weekday(from_date_str, to_date_str, weekday_str):
        try:
            from_date = datetime.strptime(from_date_str, "%Y-%m-%d").date()
            to_date = datetime.strptime(to_date_str, "%Y-%m-%d").date()
        except ValueError:
            return None
        
        target_weekday = weekday_map.get(weekday_str.lower())
        if target_weekday is None:
            return None
        
        days_ahead = (target_weekday - from_date.weekday() + 7) % 7
        candidate_date = from_date + timedelta(days=days_ahead)
        if candidate_date > to_date:
            return None
        return candidate_date

    # Busca as aulas (na ordem dada)
    lessons = []
    for lesson_id in lesson_ids:
        try:
            lesson = Lesson.objects.get(id=lesson_id)
            lessons.append(lesson)
        except Lesson.DoesNotExist:
            return Response({"error": f"Aula com id {lesson_id} não encontrada."}, status=404)
    
    scheduled_results = {}
    unscheduled_lessons = lessons[:]
    
    for block in sorted_blocks:
        if not unscheduled_lessons:
            break
        block_from = block.get("from_date")
        block_to = block.get("to_date")
        options = block.get("options", [])
        if not block_from or not block_to or not options:
            continue
        
        try:
            block_from_date = datetime.strptime(block_from, "%Y-%m-%d").date()
            block_to_date = datetime.strptime(block_to, "%Y-%m-%d").date()
        except ValueError:
            continue
        
        block_options = []
        for option in options:
            weekday_str = option.get("weekday")
            time_str = option.get("time")
            if not weekday_str or not time_str:
                continue
            base_date = get_date_for_weekday(block_from, block_to, weekday_str)
            if base_date:
                block_options.append((base_date, time_str))
        if not block_options:
            continue
        
        sorted_options = sorted(block_options, key=lambda x: x[0])
        num_options = len(sorted_options)
        
        scheduled_this_block = []
        for j, lesson in enumerate(unscheduled_lessons):
            option_index = j % num_options
            cycle_count = j // num_options
            base_date, time_str = sorted_options[option_index]
            candidate_date = base_date + timedelta(days=7 * cycle_count)
            if candidate_date > block_to_date:
                break
            try:
                candidate_time = datetime.strptime(time_str, "%H:%M").time()
            except ValueError:
                continue
            
            available_instructors = []
            if schedule_flag:
                # Actually schedule the lesson.
                scheduled_success = lesson.schedule_lesson(candidate_date, candidate_time)
                if not scheduled_success:
                    continue
                # Use a default instructor (e.g., the first one) if available.
                if lesson.instructors.exists():
                    available_instructors = [lesson.instructors.first()]
                else:
                    available_instructors = []
            else:
                if lesson.instructors.exists():
                    for instructor in lesson.instructors.all():
                        available, ret_instructor = lesson.is_available(
                            date=candidate_date,
                            start_time=candidate_time,
                            instructor=instructor
                        )
                        if available:
                            available_instructors.append(ret_instructor)
                    if not available_instructors:
                        continue
                else:
                    available, ret_instructor = lesson.is_available(
                        date=candidate_date,
                        start_time=candidate_time,
                        instructor=None
                    )
                    if available:
                        available_instructors = [ret_instructor]
                    else:
                        continue
            
            weekday_out = candidate_date.strftime("%A")
            old_date_str = lesson.date.strftime("%Y-%m-%d") if lesson.date else ""
            old_time_str = lesson.start_time.strftime("%H:%M") if lesson.start_time else ""
            lesson_str = f"{lesson.get_students_name()} lesson number {lesson.class_number}/{lesson.packs.all()[0].number_of_classes if lesson.packs.exists() else 'None'}"
            scheduled_results[lesson.id] = {
                "lesson_id": str(lesson.id),
                "lesson_str": lesson_str,
                "new_date": candidate_date.strftime("%Y-%m-%d"),
                "new_time": candidate_time.strftime("%H:%M"),
                "old_date": old_date_str,
                "old_time": old_time_str,
                "weekday": weekday_out,
                "instructor_ids": [str(instr.id) for instr in available_instructors],
                "instructors_str": [str(instr) for instr in available_instructors]
            }
            scheduled_this_block.append(lesson)
        
        unscheduled_lessons = [l for l in unscheduled_lessons if l not in scheduled_this_block]
    
    for lesson in unscheduled_lessons:
        old_date_str = lesson.date.strftime("%Y-%m-%d") if lesson.date else ""
        old_time_str = lesson.start_time.strftime("%H:%M") if lesson.start_time else ""
        lesson_str = f"{lesson.get_students_name()} lesson number {lesson.class_number}/{lesson.packs.all()[0].number_of_classes if lesson.packs.exists() else 'None'}"
        scheduled_results[lesson.id] = {
            "lesson_id": str(lesson.id),
            "lesson_str": lesson_str,
            "new_date": "",
            "new_time": "",
            "old_date": old_date_str,
            "old_time": old_time_str,
            "weekday": "",
            "instructor_ids": [],
            "instructors_str": []
        }
    
    final_results = []
    for lesson in lessons:
        final_results.append(scheduled_results.get(lesson.id))
    
    return Response(final_results, status=200)

# (lessons)
# update extras - the user is able to book equipment or extra students for that specific lesson
# edit date - the user is able to edit the date, first it will just check if it can, if so then change successefully, if not then send an override confirmation with details, if the user accepts the override then the date is changed
# edit time - the user is able to edit the time, first it will just check if it can, if so then change successefully, if not then send an override confirmation with details, if the user accepts the override then the time is changed
# toggle completition - marks the lesson or pack as was_done() or was_undone() based on the is_done attribute
# edit subject - adds or removes the subjects based on the available Sport, on the frontend the user will see a list of all the available sports and an option to create a new subject, if this option is selected then create a Sport with that name and associate it with the lesson and school
# edit students - adds or removes the students based on the available students, the user can search through all the Student by first name, last name or id and there will be an option to create a new student, if this option is selected then create a Student with first name, last_name, birthday and associate parentes, add the student to the lesson and school
# edit instructors - adds or removes the instructors based on the available instructors, the user can search through all the Instructor by first name, last name or id and there will be an option to create a new instructor, if this option is selected and a user_id is provided then create an Instructor and associate the user to instructor.user, add the instructor to the lesson and school
# edit location - adds or removes the location based on the available Location, on the frontend the user will see a list of all the available locations and an option to create a new location, if this option is selected then create a Location with that name and address and associate it with the lesson and school
# 
# (packs)
# add payment - adds a payment and specifies who was the user that payed if a user_id is provided, if not there will be a description, a Payment object will be created and we will update_debt with the value, the payment should be associated with the school and pack
# pay debt - adds a payment and specifies who was the user that payed, a Payment object will be created and we will update_debt with the value, the payment should be associated with the school and pack and user 
# edit students - adds or removes the students based on the available students, the user can search through all the Student by first name, last name or id and there will be an option to create a new student, if this option is selected then create a Student with first name, last_name, birthday and associate parentes, add the student to the pack, pack.lessons and school
# edit instructors - adds or removes the instructors based on the available instructors, the user can search through all the Instructor by first name, last name or id and there will be an option to create a new instructor, if this option is selected and a user_id is provided then create an Instructor and associate the user to instructor.user, add the instructor to the pack, pack.lessons and school
# edit subject - adds or removes the students based on the available students, the user can search through all the Student by first name, last name or id and there will be an option to create a new student, if this option is selected then create a Student with first name, last_name, birthday and associate parentes, add the student to the pack, pack.lessons and school
#
# (stats) TODO
# view lessons in timeframe
# view students in timeframe
# view instructors in timeframe
# view payments in timeframe

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def toggle_lesson_completion(request):
    """
    Toggle the completion status of a lesson.
    Calls lesson.was_done() or lesson.was_undone() based on current status.
    """
    lesson_id = request.data.get("lesson_id")
    today = now().date()
    if not lesson_id:
        return Response({"error": "É necessário fornecer lesson_id"}, status=400)
    lesson = get_object_or_404(Lesson, id=lesson_id)
    if lesson.is_done:
        lesson.mark_as_not_given()
        status_msg = "marked as undone"
    else:
        if today < lesson.date:
            return Response({"error": "A data da aula é superior á data de hoje"}, status=400)
        lesson.mark_as_given()  
        status_msg = "marked as done"
    lesson.save()
    return Response({"status": status_msg}, status=status.HTTP_200_OK)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def edit_subject(request):
    """
    Edit the subject associated with a lesson or a pack.
    For adding: send action 'add' with either a subject_id or new_subject name.
    For changing: send action 'change' with subject_id.
    When a pack_id is provided:
      - if pack.type == "private": update the subject for all lessons in the pack.
      - otherwise, update only the pack.subject.
    """
    subject_id = request.data.get("subject_id")
    if not subject_id:
        return Response({"error": "subject_id is required"}, status=400)
    action = request.data.get('action')
    # If pack_id is provided, update the pack and possibly its lessons.
    if request.data.get("pack_id"):
        pack_id = request.data.get("pack_id")
        pack = get_object_or_404(Pack, id=pack_id)
        if action == 'add':
            subject = Sport.objects.create(name=subject_id)
            if pack.type == 'private':
                lessons = pack.lessons_many.all()
                for lesson in lessons:
                    lesson.sport = subject
                    lesson.save()
            pack.sport = subject
            pack.school.sports.add(subject)
            pack.save()
            pack.school.save()
            status_msg = f"subject created: {subject.name}"
        elif action == 'change':
            subject = get_object_or_404(Sport, id=subject_id)
            if pack.type == 'private':
                lessons = pack.lessons_many.all()
                for lesson in lessons:
                    lesson.sport = subject
                    lesson.save()
            pack.sport = subject
            pack.save()
            status_msg = f"subject changed to {subject.name}"
        else:
            return Response({"error": "Invalid action"}, status=status.HTTP_400_BAD_REQUEST)
        return Response({"status": status_msg}, status=status.HTTP_200_OK)
    else:
        # Fallback to lesson update.
        lesson_id = request.data.get("lesson_id")
        if not lesson_id:
            return Response({"error": "lesson_id is required"}, status=400)
        lesson = get_object_or_404(Lesson, id=lesson_id)
        if action == 'add':
            subject = Sport.objects.create(name=subject_id)
            lesson.sport = subject
            lesson.school.sports.add(subject)
            status_msg = f"subject created: {subject.name}"
        elif action == 'change':
            subject = get_object_or_404(Sport, id=subject_id)
            lesson.sport = subject
            status_msg = f"subject changed to {subject.name}"
        else:
            return Response({"error": "Invalid action"}, status=status.HTTP_400_BAD_REQUEST)
        lesson.save()
        return Response({"status": status_msg}, status=status.HTTP_200_OK)

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def edit_students(request):
    """
    Edit the students for a lesson or a pack.
    For adding: send action 'add' with either student_id or new_student data.
    For removing: send action 'remove' with student_id.
    When a pack_id is provided:
      - Add or remove the student from the pack.
      - If pack.type == "private", apply the change to every lesson in the pack.
    """
    action = request.data.get('action')
    # If pack_id provided, update pack students.
    if request.data.get("pack_id"):
        pack_id = request.data.get("pack_id")
        pack = get_object_or_404(Pack, id=pack_id)
        if action == 'add':
            new_student = request.data.get('new_student')
            if new_student:
                first_name = request.data.get('first_name')
                last_name = request.data.get('last_name')
                birthday_str = request.data.get('birthday')
                if not all([first_name, last_name, birthday_str]):
                    return Response({'error': 'Missing required fields.'}, status=400)
                try:
                    birthday_date = datetime.strptime(birthday_str, '%Y-%m-%d').date()
                except ValueError:
                    return Response({'error': 'Birthday must be in YYYY-MM-DD format.'}, status=400)
                student = Student.objects.create(
                    first_name=first_name,
                    last_name=last_name,
                    birthday=birthday_date,
                    level=1
                )
                pack.school.students.add(student)
                pack.school.save()
            else:
                student_id = request.data.get('student_id')
                student = get_object_or_404(Student, id=student_id)
            pack.students.add(student)
            
            if pack.type == 'private':
                lessons = pack.lessons_many.all()
                for lesson in lessons:
                    lesson.students.add(student)
                    lesson.save()
            pack.save()
            status_msg = "student added"
        elif action == 'remove':
            student_id = request.data.get('student_id')
            student = get_object_or_404(Student, id=student_id)
            pack.students.remove(student)
            if pack.type == 'private':
                lessons = pack.lessons_many.all()
                for lesson in lessons:
                    lesson.students.remove(student)
                    lesson.save()
            pack.save()
            status_msg = "student removed"
        else:
            return Response({"error": "Invalid action"}, status=400)
        return Response({"status": status_msg}, status=200)
    else:
        # Fallback to lesson update.
        lesson_id = request.data.get("lesson_id")
        if not lesson_id:
            return Response({"error": "lesson_id is required"}, status=400)
        lesson = get_object_or_404(Lesson, id=lesson_id)
        if action == 'add':
            new_student = request.data.get('new_student')
            if new_student:
                first_name = request.data.get('first_name')
                last_name = request.data.get('last_name')
                birthday_str = request.data.get('birthday')
                if not all([first_name, last_name, birthday_str]):
                    return Response({'error': 'Missing required fields.'}, status=400)
                try:
                    birthday_date = datetime.strptime(birthday_str, '%Y-%m-%d').date()
                except ValueError:
                    return Response({'error': 'Birthday must be in YYYY-MM-DD format.'}, status=400)
                student = Student.objects.create(
                    first_name=first_name,
                    last_name=last_name,
                    birthday=birthday_date,
                    level=1
                )
            else:
                student_id = request.data.get('student_id')
                student = get_object_or_404(Student, id=student_id)
            lesson.students.add(student)
            lesson.school.students.add(student)
            status_msg = "student added"
        elif action == 'remove':
            student_id = request.data.get('student_id')
            student = get_object_or_404(Student, id=student_id)
            lesson.students.remove(student)
            status_msg = "student removed"
        else:
            return Response({"error": "Invalid action"}, status=400)
        lesson.save()
        return Response({"status": status_msg}, status=200)

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def edit_instructors(request):
    """
    Edit the instructors for a lesson or a pack.
    For adding: send action 'add' with either instructor_id or new_instructor data.
    For removing: send action 'remove' with instructor_id.
    When a pack_id is provided:
      - Update the instructors on the pack.
      - If pack.type == "private", update the instructors for every lesson in the pack.
    """
    action = request.data.get('action')
    if request.data.get("pack_id"):
        pack_id = request.data.get("pack_id")
        pack = get_object_or_404(Pack, id=pack_id)
        if action == 'add':
            new_instructor = request.data.get('new_instructor')
            if new_instructor:
                user_id = request.data.get('user_id')
                if not user_id:
                    return Response({"error": "user_id is required"}, status=400)
                user = get_object_or_404(UserAccount, id=user_id)
                instructor = Instructor.objects.create(user=user)
                pack.school.instructors.add(instructor)
                pack.school.save()
            else:
                instructor_id = request.data.get('instructor_id')
                instructor = get_object_or_404(Instructor, id=instructor_id)
            pack.instructors.add(instructor)
            
            if pack.type == 'private':
                lessons = pack.lessons_many.all()
                for lesson in lessons:
                    lesson.instructors.add(instructor)
                    lesson.save()
            pack.save()
            status_msg = "instructor added"
        elif action == 'remove':
            instructor_id = request.data.get('instructor_id')
            instructor = get_object_or_404(Instructor, id=instructor_id)
            pack.instructors.remove(instructor)
            if pack.type == 'private':
                lessons = pack.lessons_many.all()
                for lesson in lessons:
                    lesson.instructors.remove(instructor)
                    lesson.save()
            pack.save()
            status_msg = "instructor removed"
        else:
            return Response({"error": "Invalid action"}, status=400)
        return Response({"status": status_msg}, status=200)
    else:
        lesson_id = request.data.get("lesson_id")
        if not lesson_id:
            return Response({"error": "lesson_id is required"}, status=400)
        lesson = get_object_or_404(Lesson, id=lesson_id)
        if action == 'add':
            instructor_id = request.data.get('instructor_id')
            instructor = get_object_or_404(Instructor, id=instructor_id)
            lesson.instructors.add(instructor)
            lesson.school.add_instructor(instructor)
            status_msg = "instructor added"
        elif action == 'remove':
            instructor_id = request.data.get('instructor_id')
            instructor = get_object_or_404(Instructor, id=instructor_id)
            lesson.instructors.remove(instructor)
            status_msg = "instructor removed"
        else:
            return Response({"error": "Invalid action"}, status=400)
        lesson.save()
        return Response({"status": status_msg}, status=200)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def edit_location(request):
    """
    Edit the location for a lesson or a pack.
    For setting: send action 'add' with either location_id or new location data.
    For changing: send action 'change' with location_id.
    When a pack_id is provided:
      - Update the pack’s location.
      - If pack.type == "private", update the location for every lesson in the pack.
    """
    action = request.data.get('action')
    if request.data.get("pack_id"):
        pack_id = request.data.get("pack_id")
        pack = get_object_or_404(Pack, id=pack_id)
        if action == 'add':
            location_name = request.data.get("location_name")
            location_address = request.data.get("location_address")
            if not location_name:
                return Response({"error": "location_name is required"}, status=400)
            if not location_address:
                return Response({"error": "location_address is required"}, status=400)
            location = Location.objects.create(name=location_name, address=location_address)
            # Assume pack has a locations relation and a primary location field.
            pack.locations.add(location)
            pack.school.locations.add(location)
            if pack.type == 'private':
                lessons = pack.lessons_many.all()
                for lesson in lessons:
                    lesson.location = location
                    lesson.save()
            pack.location = location
            pack.save()
            pack.school.save()
            status_msg = "location set"
        elif action == 'change':
            location_id = request.data.get("location_id")
            if not location_id:
                return Response({"error": "location_id is required"}, status=400)
            location = get_object_or_404(Location, id=location_id)
            if pack.type == 'private':
                lessons = pack.lessons_many.all()
                for lesson in lessons:
                    lesson.location = location
                    lesson.save()
            pack.location = location
            pack.save()
            status_msg = "location changed"
        else:
            return Response({"error": "Invalid action"}, status=400)
        return Response({"status": status_msg}, status=200)
    else:
        lesson_id = request.data.get("lesson_id")
        if not lesson_id:
            return Response({"error": "lesson_id is required"}, status=400)
        lesson = get_object_or_404(Lesson, id=lesson_id)
        if action == 'add':
            location_name = request.data.get("location_name")
            location_address = request.data.get("location_address")
            if not location_name:
                return Response({"error": "location_name is required"}, status=400)
            if not location_address:
                return Response({"error": "location_address is required"}, status=400)
            location = Location.objects.create(name=location_name, address=location_address)
            lesson.school.locations.add(location)
            lesson.location = location
            status_msg = "location set"
        elif action == 'change':
            location_id = request.data.get("location_id")
            if not location_id:
                return Response({"error": "location_id is required"}, status=400)
            location = get_object_or_404(Location, id=location_id)
            lesson.location = location
            status_msg = "location changed"
        else:
            return Response({"error": "Invalid action"}, status=400)
        lesson.save()
        return Response({"status": status_msg}, status=200)

# ------------------------------
# PACK VIEWS
# ------------------------------

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def add_pack_payment(request):
    # TODO all
    """
    Add a payment for a pack.
    If a user_id is provided, the payment is associated with that user.
    Otherwise, a description should be provided.
    """
    pack_id = request.data.get("pack_id")
    if not pack_id:
        return Response({"error": "É necessário fornecer pack_id"}, status=400)
    pack = get_object_or_404(Pack, id=pack_id)
    amount = request.data.get('amount')
    user_id = request.data.get('user_id')
    description = request.data.get('description', '')
    
    payment = Payment.objects.create(
        amount=amount,
        user_id=user_id if user_id else None,
        description=description,
        school=pack.school,
        pack=pack
    )
    pack.update_debt(amount)  # Ensure you implement this method in your Pack model.
    return Response({"status": "payment added", "payment_id": payment.id}, status=status.HTTP_200_OK)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def pay_pack_debt(request):
    # TODO all
    """
    Pay debt for a pack.
    A user_id is required. A Payment is created and debt is updated.
    """
    pack_id = request.data.get("pack_id")
    if not pack_id:
        return Response({"error": "É necessário fornecer pack_id"}, status=400)
    pack = get_object_or_404(Pack, id=pack_id)
    amount = request.data.get('amount')
    user_id = request.data.get('user_id')
    if not user_id:
        return Response({"error": "user_id required"}, status=status.HTTP_400_BAD_REQUEST)
    
    payment = Payment.objects.create(
        amount=amount,
        user_id=user_id,
        school=pack.school,
        pack=pack
    )
    pack.update_debt(amount)
    return Response({"status": "debt payment added", "payment_id": payment.id}, status=status.HTTP_200_OK)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def edit_pack_students(request):
    # TODO all
    """
    Edit the students for a pack.
    For adding: send action 'add' with either student_id or new_student data.
    The student is added to the pack, all lessons in the pack, and the school.
    For removing: send action 'remove' with student_id.
    """
    pack_id = request.data.get("pack_id")
    if not pack_id:
        return Response({"error": "É necessário fornecer pack_id"}, status=400)
    pack = get_object_or_404(Pack, id=pack_id)
    action = request.data.get('action')
    
    if action == 'add':
        new_student = request.data.get('new_student')
        if new_student:
            student = Student.objects.create(**new_student)
        else:
            student_id = request.data.get('student_id')
            student = get_object_or_404(Student, id=student_id)
        pack.students.add(student)
        # Also add the student to every lesson in the pack.
        for lesson in pack.lessons_many.all():
            lesson.students.add(student)
        pack.school.students.add(student)
        status_msg = "student added"
        
    elif action == 'remove':
        student_id = request.data.get('student_id')
        student = get_object_or_404(Student, id=student_id)
        pack.students.remove(student)
        for lesson in pack.lessons_many.all():
            lesson.students.remove(student)
        status_msg = "student removed"
    else:
        return Response({"error": "Invalid action"}, status=status.HTTP_400_BAD_REQUEST)
    
    pack.save()
    return Response({"status": status_msg}, status=status.HTTP_200_OK)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def edit_pack_instructors(request):
    # TODO all
    """
    Edit the instructors for a pack.
    For adding: send action 'add' with either instructor_id or new_instructor data.
    The instructor is added to the pack, all lessons in the pack, and the school.
    For removing: send action 'remove' with instructor_id.
    """
    pack_id = request.data.get("pack_id")
    if not pack_id:
        return Response({"error": "É necessário fornecer pack_id"}, status=400)
    pack = get_object_or_404(Pack, id=pack_id)
    action = request.data.get('action')
    
    if action == 'add':
        new_instructor = request.data.get('new_instructor')
        if new_instructor:
            instructor = Instructor.objects.create(**new_instructor)
        else:
            instructor_id = request.data.get('instructor_id')
            instructor = get_object_or_404(Instructor, id=instructor_id)
        pack.instructors.add(instructor)
        for lesson in pack.lessons_many.all():
            lesson.instructors.add(instructor)
        pack.school.instructors.add(instructor)
        status_msg = "instructor added"
        
    elif action == 'remove':
        instructor_id = request.data.get('instructor_id')
        instructor = get_object_or_404(Instructor, id=instructor_id)
        pack.instructors.remove(instructor)
        for lesson in pack.lessons_many.all():
            lesson.instructors.remove(instructor)
        status_msg = "instructor removed"
    else:
        return Response({"error": "Invalid action"}, status=status.HTTP_400_BAD_REQUEST)
    
    pack.save()
    return Response({"status": status_msg}, status=status.HTTP_200_OK)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def edit_pack_subject(request):
    # TODO all
    """
    Edit the subject(s) for a pack.
    For adding: send action 'add' with either subject_id or new_subject.
    The subject (Sport) is added to the pack and all lessons in the pack.
    For removing: send action 'remove' with subject_id.
    """
    pack_id = request.data.get("pack_id")
    if not pack_id:
        return Response({"error": "É necessário fornecer pack_id"}, status=400)
    pack = get_object_or_404(Pack, id=pack_id)
    action = request.data.get('action')
    
    if action == 'add':
        new_subject = request.data.get('new_subject')
        if new_subject:
            sport = Sport.objects.create(name=new_subject, school=pack.school)
        else:
            subject_id = request.data.get('subject_id')
            sport = get_object_or_404(Sport, id=subject_id, school=pack.school)
        pack.subjects.add(sport)
        for lesson in pack.lessons_many.all():
            lesson.subjects.add(sport)
        status_msg = "subject added"
        
    elif action == 'remove':
        subject_id = request.data.get('subject_id')
        sport = get_object_or_404(Sport, id=subject_id, school=pack.school)
        pack.subjects.remove(sport)
        for lesson in pack.lessons_many.all():
            lesson.subjects.remove(sport)
        status_msg = "subject removed"
    else:
        return Response({"error": "Invalid action"}, status=status.HTTP_400_BAD_REQUEST)
    
    pack.save()
    return Response({"status": status_msg}, status=status.HTTP_200_OK)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def unschedulable_lessons(request):
    user = request.user
    current_role = user.current_role
    lesson_ids = []
    
    if current_role == "Parent":
        schools = user.schools.all()
        # Query lessons that are not done, that belong to any of the user's students,
        # and that are in one of the user's schools.
        lessons = Lesson.objects.filter(
            is_done=False,
            students__in=user.students.all(),
            school__in=schools
        ).distinct()
        
        # Check each lesson whether it can be rescheduled.
        # Since the view is for lessons that are unable to be rescheduled,
        # we add the lesson's ID if it *cannot* be rescheduled.
        for lesson in lessons:
            if not lesson.can_still_reschedule(current_role):
                lesson_ids.append(str(lesson.id))
           
    data = {
        "lesson_ids": lesson_ids,
    }
    return Response(data)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_group_packs_from_a_lesson(request):
    # Expect a query parameter "lesson_id"
    lesson_id = request.query_params.get("lesson_id")
    today = now().date()
    if not lesson_id:
        return Response({"error": "Missing 'lesson_id' parameter."}, status=status.HTTP_400_BAD_REQUEST)
    
    lesson = get_object_or_404(Lesson, id=lesson_id)
    
    # Ensure the lesson is a group lesson.
    if lesson.type != "group":
        return Response({"error": "The lesson is not of type 'group'."}, status=status.HTTP_400_BAD_REQUEST)

    # Build response data.
    packs_data = [
        {
            "pack_id": pack.id,
        "date": pack.date,
        "type": pack.type,
        "number_of_classes": pack.number_of_classes,
        "lessons_remaining": pack.number_of_classes_left,
        "unscheduled_lessons": pack.get_number_of_unscheduled_lessons(),
        "days_until_expiration": (pack.expiration_date - today).days if pack.expiration_date else None,
        "expiration_date": pack.expiration_date,
        "duration_in_minutes": pack.duration_in_minutes,
        "price": str(pack.price),
        "is_done": pack.is_done,
        "is_paid": pack.is_paid,
        "is_suspended": pack.is_suspended,
        "debt": str(pack.debt),
        "lessons": [{
          "lesson_id": lesson.id,
            "date": lesson.date.strftime("%d %b %Y") if lesson.date else "None",
            "start_time": lesson.start_time.strftime("%H:%M") if lesson.start_time else "None",
            "lesson_number": lesson.class_number if lesson.class_number else "None",  # TODO: fix for group lessons
            "number_of_lessons": lesson.packs.all()[0].number_of_classes if lesson.packs.exists() else "None",  # TODO: fix for group lessons
            "students_name": lesson.get_students_name(),
            "type": lesson.type,
            "duration_in_minutes": lesson.duration_in_minutes,
            "expiration_date": lesson.packs.all()[0].expiration_date if lesson.packs.exists() and lesson.packs.all()[0].expiration_date else "None",
            "school": str(lesson.school) if lesson.school else "",
            "subject_id": lesson.sport.id if lesson.sport else "Unknown",  
            "is_done": lesson.is_done,
        } for lesson in pack.lessons_many.all()],
        "students": [{
                        "id" : str(student.id),
                        "name": str(student),
                    }
                    for student in pack.students.all()
                ],
        "parents": [
                        {
                            "id" : str(parent.id),
                            "name": str(parent),
                            "email": parent.email,
                            "country_code" : parent.country_code,
                            "phone" : parent.phone,
                        }
                        for parent in pack.parents.all()
                    ],
        "students_name": pack.get_students_name(),
        "students_ids": pack.get_students_ids(),
        "instructors_name": pack.get_instructors_name() if pack.instructors.exists() else "",
        "instructors_ids": pack.get_instructors_ids() if pack.instructors.exists() else "",
        "finished_date": pack.finished_date,
        "school_name": str(pack.school) if pack.school else "",
        "school_id": pack.school.id if pack.school else "",
        "subject": pack.sport.name if pack.sport else None,
        }
        for pack in lesson.packs.all()
    ]
    
    return Response({"packs": packs_data}, status=status.HTTP_200_OK)

