import 'document.dart';

/// Términos de uso. BORRADOR: los revisa un abogado antes de publicarse. Portado de
/// `notify_web/src/lib/legal/terms.ts`.
final LegalDocument terms = LegalDocument(
  title: 'Términos de uso',
  version: 'borrador-1',
  effectiveDate: null,
  status: legalDraft ? LegalStatus.draft : LegalStatus.inForce,
  intro:
      'Estos términos regulan el uso de AxoNote, un servicio de notas con cifrado de extremo a '
      'extremo ofrecido por ${responsible.name} (NIT ${responsible.nit}), de '
      '${responsible.city}, ${responsible.country}. Al crear una cuenta o usar AxoNote aceptas '
      'estos términos y la Política de privacidad.',
  sections: [
    const LegalSection(
      id: 'servicio',
      title: '1. El servicio',
      blocks: [
        LegalParagraph(
          'AxoNote te permite escribir notas en Markdown, organizarlas en carpetas, buscarlas, '
          'sincronizarlas entre tus dispositivos, compartirlas mediante enlaces públicos de solo '
          'lectura y recuperarlas desde la papelera. Funciona sin conexión y sincroniza cuando hay '
          'red.',
        ),
      ],
    ),
    const LegalSection(
      id: 'cuenta',
      title: '2. Tu cuenta',
      blocks: [
        LegalList([
          'Debes ser mayor de 18 años y darnos un correo que controles y datos veraces.',
          'Eres responsable de mantener segura tu contraseña, tu clave de recuperación y tus '
              'dispositivos, y de lo que ocurra con tu cuenta.',
          'Avísanos de inmediato si crees que alguien accedió a tu cuenta. Puedes cerrar sesiones '
              'desde Ajustes → Dispositivos.',
          'Una persona puede tener una cuenta; no puedes cederla ni venderla.',
        ]),
      ],
    ),
    const LegalSection(
      id: 'no-recuperacion',
      title: '3. Cifrado y pérdida de la contraseña',
      blocks: [
        LegalParagraph(
          'Tus notas se cifran en tu dispositivo con una clave derivada de tu contraseña. AXONOTE '
          'no tiene esa clave.',
        ),
        LegalCallout(
          'Si pierdes tu contraseña y tu clave de recuperación, no podremos recuperar tus notas ni '
          'restablecer el acceso a ellas. Restablecer la contraseña sin la clave de recuperación '
          'elimina las notas guardadas en el servidor. Aceptas este riesgo al usar el servicio.',
        ),
      ],
    ),
    const LegalSection(
      id: 'contenido',
      title: '4. Tu contenido',
      blocks: [
        LegalList([
          'Tus notas son tuyas. No adquirimos ningún derecho sobre ellas más allá de almacenarlas '
              'y sincronizarlas para prestarte el servicio.',
          'Como no podemos ver su contenido, tú eres el único responsable de lo que escribes y '
              'compartes.',
          'Cuando creas un enlace público, cualquiera que tenga el enlace completo puede leer esa '
              'nota. Puedes desactivar el enlace en cualquier momento; copias que otras personas ya '
              'hayan guardado no podemos retirarlas.',
        ]),
      ],
    ),
    const LegalSection(
      id: 'uso-aceptable',
      title: '5. Uso aceptable',
      blocks: [
        LegalParagraph('No puedes usar AxoNote para:'),
        LegalList([
          'Actividades ilegales o que vulneren derechos de terceros, incluido compartir contenido '
              'ilícito mediante enlaces públicos.',
          'Intentar acceder a cuentas o datos ajenos, eludir los límites o medidas de seguridad, o '
              'sobrecargar el servicio.',
          'Automatizar el registro de cuentas o abusar de los envíos de correo.',
          'Hacer ingeniería inversa del servicio salvo lo que la ley permita.',
        ]),
        LegalParagraph(
          'Si incumples estos términos podemos limitar o suspender la cuenta. Dado que no vemos el '
          'contenido cifrado, actuaremos sobre los enlaces públicos y los datos de uso que sí '
          'conocemos.',
        ),
      ],
    ),
    const LegalSection(
      id: 'almacenamiento',
      title: '6. Almacenamiento y límites',
      blocks: [
        LegalParagraph(
          'Cada cuenta tiene un límite de almacenamiento, visible en Ajustes → Almacenamiento. Al '
          'alcanzarlo no podrás subir cambios nuevos hasta liberar espacio. Las notas en la '
          'papelera se eliminan definitivamente a los 30 días.',
        ),
      ],
    ),
    const LegalSection(
      id: 'disponibilidad',
      title: '7. Disponibilidad y cambios',
      blocks: [
        LegalParagraph(
          'Hacemos lo razonable por mantener el servicio disponible, pero puede haber '
          'interrupciones por mantenimiento o fallos. Puedes seguir usando tu copia local sin '
          'conexión. Podemos mejorar, cambiar o retirar funciones; si retiramos el servicio te '
          'avisaremos con antelación razonable para que exportes tus notas.',
        ),
      ],
    ),
    const LegalSection(
      id: 'eliminacion',
      title: '8. Eliminar tu cuenta',
      blocks: [
        LegalParagraph(
          'Puedes eliminar tu cuenta en Ajustes → Eliminar cuenta, confirmando con tu contraseña. '
          'Se cerrarán todas tus sesiones y tus datos se conservarán 30 días por si cambias de '
          'opinión; después se borran definitivamente.',
        ),
      ],
    ),
    const LegalSection(
      id: 'responsabilidad',
      title: '9. Responsabilidad',
      blocks: [
        LegalParagraph(
          'El servicio se ofrece «tal cual», sin garantías que la ley no obligue a dar. En la '
          'medida permitida por la ley, AXONOTE no responde por pérdidas indirectas ni por la '
          'pérdida de notas causada por olvidar la contraseña y la clave de recuperación, por '
          'fallos de tus dispositivos o por el uso indebido de tus credenciales. [[REVISAR: límites '
          'de responsabilidad conforme al Estatuto del Consumidor (Ley 1480 de 2011) y demás normas '
          'aplicables.]]',
        ),
      ],
    ),
    const LegalSection(
      id: 'datos-personales',
      title: '10. Datos personales',
      blocks: [
        LegalParagraph(
          'El tratamiento de tus datos personales se rige por la Política de privacidad, que forma '
          'parte de estos términos.',
        ),
      ],
    ),
    const LegalSection(
      id: 'cambios',
      title: '11. Cambios a los términos',
      blocks: [
        LegalParagraph(
          'Podemos actualizar estos términos. Si el cambio es sustancial te avisaremos en la app o '
          'por correo antes de que aplique; si sigues usando AxoNote después, se entiende que lo '
          'aceptas. La versión vigente y su fecha aparecen al inicio de esta página.',
        ),
      ],
    ),
    LegalSection(
      id: 'ley',
      title: '12. Ley aplicable y jurisdicción',
      blocks: [
        LegalParagraph(
          'Estos términos se rigen por las leyes de la República de Colombia. Las controversias se '
          'someterán a los jueces competentes de ${responsible.city}, sin perjuicio de los derechos '
          'que la ley otorgue a los consumidores. [[REVISAR]]',
        ),
      ],
    ),
    LegalSection(
      id: 'contacto',
      title: '13. Contacto',
      blocks: [
        LegalParagraph(
          'Para dudas sobre estos términos escribe a ${responsible.email}.',
        ),
      ],
    ),
  ],
);
