# :house: Hestia

**Hestia** *(nombre provisional)* es una app de gastos compartidos al estilo Tricount, pensada para llevar las cuentas entre mis padres y ver al instante quién debe a quién.

> *El nombre rinde tributo a la mitología griega: **Hestia**, diosa del hogar y la familia.*

### :tools: Stack Técnico
* **Lenguaje:** Kotlin
* **UI:** Jetpack Compose
* **Plataforma:** Android nativo
* **Arquitectura:** Clean Architecture
* **Persistencia y sincronización:** _(por decidir)_

### :moneybag: Modelo de datos
Se guardan los **hechos** (gastos y pagos), no los saldos. El saldo de cada persona se calcula a partir de ellos: :red_circle: si debe, :green_circle: si le deben y :white_circle: neutro cuando está saldado (reforzado con signo o icono por accesibilidad).

### :map: Roadmap
Actualmente preparando el proyecto y la automatización antes de escribir código.

- [x] Elección de stack (Kotlin, Compose, Android nativo)
- [x] Definición del modelo de datos (gastos como hechos, saldos calculados)
- [ ] Creación del proyecto y el repositorio
- [ ] Automatización (CI/CD, análisis estático, tests) antes de codear
- [ ] Organización del apartado de Hestia en Discord
- [ ] Elección de backend y sincronización en tiempo real
- [ ] MVP: gastos y saldos entre dos personas (padres)
- [ ] Registro de pagos para saldar deudas
- [ ] Sincronización casi en tiempo real entre móviles
- [ ] Ampliación a más miembros (hermana y yo)

**Repo:** _(pendiente)_
