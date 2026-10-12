import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'localization/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Clinic'**
  String get appTitle;

  /// No description provided for @chooseClinic.
  ///
  /// In en, this message translates to:
  /// **'Choose your clinic'**
  String get chooseClinic;

  /// No description provided for @chooseSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Care you can trust. Find the right place for your health.'**
  String get chooseSubtitle;

  /// No description provided for @clinicSelect.
  ///
  /// In en, this message translates to:
  /// **'Select clinic'**
  String get clinicSelect;

  /// No description provided for @ourClinics.
  ///
  /// In en, this message translates to:
  /// **'OUR CLINICS'**
  String get ourClinics;

  /// No description provided for @switchClinic.
  ///
  /// In en, this message translates to:
  /// **'Switch clinic'**
  String get switchClinic;

  /// No description provided for @clinicIllustration.
  ///
  /// In en, this message translates to:
  /// **'Medical center illustration'**
  String get clinicIllustration;

  /// No description provided for @demoContent.
  ///
  /// In en, this message translates to:
  /// **'Demonstration clinic'**
  String get demoContent;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @doctors.
  ///
  /// In en, this message translates to:
  /// **'Doctors'**
  String get doctors;

  /// No description provided for @specialties.
  ///
  /// In en, this message translates to:
  /// **'Specialties'**
  String get specialties;

  /// No description provided for @appointments.
  ///
  /// In en, this message translates to:
  /// **'Appointments'**
  String get appointments;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get language;

  /// No description provided for @russian.
  ///
  /// In en, this message translates to:
  /// **'Russian'**
  String get russian;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// No description provided for @noClinics.
  ///
  /// In en, this message translates to:
  /// **'No clinics available yet'**
  String get noClinics;

  /// No description provided for @noDoctors.
  ///
  /// In en, this message translates to:
  /// **'No doctors have been added'**
  String get noDoctors;

  /// No description provided for @noSpecialties.
  ///
  /// In en, this message translates to:
  /// **'No specialties have been added'**
  String get noSpecialties;

  /// No description provided for @noAppointments.
  ///
  /// In en, this message translates to:
  /// **'Your appointments will appear here'**
  String get noAppointments;

  /// No description provided for @noAppointmentsBody.
  ///
  /// In en, this message translates to:
  /// **'You have no appointments at this clinic yet.'**
  String get noAppointmentsBody;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Sign in with your phone'**
  String get login;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your appointments and personal information, always within reach.'**
  String get loginSubtitle;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get phone;

  /// No description provided for @countryCode.
  ///
  /// In en, this message translates to:
  /// **'Country code'**
  String get countryCode;

  /// No description provided for @phoneHint.
  ///
  /// In en, this message translates to:
  /// **'999 123 45 67'**
  String get phoneHint;

  /// No description provided for @sendCode.
  ///
  /// In en, this message translates to:
  /// **'Send verification code'**
  String get sendCode;

  /// No description provided for @phoneInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid international phone number'**
  String get phoneInvalid;

  /// No description provided for @otpTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify your number'**
  String get otpTitle;

  /// No description provided for @otpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the SMS code sent to'**
  String get otpSubtitle;

  /// No description provided for @otpCode.
  ///
  /// In en, this message translates to:
  /// **'SMS code'**
  String get otpCode;

  /// No description provided for @otpInvalidInput.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code'**
  String get otpInvalidInput;

  /// No description provided for @verify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verify;

  /// No description provided for @resend.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get resend;

  /// No description provided for @resendIn.
  ///
  /// In en, this message translates to:
  /// **'Resend available in'**
  String get resendIn;

  /// No description provided for @seconds.
  ///
  /// In en, this message translates to:
  /// **'s'**
  String get seconds;

  /// No description provided for @changePhone.
  ///
  /// In en, this message translates to:
  /// **'Change phone number'**
  String get changePhone;

  /// No description provided for @completeProfile.
  ///
  /// In en, this message translates to:
  /// **'Let’s get acquainted'**
  String get completeProfile;

  /// No description provided for @completeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'What should we call you? Add your name for future appointments.'**
  String get completeSubtitle;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fullName;

  /// No description provided for @nameInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a name between 2 and 120 characters'**
  String get nameInvalid;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email (optional)'**
  String get email;

  /// No description provided for @emailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get emailInvalid;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get logout;

  /// No description provided for @logoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get logoutTitle;

  /// No description provided for @logoutBody.
  ///
  /// In en, this message translates to:
  /// **'You will need to sign in again to access your appointments.'**
  String get logoutBody;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Care for your health'**
  String get welcome;

  /// No description provided for @welcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Find your doctor and get to know your clinic.'**
  String get welcomeSubtitle;

  /// No description provided for @clinicInformation.
  ///
  /// In en, this message translates to:
  /// **'About the clinic'**
  String get clinicInformation;

  /// No description provided for @contact.
  ///
  /// In en, this message translates to:
  /// **'Contact details'**
  String get contact;

  /// No description provided for @workingHours.
  ///
  /// In en, this message translates to:
  /// **'Working hours'**
  String get workingHours;

  /// No description provided for @timezone.
  ///
  /// In en, this message translates to:
  /// **'Time zone'**
  String get timezone;

  /// No description provided for @weekdays.
  ///
  /// In en, this message translates to:
  /// **'Weekdays'**
  String get weekdays;

  /// No description provided for @browseDoctors.
  ///
  /// In en, this message translates to:
  /// **'Find a doctor'**
  String get browseDoctors;

  /// No description provided for @exploreSpecialties.
  ///
  /// In en, this message translates to:
  /// **'Explore specialties'**
  String get exploreSpecialties;

  /// No description provided for @personalCare.
  ///
  /// In en, this message translates to:
  /// **'YOUR HEALTH, IN GOOD HANDS'**
  String get personalCare;

  /// No description provided for @signInRequired.
  ///
  /// In en, this message translates to:
  /// **'Sign in to view your appointments'**
  String get signInRequired;

  /// No description provided for @signInProfile.
  ///
  /// In en, this message translates to:
  /// **'Your personal account'**
  String get signInProfile;

  /// No description provided for @signInProfileBody.
  ///
  /// In en, this message translates to:
  /// **'Sign in to manage your profile and view appointments.'**
  String get signInProfileBody;

  /// No description provided for @developmentTitle.
  ///
  /// In en, this message translates to:
  /// **'Development mode · SMS is not configured'**
  String get developmentTitle;

  /// No description provided for @developmentBody.
  ///
  /// In en, this message translates to:
  /// **'Clinic browsing is available. Code verification and session creation are disabled.'**
  String get developmentBody;

  /// No description provided for @browseGuest.
  ///
  /// In en, this message translates to:
  /// **'Continue without signing in'**
  String get browseGuest;

  /// No description provided for @authUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Sign-in is temporarily unavailable. Please contact the clinic.'**
  String get authUnavailable;

  /// No description provided for @networkError.
  ///
  /// In en, this message translates to:
  /// **'No connection. Check your internet and try again.'**
  String get networkError;

  /// No description provided for @timeoutError.
  ///
  /// In en, this message translates to:
  /// **'The response is taking longer than usual. Please try again.'**
  String get timeoutError;

  /// No description provided for @sessionError.
  ///
  /// In en, this message translates to:
  /// **'Your session has expired. Please sign in again.'**
  String get sessionError;

  /// No description provided for @forbiddenError.
  ///
  /// In en, this message translates to:
  /// **'You do not have access to this information.'**
  String get forbiddenError;

  /// No description provided for @validationError.
  ///
  /// In en, this message translates to:
  /// **'Please check your information.'**
  String get validationError;

  /// No description provided for @serverError.
  ///
  /// In en, this message translates to:
  /// **'The service is temporarily unavailable. Please try later.'**
  String get serverError;

  /// No description provided for @notFoundError.
  ///
  /// In en, this message translates to:
  /// **'This information is no longer available.'**
  String get notFoundError;

  /// No description provided for @conflictError.
  ///
  /// In en, this message translates to:
  /// **'This time is already booked. Choose another slot.'**
  String get conflictError;

  /// No description provided for @responseError.
  ///
  /// In en, this message translates to:
  /// **'Information could not be loaded. Please try again.'**
  String get responseError;

  /// No description provided for @otpExpiredError.
  ///
  /// In en, this message translates to:
  /// **'The code expired or is invalid. Request a new code.'**
  String get otpExpiredError;

  /// No description provided for @otpInvalidError.
  ///
  /// In en, this message translates to:
  /// **'Incorrect code. Check your SMS and try again.'**
  String get otpInvalidError;

  /// No description provided for @rateLimitError.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please wait and try again.'**
  String get rateLimitError;

  /// No description provided for @storageError.
  ///
  /// In en, this message translates to:
  /// **'Settings could not be saved on this device.'**
  String get storageError;

  /// No description provided for @unknownError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get unknownError;

  /// No description provided for @profileRetry.
  ///
  /// In en, this message translates to:
  /// **'Your profile could not be loaded'**
  String get profileRetry;

  /// No description provided for @bookLater.
  ///
  /// In en, this message translates to:
  /// **'Online booking is coming in a subsequent phase. You can contact the clinic in the meantime.'**
  String get bookLater;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// No description provided for @confirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get confirmed;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @cancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get cancelled;

  /// No description provided for @noShow.
  ///
  /// In en, this message translates to:
  /// **'No show'**
  String get noShow;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @healthCare.
  ///
  /// In en, this message translates to:
  /// **'Care close to you'**
  String get healthCare;

  /// No description provided for @bookingDetails.
  ///
  /// In en, this message translates to:
  /// **'Dates and times are shown in the clinic’s time zone.'**
  String get bookingDetails;

  /// No description provided for @chooseLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose language'**
  String get chooseLanguage;

  /// No description provided for @guestGreeting.
  ///
  /// In en, this message translates to:
  /// **'Welcome!'**
  String get guestGreeting;

  /// No description provided for @services.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get services;

  /// No description provided for @promotions.
  ///
  /// In en, this message translates to:
  /// **'Clinic programs'**
  String get promotions;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @seeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get seeAll;

  /// No description provided for @featuredDoctors.
  ///
  /// In en, this message translates to:
  /// **'Meet our specialists'**
  String get featuredDoctors;

  /// No description provided for @popularServices.
  ///
  /// In en, this message translates to:
  /// **'Popular services'**
  String get popularServices;

  /// No description provided for @popularSpecialties.
  ///
  /// In en, this message translates to:
  /// **'Medical specialties'**
  String get popularSpecialties;

  /// No description provided for @bookAppointment.
  ///
  /// In en, this message translates to:
  /// **'Book an appointment'**
  String get bookAppointment;

  /// No description provided for @viewProfile.
  ///
  /// In en, this message translates to:
  /// **'View profile'**
  String get viewProfile;

  /// No description provided for @searchDoctors.
  ///
  /// In en, this message translates to:
  /// **'Search doctors by name'**
  String get searchDoctors;

  /// No description provided for @searchSpecialties.
  ///
  /// In en, this message translates to:
  /// **'Search specialties'**
  String get searchSpecialties;

  /// No description provided for @searchServices.
  ///
  /// In en, this message translates to:
  /// **'Search services'**
  String get searchServices;

  /// No description provided for @allSpecialties.
  ///
  /// In en, this message translates to:
  /// **'All specialties'**
  String get allSpecialties;

  /// No description provided for @allCategories.
  ///
  /// In en, this message translates to:
  /// **'All categories'**
  String get allCategories;

  /// No description provided for @sortLabel.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get sortLabel;

  /// No description provided for @sortFeatured.
  ///
  /// In en, this message translates to:
  /// **'Featured'**
  String get sortFeatured;

  /// No description provided for @sortName.
  ///
  /// In en, this message translates to:
  /// **'By name'**
  String get sortName;

  /// No description provided for @sortPriceAsc.
  ///
  /// In en, this message translates to:
  /// **'Price: low to high'**
  String get sortPriceAsc;

  /// No description provided for @sortPriceDesc.
  ///
  /// In en, this message translates to:
  /// **'Price: high to low'**
  String get sortPriceDesc;

  /// No description provided for @sortExperience.
  ///
  /// In en, this message translates to:
  /// **'Most experienced'**
  String get sortExperience;

  /// No description provided for @noSearchResults.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get noSearchResults;

  /// No description provided for @searchEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Try changing your search or filters.'**
  String get searchEmptyBody;

  /// No description provided for @loadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get loadMore;

  /// No description provided for @professionalTitle.
  ///
  /// In en, this message translates to:
  /// **'Professional title'**
  String get professionalTitle;

  /// No description provided for @experience.
  ///
  /// In en, this message translates to:
  /// **'Experience'**
  String get experience;

  /// No description provided for @education.
  ///
  /// In en, this message translates to:
  /// **'Education'**
  String get education;

  /// No description provided for @qualifications.
  ///
  /// In en, this message translates to:
  /// **'Qualifications'**
  String get qualifications;

  /// No description provided for @biography.
  ///
  /// In en, this message translates to:
  /// **'About the doctor'**
  String get biography;

  /// No description provided for @spokenLanguages.
  ///
  /// In en, this message translates to:
  /// **'Spoken languages'**
  String get spokenLanguages;

  /// No description provided for @doctorServices.
  ///
  /// In en, this message translates to:
  /// **'Services with this doctor'**
  String get doctorServices;

  /// No description provided for @scheduleOverview.
  ///
  /// In en, this message translates to:
  /// **'Schedule overview'**
  String get scheduleOverview;

  /// No description provided for @scheduleDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Working hours do not indicate free slots. Availability will be shown during booking.'**
  String get scheduleDisclaimer;

  /// No description provided for @serviceDetails.
  ///
  /// In en, this message translates to:
  /// **'About this service'**
  String get serviceDetails;

  /// No description provided for @price.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get price;

  /// No description provided for @duration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get duration;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @doctorsOffering.
  ///
  /// In en, this message translates to:
  /// **'Doctors offering this service'**
  String get doctorsOffering;

  /// No description provided for @contactClinic.
  ///
  /// In en, this message translates to:
  /// **'Contact the clinic'**
  String get contactClinic;

  /// No description provided for @contactFailed.
  ///
  /// In en, this message translates to:
  /// **'The calling app could not be opened. You can copy the number from contact details.'**
  String get contactFailed;

  /// No description provided for @bookingEntryTitle.
  ///
  /// In en, this message translates to:
  /// **'Prepare your appointment'**
  String get bookingEntryTitle;

  /// No description provided for @bookingEntryBody.
  ///
  /// In en, this message translates to:
  /// **'Choose a doctor and service. Online date and time selection is coming in Phase 4. You can contact the clinic now.'**
  String get bookingEntryBody;

  /// No description provided for @selectDoctor.
  ///
  /// In en, this message translates to:
  /// **'Choose a doctor'**
  String get selectDoctor;

  /// No description provided for @selectService.
  ///
  /// In en, this message translates to:
  /// **'Choose a service'**
  String get selectService;

  /// No description provided for @selectionSummary.
  ///
  /// In en, this message translates to:
  /// **'Your selection'**
  String get selectionSummary;

  /// No description provided for @noPromotions.
  ///
  /// In en, this message translates to:
  /// **'No active programs right now'**
  String get noPromotions;

  /// No description provided for @noNotifications.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get noNotifications;

  /// No description provided for @saturday.
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get saturday;

  /// No description provided for @noSchedule.
  ///
  /// In en, this message translates to:
  /// **'Contact the clinic for working hours'**
  String get noSchedule;

  /// No description provided for @demoAvatar.
  ///
  /// In en, this message translates to:
  /// **'Demonstration doctor illustration'**
  String get demoAvatar;

  /// No description provided for @promotionalIllustration.
  ///
  /// In en, this message translates to:
  /// **'Clinic program illustration'**
  String get promotionalIllustration;

  /// No description provided for @filterSpecialty.
  ///
  /// In en, this message translates to:
  /// **'Specialty'**
  String get filterSpecialty;

  /// No description provided for @relatedServices.
  ///
  /// In en, this message translates to:
  /// **'Services in this specialty'**
  String get relatedServices;

  /// No description provided for @relatedDoctors.
  ///
  /// In en, this message translates to:
  /// **'Specialists in this field'**
  String get relatedDoctors;

  /// No description provided for @moreDetails.
  ///
  /// In en, this message translates to:
  /// **'Learn more'**
  String get moreDetails;

  /// No description provided for @selectedClinic.
  ///
  /// In en, this message translates to:
  /// **'Your clinic'**
  String get selectedClinic;

  /// No description provided for @resetFilters.
  ///
  /// In en, this message translates to:
  /// **'Reset filters'**
  String get resetFilters;

  /// No description provided for @greeting.
  ///
  /// In en, this message translates to:
  /// **'Hello, {name}!'**
  String greeting(String name);

  /// No description provided for @yearsExperience.
  ///
  /// In en, this message translates to:
  /// **'Experience: {years} years'**
  String yearsExperience(int years);

  /// No description provided for @priceFrom.
  ///
  /// In en, this message translates to:
  /// **'From {price}'**
  String priceFrom(String price);

  /// No description provided for @serviceDuration.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String serviceDuration(int minutes);

  /// No description provided for @specialtyDoctorCount.
  ///
  /// In en, this message translates to:
  /// **'Doctors: {count}'**
  String specialtyDoctorCount(int count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
