// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Клиника';

  @override
  String get chooseClinic => 'Выберите вашу клинику';

  @override
  String get chooseSubtitle =>
      'Медицина, которой можно доверять. Найдите место, где позаботятся о вас.';

  @override
  String get clinicSelect => 'Выбрать клинику';

  @override
  String get ourClinics => 'НАШИ КЛИНИКИ';

  @override
  String get switchClinic => 'Сменить клинику';

  @override
  String get clinicIllustration => 'Иллюстрация медицинского центра';

  @override
  String get demoContent => 'Демонстрационная клиника';

  @override
  String get home => 'Главная';

  @override
  String get doctors => 'Врачи';

  @override
  String get specialties => 'Специальности';

  @override
  String get appointments => 'Записи';

  @override
  String get profile => 'Профиль';

  @override
  String get settings => 'Настройки';

  @override
  String get language => 'Язык приложения';

  @override
  String get russian => 'Русский';

  @override
  String get english => 'Английский';

  @override
  String get retry => 'Попробовать снова';

  @override
  String get loading => 'Загрузка…';

  @override
  String get noClinics => 'Пока нет доступных клиник';

  @override
  String get noDoctors => 'Врачи пока не добавлены';

  @override
  String get noSpecialties => 'Специальности пока не добавлены';

  @override
  String get noAppointments => 'Ваши записи появятся здесь';

  @override
  String get noAppointmentsBody => 'В этой клинике у вас пока нет записей.';

  @override
  String get login => 'Войти по номеру телефона';

  @override
  String get loginSubtitle =>
      'Ваши записи и личная информация — всегда под рукой.';

  @override
  String get phone => 'Номер телефона';

  @override
  String get countryCode => 'Код страны';

  @override
  String get phoneHint => '999 123 45 67';

  @override
  String get sendCode => 'Получить код';

  @override
  String get phoneInvalid => 'Введите корректный международный номер';

  @override
  String get otpTitle => 'Подтвердите номер';

  @override
  String get otpSubtitle => 'Введите код из SMS, отправленный на';

  @override
  String get otpCode => 'Код из SMS';

  @override
  String get otpInvalidInput => 'Введите код из 6 цифр';

  @override
  String get verify => 'Подтвердить';

  @override
  String get resend => 'Отправить код повторно';

  @override
  String get resendIn => 'Повторная отправка через';

  @override
  String get seconds => 'с';

  @override
  String get changePhone => 'Изменить номер';

  @override
  String get completeProfile => 'Давайте познакомимся';

  @override
  String get completeSubtitle =>
      'Как к вам обращаться? Укажите имя для ваших будущих записей.';

  @override
  String get fullName => 'Имя и фамилия';

  @override
  String get nameInvalid => 'Укажите имя, от 2 до 120 символов';

  @override
  String get email => 'Email (необязательно)';

  @override
  String get emailInvalid => 'Введите корректный email';

  @override
  String get save => 'Сохранить';

  @override
  String get logout => 'Выйти из аккаунта';

  @override
  String get logoutTitle => 'Выйти из аккаунта?';

  @override
  String get logoutBody =>
      'Для доступа к вашим записям потребуется войти снова.';

  @override
  String get cancel => 'Отмена';

  @override
  String get welcome => 'Забота о вашем здоровье';

  @override
  String get welcomeSubtitle =>
      'Найдите своего врача и узнайте больше о клинике.';

  @override
  String get clinicInformation => 'О клинике';

  @override
  String get contact => 'Контакты';

  @override
  String get workingHours => 'Часы работы';

  @override
  String get timezone => 'Часовой пояс';

  @override
  String get weekdays => 'Будние дни';

  @override
  String get browseDoctors => 'Найти врача';

  @override
  String get exploreSpecialties => 'Медицинские направления';

  @override
  String get personalCare => 'ВАШЕ ЗДОРОВЬЕ В НАДЁЖНЫХ РУКАХ';

  @override
  String get signInRequired => 'Войдите, чтобы видеть ваши записи';

  @override
  String get signInProfile => 'Ваш личный кабинет';

  @override
  String get signInProfileBody =>
      'Войдите, чтобы управлять профилем и просматривать записи.';

  @override
  String get developmentTitle => 'Режим разработки · SMS не настроен';

  @override
  String get developmentBody =>
      'Доступен только просмотр клиник. Проверка кода и создание сессии отключены.';

  @override
  String get browseGuest => 'Продолжить без входа';

  @override
  String get authUnavailable =>
      'Вход временно недоступен. Обратитесь в клинику.';

  @override
  String get networkError =>
      'Нет соединения. Проверьте интернет и попробуйте снова.';

  @override
  String get timeoutError =>
      'Ответ занимает больше времени, чем обычно. Попробуйте снова.';

  @override
  String get sessionError => 'Сессия истекла. Войдите снова.';

  @override
  String get forbiddenError => 'У вас нет доступа к этой информации.';

  @override
  String get validationError => 'Проверьте введённые данные.';

  @override
  String get serverError => 'Сервис временно недоступен. Попробуйте позже.';

  @override
  String get notFoundError => 'Информация больше недоступна.';

  @override
  String get conflictError => 'Это время уже занято. Выберите другое.';

  @override
  String get responseError =>
      'Не удалось загрузить информацию. Попробуйте снова.';

  @override
  String get otpExpiredError =>
      'Код истёк или недействителен. Запросите новый код.';

  @override
  String get otpInvalidError =>
      'Неверный код. Проверьте SMS и попробуйте снова.';

  @override
  String get rateLimitError =>
      'Слишком много попыток. Подождите и попробуйте снова.';

  @override
  String get storageError => 'Не удалось сохранить настройки на устройстве.';

  @override
  String get unknownError => 'Что-то пошло не так. Попробуйте снова.';

  @override
  String get profileRetry => 'Не удалось загрузить ваш профиль';

  @override
  String get bookLater =>
      'Онлайн-запись появится на следующем этапе. Пока вы можете связаться с клиникой.';

  @override
  String get pending => 'Ожидает подтверждения';

  @override
  String get confirmed => 'Подтверждена';

  @override
  String get completed => 'Завершена';

  @override
  String get cancelled => 'Отменена';

  @override
  String get noShow => 'Не состоялась';

  @override
  String get back => 'Назад';

  @override
  String get healthCare => 'Медицинская помощь рядом';

  @override
  String get bookingDetails => 'Дата и время указаны в часовом поясе клиники.';

  @override
  String get chooseLanguage => 'Выбрать язык';

  @override
  String get guestGreeting => 'Добро пожаловать!';

  @override
  String get services => 'Услуги';

  @override
  String get promotions => 'Программы клиники';

  @override
  String get notifications => 'Уведомления';

  @override
  String get seeAll => 'Все';

  @override
  String get featuredDoctors => 'Специалисты нашей клиники';

  @override
  String get popularServices => 'Популярные услуги';

  @override
  String get popularSpecialties => 'Медицинские направления';

  @override
  String get bookAppointment => 'Записаться на приём';

  @override
  String get viewProfile => 'Профиль врача';

  @override
  String get searchDoctors => 'Поиск по имени врача';

  @override
  String get searchSpecialties => 'Поиск специальности';

  @override
  String get searchServices => 'Поиск услуги';

  @override
  String get allSpecialties => 'Все специальности';

  @override
  String get allCategories => 'Все категории';

  @override
  String get sortLabel => 'Сортировка';

  @override
  String get sortFeatured => 'Рекомендованные';

  @override
  String get sortName => 'По имени';

  @override
  String get sortPriceAsc => 'Сначала дешевле';

  @override
  String get sortPriceDesc => 'Сначала дороже';

  @override
  String get sortExperience => 'По опыту';

  @override
  String get noSearchResults => 'Ничего не найдено';

  @override
  String get searchEmptyBody => 'Попробуйте изменить поиск или фильтры.';

  @override
  String get loadMore => 'Показать ещё';

  @override
  String get professionalTitle => 'Специализация';

  @override
  String get experience => 'Опыт работы';

  @override
  String get education => 'Образование';

  @override
  String get qualifications => 'Квалификация';

  @override
  String get biography => 'О враче';

  @override
  String get spokenLanguages => 'Языки приёма';

  @override
  String get doctorServices => 'Услуги этого врача';

  @override
  String get scheduleOverview => 'График работы';

  @override
  String get scheduleDisclaimer =>
      'График не отражает свободные слоты. Доступность появится при онлайн-записи.';

  @override
  String get serviceDetails => 'Об услуге';

  @override
  String get price => 'Стоимость';

  @override
  String get duration => 'Продолжительность';

  @override
  String get category => 'Категория';

  @override
  String get doctorsOffering => 'Врачи, оказывающие услугу';

  @override
  String get contactClinic => 'Связаться с клиникой';

  @override
  String get contactFailed =>
      'Не удалось открыть приложение для звонка. Номер можно скопировать в разделе контактов.';

  @override
  String get bookingEntryTitle => 'Подготовка к записи';

  @override
  String get bookingEntryBody =>
      'Выберите врача и услугу. Онлайн-запись с выбором даты и времени появится на этапе 4. Сейчас вы можете связаться с клиникой.';

  @override
  String get selectDoctor => 'Выбрать врача';

  @override
  String get selectService => 'Выбрать услугу';

  @override
  String get selectionSummary => 'Ваш выбор';

  @override
  String get noPromotions => 'Сейчас нет активных программ';

  @override
  String get noNotifications => 'Пока нет уведомлений';

  @override
  String get saturday => 'Суббота';

  @override
  String get noSchedule => 'График уточняется в клинике';

  @override
  String get demoAvatar => 'Демонстрационная иллюстрация врача';

  @override
  String get promotionalIllustration => 'Иллюстрация программы клиники';

  @override
  String get filterSpecialty => 'Специальность';

  @override
  String get relatedServices => 'Услуги по направлению';

  @override
  String get relatedDoctors => 'Специалисты по направлению';

  @override
  String get moreDetails => 'Подробнее';

  @override
  String get selectedClinic => 'Ваша клиника';

  @override
  String get resetFilters => 'Сбросить фильтры';

  @override
  String greeting(String name) {
    return 'Здравствуйте, $name!';
  }

  @override
  String yearsExperience(int years) {
    return 'Опыт: $years лет';
  }

  @override
  String priceFrom(String price) {
    return 'от $price';
  }

  @override
  String serviceDuration(int minutes) {
    return '$minutes мин';
  }

  @override
  String specialtyDoctorCount(int count) {
    return 'Врачей: $count';
  }
}
