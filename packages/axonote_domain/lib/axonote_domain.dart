/// Dominio de AxoNote: entidades, errores, validación y reglas.
///
/// De momento solo se implementan los errores de aplicación ([AppError] y [AppFailure]), que el
/// plan (§4.3) sitúa aquí y que necesita `axonote_api`. Las entidades y reglas llegan en sus fases.
library;

export 'src/errors.dart';
export 'src/lock_settings.dart';
