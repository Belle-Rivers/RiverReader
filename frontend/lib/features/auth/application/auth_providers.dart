import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/registration_api.dart';

final registrationApiProvider = Provider<RegistrationApi>((ref) => RegistrationApi());
