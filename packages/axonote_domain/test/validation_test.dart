import 'package:axonote_domain/axonote_domain.dart';
import 'package:test/test.dart';

/// Casos portados de `notify_web/src/lib/domain/domain.spec.ts` y ampliados con los demás códigos
/// de `validation.ts`.
void main() {
  group('isValidEmail', () {
    test('acepta correos con forma válida, con espacios alrededor', () {
      expect(isValidEmail('ana@correo.com'), isTrue);
      expect(isValidEmail(' ana@correo.com '), isTrue);
    });

    test('rechaza los que no la tienen', () {
      for (final bad in [
        '',
        'ana',
        'ana@',
        '@correo.com',
        'ana@correo',
        'ana@correo.c',
        'ana correo.com',
      ]) {
        expect(isValidEmail(bad), isFalse, reason: bad);
      }
    });
  });

  group('passwordStrength', () {
    test('escala de 0 a 4 con la misma etiqueta que la web', () {
      expect(passwordStrength('').score, 0);
      expect(passwordStrength('abc').score, 0);
      expect(passwordStrength('abcdefgh').score, 1);
      expect(passwordStrength('Abcdefgh').score, 2);
      expect(passwordStrength('Abcdefg1').score, 3);
      final strong = passwordStrength('Abcdef1!');
      expect(strong.score, 4);
      expect(strong.label, 'Fuerte');
    });
  });

  group('validateRegister', () {
    test('nombre corto, correo inválido, contraseña corta y términos sin aceptar', () {
      final v = validateRegister(
        const RegisterInput(
          fullName: 'A',
          email: 'no-es-correo',
          password: 'corta',
          acceptedTerms: false,
        ),
      );
      expect(v, isA<Invalid>());
      expect((v as Invalid).errors, {
        'fullName': 'name-too-short',
        'email': 'invalid-email',
        'password': 'password-too-short',
        'acceptedTerms': 'terms-required',
      });
    });

    test('correo vacío da «required»', () {
      final v = validateRegister(
        const RegisterInput(
          fullName: 'Ana',
          email: '',
          password: 'Secret123!',
          acceptedTerms: true,
        ),
      );
      expect((v as Invalid).errors, {'email': 'required'});
    });

    test('un formulario correcto es válido', () {
      expect(
        validateRegister(
          const RegisterInput(
            fullName: 'Ana',
            email: 'ana@correo.com',
            password: 'Secret123!',
            acceptedTerms: true,
          ),
        ),
        isA<Valid>(),
      );
    });
  });

  group('validateLogin', () {
    test('campos vacíos', () {
      expect(validateLogin(const LoginInput(email: '', password: '')), isA<Invalid>());
      final v =
          validateLogin(const LoginInput(email: '', password: '')) as Invalid;
      expect(v.errors, {'email': 'required', 'password': 'required'});
    });

    test('correo válido y contraseña presente', () {
      expect(
        validateLogin(const LoginInput(email: 'ana@correo.com', password: 'x')),
        isA<Valid>(),
      );
    });
  });

  group('validateEmail', () {
    test('vacío → required; inválido → invalid-email; válido → valid', () {
      expect((validateEmail('  ') as Invalid).errors, {'email': 'required'});
      expect((validateEmail('nope') as Invalid).errors, {
        'email': 'invalid-email',
      });
      expect(validateEmail('ana@correo.com'), isA<Valid>());
    });
  });

  group('validateNewPassword', () {
    test('no coinciden', () {
      expect((validateNewPassword('Secret123!', 'otra') as Invalid).errors, {
        'confirmation': 'passwords-dont-match',
      });
    });

    test('contraseña corta', () {
      expect((validateNewPassword('corta', 'corta') as Invalid).errors, {
        'password': 'password-too-short',
      });
    });

    test('coincide y es larga → válida', () {
      expect(
        validateNewPassword('Secret123!', 'Secret123!'),
        isA<Valid>(),
      );
    });
  });

  group('validateVerificationCode', () {
    test('6 dígitos vale; el resto no', () {
      expect(validateVerificationCode('123456'), isA<Valid>());
      for (final bad in ['', '12345', '1234567', '12a456']) {
        expect(validateVerificationCode(bad), isA<Invalid>(), reason: bad);
      }
    });
  });

  group('validateMfaCode', () {
    test('acepta TOTP de 6 dígitos y códigos de respaldo', () {
      expect(validateMfaCode('123456'), isA<Valid>());
      expect(validateMfaCode('ABCDE-23456'), isA<Valid>());
    });

    test('rechaza otras formas', () {
      for (final bad in ['', '12345', 'abcdef', 'ABCDE12345', 'abcde-23456']) {
        expect(validateMfaCode(bad), isA<Invalid>(), reason: bad);
      }
    });
  });

  group('validateProfileName', () {
    test('menos de 2 caracteres no vale', () {
      expect((validateProfileName(' A ') as Invalid).errors, {
        'fullName': 'name-too-short',
      });
      expect(validateProfileName('Ana'), isA<Valid>());
    });
  });

  group('validateEmailChange', () {
    test('correo y contraseña obligatorios', () {
      expect((validateEmailChange('', '') as Invalid).errors, {
        'email': 'required',
        'password': 'required',
      });
      expect((validateEmailChange('nope', 'x') as Invalid).errors, {
        'email': 'invalid-email',
      });
      expect(validateEmailChange('ana@correo.com', 'x'), isA<Valid>());
    });
  });

  group('validateChangePassword', () {
    test('actual vacía, nueva corta y sin coincidir', () {
      expect((validateChangePassword('', 'corta', 'otra') as Invalid).errors, {
        'currentPassword': 'required',
        'password': 'password-too-short',
        'confirmation': 'passwords-dont-match',
      });
    });

    test('la nueva no puede ser igual a la actual', () {
      expect(
        (validateChangePassword('Actual123!', 'Actual123!', 'Actual123!')
                as Invalid)
            .errors,
        {'password': 'same-password'},
      );
    });

    test('correcta', () {
      expect(
        validateChangePassword('Actual123!', 'Nueva123!', 'Nueva123!'),
        isA<Valid>(),
      );
    });
  });

  group('validatePasswordReset', () {
    test('exige confirmación de borrado en modo wipe', () {
      expect(
        (validatePasswordReset(
          'Secret123!',
          'Secret123!',
          (recoveryKey: null, wipeConfirmed: false),
        ) as Invalid)
            .errors,
        {'wipe': 'wipe-not-confirmed'},
      );
    });

    test('exige la clave de recuperación en modo keep', () {
      expect(
        (validatePasswordReset(
          'Secret123!',
          'Secret123!',
          (recoveryKey: '  ', wipeConfirmed: null),
        ) as Invalid)
            .errors,
        {'recoveryKey': 'required'},
      );
    });
  });

  group('validateFolderName', () {
    const existing = ['Universidad', 'Personal'];

    test('vacío → required', () {
      expect((validateFolderName('  ', existing) as Invalid).errors, {
        'name': 'required',
      });
    });

    test('demasiado largo', () {
      expect(
        (validateFolderName('x' * 31, existing) as Invalid).errors,
        {'name': 'name-too-long'},
      );
    });

    test('duplicado sin distinguir mayúsculas ni tildes', () {
      expect(
        (validateFolderName('universidad', existing) as Invalid).errors,
        {'name': 'name-taken'},
      );
      expect(
        (validateFolderName('RÉCETAS', ['Recetas']) as Invalid).errors,
        {'name': 'name-taken'},
      );
    });

    test('nuevo nombre válido', () {
      expect(validateFolderName('Proyectos', existing), isA<Valid>());
    });
  });

  group('isMfaCode', () {
    test('coincide con la validación', () {
      expect(isMfaCode('123456'), isTrue);
      expect(isMfaCode('ABCDE-23456'), isTrue);
      expect(isMfaCode('12345'), isFalse);
    });
  });
}
